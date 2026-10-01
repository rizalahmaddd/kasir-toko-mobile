import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Same logo and background as the native launch screen, so restoring the session doesn't flash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/splash.png', width: 192, height: 192),
            const SizedBox(height: 8),
            const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
