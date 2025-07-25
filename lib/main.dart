import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'modules/auth/login_screen.dart';
import 'modules/dashboard/home_screen.dart';
import 'modules/voice_input/voice_input_screen.dart';
import 'modules/cv_preview/preview_screen.dart';
import 'modules/result/download_share_screen.dart';
import 'modules/result/result_screen.dart';
import 'modules/library/library_screen.dart';
import 'modules/edit_cv/edit_cv_screen.dart';
import 'modules/resume_progress/resume_prompt_screen.dart';
import 'modules/result/ai_processing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🛡 This avoids duplicate app error
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
      home: const LoginScreen(),  // Always show login
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.voiceInput: (_) => const VoiceInputScreen(),
        // AppRoutes.preview: (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return PreviewScreen(cvData: args);
        // },
        AppRoutes.result: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ResultScreen(
            cvData: args['cvData'],
            totalSections: args['totalSections'],
          );
        },

        // AppRoutes.library: (_) => const LibraryScreen(),
        // AppRoutes.editCV: (_) => const EditCVScreen(),
        AppRoutes.resumePrompt: (_) => const ResumePromptScreen(),
        // AppRoutes.downloadShare: (_) => const DownloadShareScreen(),
        // Inside MaterialApp routes:
        // AppRoutes.aiProcessing: (context) {
        //   final args =
        //   ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return AIProcessingScreen(cvData: args);
        // },
      },
    );
  }

}
