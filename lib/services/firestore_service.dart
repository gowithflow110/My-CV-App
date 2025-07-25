import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Get the last saved (incomplete) CV for the user
  Future<Map<String, dynamic>?> getLastCV(String userId) async {
    try {
      if (userId.isEmpty) return null;

      final docRef = _firestore.collection('users').doc(userId);
      final userDoc = await docRef.get();

      if (!userDoc.exists) return null;

      final data = userDoc.data();
      if (data != null && data.containsKey('cvData')) {
        return {
          'cvId': data['cvId'],
          'cvData': data['cvData'],
        };
      }
    } catch (e) {
      print('❌ Error fetching last CV: $e');
    }
    return null;
  }

  /// ✅ Save the entire CV after every section (overwrite the single document)
  Future<void> saveSection(
      String userId, String cvId, Map<String, dynamic> cvData) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).set({
        'cvId': cvId,
        'cvData': cvData,
        'isComplete': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error saving CV section: $e');
    }
  }

  /// ✅ Mark CV as complete (just update the single document)
  Future<void> markCVComplete(String userId, String cvId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'isComplete': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking CV complete: $e');
    }
  }

  /// ✅ Clear the last CV (for "Start Fresh" functionality)
  Future<void> clearLastCV(String userId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'cvId': null,
        'cvData': {},
        'isComplete': false,
      });
      print("✅ Last CV cleared successfully.");
    } catch (e) {
      print('❌ Error clearing last CV: $e');
    }
  }
}
