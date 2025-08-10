import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cvapp/modules/resume_progress/resume_prompt_screen.dart';
import 'package:cvapp/services/firestore_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:mocktail/mocktail.dart';

/// ✅ Create a mock class for FirebaseAnalytics
class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseAnalytics mockAnalytics;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    firestoreService = FirestoreService(firestore: fakeFirestore);

    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: "testUser",
        email: "test@example.com",
        displayName: "Test User",
      ),
    );

    mockAnalytics = MockFirebaseAnalytics();
  });

  /// ✅ Helper to create widget with MaterialApp wrapper
  Widget createTestWidget() {
    return MaterialApp(
      home: ResumePromptScreen(
        firestoreService: firestoreService,
        auth: mockAuth, // ✅ Mock Auth
        analytics: mockAnalytics, // ✅ Mock Analytics
      ),
    );
  }

  group('ResumePromptScreen Widget Tests', () {
    testWidgets('✅ Shows spinner while loading', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('✅ No CV → starts fresh on "No"', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text("No, Start Fresh"), findsOneWidget);

      await tester.tap(find.text("No, Start Fresh"));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('✅ Displays Resume option if CV exists',
            (WidgetTester tester) async {
          await fakeFirestore.collection('users').doc('testUser').set({
            'cvId': 'cv_123',
            'cvData': {'name': 'John Doe'},
            'isComplete': false
          });

          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          expect(find.text("Yes, Resume CV"), findsOneWidget);

          await tester.tap(find.text("Yes, Resume CV"));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
  });
}
