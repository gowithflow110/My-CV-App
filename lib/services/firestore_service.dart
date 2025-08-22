// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cv_model.dart'; // Adjust path if needed

class FirestoreService {
  FirebaseFirestore _firestore;

  /// ✅ Allow injecting mock Firestore for testing
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// ✅ Override Firestore with FakeFirestore in tests
  void overrideWithMock(FirebaseFirestore mockInstance) {
    _firestore = mockInstance;
  }


  // 6) Helper to return the generated CV DocumentReference (reuse in UI)
  DocumentReference generatedCvDocRef(String userId, String cvId) {
    return _firestore.collection('users').doc(userId).collection('aiGeneratedCVs').doc(cvId);
  }


  // ---------------------------------------------------------
  // 🗂 SINGLE CURRENT CV LOGIC
  // ---------------------------------------------------------

  Future<Map<String, dynamic>?> getLastCV(String userId) async {
    try {
      if (userId.isEmpty) return null;

      final docRef = _firestore.collection('users').doc(userId);
      final userDoc = await docRef.get();

      if (!userDoc.exists) {
        debugPrint("⚠ No user document found for $userId");
        return null;
      }

      final data = userDoc.data();
      if (data == null || !data.containsKey('cvData') || data['cvData'] == null) {
        debugPrint("⚠ No CV data found in document");
        return null;
      }

      return {
        'cvId': data['cvId'] ?? '',
        'cvData': Map<String, dynamic>.from(data['cvData']),
      };
    } catch (e) {
      debugPrint('❌ Error fetching last CV: $e');
      return null;
    }
  }

  // 1) Fix saveSection to use consistent keys and timestamps
  Future<void> saveSection(String userId, String cvId, Map<String, dynamic> cvData) async {
    try {
      if (userId.isEmpty) return;

      final docRef = _firestore.collection('users').doc(userId);
      final snapshot = await docRef.get();

      // Convert existing cvData to Map for safe comparison
      final existing = snapshot.data();
      final existingCvData = existing != null && existing['cvData'] is Map
          ? Map<String, dynamic>.from(existing['cvData'])
          : <String, dynamic>{};

      if (mapEquals(existingCvData, cvData)) {
        debugPrint("⏩ No changes detected, skipping save...");
        return;
      }

      // Preserve existing createdAt if present, otherwise set server createdAt
      final createdAt = existing != null && existing['createdAt'] != null
          ? existing['createdAt']
          : FieldValue.serverTimestamp();

      await docRef.set({
        'cvId': cvId,
        'cvData': cvData,
        'isCompleted': false, // standardized key (was isComplete)
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("✅ CV section saved successfully.");
    } catch (e) {
      debugPrint('❌ Error saving CV section: $e');
    }
  }


  Future<void> markCVComplete(String userId, String cvId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'isComplete': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ CV marked as complete.");
    } catch (e) {
      debugPrint('❌ Error marking CV complete: $e');
    }
  }

  // 4) Fix clearLastCV to use standardized key and updatedAt
  Future<void> clearLastCV(String userId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'cvId': null,
        'cvData': {},
        'isCompleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Last CV cleared successfully.");
    } catch (e) {
      debugPrint('❌ Error clearing last CV: $e');
    }
  }


  // ---------------------------------------------------------
  // 📚 LIBRARY CV LOGIC (Two-folder separation, AI overwrite)
  // ---------------------------------------------------------

  /// Save AI-generated CV (always overwrites previous one)
  Future<void> saveGeneratedCV(String userId, CVModel cv) async {
    try {
      if (userId.isEmpty) return;

      final generatedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs'); // AI-generated folder

      // Fixed document ID ensures overwrite
      final docId = "latestAI_CV";

      final dataToSave = cv
          .copyWith(cvId: docId)
          .toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();

      await generatedRef.doc(docId).set(dataToSave);

      debugPrint("✅ AI-generated CV saved/overwritten: $docId");
    } catch (e) {
      debugPrint('❌ Error saving AI-generated CV: $e');
    }
  }

  /// Fetch the latest AI-generated CV
  Future<CVModel?> getGeneratedCV(String userId) async {
    try {
      if (userId.isEmpty) return null;

      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .doc("latestAI_CV")
          .get();

      if (!docSnapshot.exists) return null;

      return CVModel.fromFirestore(docSnapshot);
    } catch (e) {
      debugPrint('❌ Error fetching AI-generated CV: $e');
      return null;
    }
  }

