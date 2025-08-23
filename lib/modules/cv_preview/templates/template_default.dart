// lib/modules/cv_preview/templates/template_default.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/cv_model.dart';
import '../../../services/experience_sanitizer.dart';

class TemplateDefault {
  final CVModel cv;
  final pw.Font? materialIcons;

  TemplateDefault(this.cv, [this.materialIcons]);

  /// Build all PDF sections
  List<pw.Widget> buildSections() {
    final sections = getOrderedSections();

    // Filter optional sections if they have no data
    final filteredSections = sections.where((section) {
      final type = section['type'];
      final data = section['data'];

      // Required sections (always keep)
      const required = [
        'header',
        'contact',
        'skills',
        'education',
        'languages'
      ];
      if (required.contains(type)) return true;

      // Exception: summary is part of header, already required

      // Optional sections: only keep if data is non-empty
      if (type == 'experience' && (data as List).isEmpty) return false;
      if (type == 'projects' && (data as List).isEmpty) return false;
      if (type == 'certifications' && (data as List).isEmpty) return false;

      return true; // any other sections (unlikely)
    }).toList();

    return [
      for (final section in filteredSections) _buildPdfSection(section),
    ];
  }

  // ---------------- SECTION DATA ----------------
  List<Map<String, dynamic>> getOrderedSections() {
    final data = cv.cvData;

    return [
      {
        'type': 'header',
        'data': {
          'name': data['name'] ?? '',        // Changed from 'fullName'
          'summary': data['summary'] ?? '',
        }
      },
      {'type': 'contact', 'data': data['contact'] ?? {}},
      {'type': 'skills', 'data': List<String>.from(data['skills'] ?? [])},
      {
        'type': 'experience',
        'data': ExperienceSanitizer.sanitizeList(data['experience']),
      },
      {
        'type': 'projects',
        'data': List<Map<String, dynamic>>.from(
          (data['projects'] ?? []).map((proj) => {
            'title': proj['name'] ?? '',
            'description': proj['description'] ?? '',
          }),
        )
      },
      {
        'type': 'education',
        'data': List<Map<String, dynamic>>.from(
          (data['education'] ?? []).map((edu) => {
            'degree': edu['degree'] ?? '',
            'institution': edu['institution'] ?? '',
            'location': edu['location'] ?? '',
            'date': edu['year'] ?? '',
            'gpa': edu['gpa'] ?? '',
          }),
        )
      },
      {
        'type': 'certifications',
        'data': List<Map<String, dynamic>>.from(data['certifications'] ?? []),
      },
      {'type': 'languages', 'data': List<String>.from(data['languages'] ?? [])},
    ];
  }

