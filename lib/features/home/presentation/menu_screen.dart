import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications.dart';
import '../../offline/offline_queue.dart';

typedef _Link = ({
  IconData icon,
  String label,
  String path,
  String? caption,
  Color color,
  int? badgeCount,
  Color? badgeColor,
});

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final waiting = ref.watch(myQueueProvider).length;

    final sections = <(String, List<_Link>)>[
      (
        'Penjualan',
        [
          if (user.canSell)
            (
              icon: LucideIcons.wallet,
              label: 'Shift saya',
              path: '/shift',
              caption: 'Kas masuk/keluar, tutup shift',
              color: const Color(0xFF10B981),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canSell)
            (
              icon: LucideIcons.cloudOff,
              label: 'Mode offline',
              path: '/offline',
              caption: waiting > 0 ? '$waiting antrean menunggu sync' : 'Katalog lokal & antrean',
              color: const Color(0xFFF59E0B),
              badgeCount: waiting > 0 ? waiting : null,
              badgeColor: const Color(0xFFF59E0B),
            ),
          if (user.canViewShifts)
            (
              icon: LucideIcons.history,
              label: 'Riwayat shift',
              path: '/shifts',
              caption: 'Rekap & selisih shift lalu',
              color: const Color(0xFF0D9488),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canManageReceivables)
            (
              icon: LucideIcons.handCoins,
              label: 'Piutang (kasbon)',
              path: '/receivables',
              caption: 'Daftar & pelunasan kasbon',
              color: const Color(0xFFD97706),
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        'Produk & Stok',
        [
          if (user.canViewCategories)
            (
              icon: LucideIcons.tags,
              label: 'Kategori',
              path: '/categories',
              caption: 'Kelola kategori produk',
              color: const Color(0xFF06B6D4),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewStock)
            (
              icon: LucideIcons.warehouse,
              label: 'Stok barang',
              path: '/stock',
              caption: 'Posisi stok, menipis, & habis',
              color: const Color(0xFF3B82F6),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewStock)
            (
              icon: LucideIcons.scrollText,
              label: 'Kartu stok',
              path: '/stock/movements',
              caption: 'Riwayat & audit mutasi stok',
              color: const Color(0xFF6366F1),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewCustomers)
            (
              icon: LucideIcons.users,
              label: 'Pelanggan',
              path: '/customers',
              caption: 'Data kontak & tempo piutang',
              color: const Color(0xFF8B5CF6),
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        'Laporan & Aktivitas',
        [
          if (user.canViewSalesReport)
            (
              icon: LucideIcons.trendingUp,
              label: 'Laporan penjualan',
              path: '/reports/sales',
              caption: 'Omzet, laba kotor, produk terlaris',
              color: const Color(0xFF10B981),
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewActivityLog)
            (
              icon: LucideIcons.fileClock,
              label: 'Log aktivitas',
              path: '/activity',
              caption: 'Audit log kasir & admin',
              color: const Color(0xFF64748B),
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        'Pengaturan & Lainnya',
        [
          (
            icon: LucideIcons.search,
            label: 'Cari global',
            path: '/search',
            caption: 'Cari produk & riwayat cepat',
            color: const Color(0xFF64748B),
            badgeCount: null,
            badgeColor: null,
          ),
          (
            icon: LucideIcons.bell,
            label: 'Notifikasi',
            path: '/notifications',
            caption: unread > 0 ? '$unread pesan baru' : 'Pemberitahuan sistem',
            color: const Color(0xFFEF4444),
            badgeCount: unread > 0 ? unread : null,
            badgeColor: const Color(0xFFEF4444),
          ),
          if (user.isSuperadmin && user.tenant != null)
            (
              icon: LucideIcons.store,
              label: 'Preset jenis toko',
              path: '/onboarding',
              caption: 'Hanya selama toko belum punya transaksi',
              color: const Color(0xFF0EA5E9),
              badgeCount: null,
              badgeColor: null,
            ),
          (
            icon: LucideIcons.printer,
            label: 'Printer struk',
            path: '/printer',
            caption: 'Konfigurasi Bluetooth thermal',
            color: const Color(0xFF0284C7),
            badgeCount: null,
            badgeColor: null,
          ),
          (
            icon: LucideIcons.circleUser,
            label: 'Akun & Profil',
            path: '/account',
            caption: 'Profil, password, tema, keluar',
            color: const Color(0xFF6366F1),
            badgeCount: null,
            badgeColor: null,
          ),
        ],
      ),
    ];

    final query = _search.trim().toLowerCase();
    final filteredSections = query.isEmpty
        ? sections
        : [
            for (final (title, links) in sections)
              (
                title,
                links
                    .where((l) =>
                        title.toLowerCase().contains(query) ||
                        l.label.toLowerCase().contains(query) ||
                        (l.caption?.toLowerCase().contains(query) ?? false))
                    .toList(),
              ),
          ];
    final hasResults = filteredSections.any((s) => s.$2.isNotEmpty);

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text('Menu'),
        hint: 'Cari menu (shift, stok, printer...)',
        initialSearch: _search,
        onSearchChanged: (val) => setState(() => _search = val),
        onSearchClosed: () => setState(() => _search = ''),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(unreadCountProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            MaxWidth(
              width: 640,
              child: hasResults
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (title, links) in filteredSections)
                          if (links.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 14, bottom: 8),
                              child: Text(
                                title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, link) in links.indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => context.push(link.path),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: link.color.withValues(alpha: isDark ? 0.2 : 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(link.icon, size: 19, color: link.color),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                link.label,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                              if (link.caption != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  link.caption!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (link.badgeCount != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (link.badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${link.badgeCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: link.badgeColor ?? theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              )
              : Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(
                    icon: LucideIcons.searchX,
                    title: 'Menu tidak ditemukan',
                    description: 'Tidak ada menu yang cocok dengan "$_search"',
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}
