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
import 'package:path/path.dart' as path;
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart';
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
bool _editingExperience = false;
bool _editingProjects = false;
bool _editingEducation = false;
bool _editingCertifications = false;

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


// Working overrides that the preview renders from (merged on top of template data)
final Map<String, dynamic> _overrides = {};

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

// Experience editing
List<Map<String, dynamic>> _experienceWorking = [];
final Map<int, TextEditingController> _expTitleCtrls = {};
final Map<int, TextEditingController> _expCompanyCtrls = {};
final Map<int, TextEditingController> _expLocationCtrls = {};
final Map<int, TextEditingController> _expDatesCtrls = {};
final Map<int, TextEditingController> _expDurationCtrls = {};
final Map<int, List<TextEditingController>> _expDetailCtrls = {};

// Projects editing
List<Map<String, dynamic>> _projectsWorking = [];
final Map<int, TextEditingController> _projectTitleCtrls = {};
final Map<int, TextEditingController> _projectDescCtrls = {};

// Education editing
List<Map<String, dynamic>> _educationWorking = [];
final Map<int, TextEditingController> _eduDegreeCtrls = {};
final Map<int, TextEditingController> _eduInstitutionCtrls = {};
final Map<int, TextEditingController> _eduLocationCtrls = {};
final Map<int, TextEditingController> _eduDateCtrls = {};
final Map<int, TextEditingController> _eduGpaCtrls = {};

// Certifications editing
List<Map<String, dynamic>> _certificationsWorking = [];
final Map<int, TextEditingController> _certTitleCtrls = {};
final Map<int, TextEditingController> _certIssuerCtrls = {};
final Map<int, TextEditingController> _certDateCtrls = {};

bool _saving = false;

CVModel get cv => widget.cv;

@override
void initState() {
super.initState();
// Initialize working data with current CV data
_skillsWorking = List<String>.from(cv.cvData['skills'] ?? []);
_langsWorking = List<String>.from(cv.cvData['languages'] ?? []);
_experienceWorking = List<Map<String, dynamic>>.from(cv.cvData['experience'] ?? []);
_projectsWorking = List<Map<String, dynamic>>.from(cv.cvData['projects'] ?? []);
_educationWorking = List<Map<String, dynamic>>.from(cv.cvData['education'] ?? []);
_certificationsWorking = List<Map<String, dynamic>>.from(cv.cvData['certifications'] ?? []);
}

@override
void dispose() {
// Dispose all controllers
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

// Dispose experience controllers
_expTitleCtrls.values.forEach((c) => c.dispose());
_expCompanyCtrls.values.forEach((c) => c.dispose());
_expLocationCtrls.values.forEach((c) => c.dispose());
_expDatesCtrls.values.forEach((c) => c.dispose());
_expDurationCtrls.values.forEach((c) => c.dispose());
_expDetailCtrls.values.forEach((list) => list.forEach((c) => c.dispose()));

// Dispose project controllers
_projectTitleCtrls.values.forEach((c) => c.dispose());
_projectDescCtrls.values.forEach((c) => c.dispose());

// Dispose education controllers
_eduDegreeCtrls.values.forEach((c) => c.dispose());
_eduInstitutionCtrls.values.forEach((c) => c.dispose());
_eduLocationCtrls.values.forEach((c) => c.dispose());
_eduDateCtrls.values.forEach((c) => c.dispose());
_eduGpaCtrls.values.forEach((c) => c.dispose());

// Dispose certification controllers
_certTitleCtrls.values.forEach((c) => c.dispose());
_certIssuerCtrls.values.forEach((c) => c.dispose());
_certDateCtrls.values.forEach((c) => c.dispose());

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

      // 2) Update local CV data - handle header specially
      if (section == 'header' && value is Map<String, dynamic>) {
        // Header fields are stored at root level, not under 'header'
        cv.cvData['name'] = value['name'] ?? '';
        cv.cvData['summary'] = value['summary'] ?? '';
      } else {
        // For other sections, replace the entire section
        cv.cvData[section] = value;
      }

      // 3) Force UI refresh
      if (mounted) setState(() {});

      // 4) Persist to Firestore
      await _persistPatchToFirestore(section: section, value: value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved changes')),
        );
      }
    } catch (e) {
      debugPrint("❌ Error in _savePatch: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
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
      final firestoreService = FirestoreService();

      // Handle header fields specially since they're at root level
      if (section == 'header' && value is Map<String, dynamic>) {
        // Create the updates map
        final updates = {
          'name': value['name'] ?? '',
          'summary': value['summary'] ?? '',
        };

        // Update both locations
        await firestoreService.updateBothCVLocations(cv.userId, cv.cvId, updates);
      } else {
        // For all other sections
        final updates = {section: value};

        // Update both locations
        await firestoreService.updateBothCVLocations(cv.userId, cv.cvId, updates);
      }

      debugPrint("✅ Updated Firestore section [$section] for cvId=${cv.cvId}");
    } catch (e) {
      debugPrint("❌ Failed to persist [$section] patch: $e");
      throw e;
    }
  }

