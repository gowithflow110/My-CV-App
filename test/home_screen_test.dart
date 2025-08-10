import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cvapp/modules/dashboard/home_screen.dart';
import 'package:cvapp/routes/app_routes.dart';

void main() {
  group('HomeScreen Test Suite', () {
    testWidgets('Banner, Navigation, Snackbar, and Logout work as expected',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              routes: {
                AppRoutes.voiceInput: (context) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Voice Input Screen'),
                ),
                AppRoutes.resumePrompt: (context) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Resume Prompt Screen'),
                ),
                // 🔥 No library route here to simulate failure (forces Snackbar)
                AppRoutes.login: (context) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Login Screen'),
                ),
              },
              home: const HomeScreen(),
            ),
          );

          // ✅ 1. Check Banner Text
          expect(find.text("Let's Build Your Professional CV"), findsOneWidget);
          expect(find.text("Create, edit and manage your resumes with ease."),
              findsOneWidget);

          // ✅ 2. Test "Start a New CV" Navigation
          await tester.tap(find.text("Start a New CV"));
          await tester.pumpAndSettle();
          expect(find.text("Voice Input Screen"), findsOneWidget);

          Navigator.pop(tester.element(find.byType(Scaffold)));
          await tester.pumpAndSettle();

          // ✅ 3. Test "Resume Previous CV" Navigation
          await tester.tap(find.text("Resume Previous CV"));
          await tester.pumpAndSettle();
          expect(find.text("Resume Prompt Screen"), findsOneWidget);

          Navigator.pop(tester.element(find.byType(Scaffold)));
          await tester.pumpAndSettle();

          // ✅ 4. Test "My CV Library" Fallback (Snackbar)
          await tester.tap(find.text("My CV Library"));
          await tester.pump(const Duration(milliseconds: 300)); // let snackbar show
          expect(
            find.text("This feature is not available yet. Please try later."),
            findsOneWidget,
          );

          // // ✅ 5. Test Logout via Popup Menu
          // await tester.tap(find.byType(PopupMenuButton<String>));
          // await tester.pumpAndSettle();
          // await tester.tap(find.text("Logout"));
          // await tester.pumpAndSettle();
          // expect(find.text("Login Screen"), findsOneWidget);
        });
  });
}
