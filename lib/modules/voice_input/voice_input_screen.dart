import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import 'controller/voice_input_controller.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({Key? key}) : super(key: key);

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  late VoiceInputController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VoiceInputController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.initializeSpeech();
      await _controller.loadCVData(
        args: ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?,
      );
    });
  }

  @override
  void dispose() {
    _controller.disposeController();
    super.dispose();
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
              : (controller.userData[key]?.toString().trim().isNotEmpty ?? false);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Voice Input'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await controller.resetSpeech(clearTranscription: false);
                  if (!mounted) return;
                  Navigator.pop(context);
                },
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// ======================
                  /// ✅ SECTION HEADER
                  /// ======================
                  Text(
                    'Section ${controller.currentIndex + 1} of ${controller.sections.length}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '🧠 ${section['title']} ${!required ? '(Optional)' : ''}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (hasCompleted)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),

                  /// ======================
                  /// ✅ VOICE TEXT DISPLAY
                  /// ======================
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        controller.transcription.isEmpty
                            ? (multiple
                            ? 'Your voice input will appear here...'
                            : (controller.userData[key]?.toString().trim().isNotEmpty == true
                            ? controller.userData[key].toString()
                            : 'Your voice input will appear here...'))
                            : controller.transcription,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  /// ✅ ADD ENTRY BUTTON FOR MULTIPLE
                  if (multiple && controller.transcription.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.addToMultipleList(key),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Entry'),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  /// ======================
                  /// ✅ MIC BUTTON
                  /// ======================
                  Center(
                    child: IconButton(
                      icon: Icon(
                        controller.isListening ? Icons.mic_off : Icons.mic,
                        size: 40,
                        color:
                        controller.isListening ? Colors.red : Colors.blue,
                      ),
                      onPressed: controller.startListening,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// ======================
                  /// ✅ NAVIGATION BUTTONS
                  /// ======================
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        onPressed: controller.backSection,
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          // ✅ Retry now keeps saved value for single-entry
                          await controller.resetSpeech(clearTranscription: true);
                        },
                        child: const Text('Retry'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        icon: Icon(controller.currentIndex ==
                            controller.sections.length - 1
                            ? Icons.check
                            : Icons.arrow_forward),
                        label: Text(controller.currentIndex ==
                            controller.sections.length - 1
                            ? 'Finish'
                            : 'Next'),
                        onPressed: () async {
                          final result = await controller.nextSection(context);
                          if (result == "completed") {
                            if (!mounted) return;
                            Navigator.pushNamed(
                              context,
                              AppRoutes.result,
                              arguments: {
                                "cvData": controller.userData,
                                "totalSections": controller.sections.length,
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// ======================
                  /// ✅ LIST VIEW FOR MULTIPLE ENTRIES
                  /// ======================
                  if (multiple &&
                      (controller.userData[key] as List).isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: (controller.userData[key] as List).length,
                        itemBuilder: (_, index) {
                          final entry =
                          (controller.userData[key] as List)[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(entry),
                              leading: const Icon(Icons.check_circle_outline),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        controller.editEntry(key, index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        controller.deleteEntry(key, index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
