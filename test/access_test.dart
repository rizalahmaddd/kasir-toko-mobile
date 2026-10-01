import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/features/auth/access.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/home/presentation/home_shell.dart';

const _allFeatures = {
  'pos.cashier', 'pos.sales', 'pos.shifts', 'pos.receivables', 'master-data.products', 'master-data.categories',
  'master-data.customers', 'inventory.stock', 'reports.sales', 'reports.activity-log',
};

CurrentUser _user(Set<String> permissions, {Set<String> features = _allFeatures, bool superadmin = false}) => CurrentUser(
      id: 1,
      name: 'Test',
      username: 'test',
      roles: const ['test'],
      permissions: permissions,
      isSuperadmin: superadmin,
      enabledFeatures: features,
    );

void main() {
  test('cashier role sees selling, receivables and read-only master data', () {
    final kasir = _user({'pos.sell', 'receivables.manage', 'master-data.view'});

    expect(kasir.canSell, isTrue);
    expect(kasir.canManageReceivables, isTrue);
    expect(kasir.canViewProducts, isTrue);
    expect(kasir.canManageMasterData, isFalse);
    expect(kasir.canAdjustStock, isFalse);
    expect(kasir.canViewSalesReport, isFalse);
    expect(visibleTabs(kasir).map((t) => t.label), ['Beranda', 'Kasir', 'Transaksi', 'Produk', 'Menu']);
  });

  test('staff role manages stock but cannot sell', () {
    final staff = _user({'master-data.view', 'inventory.manage'});

    expect(staff.canSell, isFalse);
    expect(staff.canAdjustStock, isTrue);
    expect(visibleTabs(staff).map((t) => t.label), ['Beranda', 'Produk', 'Menu']);
  });

  test('a disabled feature hides the module even for superadmin', () {
    final owner = _user(const {}, superadmin: true, features: {..._allFeatures}..remove('pos.receivables'));

    expect(owner.canSell, isTrue);
    expect(owner.canManageReceivables, isFalse);
    expect(owner.canViewActivityLog, isTrue);
  });
}
