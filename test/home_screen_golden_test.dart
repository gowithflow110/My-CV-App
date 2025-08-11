// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:cvapp/modules/dashboard/home_screen.dart';

void main() {
  group('HomeScreen Golden Tests', () {
    testGoldens('HomeScreen matches golden snapshot', (tester) async {
      await loadAppFonts();

      final builder = DeviceBuilder()
        ..addScenario(
          widget: const HomeScreen(),
          name: 'Default HomeScreen',
        );

      await tester.pumpDeviceBuilder(builder);
      await screenMatchesGolden(tester, 'home_screen_default');
    });

    testGoldens('Snackbar appears correctly on failed navigation',
            (tester) async {
          await loadAppFonts();

          await tester.pumpWidgetBuilder(const HomeScreen());

          // ✅ Trigger Snackbar
          await tester.tap(find.text("My CV Library"));
          await tester.pump(const Duration(milliseconds: 300));

          // ✅ Capture the frame with the Snackbar visible
          await screenMatchesGolden(tester, 'home_screen_snackbar');
        });
  });
}
