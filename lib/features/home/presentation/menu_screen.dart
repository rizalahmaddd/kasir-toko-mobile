import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/common.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications.dart';

typedef _Link = ({IconData icon, String label, String path, String? caption});

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }

    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final sections = <(String, List<_Link>)>[
      (
        'Penjualan',
        [
          if (user.canSell) (icon: LucideIcons.wallet, label: 'Shift saya', path: '/shift', caption: 'Kas masuk/keluar, tutup shift'),
          if (user.canViewShifts) (icon: LucideIcons.history, label: 'Riwayat shift', path: '/shifts', caption: null),
          if (user.canManageReceivables) (icon: LucideIcons.handCoins, label: 'Piutang (kasbon)', path: '/receivables', caption: 'Catat pelunasan'),
        ],
      ),
      (
        'Produk & stok',
        [
          if (user.canViewCategories) (icon: LucideIcons.tags, label: 'Kategori', path: '/categories', caption: null),
          if (user.canViewStock) (icon: LucideIcons.warehouse, label: 'Stok barang', path: '/stock', caption: 'Posisi stok, menipis, habis'),
          if (user.canViewStock) (icon: LucideIcons.scrollText, label: 'Kartu stok', path: '/stock/movements', caption: 'Riwayat mutasi stok'),
          if (user.canViewCustomers) (icon: LucideIcons.users, label: 'Pelanggan', path: '/customers', caption: null),
        ],
      ),
      (
        'Laporan',
        [
          if (user.canViewSalesReport) (icon: LucideIcons.trendingUp, label: 'Laporan penjualan', path: '/reports/sales', caption: 'Omzet, laba, produk terlaris'),
          if (user.canViewActivityLog) (icon: LucideIcons.fileClock, label: 'Log aktivitas', path: '/activity', caption: null),
        ],
      ),
      (
        'Lainnya',
        [
          (icon: LucideIcons.search, label: 'Cari', path: '/search', caption: null),
          (icon: LucideIcons.bell, label: 'Notifikasi', path: '/notifications', caption: unread > 0 ? '$unread belum dibaca' : null),
          (icon: LucideIcons.printer, label: 'Printer struk', path: '/printer', caption: 'Bluetooth thermal'),
          (icon: LucideIcons.circleUser, label: 'Akun', path: '/account', caption: 'Profil, password, tema, keluar'),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(unreadCountProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            MaxWidth(
              width: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (title, links) in sections)
                    if (links.isNotEmpty) ...[
                      SectionTitle(title),
                      Card(
                        child: Column(
                          children: [
                            for (final (i, link) in links.indexed) ...[
                              if (i > 0) const Divider(),
                              ListTile(
                                leading: Icon(link.icon, size: 20),
                                title: Text(link.label),
                                subtitle: link.caption == null ? null : Text(link.caption!),
                                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                                onTap: () => context.push(link.path),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
