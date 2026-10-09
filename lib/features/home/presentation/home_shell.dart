import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/services/in_app_update_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/display_service.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/current_user.dart';
import '../../offline/offline_queue.dart';

import '../../pos/cart_controller.dart';
import '../../pos/pos_providers.dart';

typedef ShellTab = ({int branch, IconData icon, String label});

/// Branch order must match the StatefulShellRoute in router.dart.
List<ShellTab> visibleTabs(CurrentUser? user) => [
      (branch: 0, icon: AppIcons.layoutDashboard, label: HomeStrings.tabBeranda),
      if (user?.canSell ?? false) (branch: 1, icon: AppIcons.shoppingCart, label: HomeStrings.tabKasir),
      if (user?.canViewSales ?? false) (branch: 2, icon: AppIcons.receiptText, label: HomeStrings.tabTransaksi),
      if (user?.canViewProducts ?? false) (branch: 3, icon: AppIcons.package, label: HomeStrings.tabProduk),
      (branch: 4, icon: AppIcons.layoutGrid, label: HomeStrings.tabMenu),
    ];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  DisplayService? _displayService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(inAppUpdateServiceProvider.notifier).checkForUpdate(silent: true, context: context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _displayService = ref.read(displayServiceProvider);
    _syncWakelock();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) {
      _syncWakelock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncWakelock();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _displayService?.allowScreenSleep();
    }
  }

  void _syncWakelock() {
    // Branch 1 is AppRoutes.pos (Kasir).
    final isCashierTab = widget.shell.currentIndex == 1;
    final keepScreenOn = ref.read(posDisplaySettingsProvider).keepScreenOn;
    if (isCashierTab && keepScreenOn) {
      _displayService?.keepScreenOn();
    } else {
      _displayService?.allowScreenSleep();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayService?.allowScreenSleep();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineSyncerProvider);
    ref.listen<PosDisplaySettings>(posDisplaySettingsProvider, (prev, next) {
      if (prev?.keepScreenOn != next.keepScreenOn) {
        _syncWakelock();
      }
    });
    ref.listen<InAppUpdateState>(inAppUpdateServiceProvider, (prev, next) {
      if (prev?.status != InAppUpdateStatus.downloaded && next.status == InAppUpdateStatus.downloaded) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text(AboutStrings.updateDownloaded),
              duration: const Duration(days: 1),
              action: SnackBarAction(
                label: AboutStrings.restartToUpdate,
                textColor: AppColors.emerald400,
                onPressed: () {
                  ref.read(inAppUpdateServiceProvider.notifier).completeFlexibleUpdate();
                },
              ),
            ),
          );
        }
      }
    });
    ref.listen<bool>(currentUserProvider.select((user) => user?.updateRequired ?? false), (previous, required) {
      if (required && previous != true) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(OutletStrings.updateRequiredTitle),
            content: const Text(OutletStrings.updateRequiredMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(OutletStrings.updateLater)),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref.read(inAppUpdateServiceProvider.notifier).checkForUpdate(context: context);
                },
                child: const Text(OutletStrings.updateAction),
              ),
            ],
          ),
        );
      }
    });
    final tabs = visibleTabs(ref.watch(currentUserProvider));
    final cart = ref.watch(cartProvider);
    final selected = tabs.indexWhere((tab) => tab.branch == widget.shell.currentIndex).clamp(0, tabs.length - 1);

    void go(int index) {
      final branch = tabs[index].branch;
      widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
    }

    Widget tabIcon(ShellTab tab) {
      final icon = Icon(tab.icon);
      if (tab.branch == 1 && cart.itemCount > 0) {
        return Badge(
          label: Text(cart.itemCount > 99 ? HomeStrings.tabBadgeOverflow : cart.itemCount.toInt().toString()),
          child: icon,
        );
      }
      return icon;
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
                destinations: [
                  for (final tab in tabs)
                    NavigationRailDestination(
                      icon: tabIcon(tab),
                      label: Text(tab.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: widget.shell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: go,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: tabIcon(tab),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
