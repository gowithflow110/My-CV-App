// lib/modules/voice_input/voice_input_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../models/cv_model.dart';
import 'controller/voice_input_controller.dart';
import 'edit_mode_manager.dart';
import 'widgets/section_progress_bar.dart';
import 'widgets/section_list_item.dart';

class VoiceInputScreen extends StatefulWidget {
  final String? startSectionKey;

  const VoiceInputScreen({Key? key, this.startSectionKey}) : super(key: key);

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  late VoiceInputController _controller;
  late EditModeManager _editModeManager;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final ScrollController _scrollController = ScrollController();

  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = VoiceInputController();
    _editModeManager =
        EditModeManager(controller: _controller, context: context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.initializeSpeech();
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      await _controller.loadCVData(args: args);
      await _editModeManager.initializeEditMode(args);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _editModeManager.dispose();
    _controller.disposeController();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _logEvent(String name, {Map<String, dynamic>? params}) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> _saveUpdatesAndExit() async {
    await _editModeManager.saveUpdatesAndExit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CVModel) {
      if (_controller.userData != args.cvData) {
        setState(() {
          _controller.userData = Map<String, dynamic>.from(args.cvData);
        });
      }
    }

    if (_editModeManager.manualController.text != _controller.transcription) {
      _editModeManager.manualController.text = _controller.transcription;
      _editModeManager.manualController.selection = TextSelection.fromPosition(
        TextPosition(offset: _editModeManager.manualController.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<VoiceInputController>(
        builder: (context, controller, _) {
          final section = controller.sections[controller.currentIndex];
          final String key = section['key'];
          final bool multiple = section['multiple'];
          final bool required = section['required'];
          final String hint = section['hint'];

          final hasCompleted = multiple
              ? (controller.userData[key] as List).isNotEmpty
              : (controller.userData[key]?.toString().trim().isNotEmpty ??
              false);

          _autoScrollToBottom();

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _editModeManager.isEditMode
                    ? 'Edit Section: ${section['title']}'
                    : 'Voice Input',
              ),
              backgroundColor: const Color(0xFFE8F3F8),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.isLoading
                    ? null
                    : () async {
                  if (_editModeManager.isEditMode) {
                    Navigator.pop(context);
                  } else {
                    await controller.resetSpeech(
                        clearTranscription: false);
                    if (!mounted) return;
                    Navigator.pop(
                      context,
                      CVModel(
                        cvId: _controller.cvId,
                        userId:
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                        cvData: Map<String, dynamic>.from(
                            _controller.userData),
                        isCompleted: false,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }
                },
              ),
              actions: [
                if (_editModeManager.isEditMode)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 4,
                      ),
                      onPressed: controller.isLoading
                          ? null
                          : () async {
                        await _saveUpdatesAndExit();
                      },
                      child: const Text(
                        "Save Updates",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionProgressBar(
                      currentIndex: controller.currentIndex,
                      totalSections: controller.sections.length,
                      title: section['title'],
                      required: required,
                      hasCompleted: hasCompleted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    if (multiple)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_circle,
                                size: 14, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              "You can add multiple entries",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // if (_editModeManager.isEditMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Manual Edit"),
                        Switch(
                          value: controller.isManualInput,
                          onChanged: (val) {
                            setState(() {
                              controller.isManualInput = val;

                              if (val) {
                                _editModeManager.manualController.text =
                                    controller.transcription;
                                _editModeManager
                                    .manualController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(
                                          offset: _editModeManager
                                              .manualController.text.length),
                                    );
                              } else {
                                controller.transcription =
                                    _editModeManager
                                        .manualController.text;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // =========================
                    // MANUAL / MIC INPUT FIELD
                    // =========================
                    controller.isManualInput
                        ? TextField(
                      autofocus: true,
                      maxLines: null,
                      controller: _editModeManager.manualController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'Edit text manually...',
                        suffixIcon: _editModeManager
                            .manualController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _editModeManager.manualController
                                .clear();
                            controller.transcription = '';
                            controller.editingMicEntryIndex =
                            null;
                            setState(() {});
                          },
                        )
                            : null,
                      ),
                      onChanged: (val) {
                        controller.transcription = val;
                        setState(() {});
                      },
                    )
                        : Container(
                      width: double.infinity,
                      height: 120,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(
                          controller.transcription.isEmpty
                              ? (multiple
                              ? 'Your voice input will appear here...'
                              : (controller.userData[key]
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                              true
                              ? controller.userData[key]
                              .toString()
                              : 'Your voice input will appear here...'))
                              : controller.transcription,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =========================
                    // SINGLE ADD/UPDATE BUTTON
                    // =========================
                    if (multiple &&
                        ((_editModeManager.manualController.text
                            .trim()
                            .isNotEmpty &&
                            controller.isManualInput) ||
                            (controller.transcription.trim().isNotEmpty &&
                                !controller.isManualInput)))
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: controller.isLoading
                                ? null
                                : () {
                              setState(() {
                                if (controller.isManualInput) {
                                  final newEntry = _editModeManager
                                      .manualController.text
                                      .trim();
                                  if (newEntry.isEmpty) return;

                                  final editIndex = _editModeManager
                                      .editEntryIndex;
                                  _editModeManager.manualController
                                      .clear();
                                  _editModeManager.editEntryIndex =
                                  null;

                                  controller
                                      .addEntryToCurrentSection(
                                      newEntry,
                                      editIndex: editIndex);
                                } else {
                                  final spoken = controller
                                      .transcription
                                      .trim();
                                  if (spoken.isEmpty) return;

                                  final editIndex = controller
                                      .editingMicEntryIndex;
                                  controller.transcription = '';
                                  controller.editingMicEntryIndex =
                                  null;

                                  if (editIndex != null) {
                                    controller
                                        .updateEntryInCurrentSection(
                                        editIndex, spoken);
                                  } else {
                                    controller
                                        .addEntryToCurrentSection(
                                        spoken);
                                  }
                                }
                              });
                            },
                            icon: Icon(
                              controller.isManualInput
                                  ? (_editModeManager.editEntryIndex !=
                                  null
                                  ? Icons.update
                                  : Icons.add)
                                  : (controller.editingMicEntryIndex !=
                                  null
                                  ? Icons.update
                                  : Icons.add),
                              color: Colors.blue,
                              size: 20,
                            ),
                            label: Text(
                              controller.isManualInput
                                  ? (_editModeManager.editEntryIndex !=
                                  null
                                  ? 'Update Entry'
                                  : 'Add Entry')
                                  : (controller.editingMicEntryIndex !=
                                  null
                                  ? 'Update Entry'
                                  : 'Add Entry'),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // =========================
                    // MIC UNAVAILABLE NOTICE
                    // =========================
                    if (!controller.isManualInput &&
                        !controller.isSpeechAvailable)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Mic not available or failed (give Mic Permission). Please type your response:",
                            style: TextStyle(
                                fontSize: 14, color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (value) =>
                            controller.transcription = value,
                            controller: TextEditingController(
                                text: controller.transcription),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter response manually...',
                            ),
                            maxLines: null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),

                    // =========================
                    // MIC BUTTON
                    // =========================
                    if (!controller.isManualInput &&
                        controller.isSpeechAvailable)
                      Center(
                        child: IconButton(
                          iconSize: 60,
                          icon: Icon(
                            controller.isListening
                                ? Icons.mic_off
                                : Icons.mic,
                            color: controller.isListening
                                ? Colors.red
                                : Colors.blue,
                          ),
                          onPressed: controller.isLoading
                              ? null
                              : () async {
                            final hasNet =
                            await controller.hasInternet();
                            if (!hasNet) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text(
                                      "🎙️ Internet Required"),
                                  content: const Text(
                                      "Voice input needs internet connection. Please reconnect."),
                                  actions: [
                                    TextButton(
                                      child: const Text("OK"),
                                      onPressed: () =>
                                          Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            if (!controller.isListening) {
                              await _logEvent("start_listening",
                                  params: {"section": key});
                            } else {
                              await _logEvent("stop_listening",
                                  params: {"section": key});
                            }

                            await controller
                                .startListening(context);
                          },
                        ),
                      ),
                    const SizedBox(height: 20),

                    // =========================
                    // NAVIGATION BUTTONS
                    // =========================
                    if (!_editModeManager.isEditMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            onPressed: controller.currentIndex == 0 ||
                                controller.isLoading
                                ? null
                                : () {
                              final prevIndex =
                                  controller.currentIndex;
                              controller.backSection();

                              // clear manual text ONLY if section actually changed and we're in manual mode
                              if (controller.isManualInput &&
                                  controller.currentIndex !=
                                      prevIndex) {
                                _editModeManager.manualController
                                    .clear();
                                _editModeManager.editEntryIndex =
                                null; // stop editing state
                                controller.transcription =
                                ''; // keep manual box blank on next/back
                                setState(
                                        () {}); // refresh Add/Update button visibility
                              }
                            },
                          ),
                          if (!controller.isManualInput)
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.blue, size: 32),
                              onPressed: controller.isLoading
                                  ? null
                                  : () async {
                                await controller.resetSpeech(
                                    clearTranscription: true);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Retrying current text")),
                                );
                              },
                            ),
                          ElevatedButton.icon(
                            icon: Icon(
                              controller.currentIndex ==
                                  controller.sections.length - 1
                                  ? Icons.check
                                  : Icons.arrow_forward,
                            ),
                            label: Text(
                              controller.currentIndex ==
                                  controller.sections.length - 1
                                  ? 'Finish'
                                  : 'Next',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            onPressed: controller.isLoading
                                ? null
                                : () async {
                              final hasInternet =
                              await controller.hasInternet();
                              if (!hasInternet) {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text(
                                        "⚠️ No Internet"),
                                    content: const Text(
                                        "Please connect to the internet to proceed to the next section."),
                                    actions: [
                                      TextButton(
                                        child: const Text("OK"),
                                        onPressed: () =>
                                            Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              final prevIndex =
                                  controller.currentIndex;

                              final result = await controller
                                  .nextSection(context);
                              if (result == "completed") {
                                final userId = FirebaseAuth.instance
                                    .currentUser?.uid ??
                                    '';
                                final cvId =
                                    'cv_${DateTime.now().millisecondsSinceEpoch}';
                                final cvModel = CVModel(
                                  cvId: cvId,
                                  userId: userId,
                                  cvData: controller.userData,
                                  isCompleted: false,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                if (_editModeManager.isEditMode) {
                                  Navigator.pop(context, cvModel);
                                } else {
                                  Navigator.pushNamed(
                                      context, AppRoutes.summary,
                                      arguments: cvModel);
                                }
                              } else {
                                // moved to another section (no completion)
                                if (controller.isManualInput &&
                                    controller.currentIndex !=
                                        prevIndex) {
                                  _editModeManager.manualController
                                      .clear();
                                  _editModeManager.editEntryIndex =
                                  null;
                                  controller.transcription = '';
                                  setState(() {});
                                }
                              }
                            },
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // =========================
                    // MULTIPLE ENTRY LIST DISPLAY
                    // =========================
                    if (multiple &&
                        (controller.userData[key] as List).isNotEmpty)
                      SectionListItem(
                        entries: List<String>.from(
                            controller.userData[key] as List),
                        onEdit: (index) async {
                          if (controller.isManualInput) {
                            // ✅ Manual mode → prefill text for editing
                            final entryText = controller
                                .getEntriesForSection(key)[index];
                            _editModeManager.manualController.text = "";
                            Future.delayed(
                                const Duration(milliseconds: 50), () {
                              _editModeManager.manualController.text =
                                  entryText;
                              _editModeManager.manualController
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: entryText.length),
                              );
                            });

                            _editModeManager.editEntryIndex = index;
                            setState(() {});
                          } else {
                            // ✅ Mic mode → prefill transcription with existing entry
                            final entryText = controller
                                .getEntriesForSection(key)[index];
                            setState(() {
                              controller.editingMicEntryIndex = index;
                              controller.transcription =
                                  entryText; // show old entry in mic box
                            });

                            // Don’t clear transcription on reset → keep old text visible
                            await controller.resetSpeech(
                                clearTranscription: false);
                            await controller.startListening(context);
                          }
                        },
                        onDelete: (index) =>
                            controller.deleteEntry(key, index),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}