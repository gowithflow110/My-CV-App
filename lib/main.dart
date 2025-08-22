// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Added for .env

// Auth Screens
import 'modules/auth/screens/sign_in_screen.dart';
import 'modules/auth/screens/splash_login_screen.dart';

// App Screens
import 'modules/dashboard/home_screen.dart';
import 'modules/resume_progress/resume_prompt_screen.dart';
import 'modules/voice_input/voice_input_screen.dart';
import 'modules/summary/summary_screen.dart';
import 'modules/ai_animation/ai_processing_screen.dart';
import 'modules/cv_preview/preview_screen.dart';
import 'modules/library/screens/library_screen.dart';
// import 'modules/edit_cv/edit_cv_screen.dart';

// Routes
import 'routes/app_routes.dart';
import 'models/cv_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load API keys & env vars
  await dotenv.load(fileName: ".env");

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("❌ Firebase initialization error: $e");
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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashLoginScreen(),
      routes: {
        AppRoutes.login: (_) => const SignInScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.resumePrompt: (_) => const ResumePromptScreen(),
        AppRoutes.voiceInput: (_) => const VoiceInputScreen(),
        AppRoutes.library: (_) => const LibraryScreen(),
        // AppRoutes.editCV: (_) => const EditCVScreen(),

        /// ✅ Summary Screen now expects a CVModel
        AppRoutes.summary: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as CVModel;
          return SummaryScreen(cv: args);
        },

        /// ✅ AI Processing Screen with CVModel
        AppRoutes.aiProcessing: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as CVModel;
          return AIProcessingScreen(rawCV: args);
        },

        /// ✅ Preview Screen with CVModel
        AppRoutes.preview: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as CVModel;
          return PreviewScreen(cv: args);
        },
      },
    );
  }
}