// ======= Dialogs & menu actions =======

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
        return _buildHeader(Map<String, dynamic>.from(data ?? {}));
      case 'contact':
        return _buildContact(Map<String, dynamic>.from(data ?? {}));
      case 'skills':
        return _buildSkills(List<String>.from(data ?? const []), context);
      case 'experience':
        if (_editingExperience) {
          return _buildExperienceEditor(_experienceWorking);
        } else {
          return _buildComplexWithEditor('WORK EXPERIENCE', 'experience', data,
              onEdit: () => _initExperienceEditing(data));
        }
      case 'projects':
        if (_editingProjects) {
          return _buildProjectsEditor(_projectsWorking);
        } else {
          return _buildComplexWithEditor('PROJECTS', 'projects', data,
              onEdit: () => _initProjectsEditing(data));
        }
      case 'education':
        if (_editingEducation) {
          return _buildEducationEditor(_educationWorking);
        } else {
          return _buildComplexWithEditor('EDUCATION', 'education', data,
              onEdit: () => _initEducationEditing(data));
        }
      case 'certifications':
        if (_editingCertifications) {
          return _buildCertificationsEditor(_certificationsWorking);
        } else {
          return _buildComplexWithEditor('CERTIFICATIONS', 'certifications', data,
              onEdit: () => _initCertificationsEditing(data));
        }
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
  return {...Map<String, dynamic>.from(original), ...Map<String, dynamic>.from(override)};
}
// Lists or scalars just replace
return override;
}

