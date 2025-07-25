import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/firestore_service.dart';

class ResumePromptScreen extends StatefulWidget {
  const ResumePromptScreen({super.key});

  @override
  State<ResumePromptScreen> createState() => _ResumePromptScreenState();
}

class _ResumePromptScreenState extends State<ResumePromptScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = true;
  Map<String, dynamic>? _lastCV;

  @override
  void initState() {
    super.initState();
    _checkLastCV();
  }

  Future<void> _checkLastCV() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    final cv = await _firestoreService.getLastCV(user.uid);

    setState(() {
      _lastCV = cv;
      _loading = false;
    });
  }

  Future<void> _startFreshCV() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.clearLastCV(user.uid);
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.voiceInput,
      arguments: {
        'forceNew': true, // ✅ Ensures a fresh mic session
        'resume': false,
        'cvId': 'cv_${DateTime.now().millisecondsSinceEpoch}',
        'cvData': {},
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume CV Progress'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined,
                size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "Would you like to continue your previous CV?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                if (_lastCV != null &&
                    _lastCV!['cvId'] != null &&
                    (_lastCV!['cvData'] as Map).isNotEmpty) {
                  print("✅ Resuming CV: $_lastCV");
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.voiceInput,
                    arguments: {
                      'forceNew': false, // ✅ Proper resume flag
                      'resume': true,
                      'cvId': _lastCV!['cvId'],
                      'cvData': _lastCV!['cvData'],
                    },
                  );
                } else {
                  print("⚠ No valid CV found. Starting fresh.");
                  _startFreshCV();
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("Yes, Resume"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                print("🔄 Starting a new CV.");
                _startFreshCV();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text("No, Start New"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
