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

    return [
      for (final section in sections) _buildPdfSection(section),
    ];
  }

  // ---------------- SECTION DATA ----------------
  List<Map<String, dynamic>> getOrderedSections() {
    final data = cv.cvData;

    return [
      {
        'type': 'header',
        'data': {
          'name': data['fullName'] ?? '',
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
          color: PdfColors.black,
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
                          fontSize: 10,
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

          const cols = 4;
          final usableWidth =
              PdfPageFormat.a4.availableWidth - 48; // page - margins
          final colWidth = usableWidth / cols;

          final rows = <pw.TableRow>[];
          for (int i = 0; i < items.length; i += cols) {
            final cells = <pw.Widget>[];
            for (int j = 0; j < cols; j++) {
              final idx = i + j;
              if (idx < items.length) {
                cells.add(
                  pw.Container(
                    width: colWidth,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      items[idx],
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ),
                );
              } else {
                cells.add(pw.SizedBox(width: colWidth));
              }
            }
            rows.add(pw.TableRow(children: cells));
          }

          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: _pdfSectionBlock(
              "Skills",
              pw.Table(
                defaultColumnWidth: pw.FixedColumnWidth(colWidth),
                children: rows,
              ),
            ),
          );
        }

      case 'experience':
        return _buildExperience(data);

      case 'projects':
        return _pdfSectionBlock(
          "Projects",
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (data as List).map<pw.Widget>((proj) {
              return pw.Padding(
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
                              style: pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'education':
        return _pdfSectionBlock(
          "Education",
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (data as List).map<pw.Widget>((edu) {
              return pw.Padding(
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
              );
            }).toList(),
          ),
        );

      case 'certifications':
        return _pdfSectionBlock(
          "Certifications",
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (data as List).map<pw.Widget>((cert) {
              return pw.Padding(
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
                              pw.Text(cert['issuer'] ?? '', style: _italic(10)),
                            ],
                          ),
                          pw.Text(cert['date'] ?? '', style: _italic(10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'languages':
        return _pdfSectionBlock(
          "Languages",
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (data as List)
                .map<pw.Widget>((lang) => pw.Padding(
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
                    ))
                .toList(),
          ),
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
                        fontSize: 11, fontStyle: pw.FontStyle.italic),
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

    final children = <pw.Widget>[];
    if (items.isNotEmpty) {
      children.add(
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Work Experience".toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      buildEntry(items.first),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (items.length > 1) {
      children.addAll(
        items.skip(1).map(
              (exp) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: buildEntry(exp),
              ),
            ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }
}
