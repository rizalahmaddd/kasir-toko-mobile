import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/responsive.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: LucideIcons.shoppingCart, label: 'Kasir'),
    (icon: LucideIcons.receiptText, label: 'Riwayat'),
    (icon: LucideIcons.wallet, label: 'Shift'),
    (icon: LucideIcons.user, label: 'Akun'),
  ];

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (context.isMedium) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(icon: Icon(destination.icon), label: Text(destination.label)),
                ],
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
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final destination in _destinations) NavigationDestination(icon: Icon(destination.icon), label: destination.label),
        ],
      ),
    );
  }
}