  /// Save a final CV manually (user saves from PreviewScreen)
  Future<void> saveCVToLibrary(String userId, CVModel cv,
      {String? customName}) async {
    try {
      if (userId.isEmpty) return;

      final libraryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean'); // User-saved folder

      final docId = cv.cvId.isNotEmpty
          ? cv.cvId
          : "cv_${DateTime.now().millisecondsSinceEpoch}";

      final updatedCvData = Map<String, dynamic>.from(cv.cvData)
        ..['name'] = customName ?? "My CV";

      final dataToSave = cv
          .copyWith(cvId: docId, cvData: updatedCvData)
          .toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();

      await libraryRef.doc(docId).set(dataToSave);

      debugPrint(
          "✅ CV saved to Library (manual): $docId (name: ${customName ?? "My CV"})");
    } catch (e) {
      debugPrint('❌ Error saving CV to Library: $e');
    }
  }

  /// Fetch user-saved CVs
  Future<List<CVModel>> getLibraryCVs(String userId) async {
    try {
      if (userId.isEmpty) return [];
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CVModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching Library CVs: $e');
      return [];
    }
  }

// 5) Delete CV: accept docId for library deletion
  Future<void> deleteCV(String userId, {bool isGenerated = false, String? docId}) async {
    try {
      if (userId.isEmpty) return;

      final collectionName = isGenerated ? 'aiGeneratedCVs' : 'libraryCVs_clean';
      final theDocId = docId ?? (isGenerated ? "latestAI_CV" : null);

      if (theDocId == null) {
        debugPrint('⚠ deleteCV called without docId for library deletion');
        return;
      }

      await _firestore.collection('users').doc(userId).collection(collectionName).doc(theDocId).delete();
      debugPrint("✅ CV deleted from $collectionName:$theDocId");
    } catch (e) {
      debugPrint('❌ Error deleting CV: $e');
    }
  }


  // 2) Add method to update a *single section* of a generated CV document
  Future<void> updateGeneratedCvSection(String userId, String cvId, String section, dynamic value, {String? editorId}) async {
    try {
      if (userId.isEmpty || cvId.isEmpty) return;
      final genRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs') // keep consistent with service
          .doc(cvId);

      // Try to update; if doc not exist, create with merge
      await genRef.set({
        'cvId': cvId,
        'cvData': {section: value},
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': {
          section.replaceAll('.', '_'): {
            'editedAt': FieldValue.serverTimestamp(),
            'editedBy': editorId ?? userId,
            'source': 'manual',
          }
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating generated CV section: $e');
    }
  }


  // 3) Add method to replace whole generated CV data (if needed)
  Future<void> updateGeneratedCvData(String userId, String cvId, Map<String, dynamic> cvData, {String? editorId}) async {
    try {
      if (userId.isEmpty || cvId.isEmpty) return;
      final genRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .doc(cvId);

      await genRef.set({
        'cvId': cvId,
        'cvData': cvData,
        'updatedAt': FieldValue.serverTimestamp(),
        'auditMeta': {
          'lastEditedBy': editorId ?? userId,
          'lastEditAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating generated CV data: $e');
    }
  }


  // 7) Convenience: getLastCVModel wrapping CVModel.fromFirestore (if you want CVModel directly)
  Future<CVModel?> getLastCVModel(String userId) async {
    try {
      if (userId.isEmpty) return null;
      final docRef = _firestore.collection('users').doc(userId);
      final ds = await docRef.get();
      if (!ds.exists) return null;
      // If your user doc stores top-level cvData / cvId
      final data = ds.data()!;
      final fakeDoc = ds; // CVModel.fromFirestore expects a DocumentSnapshot shaped like a CV doc
      // Build a fake DocumentSnapshot-like map to pass into CVModel.fromFirestore:
      final combined = {
        ...data,
        // ensure cvId, userId exist (CVModel.fromFirestore expects them in the document)
        'cvId': data['cvId'] ?? '',
        'userId': userId,
        'cvData': data['cvData'] ?? {},
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'isCompleted': data['isCompleted'] ?? false,
      };
      // We can't easily create a DocumentSnapshot here; instead build CVModel manually:
      return CVModel(
        cvId: combined['cvId'] ?? '',
        userId: combined['userId'] ?? userId,
        cvData: Map<String, dynamic>.from(combined['cvData'] ?? {}),
        isCompleted: combined['isCompleted'] ?? false,
        aiEnhancedText: combined['aiEnhancedText'],
        createdAt: (combined['createdAt'] is Timestamp) ? (combined['createdAt'] as Timestamp).toDate() : DateTime.now(),
        updatedAt: (combined['updatedAt'] is Timestamp) ? (combined['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error in getLastCVModel: $e');
      return null;
    }
  }



}