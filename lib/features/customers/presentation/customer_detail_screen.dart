import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../receivables/receivables.dart';
import '../../sales/presentation/sale_tile.dart';
import '../customers_providers.dart';
import '../data/customers_repository.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(customerId));
    final user = ref.watch(currentUserProvider);
    final canManage = user?.canManageMasterData ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.value?.name ?? 'Pelanggan'),
        actions: [
          if (canManage && customer.value != null) ...[
            IconButton(tooltip: 'Ubah', icon: const Icon(LucideIcons.pencil, size: 20), onPressed: () => context.push('/customer/$customerId/edit')),
            IconButton(tooltip: 'Hapus', icon: const Icon(LucideIcons.trash2, size: 20), onPressed: () => _delete(context, ref, customer.value!)),
          ],
        ],
      ),
      body: AsyncView(
        value: customer,
        onRetry: () => ref.invalidate(customerProvider(customerId)),
        data: (customer) {
          final wa = whatsappNumber(customer.phone);

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.read(customerProvider(customerId).notifier).refresh(),
              ref.read(customerSalesProvider(customerId).notifier).refresh(),
              ref.read(customerReceivablesProvider(customerId).notifier).refresh(),
            ]),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            if (Theme.of(context).brightness != Brightness.dark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                        : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              customer.code,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          if (customer.type != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                customer.type!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0D9488),
                                                ),
                                              ),
                                            ),
                                          StatusBadge(
                                            label: customer.isActive ? 'Aktif' : 'Nonaktif',
                                            tone: customer.isActive ? BadgeTone.success : BadgeTone.muted,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (customer.phone != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => openExternal(context, Uri(scheme: 'tel', path: customer.phone)),
                                      icon: const Icon(LucideIcons.phone, size: 16),
                                      label: const Text('Telepon', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  if (wa != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          foregroundColor: const Color(0xFF059669),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => openExternal(context, Uri.parse('https://wa.me/$wa'), failure: 'WhatsApp tidak bisa dibuka.'),
                                        icon: const Icon(LucideIcons.messageCircle, size: 16),
                                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            InfoRow('Nomor HP', customer.phone ?? '-'),
                            if (customer.contactPerson != null) InfoRow('Kontak person', customer.contactPerson!),
                            if (customer.email != null) InfoRow('Email', customer.email!),
                            if (customer.address != null) InfoRow('Alamat', customer.address!),
                            if (customer.npwp != null) InfoRow('NPWP', customer.npwp!),
                            InfoRow('Tempo bayar', customer.paymentTermDays == 0 ? 'Tunai' : '${customer.paymentTermDays} hari'),
                          ],
                        ),
                      ),
                      if (user?.canViewSales ?? false) _CustomerSales(customerId: customerId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Customer customer) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus pelanggan?',
      message: '${customer.name} akan dihapus. Riwayat transaksinya tetap tersimpan.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }

    try {
      await ref.read(customersRepositoryProvider).delete(customer.id);
      ref.read(customersProvider.notifier).remove((item) => item.id == customer.id);
      ref.read(dataChangesProvider).after({DataChange.customers});
      if (context.mounted) {
        context.pop();
        showMessage(context, '${customer.name} dihapus.');
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }
}

class _CustomerSales extends ConsumerWidget {
  const _CustomerSales({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(customerSalesProvider(customerId));
    final colors = StatusColors.of(context);

    return switch (sales) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(label: 'Belanja setahun', value: rupiah(value.total), caption: '${value.count} transaksi'),
                ),
                const SizedBox(width: 8),
                if (ref.watch(currentUserProvider)?.canManageReceivables ?? false)
                  Expanded(
                    child: StatTile(
                      label: 'Kasbon belum lunas',
                      value: rupiah(ref.watch(customerReceivablesProvider(customerId)).value?.fold<int>(0, (sum, sale) => sum + sale.dueAmount) ?? 0),
                      color: colors.warning,
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('Transaksi terakhir'),
          if (value.items.isEmpty)
            Text('Belum ada transaksi dalam setahun terakhir.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            Column(
              children: [
                for (final sale in value.items.take(15))
                  SaleTile(sale: sale, margin: const EdgeInsets.only(bottom: 8)),
              ],
            ),
        ],
      ),
      AsyncError(:final error) => Padding(padding: const EdgeInsets.only(top: 16), child: Text(errorMessage(error))),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SalesListSkeleton(itemCount: 3, showSummary: false, shrinkWrap: true),
      ),
    };
  }
}
