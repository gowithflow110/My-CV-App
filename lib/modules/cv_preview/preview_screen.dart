// lib/modules/cv_preview/preview_screen.dart (inline-edit version)
// Drop-in replacement that adds Edit buttons and inline editing per section
// without navigating away or touching other files.
//
// IMPORTANT:
// - This keeps all logic inside this screen. Your TemplateService & routes remain untouched.
// - Edits are applied to an in-memory override map immediately so the preview updates live.
// - Two extension points are included for persistence:
//     (A) _applyPatchToCv(...)  -> mutate your CVModel (so PDF reflects edits)
//     (B) _persistPatchToFirestore(...) -> write to your generated Firestore document
//   They are NO-OPs by default to avoid breaking other files. Provide mapping info
//   and doc reference/path to fully wire them (see TODOs).
//
// What is implemented fully:
//   - Header (name, summary) inline edit
//   - Contact section inline edit (email, location, phone, github, linkedin, website)
//   - Skills chips editor (add/remove)
//   - Edit affordances for each section (icon button)
//
// For experience/projects/education/certifications/languages:
//   - Quick JSON editor modal is provided for now (keyboard only). Paste structured data
//     matching your current shape and Save. This avoids touching other files.
//   - You can replace the JSON editor with bespoke item editors later using the same pattern.

import 'dart:convert';

import 'package:flutter/material.dart';
import '../../models/cv_model.dart';
import '../../services/template_service.dart';
import 'package:open_filex/open_filex.dart';
import 'templates/template_default.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path; // optional if you need file name handling
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart'; // ✅ your AppRoutes
import 'package:cloud_firestore/cloud_firestore.dart';


class PreviewScreen extends StatefulWidget {
  final CVModel cv;
  const PreviewScreen({Key? key, required this.cv}) : super(key: key);

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  // ======= Inline editing state =======
  bool _editingHeader = false;
  bool _editingContact = false;
  bool _editingSkills = false;
  bool _editingLanguages = false;

  // Working overrides that the preview renders from (merged on top of template data)
  final Map<String, dynamic> _overrides = {
    // 'header': {'name': '...', 'summary': '...'},
    // 'contact': {'email': '...', 'phone': ...},
    // 'skills': <String>[],
    // 'languages': <String>[],
    // 'experience': List<Map<String,dynamic>> etc.
  };

  // Controllers for header & contact
  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Skills editing
  final _newSkillCtrl = TextEditingController();
  List<String> _skillsWorking = [];

  // Languages editing
  final _newLangCtrl = TextEditingController();
  List<String> _langsWorking = [];

  bool _saving = false; // show overlay while persisting

  CVModel get cv => widget.cv;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _summaryCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    _websiteCtrl.dispose();
    _newSkillCtrl.dispose();
    _newLangCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = TemplateDefault(cv, null);
    final sections = template.getOrderedSections();

