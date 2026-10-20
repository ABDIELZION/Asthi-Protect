import 'package:flutter/material.dart';

const _questions = <String, Map<String, String>>{
  'pain_walking': {'en': 'Knee pain while walking', 'hi': 'चलते समय घुटने में दर्द'},
  'pain_stairs': {'en': 'Knee pain on stairs', 'hi': 'सीढ़ियाँ चढ़ते समय घुटने में दर्द'},
  'stiffness': {'en': 'Morning knee stiffness', 'hi': 'सुबह घुटने में जकड़न'},
  'bending': {'en': 'Difficulty bending the knee', 'hi': 'घुटना मोड़ने में कठिनाई'},
  'giving_way': {'en': 'Knee feels like giving way', 'hi': 'घुटना झुकने जैसा लगता है'},
};

const _scale = {
  'en': ['None', 'Mild', 'Moderate', 'Severe', 'Extreme'],
  'hi': ['नहीं', 'हल्का', 'मध्यम', 'गंभीर', 'बहुत अधिक'],
};

class QuestionnaireScreen extends StatefulWidget {
  final Map<String, int> answers;
  const QuestionnaireScreen({super.key, required this.answers});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  String _lang = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptoms'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _lang = _lang == 'en' ? 'hi' : 'en'),
            child: Text(_lang == 'en' ? 'हिंदी' : 'English',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final q in _questions.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.value[_lang]!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: [
                        for (var i = 0; i < 5; i++)
                          ButtonSegment(value: i, label: Text(_scale[_lang]![i])),
                      ],
                      selected: {widget.answers[q.key] ?? 0},
                      onSelectionChanged: (s) =>
                          setState(() => widget.answers[q.key] = s.first),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
