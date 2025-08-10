// sign_in_screen.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../routes/app_routes.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    _controller.stop();

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) {
          setState(() {
            _isSigningIn = false;
            _controller.repeat(reverse: true);
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        final userData = {
          'uid': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
        };

        final usersRef = FirebaseFirestore.instance.collection('users');

        try {
          await usersRef.doc(user.uid).set(userData, SetOptions(merge: true));
          debugPrint('✅ User data written to Firestore');
        } catch (e) {
          debugPrint('❌ Firestore write failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save user info.')),
            );
          }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _controller.repeat(reverse: true);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in failed. Please try again.')),
        );
      }
    }
  }

  Widget _googleButton() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ElevatedButton.icon(
        onPressed: _isSigningIn ? null : _handleGoogleSignIn,
        icon: Image.asset(
          'assets/google_logo.png',
          height: 60,
          width: 60,
        ),
        label: Text(
          'Continue with Google',
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0078D7),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Image.asset(
                    'assets/cv_illustration.png',
                    height: 400,
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Voice CV Generator',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate a job-ready CV in seconds',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: _googleButton(),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Loader overlay when signing in
            if (_isSigningIn)
              Container(
                color: Colors.black.withOpacity(0.5), // semi-transparent overlay
                child: const Center(
                  child: CircularProgressIndicator(
                     valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 29, 61, 97)), // Your custom color // voice_input_screen color
                    strokeWidth: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
