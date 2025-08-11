import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

// Auth Screens
import 'modules/auth/screens/sign_in_screen.dart';
import 'modules/auth/screens/splash_login_screen.dart';

// App Screens
import 'modules/dashboard/home_screen.dart';
import 'modules/resume_progress/resume_prompt_screen.dart';
import 'modules/voice_input/voice_input_screen.dart';
import 'modules/summary/summary_screen.dart';
// import 'modules/ai_animation/ai_processing_screen.dart';
// import 'modules/cv_preview/preview_screen.dart';
// import 'modules/library/library_screen.dart';
// import 'modules/edit_cv/edit_cv_screen.dart';

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
      // Splash screen decides where to go
      home: const SplashLoginScreen(),
      routes: {
        AppRoutes.login: (_) => const SignInScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.resumePrompt: (_) => const ResumePromptScreen(),
        AppRoutes.voiceInput: (_) => const VoiceInputScreen(),
        // AppRoutes.library: (_) => const LibraryScreen(),
        // AppRoutes.editCV: (_) => const EditCVScreen(),
        AppRoutes.summary: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SummaryScreen(
            cvData: args['cvData'],
            totalSections: args['totalSections'],
          );
        },
        // AppRoutes.aiProcessing: (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return AIProcessingScreen(cvData: args['cvData']);
        // },
        // AppRoutes.preview: (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return PreviewScreen(cvData: args['cvData']);
        // },
      },
    );
  }
}
