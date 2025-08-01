import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'modules/auth/login_screen.dart';
import 'modules/dashboard/home_screen.dart';
import 'modules/resume_progress/resume_prompt_screen.dart';
import 'modules/voice_input/voice_input_screen.dart';
import 'modules/summary/summary_screen.dart';
import 'modules/ai_animation/ai_processing_screen.dart';
import 'modules/cv_preview/preview_screen.dart';
import 'modules/library/library_screen.dart';
import 'modules/edit_cv/edit_cv_screen.dart';

// Routes
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  runApp(const VoiceCVApp());
}

class VoiceCVApp extends StatelessWidget {
  const VoiceCVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice CV Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'OpenSans',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.resumePrompt: (_) => const ResumePromptScreen(),
        AppRoutes.voiceInput: (_) => const VoiceInputScreen(),
        // AppRoutes.library: (_) => const LibraryScreen(),
        // AppRoutes.editCV: (_) => const EditCVScreen(),

        // 🆕 Summary Screen
        AppRoutes.summary: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SummaryScreen(
            cvData: args['cvData'],
            totalSections: args['totalSections'],
          );
        },

        // 🆕 AI Processing Screen
        // AppRoutes.aiProcessing: (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return AIProcessingScreen(cvData: args['cvData']);
        // },

        // 🆕 Preview Screen
        // AppRoutes.preview: (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return PreviewScreen(cvData: args['cvData']);
        // },
      },
    );
  }
}
