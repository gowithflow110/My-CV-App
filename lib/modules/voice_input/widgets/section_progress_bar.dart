//section_progress_bar.dart

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
    final double progress = (currentIndex + 1) / totalSections;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ✅ Section Info + Optional Indicator
          Row(
            children: [
              Text(
                'Section ${currentIndex + 1} of $totalSections',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (!required)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Optional",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          /// ✅ Title + Completion Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasCompleted)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),

          /// ✅ Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
