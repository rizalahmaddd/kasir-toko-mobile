import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../data/shift_models.dart';
import '../shifts_providers.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(shiftsStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Shift')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: 'Status Shift',
                  icon: LucideIcons.wallet,
                  value: status,
                  items: const [
                    (null, 'Semua Shift'),
                    ('open', 'Sedang Buka'),
                    ('closed', 'Ditutup'),
                    ('variance', 'Ada Selisih'),
                  ],
                  onChanged: ref.read(shiftsStatusProvider.notifier).set,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PagedListView(
              value: ref.watch(shiftsProvider),
              skeleton: const ShiftsListSkeleton(),
              onLoadMore: () => ref.read(shiftsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(shiftsProvider.future),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              empty: const EmptyState(
                icon: LucideIcons.wallet,
                title: 'Belum Ada Shift',
                description: 'Riwayat buka dan tutup kasir akan tercatat di sini.',
              ),
              itemBuilder: (context, shift) => _ShiftCard(shift: shift, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.isDark});

  final Shift shift;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final difference = shift.cashDifference ?? 0;
    final colors = StatusColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/shift/${shift.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Shift number, Status badge, Sales Total
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: shift.isOpen
                            ? const Color(0xFFD1FAE5)
                            : isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.wallet,
                            size: 12,
                            color: shift.isOpen
                                ? const Color(0xFF059669)
                                : isDark
                                    ? AppColors.slate300
                                    : AppColors.slate700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shift.number,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: shift.isOpen
                                  ? const Color(0xFF059669)
                                  : isDark
                                      ? AppColors.slate300
                                      : AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (shift.isOpen)
                      const StatusBadge(label: 'Buka', tone: BadgeTone.success)
                    else if (difference != 0)
                      StatusBadge(
                        label: difference > 0 ? 'Lebih' : 'Kurang',
                        tone: BadgeTone.warning,
                      )
                    else
                      const StatusBadge(label: 'Selesai', tone: BadgeTone.muted),
                    const Spacer(),
                    Text(
                      rupiah(shift.salesTotal ?? 0),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Middle: Cashier & Time range
                Row(
                  children: [
                    Icon(LucideIcons.user, size: 13, color: isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: 4),
                    Text(
                      shift.cashierName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400)),
                    ),
                    Icon(LucideIcons.clock, size: 13, color: isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${dateTime(shift.openedAt)}${shift.closedAt == null ? ' – Sekarang' : ' – ${timeOnly(shift.closedAt!)}'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 8),

                // Bottom metrics: Transaction count & Cash Difference or Starting Cash
                Row(
                  children: [
                    Text(
                      '${shift.salesCount ?? 0} transaksi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                      ),
                    ),
                    const Spacer(),
                    if (difference != 0) ...[
                      Text(
                        'Selisih kas: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                      Text(
                        '${difference > 0 ? '+' : '-'}${rupiah(difference.abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.warning,
                        ),
                      ),
                    ] else ...[
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
                    ],
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
