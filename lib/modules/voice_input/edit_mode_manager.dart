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

    if (args.containsKey('forceEdit') && args['forceEdit'] == true ||
        args.containsKey('startSectionKey')) {
      isEditMode = true;
      controller.isManualInput = false;

      if (args.containsKey('cvModel')) {
        final cvModel = args['cvModel'] as CVModel;
        controller.cvId = cvModel.cvId;
      }

      if (args.containsKey('editField')) {
        editField = args['editField'] as String?;
      } else if (args.containsKey('startSectionKey')) {
        editField = args['startSectionKey'] as String?;
      }

      if (editField != null) {
        final section = controller.sections
            .firstWhere((s) => s['key'] == editField);

        controller.currentIndex =
            controller.sections.indexOf(section);

        previousData = controller.userData[editField!];

        final isMultiple = section['multiple'] as bool;
        final isMap = section['map'] == true; // NEW

        if (isMap) {
          // Ensure we always have a map for editing
          if (previousData is Map<String, dynamic>) {
            controller.userData[editField!] =
            Map<String, String>.from(previousData);
          } else {
            controller.userData[editField!] = {};
          }
          controller.transcription = ''; // map sections handled field by field
        } else if (isMultiple) {
          if (previousData is List) {
            controller.userData[editField!] =
            List<String>.from(previousData as List);
          } else if (previousData is String && previousData.isNotEmpty) {
            controller.userData[editField!] = [previousData];
          } else {
            controller.userData[editField!] = [];
          }

          if (args.containsKey('editIndex') && args['editIndex'] != null) {
            editEntryIndex = args['editIndex'] as int;
            final list =
            List<String>.from(controller.userData[editField!] ?? []);
            if (editEntryIndex! < list.length) {
              controller.transcription = list[editEntryIndex!];
            }
          } else {
            editEntryIndex = null;
            controller.transcription = '';
          }
        } else {
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
    final key = section['key'];
    final isMultiple = section['multiple'] as bool;
    final required = section['required'] as bool;
    final isMap = section['map'] == true; // NEW
    final trimmedValue = controller.transcription.trim();

    bool hasValidData = false;

    if (isMap) {
      final entries = Map<String, String>.from(
          controller.userData[key] ?? {});

      // If transcription refers to a single field update (optional improvement),
      // you would handle it here. For now, we trust the map is updated elsewhere.
      hasValidData = entries.values.any((v) => v.trim().isNotEmpty);
      if (hasValidData) {
        controller.userData[key] = entries;
      }
    } else if (isMultiple) {
      final entries = List<String>.from(controller.userData[key] ?? []);
      if (trimmedValue.isNotEmpty) {
        if (editEntryIndex != null && editEntryIndex! < entries.length) {
          entries[editEntryIndex!] = trimmedValue;
        } else {
          entries.add(trimmedValue);
        }
      }
      hasValidData = entries.isNotEmpty;
      if (hasValidData) {
        controller.userData[key] = entries;
      }
    } else {
      hasValidData = trimmedValue.isNotEmpty;
      if (hasValidData) {
        controller.userData[key] = trimmedValue;
      }
    }

    if (required && !hasValidData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content:
          Text("This section is required. Please enter at least one value."),
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

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cvId = controller.cvId;

    final cvModel = CVModel(
      cvId: cvId,
      userId: userId,
      cvData: Map<String, dynamic>.from(controller.userData),
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, cvModel);
  }
}
