import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/screening.dart';

class Storage {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'asthi_protect.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE screenings('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'created_at TEXT,'
        'gait_json TEXT,'
        'flags_json TEXT,'
        'questionnaire_json TEXT,'
        'band_json TEXT,'
        'risk_level TEXT,'
        'referral TEXT,'
        'synced INTEGER DEFAULT 0)',
      ),
    );
    return _db!;
  }

  static Future<int> insert(Screening s) async {
    final db = await _open();
    return db.insert('screenings', {
      'created_at': s.createdAt.toIso8601String(),
      'gait_json': jsonEncode(s.gaitMetrics),
      'flags_json': jsonEncode(s.gaitFlags),
      'questionnaire_json': jsonEncode(s.questionnaire),
      'band_json': jsonEncode(s.band.toJson()),
      'risk_level': s.riskLevel,
      'referral': s.referral,
      'synced': 0,
    });
  }

  static Future<List<Screening>> list() async {
    final db = await _open();
    final rows = await db.query('screenings', orderBy: 'created_at DESC');
    return rows
        .map((r) => Screening(
              id: r['id'] as int,
              createdAt: DateTime.parse(r['created_at'] as String),
              gaitMetrics: jsonDecode(r['gait_json'] as String) as Map<String, dynamic>,
              gaitFlags: (jsonDecode(r['flags_json'] as String) as List).cast<String>(),
              questionnaire:
                  (jsonDecode(r['questionnaire_json'] as String) as Map<String, dynamic>)
                      .map((k, v) => MapEntry(k, v as int)),
              band: BandSummary.fromJson(
                  jsonDecode(r['band_json'] as String) as Map<String, dynamic>),
              riskLevel: r['risk_level'] as String,
              referral: r['referral'] as String,
              synced: (r['synced'] as int) == 1,
            ))
        .toList();
  }

  static Future<List<Screening>> unsynced() async =>
      (await list()).where((s) => !s.synced).toList();

  static Future<void> markSynced(int id) async {
    final db = await _open();
    await db.update('screenings', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
