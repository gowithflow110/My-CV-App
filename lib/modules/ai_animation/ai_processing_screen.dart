// lib/modules/ai_animation/ai_processing_screen.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cv_model.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cv_parser.dart';
import '../../routes/app_routes.dart';

class AIProcessingScreen extends StatefulWidget {
  final CVModel rawCV;
  const AIProcessingScreen({Key? key, required this.rawCV}) : super(key: key);

  @override
  State<AIProcessingScreen> createState() => _AIProcessingScreenState();
}

class _AIProcessingScreenState extends State<AIProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _lottieController;
  double _progress = 0.0;
  String _progressText = "Initializing AI process...";
  String _providerUsed = "";
  bool _hasError = false;

  final List<String> _steps = [
    "Analyzing Data...",
    "Cleaning & Normalizing...",
    "Enhancing Grammar & Clarity...",
    "Structuring for Template...",
    "Finalizing CV..."
  ];

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAIProcessing();
    });
  }

  Future<void> _startAIProcessing() async {
    setState(() {
      _hasError = false;
      _progress = 0.0;
      _progressText = _steps.isNotEmpty ? _steps[0] : "";
      _providerUsed = "";
    });

    try {
      // Step 1: Get raw data copy
      final rawData = Map<String, dynamic>.from(widget.rawCV.cvData);

      // Step 2: Deterministic cleanup & normalization
      final refined = CVParser.refine(rawData);

      // Step 3: Send to AI to enhance content & fill missing template fields
      final polishedJson = await _simulateProgressAndCallAI(refined);
      setState(() => _providerUsed = polishedJson["_provider"] ?? "");
      polishedJson.remove("_provider"); // remove internal helper key

      // Step 4: Ensure AI output follows strict schema
      final finalStructured = CVParser.ensureTemplateCompliance(polishedJson);

      // Step 5: Build updated CV model with type-safe CVSections
      final Map<String, CVSection> updatedCVData = finalStructured.map<String, CVSection>((key, value) {
        if (value is CVSection) return MapEntry(key, value);
        if (value is List) return MapEntry(key, CVSection(text: value.map((e) => e.toString()).join(', ')));
        if (value is Map) return MapEntry(key, CVSection(text: value.values.map((v) => v.toString()).join(', ')));
        return MapEntry(key, CVSection(text: value?.toString() ?? ''));
      });

      // Step 6: Build final CVModel
      final updated = widget.rawCV.copyWith(
        cvData: updatedCVData,
        aiEnhancedText: null,
        isCompleted: true,
        updatedAt: DateTime.now(),
      );

      // Step 7: Save to Firestore (AI-generated CV)
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isNotEmpty) {
        await _firestoreService.saveGeneratedCV(userId, updated);
      }

      // Step 8: Navigate to preview
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.preview,
        arguments: updated,
      );
    } catch (e, stack) {
      debugPrint("❌ AI Processing Error: $e\n$stack");
      if (mounted) setState(() => _hasError = true);
    }
  }



  Future<Map<String, dynamic>> _simulateProgressAndCallAI(
      Map<String, dynamic> refined) async {
    final aiService = AIService();
    Map<String, dynamic> polishedJson = {};

    try {
      // Step 1: Update progress incrementally before calling AI
      for (int i = 0; i < _steps.length; i++) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) break;
        setState(() {
          _progress = (i + 1) / (_steps.length + 2); // leave room for AI call
          _progressText = _steps[i];
        });
      }

      // Step 2: Call AI service while showing interpolated progress
      final aiFuture = aiService.polishCVAsJson(refined);

      // Animate progress smoothly while AI call is ongoing
      double startProgress = _progress;
      const int updates = 10; // number of progress increments
      for (int j = 1; j <= updates; j++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) break;
        setState(() {
          _progress = startProgress + (j / updates) * (1.0 - startProgress);
        });
      }

      // Await AI result
      polishedJson = await aiFuture;

      // Store which AI provider was used
      polishedJson["_provider"] = aiService.lastProviderUsed;

      // Step 3: Ensure progress is complete
      if (mounted) {
        setState(() {
          _progress = 1.0;
          _progressText = "AI Processing Complete";
        });
      }
    } catch (e, stack) {
      debugPrint("❌ Error during AI processing: $e\n$stack");
      if (mounted) {
        setState(() {
          _progressText = "Error occurred during AI processing";
        });
      }
      rethrow; // allow caller to handle retry
    }

    return polishedJson;
  }


  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _hasError
                ? _buildErrorUI()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Lottie.asset(
                          'assets/lottie/ai_processing.json',
                          controller: _lottieController,
                          onLoaded: (composition) {
                            _lottieController
                              ..duration = composition.duration
                              ..repeat();
                          },
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Text(
                            _progressText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_steps.length, (index) {
                              bool isActive =
                                  _progress >= (index + 1) / _steps.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                width: isActive ? 14 : 10,
                                height: isActive ? 14 : 10,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.blueAccent
                                      : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: _progress),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, value, child) {
                                return Container(
                                  height: 12,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6a11cb),
                                            Color(0xFF2575fc)
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${(_progress * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      if (_providerUsed.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          "AI Provider: $_providerUsed",
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        const Text(
          "Something went wrong while processing your CV.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _startAIProcessing,
          child: const Text("Retry"),
        ),
      ],
    );
  }
}
