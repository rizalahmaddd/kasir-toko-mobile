import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'features/pos/presentation/pos_screen.dart';
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

String homeFor(CurrentUser user) => user.canSell ? '/pos' : '/dashboard';

/// Screens a user without the matching permission must not land on, e.g. from a stale deep link.
@visibleForTesting
bool allowedLocation(CurrentUser user, String location) {
  bool under(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (under('/pos') || location == '/shift') {
    return user.canSell;
  }
  if (under('/sales')) {
    return user.canViewSales;
  }
  if (location == '/product/new' || location.endsWith('/edit')) {
    return (under('/product') ? user.canViewProducts : user.canViewCustomers) && user.canManageMasterData;
  }
  if (location == '/customer/new') {
    return user.canViewCustomers && user.canManageMasterData;
  }
  if (under('/products') || under('/product')) {
    return user.canViewProducts;
  }
  if (under('/stock')) {
    return user.canViewStock;
  }
  if (under('/customers') || under('/customer')) {
    return user.canViewCustomers;
  }
  if (under('/categories')) {
    return user.canViewCategories;
  }
  if (under('/receivables')) {
    return user.canManageReceivables;
  }
  if (under('/shifts') || under('/shift')) {
    return user.canViewShifts;
  }
  if (under('/reports')) {
    return user.canViewSalesReport;
  }
  if (under('/activity')) {
    return user.canViewActivityLog;
  }

  return true;
}

GoRoute _page(String path, Widget Function(GoRouterState state) build) => GoRoute(path: path, builder: (context, state) => build(state));

int _id(GoRouterState state) => int.parse(state.pathParameters['id']!);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<CurrentUser?>>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (auth.value.isLoading && !auth.value.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final user = auth.value.value;
      if (user == null) {
        return location == '/login' || location == '/register' ? null : '/login';
      }
      if (user.isTenantBlocked) {
        return location == '/blocked' ? null : '/blocked';
      }
      if (location == '/login' || location == '/splash' || location == '/register' || location == '/blocked') {
        return homeFor(user);
      }

      return allowedLocation(user, location) ? null : '/dashboard';
    },
    routes: [
      _page('/splash', (_) => const SplashScreen()),
      _page('/login', (_) => const LoginScreen()),
      _page('/register', (_) => const RegisterScreen()),
      _page('/blocked', (_) => const TenantBlockedScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [_page('/dashboard', (_) => const DashboardScreen())]),
          StatefulShellBranch(routes: [_page('/pos', (_) => const PosScreen())]),
          StatefulShellBranch(routes: [_page('/sales', (_) => const SalesScreen())]),
          StatefulShellBranch(routes: [_page('/products', (_) => const ProductsScreen())]),
          StatefulShellBranch(routes: [_page('/menu', (_) => const MenuScreen())]),
        ],
      ),
      _page('/sale/:id', (state) => SaleDetailScreen(saleId: _id(state))),
      _page('/product/new', (_) => const ProductFormScreen()),
      _page('/product/:id', (state) => ProductDetailScreen(productId: _id(state))),
      _page('/product/:id/edit', (state) => ProductFormScreen(productId: _id(state))),
      _page('/categories', (_) => const CategoriesScreen()),
      _page('/stock', (_) => const StockScreen()),
      _page(
        '/stock/movements',
        (state) => MovementsScreen(
          productId: int.tryParse(state.uri.queryParameters['product'] ?? ''),
          productName: state.uri.queryParameters['name'],
        ),
      ),
      _page('/customers', (_) => const CustomersScreen()),
      _page('/customer/new', (_) => const CustomerFormScreen()),
      _page('/customer/:id', (state) => CustomerDetailScreen(customerId: _id(state))),
      _page('/customer/:id/edit', (state) => CustomerFormScreen(customerId: _id(state))),
      _page('/receivables', (_) => const ReceivablesScreen()),
      _page('/shift', (_) => const ShiftScreen()),
      _page('/shifts', (_) => const ShiftsScreen()),
      _page('/shift/:id', (state) => ShiftDetailScreen(shiftId: _id(state))),
      _page('/reports/sales', (_) => const SalesReportScreen()),
      _page('/activity', (_) => const ActivityLogScreen()),
      _page('/notifications', (_) => const NotificationsScreen()),
      _page('/search', (_) => const SearchScreen()),
      _page('/account', (_) => const AccountScreen()),
      _page('/printer', (_) => const PrinterScreen()),
      _page('/offline', (_) => const OfflineScreen()),
    ],
  );
});
