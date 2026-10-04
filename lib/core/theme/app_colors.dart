import 'package:flutter/material.dart';

/// Palet warna aplikasi. Untuk mengganti warna, cukup ubah di file ini.
abstract final class AppColors {
  // Emerald
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065F46);
  static const emerald900 = Color(0xFF064E3B);

  // Teal
  static const teal100 = Color(0xFFCCFBF1);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);

  // Cyan / Sky / Blue
  static const cyan500 = Color(0xFF06B6D4);
  static const sky500 = Color(0xFF0EA5E9);
  static const sky600 = Color(0xFF0284C7);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue900 = Color(0xFF1E3A8A);

  // Indigo / Violet
  static const indigo500 = Color(0xFF6366F1);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet600 = Color(0xFF7C3AED);

  // Amber / Orange
  static const amber100 = Color(0xFFFEF3C7);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber900 = Color(0xFF78350F);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange700 = Color(0xFFC2410C);
  static const orange900 = Color(0xFF7C2D12);

  // Red / Rose
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red300 = Color(0xFFFCA5A5);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red800 = Color(0xFF991B1B);
  static const red900 = Color(0xFF7F1D1D);
  static const rose100 = Color(0xFFFECDD3);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);

  // Slate / Gray
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
  static const gray800 = Color(0xFF1F2937);
  static const warmWhite = Color(0xFFFFFEFA);

  // Brand
  static const whatsappGreen = Color(0xFF25D366);
  static const googleBlue = Color(0xFF4285F4);
}

/// Semantic colors that Material's ColorScheme has no slot for.
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.warning, required this.danger, required this.info, required this.muted});

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color muted;

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ??
      const StatusColors(
        success: AppColors.emerald600,
        warning: AppColors.amber600,
        danger: AppColors.rose600,
        info: AppColors.sky600,
        muted: AppColors.slate600,
      );

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
