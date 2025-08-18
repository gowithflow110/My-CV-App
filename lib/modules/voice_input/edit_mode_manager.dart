// lib/modules/voice_input/edit_mode_manager.dart

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
  int? editEntryIndex; // null means new entry; int means editing existing entry
  String? editField;
  dynamic previousData;

  TextEditingController manualController = TextEditingController();

  EditModeManager({required this.controller, required this.context});

  void dispose() {
    manualController.dispose();
  }

  /// Initialize edit mode variables and preload data if applicable
  Future<void> initializeEditMode(Map<String, dynamic>? args) async {
    if (args == null || args['forceEdit'] != true) return;

    isEditMode = true;
    editField = args['editField'] as String?;
    previousData = args['previousData'];
    controller.isManualInput = false;

    if (editField != null) {
      final idx = controller.sections.indexWhere((s) => s['key'] == editField);
      if (idx != -1) {
        controller.currentIndex = idx;
      }

      final isMultiple = controller.sections
          .firstWhere((s) => s['key'] == editField)['multiple'] as bool;

      if (isMultiple) {
        // Keep existing entries visible
        if (previousData is List<String>) {
          controller.userData[editField!] = List<String>.from(previousData as List);
        } else if (previousData is String && previousData!.isNotEmpty) {
          controller.userData[editField!] = [previousData!];
        }

        // If editing a specific entry, preload it
        if (args.containsKey('editIndex') && args['editIndex'] != null) {
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
        controller.transcription = previousData?.toString() ?? '';
        controller.userData[editField!] = controller.transcription;
      }
    }
  }

  /// Save updates for the current edit and exit (pop)
  Future<void> saveUpdatesAndExit() async {
    if (!isEditMode || editField == null) return;

    final key = controller.sections[controller.currentIndex]['key'];
    final isMultiple =
        controller.sections[controller.currentIndex]['multiple'] as bool;
    final required =
        controller.sections[controller.currentIndex]['required'] as bool;
    final trimmedValue = controller.transcription.trim();

    bool hasValidData;
    if (isMultiple) {
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
          content: Text("This section is required. Please enter at least one value."),
        ),
      );
      return; // prevent saving if validation fails
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
