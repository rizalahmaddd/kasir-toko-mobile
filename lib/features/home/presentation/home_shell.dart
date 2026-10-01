import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/responsive.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/current_user.dart';
import '../../offline/offline_queue.dart';

typedef ShellTab = ({int branch, IconData icon, String label});

/// Branch order must match the StatefulShellRoute in router.dart.
List<ShellTab> visibleTabs(CurrentUser? user) => [
      (branch: 0, icon: LucideIcons.layoutDashboard, label: 'Beranda'),
      if (user?.canSell ?? false) (branch: 1, icon: LucideIcons.shoppingCart, label: 'Kasir'),
      if (user?.canViewSales ?? false) (branch: 2, icon: LucideIcons.receiptText, label: 'Transaksi'),
      if (user?.canViewProducts ?? false) (branch: 3, icon: LucideIcons.package, label: 'Produk'),
      (branch: 4, icon: LucideIcons.layoutGrid, label: 'Menu'),
    ];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(offlineSyncerProvider);
    final tabs = visibleTabs(ref.watch(currentUserProvider));
    final selected = tabs.indexWhere((tab) => tab.branch == shell.currentIndex).clamp(0, tabs.length - 1);

    void go(int index) {
      final branch = tabs[index].branch;
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
    }

    if (context.isMedium) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: go,
                labelType: NavigationRailLabelType.all,
                destinations: [for (final tab in tabs) NavigationRailDestination(icon: Icon(tab.icon), label: Text(tab.label))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: go,
        destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label)],
      ),
    );
  }
}
