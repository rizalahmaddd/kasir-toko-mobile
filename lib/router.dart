import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_routes.dart';
import 'features/auth/access.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/data/current_user.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/tenant_blocked_screen.dart';
import 'features/customers/presentation/customer_detail_screen.dart';
import 'features/customers/presentation/customer_form_screen.dart';
import 'features/customers/presentation/customers_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/home/presentation/account_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/home/presentation/menu_screen.dart';
import 'features/home/presentation/splash_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/offline/presentation/offline_screen.dart';
import 'features/notifications/presentation/search_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/pos/presentation/pos_screen.dart';
import 'features/pos/presentation/pos_settings_screen.dart';
import 'features/printing/presentation/printer_screen.dart';
import 'features/products/presentation/categories_screen.dart';
import 'features/products/presentation/movements_screen.dart';
import 'features/products/presentation/product_detail_screen.dart';
import 'features/products/presentation/product_form_screen.dart';
import 'features/products/presentation/products_screen.dart';
import 'features/products/presentation/stock_screen.dart';
import 'features/receivables/presentation/receivables_screen.dart';
import 'features/reports/presentation/activity_log_screen.dart';
import 'features/reports/presentation/sales_report_screen.dart';
import 'features/sales/presentation/sale_detail_screen.dart';
import 'features/sales/presentation/sales_screen.dart';
import 'features/shift/presentation/shift_screen.dart';
import 'features/shift/presentation/shifts_screen.dart';

String homeFor(CurrentUser user) => user.canSell ? AppRoutes.pos : AppRoutes.dashboard;

/// Screens a user without the matching permission must not land on, e.g. from a stale deep link.
@visibleForTesting
bool allowedLocation(CurrentUser user, String location) {
  bool under(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (under(AppRoutes.pos) || location == AppRoutes.shift) {
    return user.canSell;
  }
  if (under(AppRoutes.sales)) {
    return user.canViewSales;
  }
  if (location == AppRoutes.productNew || location.endsWith(AppRoutes.editSuffix)) {
    return (under(AppRoutes.product) ? user.canViewProducts : user.canViewCustomers) && user.canManageMasterData;
  }
  if (location == AppRoutes.customerNew) {
    return user.canViewCustomers && user.canManageMasterData;
  }
  if (under(AppRoutes.products) || under(AppRoutes.product)) {
    return user.canViewProducts;
  }
  if (under(AppRoutes.stock)) {
    return user.canViewStock;
  }
  if (under(AppRoutes.customers) || under(AppRoutes.customer)) {
    return user.canViewCustomers;
  }
  if (under(AppRoutes.categories)) {
    return user.canViewCategories;
  }
  if (under(AppRoutes.receivables)) {
    return user.canManageReceivables;
  }
  if (under(AppRoutes.shifts) || under(AppRoutes.shift)) {
    return user.canViewShifts;
  }
  if (under(AppRoutes.reports)) {
    return user.canViewSalesReport;
  }
  if (under(AppRoutes.activity)) {
    return user.canViewActivityLog;
  }
  if (under(AppRoutes.onboarding)) {
    return user.isSuperadmin && user.tenant != null;
  }
  if (under(AppRoutes.posSettings)) {
    return user.canManagePosSettings;
  }

  return true;
}

@visibleForTesting
String? routeRedirect(AsyncValue<CurrentUser?> auth, String location) {
  if (auth.isLoading && !auth.hasValue) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final user = auth.value;
  if (user == null) {
    return location == AppRoutes.login || location == AppRoutes.register ? null : AppRoutes.login;
  }
  if (user.isTenantBlocked) {
    return location == AppRoutes.blocked ? null : AppRoutes.blocked;
  }
  if (user.needsOnboarding) {
    return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }
  if (location == AppRoutes.login || location == AppRoutes.splash || location == AppRoutes.register || location == AppRoutes.blocked) {
    return homeFor(user);
  }

  return allowedLocation(user, location) ? null : AppRoutes.dashboard;
}

GoRoute _page(String path, Widget Function(GoRouterState state) build) => GoRoute(path: path, builder: (context, state) => build(state));

int _id(GoRouterState state) => int.parse(state.pathParameters['id']!);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<CurrentUser?>>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) => routeRedirect(auth.value, state.matchedLocation),
    routes: [
      _page(AppRoutes.splash, (_) => const SplashScreen()),
      _page(AppRoutes.login, (_) => const LoginScreen()),
      _page(AppRoutes.register, (_) => const RegisterScreen()),
      _page(AppRoutes.blocked, (_) => const TenantBlockedScreen()),
      _page(AppRoutes.onboarding, (_) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [_page(AppRoutes.dashboard, (_) => const DashboardScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.pos, (_) => const PosScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.sales, (_) => const SalesScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.products, (_) => const ProductsScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.menu, (_) => const MenuScreen())]),
        ],
      ),
      _page(AppRoutes.salePattern, (state) => SaleDetailScreen(saleId: _id(state))),
      _page(AppRoutes.productNew, (_) => const ProductFormScreen()),
      _page(AppRoutes.productPattern, (state) => ProductDetailScreen(productId: _id(state))),
      _page(AppRoutes.productEditPattern, (state) => ProductFormScreen(productId: _id(state))),
      _page(AppRoutes.categories, (_) => const CategoriesScreen()),
      _page(AppRoutes.stock, (_) => const StockScreen()),
      _page(
        AppRoutes.stockMovements,
        (state) => MovementsScreen(
          productId: int.tryParse(state.uri.queryParameters['product'] ?? ''),
          productName: state.uri.queryParameters['name'],
        ),
      ),
      _page(AppRoutes.customers, (_) => const CustomersScreen()),
      _page(AppRoutes.customerNew, (_) => const CustomerFormScreen()),
      _page(AppRoutes.customerPattern, (state) => CustomerDetailScreen(customerId: _id(state))),
      _page(AppRoutes.customerEditPattern, (state) => CustomerFormScreen(customerId: _id(state))),
      _page(AppRoutes.receivables, (_) => const ReceivablesScreen()),
      _page(AppRoutes.shift, (_) => const ShiftScreen()),
      _page(AppRoutes.shifts, (_) => const ShiftsScreen()),
      _page(AppRoutes.shiftPattern, (state) => ShiftDetailScreen(shiftId: _id(state))),
      _page(AppRoutes.reportsSales, (_) => const SalesReportScreen()),
      _page(AppRoutes.activity, (_) => const ActivityLogScreen()),
      _page(AppRoutes.notifications, (_) => const NotificationsScreen()),
      _page(AppRoutes.search, (_) => const SearchScreen()),
      _page(AppRoutes.account, (state) => AccountScreen(scrollToDelete: state.uri.queryParameters['action'] == 'delete')),
      _page(AppRoutes.printer, (_) => const PrinterScreen()),
      _page(AppRoutes.posSettings, (_) => const PosSettingsScreen()),
      _page(AppRoutes.offline, (_) => const OfflineScreen()),
    ],
  );
});
