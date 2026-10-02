import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../sales/data/sale_models.dart';

class RecentSalesSection extends StatelessWidget {
  const RecentSalesSection({super.key, required this.sales});

  final List<SaleSummary> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Transaksi Terakhir',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              context.go('/sales');
            },
            icon: const Text('Lihat semua', style: TextStyle(fontSize: 12)),
            label: const Icon(LucideIcons.chevronRight, size: 14),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, sale) in sales.take(5).indexed) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.push('/sale/${sale.id}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: sale.isVoided
                                ? (isDark ? AppColors.rose500.withValues(alpha: 0.2) : AppColors.rose500.withValues(alpha: 0.1))
                                : (sale.dueAmount > 0
                                    ? (isDark ? AppColors.amber500.withValues(alpha: 0.2) : AppColors.amber500.withValues(alpha: 0.1))
                                    : (isDark ? AppColors.slate800 : AppColors.slate100)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            sale.isVoided
                                ? LucideIcons.ban
                                : (sale.dueAmount > 0 ? LucideIcons.handCoins : LucideIcons.receipt),
                            size: 18,
                            color: sale.isVoided
                                ? (isDark ? AppColors.rose500 : AppColors.rose600)
                                : (sale.dueAmount > 0
                                    ? (isDark ? AppColors.amber500 : AppColors.amber600)
                                    : (isDark ? AppColors.slate300 : AppColors.slate700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sale.number,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (sale.isVoided)
                                    const StatusBadge(label: 'Batal', tone: BadgeTone.danger)
                                  else if (sale.dueAmount > 0)
                                    const StatusBadge(label: 'Kasbon', tone: BadgeTone.warning),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${timeOnly(sale.soldAt)} · ${sale.itemsCount} barang${sale.customer == null ? '' : ' · ${sale.customer!.name}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupiah(sale.total),
                              style: AppTypography.money(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sale.isVoided ? muted : (isDark ? Colors.white : AppColors.slate900),
                                decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (sale.paymentMethods.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  sale.paymentMethods.first,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
