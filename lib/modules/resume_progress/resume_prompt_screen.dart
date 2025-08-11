//resume_prompt_screen.dart

import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../routes/app_routes.dart';
import '../../services/firestore_service.dart';

class ResumePromptScreen extends StatefulWidget {
  final FirestoreService? firestoreService;
  final FirebaseAnalytics? analytics;
  final FirebaseAuth? auth; // ✅ NEW: allows mock injection for tests

  const ResumePromptScreen({
    super.key,
    this.firestoreService,
    this.analytics,
    this.auth,
  });

  @override
  State<ResumePromptScreen> createState() => _ResumePromptScreenState();
}

class _ResumePromptScreenState extends State<ResumePromptScreen> {
  late final FirestoreService _firestoreService;
  late final FirebaseAnalytics _analytics;
  late final FirebaseAuth _auth; // ✅ NEW

  bool _loading = true;
  Map<String, dynamic>? _lastCV;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _analytics = widget.analytics ?? FirebaseAnalytics.instance;
    _auth = widget.auth ?? FirebaseAuth.instance; // ✅ use mock in tests
    _checkLastCV();
  }

  Future<void> _checkLastCV() async {
    try {
      final user = _auth.currentUser; // ✅ replaced direct FirebaseAuth.instance
      if (user == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final cv = await _firestoreService.getLastCV(user.uid);

      setState(() {
        _lastCV = cv;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
        _loading = false;
      });
      debugPrint("❌ Error loading last CV: $e");
    }
  }

  Future<void> _startFreshCV() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.clearLastCV(user.uid);
      }

      await _analytics.logEvent(name: "resume_no_pressed");
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.voiceInput,
        arguments: {
          'forceNew': true,
          'resume': false,
          'cvId': 'cv_${DateTime.now().millisecondsSinceEpoch}',
          'cvData': {},
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to start a new CV.")),
      );
    }
  }

  Future<void> _resumeCV() async {
    try {
      if (_lastCV != null &&
          _lastCV!['cvId'] != null &&
          (_lastCV!['cvData'] as Map).isNotEmpty) {
        await _analytics.logEvent(name: "resume_yes_pressed");
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          AppRoutes.voiceInput,
          arguments: {
            'forceNew': false,
            'resume': true,
            'cvId': _lastCV!['cvId'],
            'cvData': _lastCV!['cvData'],
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No saved CV found. Starting fresh.")),
        );
        _startFreshCV();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to resume CV. Starting fresh.")),
      );
      _startFreshCV();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Body color
      appBar: AppBar(
        title: const Text('Resume CV Progress'),
        centerTitle: true,
        backgroundColor: const Color(0xFFE8F3F8), // ✅ Head color
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// ✅ Top Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.assignment_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            /// ✅ Title & Subtitle
            Text(
              _errorMessage ?? "Resume Your CV Progress?",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  "We found an incomplete CV. Would you like to continue where you left off?",
              style: const TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            /// ✅ Resume Button (Primary)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _resumeCV,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  "Yes, Resume CV",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            /// ✅ Start Fresh Button (Secondary)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _startFreshCV,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Colors.blueAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "No, Start Fresh",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
