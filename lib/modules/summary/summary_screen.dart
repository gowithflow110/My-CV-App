import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class SummaryScreen extends StatelessWidget {
  final Map<String, dynamic> cvData;
  final int totalSections;

  const SummaryScreen({
    Key? key,
    required this.cvData,
    required this.totalSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> sectionOrder = [
      'name',
      'contact',
      'education',
      'experience',
      'skills',
      'projects',
      'certifications',
      'languages',
      'summary',
    ];

    int completedSections = sectionOrder.where((key) {
      final value = cvData[key];
      if (value == null) return false;
      if (value is List) return value.isNotEmpty;
      return value.toString().trim().isNotEmpty;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your CV Input'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Completion Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Section Progress",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Chip(
                  label: Text("$completedSections / $totalSections"),
                  backgroundColor: Colors.deepPurple.shade50,
                  labelStyle: const TextStyle(color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: sectionOrder.length,
                itemBuilder: (context, index) {
                  final key = sectionOrder[index];
                  final value = cvData[key];

                  final bool isCompleted = value != null &&
                      ((value is List && value.isNotEmpty) ||
                          (value is String && value.trim().isNotEmpty));

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ExpansionTile(
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.info_outline,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        key[0].toUpperCase() + key.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Chip(
                        label: Text(isCompleted ? "Completed" : "Skipped"),
                        backgroundColor: isCompleted
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                        labelStyle: TextStyle(
                          color: isCompleted ? Colors.green.shade800 : Colors.grey.shade800,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                          child: value == null || (value is List && value.isEmpty) || (value is String && value.trim().isEmpty)
                              ? const Text("No input provided.")
                              : value is List
                              ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (value as List)
                                .map((e) => Text("• $e"))
                                .toList(),
                          )
                              : Text(value.toString()),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            /// ✅ Generate Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.aiProcessing,
                  arguments: {
                    'cvData': cvData,
                  },
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Professional CV"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "AI will polish your content and convert it into a professional CV.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
