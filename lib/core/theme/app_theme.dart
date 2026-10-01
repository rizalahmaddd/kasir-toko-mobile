import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_storage.dart';

abstract final class AppColors {
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const sky500 = Color(0xFF0EA5E9);
  static const sky600 = Color(0xFF0284C7);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);
}

/// Semantic colors that Material's ColorScheme has no slot for.
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.warning, required this.danger, required this.info, required this.muted});

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color muted;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({Color? success, Color? warning, Color? danger, Color? info, Color? muted}) => StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        muted: muted ?? this.muted,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) => other == null ? this : t < 0.5 ? this : other;
}

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
      secondary: AppColors.amber500,
      onSecondary: AppColors.slate950,
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

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: 'Inter');
    final textTheme = base.textTheme.apply(bodyColor: text, displayColor: text);
    final radius = BorderRadius.circular(10);

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
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: status.danger)),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(44, 44))),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.16),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
        height: 64,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Dark by default, matching the web app.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(StorageKeys.themeMode);
    return saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref.read(sharedPreferencesProvider).setString(StorageKeys.themeMode, state.name);
  }
}
