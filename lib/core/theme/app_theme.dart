import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_fonts.dart';
import '../constants/status_values.dart';
import '../storage/app_storage.dart';
import 'app_colors.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';

export 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.slate950,
        surface: AppColors.slate900,
        surfaceHigh: AppColors.slate800,
        border: AppColors.slate800,
        text: AppColors.slate100,
        muted: AppColors.slate400,
        primary: AppColors.emerald500,
        status: const StatusColors(
          success: AppColors.emerald400,
          warning: AppColors.amber500,
          danger: AppColors.rose500,
          info: AppColors.sky500,
          muted: AppColors.slate400,
        ),
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.slate50,
        surface: Colors.white,
        surfaceHigh: AppColors.slate100,
        border: AppColors.slate200,
        text: AppColors.slate900,
        muted: AppColors.slate600,
        primary: AppColors.emerald600,
        status: const StatusColors(
          success: AppColors.emerald700,
          warning: AppColors.amber600,
          danger: AppColors.rose600,
          info: AppColors.sky600,
          muted: AppColors.slate600,
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color border,
    required Color text,
    required Color muted,
    required Color primary,
    required StatusColors status,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primary.withValues(alpha: 0.16),
      onPrimaryContainer: primary,
      secondary: AppColors.amber500,
      onSecondary: AppColors.slate950,
      // Selected chips and navigation indicators draw from the secondary container slots.
      secondaryContainer: primary.withValues(alpha: 0.16),
      onSecondaryContainer: primary,
      error: status.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: border,
      outlineVariant: border,
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: AppFonts.primary);
    final textTheme = base.textTheme.apply(bodyColor: text, displayColor: text);
    final radius = BorderRadius.circular(AppRadius.r10);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [status],
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s14),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: status.danger)),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        leadingAndTrailingTextStyle: textTheme.bodyLarge,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s2),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.16),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primary : muted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, color: primary),
        unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w500, color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: false,
        dragHandleColor: muted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: primary,
        unselectedLabelColor: muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return brightness == Brightness.dark ? AppColors.slate300 : AppColors.slate500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return brightness == Brightness.dark ? AppColors.slate900 : AppColors.slate200;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return brightness == Brightness.dark ? AppColors.slate600 : AppColors.slate300;
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return 0.0;
          }
          return 1.2;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 5,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

/// Dark by default, matching the web app.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(StorageKeys.themeMode);
    return saved == ThemePreferences.light ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref.read(sharedPreferencesProvider).setString(StorageKeys.themeMode, state.name);
  }
}