// ----- Header -----
Widget _buildHeader(Map<String, dynamic> data) {
  final Map<String, dynamic> headerData = Map<String, dynamic>.from(data);
  final name = (headerData['name'] ?? '').toString();
  final summary = (headerData['summary'] ?? '').toString();

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
  final Map<String, dynamic> contactData = Map<String, dynamic>.from(data);
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

// Generic section with edit button
Widget _buildComplexWithEditor(String title, String sectionKey, dynamic data, {required VoidCallback onEdit}) {
final child = _renderComplex(title, data);
return Stack(
children: [
child,
Positioned(
right: 0,
top: 0,
child: IconButton(
tooltip: 'Edit $title',
onPressed: onEdit,
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

// ======= Initialize editing for complex sections =======

void _initExperienceEditing(dynamic data) {
setState(() {
_editingExperience = true;
_experienceWorking = List<Map<String, dynamic>>.from(data ?? []);
_initExperienceControllers();
});
}

void _initExperienceControllers() {
// Clear existing controllers
_expTitleCtrls.clear();
_expCompanyCtrls.clear();
_expLocationCtrls.clear();
_expDatesCtrls.clear();
_expDurationCtrls.clear();
_expDetailCtrls.clear();

// Initialize controllers for each experience item
for (int i = 0; i < _experienceWorking.length; i++) {
final exp = _experienceWorking[i];
_expTitleCtrls[i] = TextEditingController(text: exp['title']?.toString() ?? '');
_expCompanyCtrls[i] = TextEditingController(text: exp['company']?.toString() ?? '');
_expLocationCtrls[i] = TextEditingController(text: exp['location']?.toString() ?? '');
_expDatesCtrls[i] = TextEditingController(text: exp['dates']?.toString() ?? '');
_expDurationCtrls[i] = TextEditingController(text: exp['duration']?.toString() ?? '');

// Initialize detail controllers
final details = List<String>.from(exp['details'] ?? []);
_expDetailCtrls[i] = details.map((detail) => TextEditingController(text: detail)).toList();
}
}

void _initProjectsEditing(dynamic data) {
setState(() {
_editingProjects = true;
_projectsWorking = List<Map<String, dynamic>>.from(data ?? []);
_initProjectsControllers();
});
}

void _initProjectsControllers() {
_projectTitleCtrls.clear();
_projectDescCtrls.clear();

for (int i = 0; i < _projectsWorking.length; i++) {
final project = _projectsWorking[i];
_projectTitleCtrls[i] = TextEditingController(text: project['title']?.toString() ?? '');
_projectDescCtrls[i] = TextEditingController(text: project['description']?.toString() ?? '');
}
}

void _initEducationEditing(dynamic data) {
setState(() {
_editingEducation = true;
_educationWorking = List<Map<String, dynamic>>.from(data ?? []);
_initEducationControllers();
});
}

void _initEducationControllers() {
_eduDegreeCtrls.clear();
_eduInstitutionCtrls.clear();
_eduLocationCtrls.clear();
_eduDateCtrls.clear();
_eduGpaCtrls.clear();

for (int i = 0; i < _educationWorking.length; i++) {
final edu = _educationWorking[i];
_eduDegreeCtrls[i] = TextEditingController(text: edu['degree']?.toString() ?? '');
_eduInstitutionCtrls[i] = TextEditingController(text: edu['institution']?.toString() ?? '');
_eduLocationCtrls[i] = TextEditingController(text: edu['location']?.toString() ?? '');
_eduDateCtrls[i] = TextEditingController(text: edu['date']?.toString() ?? '');
_eduGpaCtrls[i] = TextEditingController(text: edu['gpa']?.toString() ?? '');
}
}

void _initCertificationsEditing(dynamic data) {
setState(() {
_editingCertifications = true;
_certificationsWorking = List<Map<String, dynamic>>.from(data ?? []);
_initCertificationsControllers();
});
}

void _initCertificationsControllers() {
_certTitleCtrls.clear();
_certIssuerCtrls.clear();
_certDateCtrls.clear();

for (int i = 0; i < _certificationsWorking.length; i++) {
final cert = _certificationsWorking[i];
_certTitleCtrls[i] = TextEditingController(text: cert['title']?.toString() ?? '');
_certIssuerCtrls[i] = TextEditingController(text: cert['issuer']?.toString() ?? '');
_certDateCtrls[i] = TextEditingController(text: cert['date']?.toString() ?? '');
}
}

// ======= Editors for complex sections =======

Widget _buildExperienceEditor(List<Map<String, dynamic>> experiences) {
return Card(
margin: const EdgeInsets.only(bottom: 16),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"EDIT WORK EXPERIENCE",
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
..._buildExperienceItems(),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: _addExperienceItem,
icon: const Icon(Icons.add),
label: const Text('Add Experience'),
),
const SizedBox(height: 16),
Row(
children: [
ElevatedButton(
onPressed: () async {
await _saveExperience();
setState(() => _editingExperience = false);
},
child: const Text('Save'),
),
const SizedBox(width: 12),
TextButton(
onPressed: () => setState(() => _editingExperience = false),
child: const Text('Cancel'),
),
],
),
],
),
),
);
}

List<Widget> _buildExperienceItems() {
return _experienceWorking.asMap().entries.map((entry) {
final index = entry.key;
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Experience ${index + 1}',
style: const TextStyle(fontWeight: FontWeight.bold),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.red),
onPressed: () => _removeExperienceItem(index),
),
],
),
TextField(
controller: _expTitleCtrls[index],
decoration: const InputDecoration(labelText: 'Job Title'),
),
TextField(
controller: _expCompanyCtrls[index],
decoration: const InputDecoration(labelText: 'Company'),
),
TextField(
controller: _expLocationCtrls[index],
decoration: const InputDecoration(labelText: 'Location'),
),
TextField(
controller: _expDatesCtrls[index],
decoration: const InputDecoration(labelText: 'Dates (e.g., Jan 2020 - Dec 2022)'),
),
TextField(
controller: _expDurationCtrls[index],
decoration: const InputDecoration(labelText: 'Duration (e.g., 2 years 3 months)'),
),
const SizedBox(height: 8),
const Text('Responsibilities:', style: TextStyle(fontWeight: FontWeight.bold)),
..._buildDetailFields(index),
ElevatedButton(
onPressed: () => _addDetailField(index),
child: const Text('Add Responsibility'),
),
],
),
),
);
}).toList();
}

