import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/auth_config.dart';
import 'package:web_pos_mobile/features/auth/presentation/widgets/social_auth_buttons.dart';

void main() {
  group('AuthConfig', () {
    test('parses empty or invalid map into disabled config', () {
      final config = AuthConfig.fromJson({});
      expect(config.googleEnabled, isFalse);
      expect(config.googleClientId, isNull);
      expect(config.appleEnabled, isFalse);
      expect(config.appleBundleId, isNull);
      expect(config.otpEnabled, isFalse);
    });

    test('parses configured providers correctly', () {
      final config = AuthConfig.fromJson({
        'google': {
          'enabled': true,
          'client_id': 'xyz-google.apps.googleusercontent.com',
        },
        'apple': {
          'enabled': true,
          'bundle_id': 'com.kasir.pos',
        },
        'whatsapp_otp': {
          'enabled': true,
        },
      });
      expect(config.googleEnabled, isTrue);
      expect(config.googleClientId, 'xyz-google.apps.googleusercontent.com');
      expect(config.appleEnabled, isTrue);
      expect(config.appleBundleId, 'com.kasir.pos');
      expect(config.otpEnabled, isTrue);
    });
  });

  group('SocialAuthButtons', () {
    testWidgets('renders nothing when all providers are disabled', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authConfigProvider.overrideWith((ref) => Future.value(const AuthConfig())),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SocialAuthButtons(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Masuk dengan Google'), findsNothing);
      expect(find.text('Masuk dengan Apple'), findsNothing);
      expect(find.text('atau lanjutkan dengan'), findsNothing);
    });

    testWidgets('renders Google sign-in button when Google is enabled', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authConfigProvider.overrideWith((ref) => Future.value(const AuthConfig(
                googleEnabled: true,
                googleClientId: 'test-google-id',
              ))),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SocialAuthButtons(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('atau lanjutkan dengan'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.text('Masuk dengan Apple'), findsNothing);
    });

    testWidgets('renders register label when isRegister is true', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authConfigProvider.overrideWith((ref) => Future.value(const AuthConfig(
                googleEnabled: true,
                googleClientId: 'test-google-id',
              ))),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SocialAuthButtons(isRegister: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('atau daftar dengan'), findsOneWidget);
      expect(find.text('Daftar dengan Google'), findsOneWidget);
    });

    testWidgets('renders Apple sign-in button when Apple is enabled on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = ProviderContainer(
          overrides: [
            authConfigProvider.overrideWith((ref) => Future.value(const AuthConfig(
                  appleEnabled: true,
                  appleBundleId: 'com.kasir.pos',
                ))),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SocialAuthButtons(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Masuk dengan Apple'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
