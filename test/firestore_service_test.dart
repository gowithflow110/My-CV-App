import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cvapp/services/firestore_service.dart';

void main() {
  late FirestoreService firestoreService;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    firestoreService = FirestoreService(firestore: fakeFirestore);
  });

  group('FirestoreService Edge Case Tests', () {
    test('✅ Returns null if no CV exists', () async {
      final result = await firestoreService.getLastCV("user123");
      expect(result, isNull);
    });

    test('✅ Returns correct CV if document exists', () async {
      await fakeFirestore.collection('users').doc('user123').set({
        'cvId': 'cv_123',
        'cvData': {'name': 'John Doe'},
        'isComplete': false
      });

      final result = await firestoreService.getLastCV("user123");
      expect(result?['cvId'], 'cv_123');
      expect(result?['cvData']['name'], 'John Doe');
    });

    test('✅ Handles empty cvData gracefully', () async {
      await fakeFirestore.collection('users').doc('user123').set({
        'cvId': 'cv_123',
        'cvData': {},
        'isComplete': false
      });

      final result = await firestoreService.getLastCV("user123");
      expect(result?['cvData'], isA<Map>());
      expect(result?['cvData'].isEmpty, true);
    });

    test('✅ Saves section without duplication', () async {
      final cvData = {'name': 'John Doe'};
      await firestoreService.saveSection("user123", "cv_123", cvData);

      final snapshot =
      await fakeFirestore.collection('users').doc('user123').get();
      expect(snapshot.data()?['cvData']['name'], 'John Doe');

      // Try saving same data again → should not duplicate or crash
      await firestoreService.saveSection("user123", "cv_123", cvData);
      final snapshot2 =
      await fakeFirestore.collection('users').doc('user123').get();
      expect(snapshot2.data()?['cvData']['name'], 'John Doe');
    });
  });
}