    return Stack(
      children: [
        Scaffold(
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
              final type = s['type'] as String;
              final original = s['data'];
              final data = _mergeWithOverride(type, original);
              return _buildSection(type, data, context);
            },
          ),
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
      ],
    );
  }

  // ======= Save & persistence helpers =======

  Future<void> _savePatch({required String section, required dynamic value}) async {
    setState(() => _saving = true);
    try {
      // 1) Update overrides so UI reflects immediately
      setState(() {
        _overrides[section] = value;
      });

      // 2) Mutate your CVModel so TemplateService(pdf) uses updated data
      await _applyPatchToCv(section: section, value: value);

      // 3) Persist to Firestore generated doc (post-AI)
      await _persistPatchToFirestore(section: section, value: value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved changes')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    return <String, dynamic>{};
  }



  Future<void> _applyPatchToCv({
    required String section,
    required dynamic value,
  }) async {
    // 1️⃣ Update local CV data
    final current = cv.cvData[section];

    if (value is Map<String, dynamic>) {
      // Merge maps (header, contact, etc.)
      cv.cvData[section] = {
        ..._asMap(current),
        ...value,
      };
    } else if (value is List) {
      // Replace list sections wholesale
      cv.cvData[section] = List.from(value);
    } else {
      // Replace scalar values (strings, numbers, etc.)
      cv.cvData[section] = value;
    }

    // Refresh UI immediately
    if (mounted) setState(() {});

    // 2️⃣ Persist the patch to Firestore (lighter than full overwrite)
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(cv.userId)
          .collection('aiGeneratedCVs')
          .doc(cv.cvId);

      await docRef.update({
        'cvData.$section': cv.cvData[section],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ [$section] updated and synced to Firestore.");
    } catch (e) {
      debugPrint("❌ Failed to sync [$section]: $e");
      // Optionally, queue the change locally to retry when online
    }
  }



  Future<void> _persistPatchToFirestore({
    required String section,
    required dynamic value,
  }) async {
    if (cv.userId.isEmpty || cv.cvId.isEmpty) {
      debugPrint("⚠ Skipping Firestore patch — missing userId or cvId");
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Correct path (your service uses aiGeneratedCVs/latestAI_CV for AI CVs)
      final docRef = firestore
          .collection('users')
          .doc(cv.userId)
          .collection('aiGeneratedCVs')
          .doc(cv.cvId);

      // Update only the patched section inside cvData + refresh timestamp
      await docRef.update({
        'cvData.$section': cv.cvData[section],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Firestore patched [$section] for cvId=${cv.cvId}");
    } catch (e) {
      // Swallow to preserve UX, but still log for dev insight
      debugPrint("❌ Failed to persist [$section] patch: $e");
    }
  }


  // ======= Dialogs & menu actions (unchanged from your file) =======

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
    final confirm = await _showConfirmDialog(context);
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
    }
  }

  Future<void> _showSaveToLibraryDialog(BuildContext context) async {
    final TextEditingController filenameController = TextEditingController(text: "My CV");

    final saveConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save CV to Library"),
        content: TextField(
          controller: filenameController,
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

    final filename = filenameController.text.trim();
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
            content: Text("'$filename' saved to Library", style: const TextStyle(color: Colors.white)),
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

  // ======= Render sections (with edit capability) =======

  Widget _buildSection(String type, dynamic data, BuildContext context) {
    switch (type) {
      case 'header':
        return _buildHeader(data);
      case 'contact':
        return _buildContact(data);
      case 'skills':
        return _buildSkills(List<String>.from(data ?? const []), context);
      case 'experience':
        return _buildComplexWithJsonEditor('WORK EXPERIENCE', 'experience', data);
      case 'projects':
        return _buildComplexWithJsonEditor('PROJECTS', 'projects', data);
      case 'education':
        return _buildComplexWithJsonEditor('EDUCATION', 'education', data);
      case 'certifications':
        return _buildComplexWithJsonEditor('CERTIFICATIONS', 'certifications', data);
      case 'languages':
        return _buildLanguages(List<String>.from(data ?? const []));
      default:
        return const SizedBox.shrink();
    }
  }

  dynamic _mergeWithOverride(String section, dynamic original) {
    final override = _overrides[section];
    if (override == null) return original;

    if (original is Map && override is Map) {
      return {...original, ...override};
    }
    // Lists or scalars just replace
    return override;
  }


  // ----- Header -----
  Widget _buildHeader(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final summary = (data['summary'] ?? '').toString();

    if (!_editingHeader) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit header',
                  onPressed: () {
                    setState(() {
                      _editingHeader = true;
                      _nameCtrl.text = name;
                      _summaryCtrl.text = summary;
                    });
                  },
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(summary, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summaryCtrl,
              minLines: 3,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Professional Summary / Headline',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = _nameCtrl.text.trim();
                    final summary = _summaryCtrl.text.trim();

                    if (name.isEmpty && summary.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("⚠️ Please fill at least one field before saving")),
                      );
                      return;
                    }

                    await _savePatch(
                      section: 'header',
                      value: {'name': name, 'summary': summary},
                    );

                    if (mounted) setState(() => _editingHeader = false);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editingHeader = false),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
            )
          ],
        ),
      ),
    );

  }

  // ----- Contact -----
  Widget _buildContact(Map<String, dynamic> data) {
    if (!_editingContact) {
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

      final m = data;
      addItem(Icons.email, m['email']);
      addItem(Icons.location_on, m['location']);
      addItem(Icons.phone, m['phone']);
      addItem(Icons.code, m['github']);
      addItem(Icons.link, m['linkedin']);
      addItem(Icons.public, m['website']);

      return Stack(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Wrap(
              spacing: 30,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: items,
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            child: IconButton(
              onPressed: () {
                setState(() {
                  _editingContact = true;
                  _emailCtrl.text = (m['email'] ?? '').toString();
                  _locationCtrl.text = (m['location'] ?? '').toString();
                  _phoneCtrl.text = (m['phone'] ?? '').toString();
                  _githubCtrl.text = (m['github'] ?? '').toString();
                  _linkedinCtrl.text = (m['linkedin'] ?? '').toString();
                  _websiteCtrl.text = (m['website'] ?? '').toString();
                });
              },
              icon: const Icon(Icons.edit, color: Colors.white),
            ),
          )
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _contactField(_emailCtrl, 'Email', Icons.email),
            _contactField(_locationCtrl, 'Location', Icons.location_on),
            _contactField(_phoneCtrl, 'Phone', Icons.phone),
            _contactField(_githubCtrl, 'GitHub', Icons.code),
            _contactField(_linkedinCtrl, 'LinkedIn', Icons.link),
            _contactField(_websiteCtrl, 'Website', Icons.public),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await _savePatch(section: 'contact', value: {
                    'email': _emailCtrl.text.trim(),
                    'location': _locationCtrl.text.trim(),
                    'phone': _phoneCtrl.text.trim(),
                    'github': _githubCtrl.text.trim(),
                    'linkedin': _linkedinCtrl.text.trim(),
                    'website': _websiteCtrl.text.trim(),
                  });
                  if (mounted) setState(() => _editingContact = false);
                },
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _editingContact = false),
                child: const Text('Cancel'),
              ),
            ])
          ],
        ),
      ),
    );
  }

  Widget _contactField(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ----- Skills -----
  Widget _buildSkills(List<String> skills, BuildContext context) {
    if (!_editingSkills) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _sectionBlock(
          "SKILLS",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final skill in skills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: Center(
                          child: Transform.rotate(
                            angle: 0.785, // 45° diamond
                            child: Container(width: 6, height: 6, color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(skill, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Edit skills',
                  onPressed: () {
                    setState(() {
                      _editingSkills = true;
                      _skillsWorking = [...skills];
                      _newSkillCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.edit),
                ),
              )
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _sectionBlock(
        "SKILLS",
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: -8,
              children: _skillsWorking
                  .map((s) => InputChip(
                label: Text(s),
                onDeleted: () => setState(() => _skillsWorking.remove(s)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newSkillCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add a skill and press +',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addSkill(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addSkill,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await _savePatch(section: 'skills', value: _skillsWorking);
                  if (mounted) setState(() => _editingSkills = false);
                },
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _editingSkills = false),
                child: const Text('Cancel'),
              ),
            ])
          ],
        ),
      ),
    );
  }

  void _addSkill() {
    final t = _newSkillCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_skillsWorking.contains(t)) _skillsWorking.add(t);
      _newSkillCtrl.clear();
    });
  }

  // ----- Languages (chips editor, like skills) -----
  Widget _buildLanguages(List<String> languages) {
    if (!_editingLanguages) {
      return _sectionBlock(
        "LANGUAGES",
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final lang in languages)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(lang, style: const TextStyle(fontSize: 14)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Edit languages',
                onPressed: () {
                  setState(() {
                    _editingLanguages = true;
                    _langsWorking = [...languages];
                    _newLangCtrl.clear();
                  });
                },
                icon: const Icon(Icons.edit),
              ),
            )
          ],
        ),
      );
    }

    return _sectionBlock(
      "LANGUAGES",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: -8,
            children: _langsWorking
                .map((s) => InputChip(
              label: Text(s),
              onDeleted: () => setState(() => _langsWorking.remove(s)),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newLangCtrl,
                decoration: const InputDecoration(
                  hintText: 'Add a language and press +',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addLanguage(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _addLanguage,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
              onPressed: () async {
                await _savePatch(section: 'languages', value: _langsWorking);
                if (mounted) setState(() => _editingLanguages = false);
              },
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _editingLanguages = false),
              child: const Text('Cancel'),
            ),
          ])
        ],
      ),
    );
  }

  void _addLanguage() {
    final t = _newLangCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_langsWorking.contains(t)) _langsWorking.add(t);
      _newLangCtrl.clear();
    });
  }

  // ----- Generic complex sections with quick JSON editor (temporary, keyboard-only) -----
  Widget _buildComplexWithJsonEditor(String title, String sectionKey, dynamic data) {
    final child = _renderComplex(title, data);
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: 'Edit $title',
            onPressed: () => _openJsonEditor(sectionKey, data),
            icon: const Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  Widget _renderComplex(String title, dynamic data) {
    // Reuse your original renderers for experience/projects/education/certifications
    switch (title) {
      case 'WORK EXPERIENCE':
        return _sectionBlock(
          "WORK EXPERIENCE",
          Column(
            children: (data as List<dynamic>).map((exp) {
              final m = Map<String, dynamic>.from(exp as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "${m['company'] ?? ''}${(m['location'] ?? '').toString().isNotEmpty ? ", ${m['location']}" : ""}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if ((m['dates'] ?? '').toString().isNotEmpty)
                          Text(m['dates'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    if ((m['duration'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(m['duration'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 6),
                    ...((m['details'] as List?) ?? []).map((d) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontSize: 14, height: 1.4)),
                        Expanded(child: Text(d.toString(), style: const TextStyle(fontSize: 14, height: 1.4))),
                      ],
                    )),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case 'PROJECTS':
        return _sectionBlock(
          "PROJECTS",
          Column(
            children: (data as List<dynamic>).map((proj) {
              final m = Map<String, dynamic>.from(proj as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if ((m['description'] ?? '').toString().isNotEmpty)
                      Text(m['description'], style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case 'EDUCATION':
        return _sectionBlock(
          "EDUCATION",
          Column(
            children: (data as List<dynamic>).map((edu) {
              final m = Map<String, dynamic>.from(edu as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['degree'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if ((m['institution'] ?? '').toString().isNotEmpty)
                            Text(
                              (m['location'] ?? '').toString().isNotEmpty ? "${m['institution']}, ${m['location']}" : m['institution'],
                              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          if ((m['gpa'] ?? '').toString().isNotEmpty)
                            Text("GPA / Marks: ${m['gpa']}", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87)),
                        ],
                      ),
                    ),
                    Text(m['date'] ?? '', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case 'CERTIFICATIONS':
        return _sectionBlock(
          "CERTIFICATIONS",
          Column(
            children: (data as List<dynamic>).map((cert) {
              final m = Map<String, dynamic>.from(cert as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(m['issuer'] ?? '', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                          ],
                        )),
                    Text(m['date'] ?? '', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openJsonEditor(String sectionKey, dynamic data) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(data),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${sectionKey.toUpperCase()} (JSON)'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            minLines: 12,
            maxLines: 26,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Edit JSON and press Save',
            ),
            keyboardType: TextInputType.multiline,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;

    try {
      final dynamic parsed = jsonDecode(controller.text);
      await _savePatch(section: sectionKey, value: parsed);
      setState(() {
        _overrides[sectionKey] = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON: $e')),
      );
    }
  }

  // ----- Shared section block -----
  Widget _sectionBlock(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
