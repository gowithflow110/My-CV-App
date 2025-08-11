//live_text_display.dart

import 'package:flutter/material.dart';

class LiveTextDisplay extends StatelessWidget {
  final String transcription;

  const LiveTextDisplay({
    Key? key,
    required this.transcription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          transcription.isEmpty
              ? 'Your voice input will appear here...'
              : transcription,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}