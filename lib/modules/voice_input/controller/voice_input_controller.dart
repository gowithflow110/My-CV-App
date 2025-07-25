import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';

class VoiceInputController extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late String cvId = 'cv_${DateTime.now().millisecondsSinceEpoch}';
  late String userId;
  bool isResumed = false;

  bool isListening = false;
  String transcription = '';

  List<Map<String, dynamic>> sections = [];
  int currentIndex = 0;
  Map<String, dynamic> userData = {};

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
        'hint': "What's your full name? Say: My name is John Doe."
      },
      {
        'title': 'Contact Info',
        'key': 'contact',
        'required': true,
        'multiple': true,
        'hint': "Say your phone or email. E.g., My phone is 1234567890."
      },
      {
        'title': 'Education',
        'key': 'education',
        'required': true,
        'multiple': true,
        'hint': "Mention degrees like: I completed BSc from XYZ."
      },
      {
        'title': 'Work Experience',
        'key': 'experience',
        'required': true,
        'multiple': true,
        'hint': "Say: I worked at ABC as a developer."
      },
      {
        'title': 'Skills',
        'key': 'skills',
        'required': true,
        'multiple': true,
        'hint': "Say skills: I know Flutter, Dart, and Firebase."
      },
      {
        'title': 'Projects',
        'key': 'projects',
        'required': false,
        'multiple': true,
        'hint': "Say project: I built a weather app using Flutter."
      },
      {
        'title': 'Certifications',
        'key': 'certifications',
        'required': false,
        'multiple': true,
        'hint': "Say certification: I am Google certified."
      },
      {
        'title': 'Languages',
        'key': 'languages',
        'required': false,
        'multiple': true,
        'hint': "Say: I speak English and French."
      },
      {
        'title': 'Professional Summary',
        'key': 'summary',
        'required': false,
        'multiple': false,
        'hint': "Say: I am a dedicated software engineer..."
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

    bool available = await _speech.initialize(
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

    isListening = false;
    if (!available) {
      debugPrint("Speech recognition not available");
    }
    notifyListeners();
  }

  Future<void> resetSpeech({bool clearTranscription = true}) async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _speech.cancel();
    isListening = false;

    // Only clear if explicitly asked
    if (clearTranscription) {
      transcription = '';
    }

    notifyListeners();
  }

  Future<void> startListening() async {
    if (isListening) {
      await stopListening();
      return;
    }

    if (!_speech.isAvailable) {
      await initializeSpeech();
      if (!_speech.isAvailable) {
        debugPrint("Speech engine not available even after init");
        return;
      }
    }

    isListening = true;
    transcription = '';
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
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
      notifyListeners();
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
      notifyListeners();
      return;
    }

    final lastCV = await _firestoreService.getLastCV(userId);
    if (lastCV != null) {
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

  void editEntry(String key, int index) {
    transcription = (userData[key] as List<String>)[index];
    (userData[key] as List<String>).removeAt(index);
    notifyListeners();
    startListening();
  }

  void deleteEntry(String key, int index) {
    (userData[key] as List<String>).removeAt(index);
    notifyListeners();
  }

  Future<String?> nextSection(BuildContext context) async {
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in. Cannot save CV.")),
      );
      return null;
    }

    final section = sections[currentIndex];
    final key = section['key'];
    final required = section['required'];
    final multiple = section['multiple'];

    // ✅ Save single-entry data before switching
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
        const SnackBar(content: Text("This field is required.")),
      );
      return null;
    }

    await _firestoreService.saveSection(userId, cvId, userData);

    if (currentIndex < sections.length - 1) {
      currentIndex++;
      final nextKey = sections[currentIndex]['key'];
      transcription = sections[currentIndex]['multiple']
          ? ''
          : (userData[nextKey]?.toString() ?? '');
      await resetSpeech(clearTranscription: false); // ✅ Don't wipe saved text
      notifyListeners();
      return null;
    } else {
      await _firestoreService.markCVComplete(userId, cvId);
      await resetSpeech();
      return "completed";
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
      resetSpeech(clearTranscription: false); // ✅ Keep restored text
      notifyListeners();
    }
  }

  void disposeController() {
    resetSpeech();
  }
}
