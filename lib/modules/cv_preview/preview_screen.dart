import 'package:flutter/material.dart';
import '../../models/cv_model.dart';
import '../../services/template_service.dart';
import 'package:open_filex/open_filex.dart';
import 'templates/template_default.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart';

class PreviewScreen extends StatelessWidget {
  final CVModel cv;
  const PreviewScreen({Key? key, required this.cv}) : super(key: key);

  dynamic _convertCVSection(dynamic data) {
    if (data is CVSection) {
      // Convert CVSection to a map
      return {"text": data.text ?? ""};
    } else if (data is Map) {
      // Recursively convert map values
      final Map<String, dynamic> result = {};
      data.forEach((key, value) {
        result[key.toString()] = _convertCVSection(value);
      });
      return result;
    } else if (data is List) {
      // Recursively convert list items
      return data.map((e) => _convertCVSection(e)).toList();
    } else {
      // Convert primitive values to string
      return data?.toString() ?? '';
    }
  }



  @override
  Widget build(BuildContext context) {
    final template = TemplateDefault(cv, null);
    final sections = template.getOrderedSections();

    dynamic _convertCVSection(dynamic data) {
      if (data is CVSection) {
        // Flatten CVSection into a string
        return data.text;
      } else if (data is List) {
        // Recursively convert list elements to strings
        return data.map((e) => _convertCVSection(e).toString()).toList();
      } else if (data is Map) {
        // Recursively convert map values to strings
        final Map<String, dynamic> result = {};
        data.forEach((key, value) {
          result[key.toString()] = _convertCVSection(value).toString();
        });
        return result;
      } else {
        // Fallback to string
        return data?.toString() ?? '';
      }
    }


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("CV Preview"),
        backgroundColor: const Color(0xFFE8F3F8),
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        backgroundColor: Colors.blue.shade700,
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: "OPEN",
                          textColor: Colors.amberAccent,
                          onPressed: () => OpenFilex.open(file.path),
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                  break;

                case "share":
                  final file = await TemplateService(cv).buildPdf();
                  await Share.shareXFiles([XFile(file.path)], text: "Check out my CV!");
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
          final type = s['type'];
          final rawData = s['data'];

          // Convert CVSection to map/string structure expected by _buildSection
          final data = _convertCVSection(rawData);

          return _buildSection(type, data, context);
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _startNewCV(BuildContext context) async {
    bool confirm = await _showConfirmDialog(context);
    if (!confirm) return;

    try {
      await FirestoreService().clearLastCV(cv.userId);

      if (!context.mounted) return;

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

  Future<void> _showSaveToLibraryDialog(BuildContext context) async {
    final TextEditingController _filenameController = TextEditingController(text: "My CV");

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
            backgroundColor: Colors.blue,
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

  Future<void> _editField(BuildContext context, String key) async {
    final updatedCV = await Navigator.pushNamed(
      context,
      AppRoutes.voiceInput,
      arguments: {
        'cvModel': cv,
        'startSectionKey': key,
      },
    );

    if (updatedCV is CVModel && context.mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.summary,
        arguments: updatedCV,
      );
    }
  }

  Widget _buildSection(String type, dynamic data, BuildContext context) {
    switch (type) {
      case 'header':
        return _buildHeader(data, context);
      case 'contact':
        return _buildContact(data, context);
      case 'skills':
        return _buildSkills(data, context);
      case 'experience':
        return _buildExperience(data, context);
      case 'projects':
        return _buildProjects(data, context);
      case 'education':
        return _buildEducation(data, context);
      case 'certifications':
        return _buildCertifications(data, context);
      case 'languages':
        return _buildLanguages(data, context);
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildContact(dynamic data, BuildContext context) {
    if (data is! Map) return const SizedBox.shrink();

    final items = <Widget>[];

    void addItem(IconData icon, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
    }

    addItem(Icons.email, data['email']);
    addItem(Icons.phone, data['phone']);
    addItem(Icons.link, data['website']);
    addItem(Icons.location_on, data['location']);

    if (items.isEmpty) return const SizedBox.shrink();

    return _sectionBlock("CONTACT", Wrap(spacing: 8, runSpacing: 4, children: items),
        key: 'contact', context: context);
  }





  Widget _buildHeader(Map<String, dynamic> data, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data['name'] ?? '',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.black, size: 20),
                onPressed: () => _editField(context, 'name'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  data['summary'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.black, size: 20),
                onPressed: () => _editField(context, 'summary'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionBlock(String title, Widget child,
      {String? key, required BuildContext context}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (key != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.black, size: 20),
                  onPressed: () => _editField(context, key),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }





  Widget _buildSkills(dynamic data, BuildContext context) {
    List<String> skills = [];

    if (data is String) {
      skills = [data];
    } else if (data is List) {
      skills = data.map((e) => e.toString()).toList();
    }

    if (skills.isEmpty) return const SizedBox.shrink();

    return _sectionBlock(
      "SKILLS",
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: skills
            .map((s) => SizedBox(
          width: MediaQuery.of(context).size.width / 3 - 30,
          child: Text(s, style: const TextStyle(fontSize: 14)),
        ))
            .toList(),
      ),
      key: 'skills',
      context: context,
    );
  }

  Widget _buildExperience(dynamic data, BuildContext context) {
    List<Map<String, dynamic>> experiences = [];

    if (data is Map<String, dynamic>) {
      experiences = [data];
    } else if (data is List) {
      experiences = data
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }

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
                Text(exp['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${exp['company'] ?? ''}${(exp['location'] ?? '').isNotEmpty ? ", ${exp['location']}" : ""}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if ((exp['dates'] ?? '').isNotEmpty)
                      Text(
                        exp['dates'],
                        style: const TextStyle(
                            fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
                if ((exp['duration'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(exp['duration'],
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 6),
                if ((exp['details'] as List?)?.isNotEmpty ?? false) ...[
                  ...((exp['details'] as List).map((d) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "• ",
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                      Expanded(
                        child: Text(
                          d.toString(),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  ).toList()),
                ],
              ],
            ),
          );
        }).toList(),
      ),
      key: 'experience',
      context: context,
    );
  }

  Widget _buildProjects(dynamic data, BuildContext context) {
    List<Map<String, dynamic>> projects = [];

    if (data is Map<String, dynamic>) {
      projects = [data];
    } else if (data is List) {
      projects =
          data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }

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
                    style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if ((proj['description'] ?? '').toString().isNotEmpty)
                  Text(proj['description'] ?? '',
                      style: const TextStyle(
                          fontSize: 14, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
      ),
      key: 'projects',
      context: context,
    );
  }

  Widget _buildEducation(dynamic data, BuildContext context) {
    List<Map<String, dynamic>> education = [];

    if (data is Map<String, dynamic>) {
      education = [data];
    } else if (data is List) {
      education =
          data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }

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
                      Text(edu['degree'] ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((edu['institution'] ?? '').toString().isNotEmpty)
                        Text(
                          edu['location'] != null &&
                              edu['location'].toString().isNotEmpty
                              ? "${edu['institution']}, ${edu['location']}"
                              : edu['institution'] ?? '',
                          style: const TextStyle(
                              fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      if ((edu['gpa'] ?? '').toString().isNotEmpty)
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
                Text(edu['date'] ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
      ),
      key: 'education',
      context: context,
    );
  }

  Widget _buildCertifications(dynamic data, BuildContext context) {
    List<Map<String, dynamic>> certs = [];

    if (data is Map<String, dynamic>) {
      certs = [data];
    } else if (data is List) {
      certs =
          data.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }

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
                  ),
                ),
                Text(cert['date'] ?? '',
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }).toList(),
      ),
      key: 'certifications',
      context: context,
    );
  }

  Widget _buildLanguages(dynamic data, BuildContext context) {
    List<String> languages = [];

    if (data is String) {
      languages = [data];
    } else if (data is List) {
      languages = data.map((e) => e.toString()).toList();
    }

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
      key: 'languages',
      context: context,
    );
  }

}