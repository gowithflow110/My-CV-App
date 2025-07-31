import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';
import 'dart:io';


class VoiceInputController extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late String cvId = 'cv_${DateTime.now().millisecondsSinceEpoch}';
  late String userId;
  bool isResumed = false;

  bool isListening = false;
  bool isLoading = false;
  String transcription = '';

  List<Map<String, dynamic>> sections = [];
  int currentIndex = 0;
  Map<String, dynamic> userData = {};

  // ✅ SCRUM-81: Mic Fallback Logic
  bool micFailed = false;

  VoiceInputController() {
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _initSections();
  }

  void _initSections() {
    sections = [
      {
        'title': 'Full Name',
        'key': 'name',
        'required': true,
        'multiple': false,
        'hint': "What's your full name? Example: My name is Ali Ahmed."
      },
      {
        'title': 'Contact Info',
        'key': 'contact',
        'required': true,
        'multiple': true,
        'hint': "Share your phone, email or address. Example: My phone number is 03001234560. "
      },
      {
        'title': 'Education',
        'key': 'education',
        'required': true,
        'multiple': true,
        'hint': "Mention your education. Example: I completed my Bachelor's from Punjab University in 2022."
      },
      {
        'title': 'Work Experience',
        'key': 'experience',
        'required': true,
        'multiple': true,
        'hint': "Talk about your job experience. Example: I worked as a sales man at Metro Store for 2 years."
      },
      {
        'title': 'Skills',
        'key': 'skills',
        'required': true,
        'multiple': true,
        'hint': "List your skills. Example: I am good at communication, teamwork, and using MS Office."
      },
      {
        'title': 'Projects',
        'key': 'projects',
        'required': false,
        'multiple': true,
        'hint': "Mention a project you’ve done. Example: I helped set up a billing system at my last job."
      },
      {
        'title': 'Certifications',
        'key': 'certifications',
        'required': false,
        'multiple': true,
        'hint': "Say a certificate you earned. Example: I completed a course in Office Management from ABC Institute."
      },
      {
        'title': 'Languages',
        'key': 'languages',
        'required': false,
        'multiple': true,
        'hint': "Which languages do you speak? Example: I can speak English, Urdu, and Punjabi."
      },
      {
        'title': 'Professional Summary',
        'key': 'summary',
        'required': false,
        'multiple': false,
        'hint': "Briefly describe yourself. Example: I am a hardworking individual with strong communication skills and a passion for learning."
      },
    ];

    for (var section in sections) {
      userData[section['key']] = section['multiple'] ? <String>[] : '';
    }
  }

  /// ======================
  /// ✅ SPEECH FUNCTIONS
  /// ======================

  Future<void> initializeSpeech() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _speech.cancel();

    micFailed = false;
    bool available = false;

    try {
      available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech Status: $status");
          if (status == 'done' || status == 'notListening') {
            if (isListening) {
              isListening = false;
              notifyListeners();
            }
          }
        },
        onError: (error) {
          debugPrint("Speech Error: $error");
          stopListening();
        },
      );
    } catch (e) {
      debugPrint("❌ Exception during mic init: $e");
      micFailed = true;
      notifyListeners();
      return;
    }

    isListening = false;

    if (!available) {
      debugPrint("⚠️ Speech recognition not available");
      micFailed = true;
    }

    notifyListeners();
  }

  Future<void> resetSpeech({bool clearTranscription = true}) async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _speech.cancel();
    isListening = false;

    if (clearTranscription) {
      transcription = '';
    }

    micFailed = false; // Reset fallback state when retrying
    notifyListeners();
  }

  Future<void> startListening(BuildContext context) async {
    if (!await hasInternet()) {
      micFailed = true;
      notifyListeners();
      debugPrint("📴 Mic blocked due to no internet");
      return;
    }

    if (isListening) {
      await stopListening();
      return;
    }

    await initializeSpeech();
    await Future.delayed(Duration(milliseconds: 100)); // Give a moment for state update
    if (!_speech.isAvailable || micFailed) {
      debugPrint("🚫 Mic not available, fallback required");
      micFailed = true;
      notifyListeners();
      return;
    }


    isListening = true;
    transcription = '';
    notifyListeners();

    await _speech.listen(
      onResult: (result) async {
        transcription = result.recognizedWords;
        notifyListeners();


      },

      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }


  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      await _speech.cancel();
    }
    isListening = false;
    notifyListeners();
  }

  /// ======================
  /// ✅ CV DATA FUNCTIONS
  /// ======================

  Future<void> loadCVData({Map<String, dynamic>? args}) async {
    await resetSpeech();
    isLoading = true;
    notifyListeners();

    try {
      if (args != null && args['forceEdit'] == true) {
        isResumed = false;
        cvId = args['cvId'] ?? cvId;

        final lastCV = await _firestoreService.getLastCV(userId);
        if (lastCV != null) {
          final savedData = Map<String, dynamic>.from(lastCV['cvData']);
          for (var section in sections) {
            final key = section['key'];
            userData[key] = section['multiple']
                ? List<String>.from(savedData[key] ?? [])
                : savedData[key] ?? '';
          }
        }

        final editKey = args['editField'] as String;
        currentIndex = sections.indexWhere((s) => s['key'] == editKey);
        transcription = args['previousData']?.toString() ?? '';
        return;
      }

      if (args != null && args['forceNew'] == true) {
        isResumed = false;
        cvId = 'cv_${DateTime.now().millisecondsSinceEpoch}';
        userData.clear();
        for (var section in sections) {
          userData[section['key']] = section['multiple'] ? <String>[] : '';
        }
        currentIndex = 0;
        transcription = '';
        return;
      }

      final lastCV = await _firestoreService.getLastCV(userId);

      if (lastCV != null &&
          lastCV['cvData'] != null &&
          (lastCV['cvData'] as Map).isNotEmpty) {
        isResumed = true;
        cvId = lastCV['cvId'];
        final savedData = Map<String, dynamic>.from(lastCV['cvData']);
        for (var section in sections) {
          final key = section['key'];
          userData[key] = section['multiple']
              ? List<String>.from(savedData[key] ?? [])
              : savedData[key] ?? '';
        }
        jumpToFirstIncomplete();
      } else {
        debugPrint("⚠ No valid last CV found, starting fresh.");
      }
    } catch (e) {
      debugPrint("❌ Error loading CV data: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void jumpToFirstIncomplete() {
    currentIndex = 0;
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final key = section['key'];
      final value = userData[key];
      final isFilled = section['multiple']
          ? (value as List).isNotEmpty
          : value.toString().trim().isNotEmpty;
      if (!isFilled) {
        currentIndex = i;
        break;
      }
    }
    transcription = sections[currentIndex]['multiple']
        ? ''
        : (userData[sections[currentIndex]['key']]?.toString() ?? '');
    notifyListeners();
  }

  void addToMultipleList(String key) {
    if (transcription.trim().isNotEmpty) {
      (userData[key] as List<String>).add(transcription.trim());
      transcription = '';
      notifyListeners();
    }
  }

  void editEntry(BuildContext context, String key, int index) {
    transcription = (userData[key] as List<String>)[index];
    (userData[key] as List<String>).removeAt(index);
    notifyListeners();
    startListening(context); // ✅ pass context here
  }

  void deleteEntry(String key, int index) {
    (userData[key] as List<String>).removeAt(index);
    notifyListeners();
  }

  Future<String?> nextSection(BuildContext context) async {
    // ✅ 1. Check internet FIRST before any UI change
    final isConnected = await hasInternet();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📡 No internet connection. Please reconnect to continue."),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User not logged in. Cannot save CV."),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }

    final section = sections[currentIndex];
    final key = section['key'];
    final required = section['required'];
    final multiple = section['multiple'];

    // ✅ Add input to userData
    if (transcription.trim().isNotEmpty) {
      if (multiple) {
        (userData[key] as List<String>).add(transcription.trim());
      } else {
        userData[key] = transcription.trim();
      }
    }

    final hasData = multiple
        ? (userData[key] as List<String>).isNotEmpty
        : userData[key].toString().trim().isNotEmpty;

    if (required && !hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange[700],
          elevation: 8,
          duration: const Duration(seconds: 4),
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "This field is required.",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      return null;
    }

    try {
      // ✅ Only now, if everything is okay, show loading animation
      isLoading = true;
      notifyListeners();

      await _firestoreService.saveSection(userId, cvId, userData);

      if (currentIndex < sections.length - 1) {
        currentIndex++;
        final nextKey = sections[currentIndex]['key'];
        transcription = sections[currentIndex]['multiple']
            ? ''
            : (userData[nextKey]?.toString() ?? '');

        await resetSpeech(clearTranscription: false);
        return null;
      } else {
        await _firestoreService.markCVComplete(userId, cvId);
        await resetSpeech();
        return "completed";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error saving CV: $e"),
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint("🛑 Error in nextSection(): $e");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }




  void backSection() {
    final section = sections[currentIndex];
    final key = section['key'];

    if (!section['multiple'] && transcription.trim().isNotEmpty) {
      userData[key] = transcription.trim();
    }

    if (currentIndex > 0) {
      currentIndex--;
      final prevKey = sections[currentIndex]['key'];
      transcription = sections[currentIndex]['multiple']
          ? ''
          : (userData[prevKey]?.toString() ?? '');
      resetSpeech(clearTranscription: false);
      notifyListeners();
    }
  }

  void disposeController() {
    resetSpeech();
  }
  // ✅ Used by UI to check mic status
  bool get isSpeechAvailable => !micFailed;

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

}