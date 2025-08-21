import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cv_model.dart';
import '../../../services/firestore_service.dart';
import 'controller/voice_input_controller.dart';

class EditModeManager {
  final VoiceInputController controller;
  final BuildContext context;
  final FirestoreService _firestoreService = FirestoreService();

  bool isEditMode = false;
  int? editEntryIndex; // for lists
  String? editField;
  dynamic previousData;

  TextEditingController manualController = TextEditingController();

  EditModeManager({required this.controller, required this.context});

  void dispose() {
    manualController.dispose();
  }

  /// Initialize edit mode variables and preload data if applicable
  Future<void> initializeEditMode(Map<String, dynamic>? args) async {
    if (args == null) return;

    final forceEdit = args['forceEdit'] == true;
    final startSectionKey = args['startSectionKey'] as String?;

    if (forceEdit || startSectionKey != null) {
      isEditMode = true;
      controller.isManualInput = false;

      // Load CV ID if available
      if (args.containsKey('cvModel') && args['cvModel'] is CVModel) {
        final cvModel = args['cvModel'] as CVModel;
        controller.cvId = cvModel.cvId;
      }

      // Determine which field to edit
      editField = args['editField'] as String? ?? startSectionKey;

      if (editField != null) {
        // Find the section
        final section = controller.sections.firstWhere(
              (s) => s['key'] == editField,
          orElse: () => {},
        );

        controller.currentIndex = controller.sections.indexOf(section);

        // Get previous data
        previousData = controller.userData[editField!];

        final isMultiple = section['multiple'] as bool? ?? false;
        final isMap = section['map'] as bool? ?? false;

        if (isMap) {
          // Ensure we have a map for editing
          if (previousData is Map<String, dynamic>) {
            controller.userData[editField!] =
            Map<String, String>.from(previousData as Map);
          } else {
            controller.userData[editField!] = <String, String>{};
          }
          controller.transcription = ''; // Map handled field by field
        } else if (isMultiple) {
          // Ensure list structure
          if (previousData is List) {
            controller.userData[editField!] = List<String>.from(previousData as List);
          } else if (previousData is String && previousData.isNotEmpty) {
            controller.userData[editField!] = [previousData];
          } else {
            controller.userData[editField!] = <String>[];
          }

          // Handle editing a specific list entry
          if (args.containsKey('editIndex') && args['editIndex'] is int) {
            editEntryIndex = args['editIndex'] as int;
            final list = List<String>.from(controller.userData[editField!] ?? []);
            if (editEntryIndex! < list.length) {
              controller.transcription = list[editEntryIndex!];
            }
          } else {
            editEntryIndex = null;
            controller.transcription = '';
          }
        } else {
          // Single value section
          controller.transcription = previousData?.toString() ?? '';
          controller.userData[editField!] = controller.transcription;
        }
      }
    }
  }


  /// Save updates for the current edit and exit (pop)
  Future<void> saveUpdatesAndExit() async {
    if (!isEditMode || editField == null) return;

    final section = controller.sections[controller.currentIndex];
    final key = section['key'] as String;
    final isMultiple = section['multiple'] as bool? ?? false;
    final required = section['required'] as bool? ?? false;
    final isMap = section['map'] == true;
    final trimmedValue = controller.transcription.trim();

    bool hasValidData = false;

    if (isMap) {
      // Ensure all map values are strings
      final rawMap = controller.userData[key] as Map<dynamic, dynamic>? ?? {};
      final entries = rawMap.map<String, String>(
            (k, v) => MapEntry(k.toString(), v.toString()),
      );
      hasValidData = entries.values.any((v) => v.trim().isNotEmpty);
      if (hasValidData) controller.userData[key] = entries;
    } else if (isMultiple) {
      // Ensure list contains only strings
      final rawList = controller.userData[key] as List<dynamic>? ?? [];
      final entries = rawList.map((e) => e.toString()).toList();
      if (trimmedValue.isNotEmpty) {
        if (editEntryIndex != null && editEntryIndex! < entries.length) {
          entries[editEntryIndex!] = trimmedValue;
        } else {
          entries.add(trimmedValue);
        }
      }
      hasValidData = entries.isNotEmpty;
      if (hasValidData) controller.userData[key] = entries;
    } else {
      hasValidData = trimmedValue.isNotEmpty;
      if (hasValidData) controller.userData[key] = trimmedValue;
    }

    // Required field validation
    if (required && !hasValidData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            "This section is required. Please enter at least one value.",
          ),
        ),
      );
      return;
    }

    try {
      await controller.saveCurrentData();
    } catch (e) {
      debugPrint("Error saving updates: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save updates: $e")),
      );
      return;
    }

    // Convert userData to Map<String, CVSection> safely
    final cvData = controller.userData.map<String, CVSection>((key, value) {
      if (value is CVSection) return MapEntry(key, value);

      if (value is List) {
        final list = value.map((e) => e.toString()).toList();
        return MapEntry(key, CVSection(text: list.join(', ')));
      }

      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v.toString()));
        return MapEntry(key, CVSection(text: map.values.join(', ')));
      }

      return MapEntry(key, CVSection(text: value?.toString() ?? ''));
    });

    final cvModel = CVModel(
      cvId: controller.cvId,
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      cvData: cvData,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, cvModel);
  }



}