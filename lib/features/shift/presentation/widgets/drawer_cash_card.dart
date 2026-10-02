import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/shift_models.dart';

class DrawerCashCard extends StatelessWidget {
  const DrawerCashCard({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final expected = shift.summary?.expected ?? shift.expectedCash ?? shift.openingCash;
    final summary = shift.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : AppColors.slate900.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Shift Number + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.hash, size: 13, color: isDark ? AppColors.slate400 : AppColors.slate600),
                    const SizedBox(width: 4),
                    Text(
                      shift.number,
                      style: TextStyle(
                        color: isDark ? AppColors.slate200 : AppColors.slate800,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: shift.isOpen ? 'Shift Aktif' : 'Shift Ditutup',
                tone: shift.isOpen ? BadgeTone.success : BadgeTone.muted,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hero Label & Amount
          Text(
            shift.isOpen ? 'Uang di laci seharusnya' : 'Uang fisik saat ditutup',
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(shift.isOpen ? expected : shift.countedCash ?? expected),
              style: AppTypography.money(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
          ),

          // Micro Breakdown Chips (Modal, Tunai, Mutasi)
          if (summary != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800.withValues(alpha: 0.6) : AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Modal Awal',
                      value: rupiah(summary.opening),
                      isDark: isDark,
                    ),
                  ),
                  Container(width: 1, height: 26, color: isDark ? AppColors.slate700 : AppColors.slate200),
                  Expanded(
                    child: _MiniStat(
                      label: 'Kas Masuk',
                      value: '+${rupiah(summary.cashSales + summary.cashIn)}',
                      isDark: isDark,
                      highlightColor: AppColors.emerald500,
                    ),
                  ),
                  if (summary.cashOut > 0) ...[
                    Container(width: 1, height: 26, color: isDark ? AppColors.slate700 : AppColors.slate200),
                    Expanded(
                      child: _MiniStat(
                        label: 'Kas Keluar',
                        value: '-${rupiah(summary.cashOut)}',
                        isDark: isDark,
                        highlightColor: AppColors.rose500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Cashier and Time Info
          Row(
            children: [
              Icon(LucideIcons.user, size: 14, color: isDark ? AppColors.slate500 : AppColors.slate400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Kasir: ${shift.cashierName}',
                  style: TextStyle(
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 14, color: isDark ? AppColors.slate500 : AppColors.slate400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dibuka ${dateTime(shift.openedAt)}',
                  style: TextStyle(
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (shift.closedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.lockKeyhole, size: 14, color: isDark ? AppColors.slate500 : AppColors.slate400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ditutup ${dateTime(shift.closedAt!)}${shift.closedByName == null ? '' : ' oleh ${shift.closedByName}'}',
                    style: TextStyle(
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.isDark,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? (isDark ? AppColors.slate200 : AppColors.slate800),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