List<Widget> _buildDetailFields(int expIndex) {
if (!_expDetailCtrls.containsKey(expIndex)) {
return [];
}

return _expDetailCtrls[expIndex]!.asMap().entries.map((entry) {
final detailIndex = entry.key;
final controller = entry.value;

return Row(
children: [
Expanded(
child: TextField(
controller: controller,
decoration: InputDecoration(
labelText: 'Responsibility ${detailIndex + 1}',
),
),
),
IconButton(
icon: const Icon(Icons.remove, color: Colors.red),
onPressed: () => _removeDetailField(expIndex, detailIndex),
),
],
);
}).toList();
}

void _addExperienceItem() {
setState(() {
final newIndex = _experienceWorking.length;
_experienceWorking.add({});
_expTitleCtrls[newIndex] = TextEditingController();
_expCompanyCtrls[newIndex] = TextEditingController();
_expLocationCtrls[newIndex] = TextEditingController();
_expDatesCtrls[newIndex] = TextEditingController();
_expDurationCtrls[newIndex] = TextEditingController();
_expDetailCtrls[newIndex] = [TextEditingController()];
});
}

void _removeExperienceItem(int index) {
setState(() {
_experienceWorking.removeAt(index);

// Remove controllers
_expTitleCtrls.remove(index);
_expCompanyCtrls.remove(index);
_expLocationCtrls.remove(index);
_expDatesCtrls.remove(index);
_expDurationCtrls.remove(index);
_expDetailCtrls.remove(index);

// Reindex remaining controllers
_reindexControllers(_expTitleCtrls, index);
_reindexControllers(_expCompanyCtrls, index);
_reindexControllers(_expLocationCtrls, index);
_reindexControllers(_expDatesCtrls, index);
_reindexControllers(_expDurationCtrls, index);
_reindexDetailControllers(index);
});
}

void _reindexControllers(Map<int, TextEditingController> controllers, int removedIndex) {
final keys = controllers.keys.toList()..sort();
for (final key in keys) {
if (key > removedIndex) {
controllers[key - 1] = controllers[key]!;
controllers.remove(key);
}
}
}

void _reindexDetailControllers(int removedIndex) {
final keys = _expDetailCtrls.keys.toList()..sort();
for (final key in keys) {
if (key > removedIndex) {
_expDetailCtrls[key - 1] = _expDetailCtrls[key]!;
_expDetailCtrls.remove(key);
}
}
}

void _addDetailField(int expIndex) {
setState(() {
_expDetailCtrls[expIndex]!.add(TextEditingController());
});
}

void _removeDetailField(int expIndex, int detailIndex) {
setState(() {
_expDetailCtrls[expIndex]!.removeAt(detailIndex);
});
}

Future<void> _saveExperience() async {
// Convert form data to experience objects
final List<Map<String, dynamic>> experiences = [];

for (int i = 0; i < _experienceWorking.length; i++) {
final details = _expDetailCtrls[i]!
    .map((controller) => controller.text.trim())
    .where((text) => text.isNotEmpty)
    .toList();

experiences.add({
'title': _expTitleCtrls[i]!.text.trim(),
'company': _expCompanyCtrls[i]!.text.trim(),
'location': _expLocationCtrls[i]!.text.trim(),
'dates': _expDatesCtrls[i]!.text.trim(),
'duration': _expDurationCtrls[i]!.text.trim(),
'details': details,
});
}

await _savePatch(section: 'experience', value: experiences);
}