  // ---------------- SECTION RENDERERS ----------------
  pw.Widget _buildPdfSection(Map<String, dynamic> section) {
    final type = section['type'];
    final data = section['data'];

    switch (type) {
      case 'header':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data['name'] ?? '',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              data['summary'] ?? '',
              style: pw.TextStyle(fontSize: 11, lineSpacing: 3),
            ),
            pw.SizedBox(height: 16),
          ],
        );

      case 'contact':
        final items = _orderedContactItems(data);

        final availableWidth =
            PdfPageFormat.a4.availableWidth - 48; // page width - margins
        final itemWidth = availableWidth / 3;

        return pw.Container(
          width: double.infinity,
          color: PdfColor.fromInt(0xFF0D47A1), // Dark Blue
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: pw.Wrap(
            spacing: 20,
            runSpacing: 12,
            children: items.map((item) {
              final int code = item['icon'] as int;
              final String text = item['text'] as String;

              return pw.Container(
                width: itemWidth,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      String.fromCharCode(code),
                      style: pw.TextStyle(
                        font: materialIcons,
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        text,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'skills':
        {
          final items = List<String>.from(data as List);
          if (items.isEmpty) return pw.SizedBox();

          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: _pdfSectionBlock(
              "Skills",
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: items.map((skill) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Diamond bullet (center aligned)
                        pw.SizedBox(
                          width: 12,
                          height: 12,
                          child: pw.Center(
                            child: pw.Transform.rotateBox(
                              angle: 0.785, // 45° = diamond
                              child: pw.Container(
                                width: 6,
                                height: 6,
                                color: PdfColors.black,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(
                            width: 12), // indent space between bullet & text
                        // Skill text
                        pw.Expanded(
                          child: pw.Text(
                            skill,
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }

      case 'experience':
        return _buildExperience(data);

      case 'projects':
        final widgets = <pw.Widget>[];

        // Add section heading
        widgets.add(
          pw.Text(
            "PROJECTS",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));

        // Add each project individually
        for (final proj in data as List) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 2,
                    height: 28,
                    color: PdfColors.black,
                    margin: const pw.EdgeInsets.only(right: 8, top: 2),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          proj['title'] ?? '',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if ((proj['description'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            proj['description'] ?? '',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: widgets,
        );

      case 'education':
        final widgets = <pw.Widget>[];

        // Add section heading first
        widgets.add(
          pw.Text(
            "EDUCATION",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));

        // Add each entry individually so they can break
        for (final edu in data as List) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 2,
                    height: 40,
                    color: PdfColors.black,
                    margin: const pw.EdgeInsets.only(right: 8, top: 2),
                  ),
                  pw.Expanded(
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              edu['degree'] ?? '',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              (edu['location'] ?? '').toString().isNotEmpty
                                  ? "${edu['institution']}, ${edu['location']}"
                                  : (edu['institution'] ?? ''),
                              style: _italic(10),
                            ),
                            if ((edu['gpa'] ?? '').isNotEmpty)
                              pw.Text("GPA / Marks: ${edu['gpa']}",
                                  style: _italic(9)),
                          ],
                        ),
                        pw.Text(edu['date'] ?? '', style: _italic(10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: widgets,
        );

      case 'certifications':
        final widgets = <pw.Widget>[];

        // Add section heading
        widgets.add(
          pw.Text(
            "CERTIFICATIONS",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));

        // Add each certification separately
        for (final cert in data as List) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 2,
                    height: 30,
                    color: PdfColors.black,
                    margin: const pw.EdgeInsets.only(right: 8, top: 2),
                  ),
                  pw.Expanded(
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              cert['title'] ?? '',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if ((cert['issuer'] ?? '').toString().isNotEmpty)
                              pw.Text(cert['issuer'], style: _italic(10)),
                          ],
                        ),
                        if ((cert['date'] ?? '').toString().isNotEmpty)
                          pw.Text(cert['date'], style: _italic(10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: widgets,
        );

      case 'languages':
        final widgets = <pw.Widget>[];

        // Add section heading
        widgets.add(
          pw.Text(
            "LANGUAGES",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));

        // Add each language separately
        for (final lang in data as List) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    margin: const pw.EdgeInsets.only(top: 3, right: 6),
                    color: PdfColors.black,
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      lang,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: widgets,
        );

      default:
        return pw.SizedBox();
    }
  }

  // ---------------- HELPERS ----------------
  pw.Widget _pdfSectionBlock(String title, pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  pw.TextStyle _italic(double size) =>
      pw.TextStyle(fontSize: size, fontStyle: pw.FontStyle.italic);

  List<Map<String, dynamic>> _orderedContactItems(Map<String, dynamic> data) {
    return [
      if (data['email']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe0be, 'text': data['email']}, // email
      if (data['location']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe55f, 'text': data['location']}, // location_on
      if (data['phone']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe0cd, 'text': data['phone']}, // phone
      if (data['github']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe86f, 'text': data['github']}, // code
      if (data['linkedin']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe157, 'text': data['linkedin']}, // link
      if (data['website']?.toString().trim().isNotEmpty ?? false)
        {'icon': 0xe894, 'text': data['website']}, // public
    ];
  }

  pw.Widget _buildExperience(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return pw.SizedBox();

    pw.Widget buildEntry(Map<String, dynamic> exp) {
      final companyLoc = "${exp['company'] ?? ''}"
          "${(exp['location'] ?? '').toString().trim().isNotEmpty ? ", ${exp['location']}" : ""}";
      final dates =
      (exp['dates'] ?? '').toString().replaceAll(RegExp(r'[–—]'), '-');

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 12,
                height: 1.2,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.only(right: 6, top: 0),
              ),
              pw.Text(
                exp['title'] ?? '',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          if (companyLoc.trim().isNotEmpty || dates.isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    companyLoc,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
                if (dates.isNotEmpty)
                  pw.Text(
                    dates,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
              ],
            ),
          if ((exp['duration'] ?? '').toString().trim().isNotEmpty)
            pw.Text(
              exp['duration'],
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          pw.SizedBox(height: 4),
          ...((exp['details'] as List?) ?? const []).map(
                (d) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4.4),
                    width: 3,
                    height: 3,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.black,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      d,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 👉 Heading + Entries (each entry independent)
    final widgets = <pw.Widget>[
      pw.Text(
        "WORK EXPERIENCE",
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
      pw.SizedBox(height: 6),
      for (final exp in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: buildEntry(exp),
        ),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
}