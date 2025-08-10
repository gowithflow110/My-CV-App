//splash_login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // only if checking Firestore
import '../../../routes/app_routes.dart';

class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({Key? key}) : super(key: key);

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // splash delay
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // ✅ Force refresh from Firebase to check if user still exists
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser == null) {
          // user was deleted/disabled
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }

        // ✅ OPTIONAL: Check if Firestore doc still exists
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .get();

        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }

        // ✅ User still valid → Go Home
        Navigator.pushReplacementNamed(context, AppRoutes.home);

      } catch (e) {
        // Any error → treat as invalid session
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
