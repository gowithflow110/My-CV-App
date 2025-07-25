import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> cvData;
  final int totalSections;

  const ResultScreen({
    Key? key,
    required this.cvData,
    required this.totalSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int completedSections = cvData.entries
        .where((entry) => entry.value is List
        ? (entry.value as List).isNotEmpty
        : entry.value.toString().trim().isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Summary Result'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              "Your CV data has been successfully processed!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            /// ✅ Summary Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CV Summary",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("👤 Name: ${cvData['name'] ?? 'Not provided'}"),
                    Text(
                        "🎓 Education Entries: ${(cvData['education'] as List?)?.length ?? 0}"),
                    Text(
                        "💼 Work Experiences: ${(cvData['experience'] as List?)?.length ?? 0}"),
                    Text(
                        "🛠 Skills: ${(cvData['skills'] as List?)?.length ?? 0}"),
                    const SizedBox(height: 10),

                    /// ✅ Progress
                    Text(
                      "Progress: $completedSections / $totalSections sections completed",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: completedSections / totalSections,
                      color: Colors.green,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            /// ✅ Buttons
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.aiProcessing, // Go to AI Screen
                  arguments: cvData, // ✅ FIXED HERE
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Preview My CV (AI-Polished)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.downloadShare,
                  arguments: cvData,
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Go to Download/Share"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
