import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
            const SizedBox(height: AppSizes.s8),
            const SizedBox.square(dimension: AppSizes.s22, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
