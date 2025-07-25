import 'package:flutter/material.dart';

class SectionProgressBar extends StatelessWidget {
  final int currentIndex;
  final int totalSections;
  final String title;
  final bool required;
  final bool hasCompleted;

  const SectionProgressBar({
    Key? key,
    required this.currentIndex,
    required this.totalSections,
    required this.title,
    required this.required,
    required this.hasCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section ${currentIndex + 1} of $totalSections',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '🧠 $title ${!required ? '(Optional)' : ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasCompleted)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ],
    );
  }
}
