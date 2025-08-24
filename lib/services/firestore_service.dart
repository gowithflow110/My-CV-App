// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cv_model.dart';

class FirestoreService {
  FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  void overrideWithMock(FirebaseFirestore mockInstance) {
    _firestore = mockInstance;
  }

  // Helper to return the generated CV DocumentReference
  DocumentReference generatedCvDocRef(String userId, String cvId) {
    return _firestore.collection('users').doc(userId).collection('aiGeneratedCVs').doc(cvId);
  }

  // ---------------------------------------------------------
  // 🗂 SINGLE CURRENT CV LOGIC
  // ---------------------------------------------------------

  Future<Map<String, dynamic>?> getLastCV(String userId) async {
    try {
      if (userId.isEmpty) return null;

      // First try to get from aiGeneratedCVs collection (where edits are saved)
      final aiCvSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (aiCvSnapshot.docs.isNotEmpty) {
        final data = aiCvSnapshot.docs.first.data();
        return {
          'cvId': data['cvId'] ?? aiCvSnapshot.docs.first.id,
          'cvData': Map<String, dynamic>.from(data['cvData'] ?? {}),
        };
      }

      // Fallback to user document (legacy)
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

  // Save section to both user document and aiGeneratedCVs collection
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

      // Update user document
      await docRef.set({
        'cvId': cvId,
        'cvData': cvData,
        'isCompleted': false,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update aiGeneratedCVs collection
      await updateGeneratedCvData(userId, cvId, cvData);

      debugPrint("✅ CV section saved successfully to both locations.");
    } catch (e) {
      debugPrint('❌ Error saving CV section: $e');
    }
  }

  Future<void> markCVComplete(String userId, String cvId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'isCompleted': true,
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
        'isCompleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Last CV cleared successfully.");
    } catch (e) {
      debugPrint('❌ Error clearing last CV: $e');
    }
  }

  // ---------------------------------------------------------
  // 📚 LIBRARY CV LOGIC
  // ---------------------------------------------------------

  Future<void> saveGeneratedCV(String userId, CVModel cv) async {
    try {
      if (userId.isEmpty) return;

      final generatedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs');

      // Use the actual CV ID instead of a fixed one
      final docId = cv.cvId.isNotEmpty ? cv.cvId : "cv_${DateTime.now().millisecondsSinceEpoch}";

      final dataToSave = cv
          .copyWith(cvId: docId)
          .toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();

      await generatedRef.doc(docId).set(dataToSave);

      debugPrint("✅ AI-generated CV saved: $docId");
    } catch (e) {
      debugPrint('❌ Error saving AI-generated CV: $e');
    }
  }

  Future<CVModel?> getGeneratedCV(String userId) async {
    try {
      if (userId.isEmpty) return null;

      // Get the most recent CV instead of a fixed ID
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return CVModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error fetching AI-generated CV: $e');
      return null;
    }
  }

  // lib/services/firestore_service.dart

// ... (previous code remains the same)


  /// Save a final CV manually (user saves from PreviewScreen)
  /// Save a final CV manually (user saves from PreviewScreen)
  /// Save a final CV manually (user saves from PreviewScreen)
  /// Save a final CV manually (user saves from PreviewScreen)
  /// Save a final CV manually (user saves from PreviewScreen)
  Future<void> saveCVToLibrary(String userId, CVModel cv, {String? customName}) async {
    try {
      if (userId.isEmpty) return;

      final libraryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean');

      final docId = cv.cvId.isNotEmpty
          ? cv.cvId
          : "cv_${DateTime.now().millisecondsSinceEpoch}";

      // Keep the original CV data intact
      final updatedCvData = Map<String, dynamic>.from(cv.cvData);

      // Store both the original CV name and the custom library name
      final dataToSave = {
        'cvId': docId,
        'userId': userId,
        'cvData': updatedCvData,  // This contains the original name
        'isCompleted': cv.isCompleted,
        'aiEnhancedText': cv.aiEnhancedText,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'libraryName': customName ?? "My CV",  // Store custom name separately
        'originalName': cv.cvData['name'] ?? '',  // Preserve the original name
        'savedAt': FieldValue.serverTimestamp(),
      };

      await libraryRef.doc(docId).set(dataToSave);

      debugPrint(
          "✅ CV saved to Library: $docId (library name: ${customName ?? "My CV"}, original name: ${cv.cvData['name']})");
    } catch (e) {
      debugPrint('❌ Error saving CV to Library: $e');
    }
  }

// ... (rest of the code remains the same)

// When loading a CV from the library, make sure to use the CV's actual name
// not the library name

  /// Fetch user-saved CVs
  /// Fetch user-saved CVs
  Future<List<CVModel>> getLibraryCVs(String userId) async {
    try {
      if (userId.isEmpty) return [];
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean')
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Extract the CV data (which contains the original name)
        final cvData = Map<String, dynamic>.from(data['cvData'] ?? {});

        // If we have an originalName field, use it to restore the name
        if (data.containsKey('originalName') && data['originalName'] != null) {
          cvData['name'] = data['originalName'];
        }

        return CVModel(
          cvId: data['cvId'] ?? doc.id,
          userId: userId,
          cvData: cvData,  // This contains the original name
          isCompleted: data['isCompleted'] ?? false,
          aiEnhancedText: data['aiEnhancedText'],
          createdAt: (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          updatedAt: (data['savedAt'] is Timestamp)
              ? (data['savedAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      })
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching Library CVs: $e');
      return [];
    }
  }

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

  // Update a single section of a generated CV document
  Future<void> updateGeneratedCvSection(String userId, String cvId, String section, dynamic value, {String? editorId}) async {
    try {
      if (userId.isEmpty || cvId.isEmpty) return;
      final genRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .doc(cvId);

      // Handle header fields specially
      Map<String, dynamic> updateData = {
        'cvId': cvId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (section == 'header' && value is Map<String, dynamic>) {
        updateData['cvData.name'] = value['name'];
        updateData['cvData.summary'] = value['summary'];
      } else {
        updateData['cvData.$section'] = value;
      }

      // Add audit info
      updateData['audit.${section.replaceAll('.', '_')}'] = {
        'editedAt': FieldValue.serverTimestamp(),
        'editedBy': editorId ?? userId,
        'source': 'manual',
      };

      await genRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating generated CV section: $e');
    }
  }

  // Update both user document and aiGeneratedCVs collection
  Future<void> updateBothCVLocations(String userId, String cvId, Map<String, dynamic> updates) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(userId).set({
        'cvData': updates,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update aiGeneratedCVs collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .doc(cvId)
          .set({
        'cvData': updates,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating both CV locations: $e');
    }
  }

  // Replace whole generated CV data
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

  // Get CVModel directly
  Future<CVModel?> getLastCVModel(String userId) async {
    try {
      if (userId.isEmpty) return null;

      // First try to get from aiGeneratedCVs collection
      final aiCvSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiGeneratedCVs')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (aiCvSnapshot.docs.isNotEmpty) {
        return CVModel.fromFirestore(aiCvSnapshot.docs.first);
      }

      // Fallback to user document
      final docRef = _firestore.collection('users').doc(userId);
      final ds = await docRef.get();
      if (!ds.exists) return null;

      final data = ds.data()!;
      return CVModel(
        cvId: data['cvId'] ?? '',
        userId: userId,
        cvData: Map<String, dynamic>.from(data['cvData'] ?? {}),
        isCompleted: data['isCompleted'] ?? false,
        aiEnhancedText: data['aiEnhancedText'],
        createdAt: (data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error in getLastCVModel: $e');
      return null;
    }
  }
}