Widget _buildProjectsEditor(List<Map<String, dynamic>> projects) {
return Card(
margin: const EdgeInsets.only(bottom: 16),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"EDIT PROJECTS",
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
..._buildProjectItems(),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: _addProjectItem,
icon: const Icon(Icons.add),
label: const Text('Add Project'),
),
const SizedBox(height: 16),
Row(
children: [
ElevatedButton(
onPressed: () async {
await _saveProjects();
setState(() => _editingProjects = false);
},
child: const Text('Save'),
),
const SizedBox(width: 12),
TextButton(
onPressed: () => setState(() => _editingProjects = false),
child: const Text('Cancel'),
),
],
),
],
),
),
);
}

List<Widget> _buildProjectItems() {
return _projectsWorking.asMap().entries.map((entry) {
final index = entry.key;
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Project ${index + 1}',
style: const TextStyle(fontWeight: FontWeight.bold),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.red),
onPressed: () => _removeProjectItem(index),
),
],
),
TextField(
controller: _projectTitleCtrls[index],
decoration: const InputDecoration(labelText: 'Project Title'),
),
TextField(
controller: _projectDescCtrls[index],
maxLines: 3,
decoration: const InputDecoration(labelText: 'Description'),
),
],
),
),
);
}).toList();
}

void _addProjectItem() {
setState(() {
final newIndex = _projectsWorking.length;
_projectsWorking.add({});
_projectTitleCtrls[newIndex] = TextEditingController();
_projectDescCtrls[newIndex] = TextEditingController();
});
}

void _removeProjectItem(int index) {
setState(() {
_projectsWorking.removeAt(index);
_projectTitleCtrls.remove(index);
_projectDescCtrls.remove(index);
_reindexControllers(_projectTitleCtrls, index);
_reindexControllers(_projectDescCtrls, index);
});
}

Future<void> _saveProjects() async {
final List<Map<String, dynamic>> projects = [];

for (int i = 0; i < _projectsWorking.length; i++) {
projects.add({
'title': _projectTitleCtrls[i]!.text.trim(),
'description': _projectDescCtrls[i]!.text.trim(),
});
}

await _savePatch(section: 'projects', value: projects);
}

Widget _buildEducationEditor(List<Map<String, dynamic>> education) {
return Card(
margin: const EdgeInsets.only(bottom: 16),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"EDIT EDUCATION",
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
..._buildEducationItems(),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: _addEducationItem,
icon: const Icon(Icons.add),
label: const Text('Add Education'),
),
const SizedBox(height: 16),
Row(
children: [
ElevatedButton(
onPressed: () async {
await _saveEducation();
setState(() => _editingEducation = false);
},
child: const Text('Save'),
),
const SizedBox(width: 12),
TextButton(
onPressed: () => setState(() => _editingEducation = false),
child: const Text('Cancel'),
),
],
),
],
),
),
);
}

List<Widget> _buildEducationItems() {
return _educationWorking.asMap().entries.map((entry) {
final index = entry.key;
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Education ${index + 1}',
style: const TextStyle(fontWeight: FontWeight.bold),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.red),
onPressed: () => _removeEducationItem(index),
),
],
),
TextField(
controller: _eduDegreeCtrls[index],
decoration: const InputDecoration(labelText: 'Degree'),
),
TextField(
controller: _eduInstitutionCtrls[index],
decoration: const InputDecoration(labelText: 'Institution'),
),
TextField(
controller: _eduLocationCtrls[index],
decoration: const InputDecoration(labelText: 'Location'),
),
TextField(
controller: _eduDateCtrls[index],
decoration: const InputDecoration(labelText: 'Date'),
),
TextField(
controller: _eduGpaCtrls[index],
decoration: const InputDecoration(labelText: 'GPA/Marks'),
),
],
),
),
);
}).toList();
}

