// lib/modules/cv_preview/preview_screen.dart

import 'package:flutter/material.dart';
import '../../models/cv_model.dart';
import '../../services/template_service.dart';
import 'package:open_filex/open_filex.dart';
import 'templates/template_default.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart'
as path; // optional if you need file name handling
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart'; // ✅ import your AppRoutes

class PreviewScreen extends StatelessWidget {
  final CVModel cv;
  const PreviewScreen({Key? key, required this.cv}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final template = TemplateDefault(cv, null);
    final sections = template.getOrderedSections();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("CV Preview"),
        backgroundColor:
        const Color(0xFFE8F3F8), // ✅ same head color you asked before
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case "download":
                  final file = await TemplateService(cv).buildPdf();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "CV saved to Downloads/${file.uri.pathSegments.last}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        backgroundColor: Colors
                            .blue.shade700, // darker blue for better contrast
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: "OPEN",
                          textColor:
                          Colors.amberAccent, // bright, high contrast
                          onPressed: () => OpenFilex.open(file.path),
                        ),
                        behavior: SnackBarBehavior
                            .floating, // makes it more modern and elevated
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12), // rounded corners
                        ),
                      ),
                    );
                  }
                  break;

                case "share":
                  final file = await TemplateService(cv).buildPdf();
                  await Share.shareXFiles([XFile(file.path)],
                      text: "Check out my CV!");
                  break;

                case "save":
                  await _showSaveToLibraryDialog(context);
                  break;

                case "new":
                  await _startNewCV(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "download", child: Text("Download PDF")),
              PopupMenuItem(value: "share", child: Text("Share")),
              PopupMenuItem(value: "save", child: Text("Save to Library")),
              PopupMenuItem(value: "new", child: Text("New CV")),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final s = sections[index];
          return _buildSection(s['type'], s['data'], context);
        },
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Start a New CV?"),
        content: const Text(
            "Creating a new CV will erase your current CV data. Do you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // ❌ No
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // ✅ Yes
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ??
        false; // default false if dismissed
  }

  Future<void> _startNewCV(BuildContext context) async {
    // Show confirmation dialog
    bool confirm = await _showConfirmDialog(context);
    if (!confirm) return; // user cancelled

    try {
      // Clear last CV from Firestore
      await FirestoreService().clearLastCV(cv.userId);

      if (!context.mounted) return;

      // Navigate to Voice Input screen with fresh CV
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.voiceInput,
        arguments: {
          'forceNew': true,
          'resume': false,
          'cvId': 'cv_${DateTime.now().millisecondsSinceEpoch}',
          'cvData': {},
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to start a new CV.")),
      );
      debugPrint('❌ Error starting new CV: $e');
    }
  }

  /// ✅ Show dialog to input filename and save CV to library
  Future<void> _showSaveToLibraryDialog(BuildContext context) async {
    final TextEditingController _filenameController =
    TextEditingController(text: "My CV");

    final saveConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save CV to Library"),
        content: TextField(
          controller: _filenameController,
          decoration: const InputDecoration(labelText: "Enter CV name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (saveConfirmed != true) return;

    final filename = _filenameController.text.trim();
    if (filename.isEmpty) return;

    try {
      await FirestoreService().saveCVToLibrary(
        cv.userId,
        cv,
        customName: filename,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "'$filename' saved to Library",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue, // same as download
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to save CV: $e")),
        );
      }
    }
  }

  Widget _buildSection(String type, dynamic data, BuildContext context) {
    switch (type) {
      case 'header':
        return _buildHeader(data);
      case 'contact':
        return _buildContact(data);
      case 'skills':
        return _buildSkills(data, context);
      case 'experience':
        return _buildExperience(data);
      case 'projects':
        return _buildProjects(data);
      case 'education':
        return _buildEducation(data);
      case 'certifications':
        return _buildCertifications(data);
      case 'languages':
        return _buildLanguages(data);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['name'] ?? '',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['summary'] ?? '',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContact(Map<String, dynamic> data) {
    final items = <Widget>[];

    void addItem(IconData icon, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        items.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        );
      }
    }

    // ✅ Order: Email → Location → Phone → Github → LinkedIn → Website
    addItem(Icons.email, data['email']);
    addItem(Icons.location_on, data['location']);
    addItem(Icons.phone, data['phone']);
    addItem(Icons.code, data['github']);
    addItem(Icons.link, data['linkedin']);
    addItem(Icons.public, data['website']);

    return Container(
      width: double.infinity,
      color: Color(0xFF0D47A1), // Dark Blue
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Wrap(
        spacing: 30, // ✅ more space between items
        runSpacing: 12, // ✅ proper vertical spacing if wrap
        alignment: WrapAlignment.start,
        children: items,
      ),
    );
  }

  Widget _buildSkills(List<String> skills, BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();

    Widget buildSkillItem(String skill) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Diamond bullet
            SizedBox(
              width: 12,
              height: 12,
              child: Center(
                child: Transform.rotate(
                  angle: 0.785, // 45° = diamond
                  child: Container(
                    width: 6,
                    height: 6,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12), // space between bullet & text
            // Skill text
            Expanded(
              child: Text(
                skill,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _sectionBlock(
        "SKILLS",
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: skills.map(buildSkillItem).toList(),
        ),
      ),
    );
  }


  Widget _buildExperience(List<Map<String, dynamic>> experiences) {
    if (experiences.isEmpty) return const SizedBox.shrink();
    return _sectionBlock(
      "WORK EXPERIENCE",
      Column(
        children: experiences.map((exp) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Company + Location + Dates in a row
                // Job title bold, own line
                Text(
                  exp['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

// Company + Location left, Dates right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${exp['company'] ?? ''}"
                            "${(exp['location'] ?? '').isNotEmpty ? ", ${exp['location']}" : ""}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if ((exp['dates'] ?? '').isNotEmpty)
                      Text(
                        exp['dates'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),

                if ((exp['duration'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      exp['duration'],
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),

                const SizedBox(height: 6),

                ...((exp['details'] as List?) ?? []).map((d) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ",
                        style: TextStyle(fontSize: 14, height: 1.4)),
                    Expanded(
                      child: Text(d,
                          style:
                          const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ],
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjects(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) return const SizedBox.shrink();
    return _sectionBlock(
      "PROJECTS",
      Column(
        children: projects.map((proj) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proj['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if ((proj['description'] ?? '').isNotEmpty)
                  Text(proj['description'] ?? '',
                      style: const TextStyle(
                          fontSize: 14, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEducation(List<Map<String, dynamic>> education) {
    if (education.isEmpty) return const SizedBox.shrink();
    return _sectionBlock(
      "EDUCATION",
      Column(
        children: education.map((edu) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edu['degree'] ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if ((edu['institution'] ?? '').isNotEmpty)
                        Text(
                          edu['location'] != null &&
                              edu['location'].toString().isNotEmpty
                              ? "${edu['institution']}, ${edu['location']}"
                              : edu['institution'],
                          style: const TextStyle(
                              fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      if ((edu['gpa'] ?? '').isNotEmpty)
                        Text(
                          "GPA / Marks: ${edu['gpa']}",
                          style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87),
                        ),
                    ],
                  ),
                ),
                Text(
                  edu['date'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCertifications(List<Map<String, dynamic>> certs) {
    if (certs.isEmpty) return const SizedBox.shrink();
    return _sectionBlock(
      "CERTIFICATIONS",
      Column(
        children: certs.map((cert) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cert['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(cert['issuer'] ?? '',
                            style: const TextStyle(
                                fontSize: 14, fontStyle: FontStyle.italic)),
                      ],
                    )),
                Text(cert['date'] ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguages(List<String> languages) {
    if (languages.isEmpty) return const SizedBox.shrink();
    return _sectionBlock(
      "LANGUAGES",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: languages
            .map((lang) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(lang, style: const TextStyle(fontSize: 14)),
        ))
            .toList(),
      ),
    );
  }

  Widget _sectionBlock(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}