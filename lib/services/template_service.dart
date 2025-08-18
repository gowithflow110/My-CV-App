// lib/services/template_service.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import '../models/cv_model.dart';
import '../modules/cv_preview/templates/template_default.dart';

class TemplateService {
  final CVModel cv;
  late pw.Font _materialIcons;

  TemplateService(this.cv);

  /// Load fonts (Material Icons)
  Future<void> _loadFonts() async {
    final data =
        await rootBundle.load("assets/fonts/MaterialIcons-Regular.ttf");
    _materialIcons = pw.Font.ttf(data);
  }

  /// Build and save PDF
  Future<File> buildPdf() async {
    await _loadFonts();

    final pdf = pw.Document();

    // Use TemplateDefault to render sections
    final template = TemplateDefault(cv, _materialIcons);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => template.buildSections(),
      ),
    );

    // Request permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception("Storage permission not granted");
    }

    // Save into Downloads
    final downloadsDir = Directory("/storage/emulated/0/Download");
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }

    final file = File(
      "${downloadsDir.path}/cv_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