void _addEducationItem() {
setState(() {
final newIndex = _educationWorking.length;
_educationWorking.add({});
_eduDegreeCtrls[newIndex] = TextEditingController();
_eduInstitutionCtrls[newIndex] = TextEditingController();
_eduLocationCtrls[newIndex] = TextEditingController();
_eduDateCtrls[newIndex] = TextEditingController();
_eduGpaCtrls[newIndex] = TextEditingController();
});
}

void _removeEducationItem(int index) {
setState(() {
_educationWorking.removeAt(index);
_eduDegreeCtrls.remove(index);
_eduInstitutionCtrls.remove(index);
_eduLocationCtrls.remove(index);
_eduDateCtrls.remove(index);
_eduGpaCtrls.remove(index);
_reindexControllers(_eduDegreeCtrls, index);
_reindexControllers(_eduInstitutionCtrls, index);
_reindexControllers(_eduLocationCtrls, index);
_reindexControllers(_eduDateCtrls, index);
_reindexControllers(_eduGpaCtrls, index);
});
}

Future<void> _saveEducation() async {
final List<Map<String, dynamic>> education = [];

for (int i = 0; i < _educationWorking.length; i++) {
education.add({
'degree': _eduDegreeCtrls[i]!.text.trim(),
'institution': _eduInstitutionCtrls[i]!.text.trim(),
'location': _eduLocationCtrls[i]!.text.trim(),
'date': _eduDateCtrls[i]!.text.trim(),
'gpa': _eduGpaCtrls[i]!.text.trim(),
});
}

await _savePatch(section: 'education', value: education);
}

Widget _buildCertificationsEditor(List<Map<String, dynamic>> certifications) {
return Card(
margin: const EdgeInsets.only(bottom: 16),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"EDIT CERTIFICATIONS",
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
..._buildCertificationItems(),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: _addCertificationItem,
icon: const Icon(Icons.add),
label: const Text('Add Certification'),
),
const SizedBox(height: 16),
Row(
children: [
ElevatedButton(
onPressed: () async {
await _saveCertifications();
setState(() => _editingCertifications = false);
},
child: const Text('Save'),
),
const SizedBox(width: 12),
TextButton(
onPressed: () => setState(() => _editingCertifications = false),
child: const Text('Cancel'),
),
],
),
],
),
),
);
}

List<Widget> _buildCertificationItems() {
return _certificationsWorking.asMap().entries.map((entry) {
final index = entry.key;
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Certification ${index + 1}',
style: const TextStyle(fontWeight: FontWeight.bold),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.red),
onPressed: () => _removeCertificationItem(index),
),
],
),
TextField(
controller: _certTitleCtrls[index],
decoration: const InputDecoration(labelText: 'Certification Title'),
),
TextField(
controller: _certDateCtrls[index],
                decoration: const InputDecoration(labelText: 'Date Earned'),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _addCertificationItem() {
    setState(() {
      final newIndex = _certificationsWorking.length;
      _certificationsWorking.add({});
      _certTitleCtrls[newIndex] = TextEditingController();
      _certIssuerCtrls[newIndex] = TextEditingController();
      _certDateCtrls[newIndex] = TextEditingController();
    });
  }

  void _removeCertificationItem(int index) {
    setState(() {
      _certificationsWorking.removeAt(index);
      _certTitleCtrls.remove(index);
      _certIssuerCtrls.remove(index);
      _certDateCtrls.remove(index);
      _reindexControllers(_certTitleCtrls, index);
      _reindexControllers(_certIssuerCtrls, index);
      _reindexControllers(_certDateCtrls, index);
    });
  }

  Future<void> _saveCertifications() async {
    final List<Map<String, dynamic>> certifications = [];

    for (int i = 0; i < _certificationsWorking.length; i++) {
      certifications.add({
        'title': _certTitleCtrls[i]!.text.trim(),
        'issuer': _certIssuerCtrls[i]!.text.trim(),
        'date': _certDateCtrls[i]!.text.trim(),
      });
    }

    await _savePatch(section: 'certifications', value: certifications);
  }

// ... (rest of the code remains the same)
}