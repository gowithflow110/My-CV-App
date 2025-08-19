// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cv_model.dart'; // Adjust path if needed

class FirestoreService {
  FirebaseFirestore _firestore;

  /// ✅ Allow injecting mock Firestore for testing
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// ✅ Override Firestore with FakeFirestore in tests (optional extra method)
  void overrideWithMock(FirebaseFirestore mockInstance) {
    _firestore = mockInstance;
  }

  // ---------------------------------------------------------
  // 🗂 SINGLE CURRENT CV LOGIC (Existing)
  // ---------------------------------------------------------

  /// ✅ Get the last saved (incomplete) CV for the user
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
      if (data == null) {
        debugPrint("⚠ User document is empty");
        return null;
      }

      if (!data.containsKey('cvData') || data['cvData'] == null) {
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

  /// ✅ Save CV section (skip if no changes → prevents duplicates)
  Future<void> saveSection(
      String userId, String cvId, Map<String, dynamic> cvData) async {
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

  /// ✅ Mark CV as complete
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

  /// ✅ Clear the last CV
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
  // 📚 LIBRARY CV LOGIC (New for AI-enhanced saved CVs)
  // ---------------------------------------------------------

  /// Save a final CV to the Library with optional custom name
  Future<void> saveCVToLibrary(String userId, CVModel cv,
      {String? customName}) async {
    try {
      if (userId.isEmpty) return;

      final libraryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean'); // consistent collection

      // Use the same cvId if exists, else generate new
      final docId = cv.cvId.isNotEmpty
          ? cv.cvId
          : "cv_${DateTime.now().millisecondsSinceEpoch}";

      // Ensure the name is stored inside cvData
      final updatedCvData = Map<String, dynamic>.from(cv.cvData)
        ..['name'] = customName ?? "My CV";

      final dataToSave = cv
          .copyWith(
            cvId: docId,
            cvData: updatedCvData,
          )
          .toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();

      await libraryRef.doc(docId).set(dataToSave);

      debugPrint(
          "✅ CV saved to Library: $docId (name: ${customName ?? "My CV"})");
    } catch (e) {
      debugPrint('❌ Error saving CV to Library: $e');
    }
  }

  /// Fetch all CVs from the Library
  Future<List<CVModel>> getLibraryCVs(String userId) async {
    try {
      if (userId.isEmpty) return [];
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs')
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

  /// Delete a CV from the Library
  Future<void> deleteCVFromLibrary(String userId, String cvId) async {
    try {
      if (userId.isEmpty || cvId.isEmpty) return;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs')
          .doc(cvId)
          .delete();
      debugPrint("✅ CV deleted from Library: $cvId");
    } catch (e) {
      debugPrint('❌ Error deleting CV from Library: $e');
    }
  }
}
