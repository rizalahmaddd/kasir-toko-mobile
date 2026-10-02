import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/payment_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sale_models.dart';

class SaleTile extends StatelessWidget {
  const SaleTile({
    super.key,
    required this.sale,
    this.margin,
  });

  final SaleSummary sale;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isToday = DateUtils.isSameDay(sale.soldAt, DateTime.now());

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/sale/${sale.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Invoice Number & Timestamp
                Row(
                  children: [
                    Icon(
                      LucideIcons.receipt,
                      size: 13,
                      color: muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sale.number,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isToday ? timeOnly(sale.soldAt) : '${dateOnly(sale.soldAt)} · ${timeOnly(sale.soldAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                ),

                // Main row: Customer & Items on Left, Amount & Status on Right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customer?.name ?? 'Pelanggan Umum',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${sale.itemsCount} barang',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              for (final method in sale.paymentMethods)
                                PaymentBadge(method: method),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rupiah(sale.total),
                          style: AppTypography.money(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sale.isVoided
                                ? muted
                                : sale.dueAmount > 0
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF059669),
                            decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (sale.isVoided)
                          const StatusBadge(label: 'Dibatalkan', tone: BadgeTone.danger)
                        else if (sale.dueAmount > 0) ...[
                          const StatusBadge(label: 'Kasbon', tone: BadgeTone.warning),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa ${rupiah(sale.dueAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ] else
                          const StatusBadge(label: 'Selesai', tone: BadgeTone.success),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

