import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/pos/presentation/camera_scanner_screen.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/barcode_scanner_dialog.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/barcode_scanner_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarcodeScannerView', () {
    testWidgets('renders camera scanner view with hint text and scanning frame', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: BarcodeScannerView(
              onDetect: (_) {},
              hintText: 'Arahkan kamera ke barcode',
            ),
          ),
        ),
      );

      expect(find.text('Arahkan kamera ke barcode'), findsOneWidget);
      expect(find.byIcon(AppIcons.scanLine), findsOneWidget);
    });
  });

  group('BarcodeScannerDialog', () {
    testWidgets('renders as a popup dialog with header controls including maximize button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BarcodeScannerDialog.open(context),
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      // Dialog is initially not visible
      expect(find.byType(BarcodeScannerDialog), findsNothing);

      // Tap button to open dialog
      await tester.tap(find.text('Open Scanner'));
      await tester.pump(); // Start opening
      await tester.pump(const Duration(milliseconds: 300)); // Finish opening transition

      // Verify it renders inside a Dialog
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BarcodeScannerDialog), findsOneWidget);

      // Verify dialog header controls
      expect(find.text(PosStrings.scanTitle), findsOneWidget);
      expect(find.byIcon(AppIcons.flashlightOff), findsOneWidget);
      expect(find.byIcon(AppIcons.switchCamera), findsOneWidget);
      expect(find.byIcon(AppIcons.maximize), findsOneWidget);
      expect(find.byIcon(AppIcons.x), findsOneWidget);

      // Verify inner BarcodeScannerView is present
      expect(find.byType(BarcodeScannerView), findsOneWidget);

      // Close the dialog using X button
      await tester.tap(find.byIcon(AppIcons.x));
      await tester.pumpAndSettle();

      expect(find.byType(BarcodeScannerDialog), findsNothing);
    });

    testWidgets('tapping maximize button pops dialog and requests fullscreen transition', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const BarcodeScannerDialog(),
                  );
                },
                child: const Text('Open Raw Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Raw Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BarcodeScannerDialog), findsOneWidget);

      // Tap the maximize button
      await tester.tap(find.byIcon(AppIcons.maximize));
      await tester.pumpAndSettle();

      // Dialog is dismissed and returned the maximize token
      expect(find.byType(BarcodeScannerDialog), findsNothing);
      expect(result, '__MAXIMIZE__');
    });
  });

  group('CameraScannerScreen (Fullscreen)', () {
    testWidgets('full screen screen is preserved and renders BarcodeScannerView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const CameraScannerScreen(),
        ),
      );

      expect(find.byType(CameraScannerScreen), findsOneWidget);
      expect(find.text(PosStrings.scanTitle), findsOneWidget);
      expect(find.byIcon(AppIcons.flashlightOff), findsOneWidget);
      expect(find.byIcon(AppIcons.switchCamera), findsOneWidget);
      expect(find.byType(BarcodeScannerView), findsOneWidget);
    });
  });
}
