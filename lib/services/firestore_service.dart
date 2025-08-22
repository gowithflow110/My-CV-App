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

  Future<void> saveSection(String userId, String cvId, Map<String, dynamic> cvData) async {
    try {
      if (userId.isEmpty) return;

      final docRef = _firestore.collection('users').doc(userId);
      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        final existingData = snapshot.data();
        if (mapEquals(existingData?['cvData'], cvData)) {
          debugPrint("⏩ No changes detected, skipping save...");
          return;
        }
      }

      await docRef.set({
        'cvId': cvId,
        'cvData': cvData,
        'isComplete': false,
        'timestamp': FieldValue.serverTimestamp(),
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

  Future<void> clearLastCV(String userId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'cvId': null,
        'cvData': {},
        'isComplete': false,
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

  /// Delete a CV from either folder
  Future<void> deleteCV(String userId, {bool isGenerated = false}) async {
    try {
      if (userId.isEmpty) return;

      final collectionName = isGenerated ? 'aiGeneratedCVs' : 'libraryCVs_clean';
      final docId = isGenerated ? "latestAI_CV" : null;
      if (isGenerated && docId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection(collectionName)
            .doc(docId)
            .delete();
      }

      debugPrint("✅ CV deleted from $collectionName");
    } catch (e) {
      debugPrint('❌ Error deleting CV: $e');
    }
  }
}