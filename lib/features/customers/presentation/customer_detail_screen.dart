import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
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
            onRefresh: () {
              ref.invalidate(customerSalesProvider(customerId));
              return ref.refresh(customerProvider(customerId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(customer.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  ),
                                  StatusBadge(label: customer.isActive ? 'Aktif' : 'Nonaktif', tone: customer.isActive ? BadgeTone.success : BadgeTone.muted),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InfoRow('Kode', customer.code),
                              if (customer.type != null) InfoRow('Tipe', customer.type!),
                              if (customer.contactPerson != null) InfoRow('Kontak', customer.contactPerson!),
                              InfoRow('Nomor HP', customer.phone ?? '-'),
                              if (customer.email != null) InfoRow('Email', customer.email!),
                              if (customer.address != null) InfoRow('Alamat', customer.address!),
                              if (customer.npwp != null) InfoRow('NPWP', customer.npwp!),
                              InfoRow('Tempo bayar', customer.paymentTermDays == 0 ? 'Tunai' : '${customer.paymentTermDays} hari'),
                              if (customer.phone != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => openExternal(context, Uri(scheme: 'tel', path: customer.phone)),
                                        icon: const Icon(LucideIcons.phone, size: 18),
                                        label: const Text('Telepon'),
                                      ),
                                    ),
                                    if (wa != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => openExternal(context, Uri.parse('https://wa.me/$wa'), failure: 'WhatsApp tidak bisa dibuka.'),
                                          icon: const Icon(LucideIcons.messageCircle, size: 18),
                                          label: const Text('WhatsApp'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
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
            Row(
              children: [
                Expanded(child: StatTile(label: 'Belanja setahun', value: rupiah(value.total), caption: '${value.count} transaksi')),
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
            const SectionTitle('Transaksi terakhir'),
            if (value.items.isEmpty)
              Text('Belum ada transaksi dalam setahun terakhir.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              Card(child: Column(children: [for (final sale in value.items.take(15)) SaleTile(sale: sale)])),
          ],
        ),
      AsyncError(:final error) => Padding(padding: const EdgeInsets.only(top: 16), child: Text(errorMessage(error))),
      _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    };
  }
}
