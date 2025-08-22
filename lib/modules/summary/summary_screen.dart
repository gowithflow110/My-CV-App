// lib/modules/summary/summary_screen.dart

import 'package:flutter/material.dart';
import '../../models/cv_model.dart';
import '../ai_animation/ai_processing_screen.dart';
import '../../routes/app_routes.dart';

class SummaryScreen extends StatefulWidget {
  final CVModel cv;

  const SummaryScreen({Key? key, required this.cv}) : super(key: key);

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late CVModel _cvModel;

  @override
  void initState() {
    super.initState();
    _cvModel = widget.cv;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _getSections(_cvModel.cvData);
    final completedCount =
        sections.where((s) => s['isCompleted'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Summary"),
        centerTitle: true,
        backgroundColor: const Color(0xFFE8F3F8), // ✅ same head color
        elevation: 0, // ✅ flat clean look
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 0,
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$completedCount of ${sections.length} sections completed",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Tooltip(
                        message:
                        "AI will expand and improve your input automatically.",
                        child:
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    bool isExpanded = false;

                    return StatefulBuilder(
                      builder: (context, setState) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color:
                            isExpanded ? Colors.blue.shade50 : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        Icon(
                                          section['isCompleted']
                                              ? Icons.check_circle
                                              : Icons.remove_circle,
                                          color: section['isCompleted']
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            section['title'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blueAccent),
                                          tooltip: "Edit this section",
                                          onPressed: () async {
                                            final key = section['key'];
                                            final content =
                                            _cvModel.cvData[key];
                                            dynamic previousData;

                                            if (content is List) {
                                              previousData =
                                              List<String>.from(content);
                                            } else {
                                              previousData =
                                                  content?.toString() ?? '';
                                            }

                                            final result =
                                            await Navigator.pushNamed(
                                              context,
                                              AppRoutes.voiceInput,
                                              arguments: {
                                                'forceEdit': true,
                                                'editField': key,
                                                'previousData': previousData,
                                              },
                                            );

                                            if (result is CVModel) {
                                              setState(() {
                                                _cvModel = result;
                                              });
                                            } else if (result
                                            is Map<String, dynamic>) {
                                              setState(() {
                                                _cvModel.cvData.addAll(result);
                                              });
                                            }
                                          },
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isExpanded)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: _buildSectionContent(
                                          section['content'], section['key']),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade700.withOpacity(0.85),
                      Colors.blue.shade400.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AIProcessingScreen(rawCV: _cvModel),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            "Generate Professional CV",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(dynamic content, String key) {
    if (content == null) {
      return const Text(
        "No input provided",
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    // Single entry: use small grey bullet
    if (content is String && content.trim().isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.stop_circle, size: 10, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              content.trim(),
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      );
    }

    // Multiple entries: blue bullet
    if (content is List && content.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(content.length, (index) {
          final item = content[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 8, color: Colors.blueAccent),
                ),
                Expanded(
                  child: _buildEntryText(item),
                ),
              ],
            ),
          );
        }),
      );
    }

    return Text(content.toString());
  }

  Widget _buildEntryText(dynamic item) {
    if (item is Map && item.containsKey('role')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${item['role']} at ${item['company']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          if (item['years'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item['years'],
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          if (item['details'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item['details'],
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ),
        ],
      );
    }

    return Text(
      item.toString(),
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }

  List<Map<String, dynamic>> _getSections(Map<String, dynamic> cvData) {
    final sectionList = [
      {'title': "Full Name", 'key': "name"},
      {'title': "Contact Info", 'key': "contact"},
      {'title': "Education", 'key': "education"},
      {'title': "Skills", 'key': "skills"},
      {'title': "Languages", 'key': "languages"},
      {'title': "Certifications", 'key': "certifications"},
      {'title': "Work Experience", 'key': "experience"},
      {'title': "Projects", 'key': "projects"},
      {'title': "Professional Summary", 'key': "summary"},
    ];

    return sectionList.map((s) {
      final content = cvData[s['key']];
      return {
        'title': s['title'],
        'key': s['key'],
        'content': content,
        'isCompleted': _isCompleted(content),
      };
    }).toList();
  }

  bool _isCompleted(dynamic content) {
    return content != null &&
        ((content is String && content.trim().isNotEmpty) ||
            (content is List && content.isNotEmpty));
  }
}