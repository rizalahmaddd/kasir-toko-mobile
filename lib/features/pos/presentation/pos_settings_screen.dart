import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';

class PosSettingsScreen extends ConsumerStatefulWidget {
  const PosSettingsScreen({super.key});

  @override
  ConsumerState<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends ConsumerState<PosSettingsScreen> {
  bool _saving = false;

  Future<void> _update({bool? allowNegativeStock, bool? allowCredit, bool? autoPrint}) async {
    setState(() => _saving = true);
    try {
      await ref.read(posRepositoryProvider).updateSettings(
            allowNegativeStock: allowNegativeStock,
            allowCredit: allowCredit,
            autoPrint: autoPrint,
          );
      ref.invalidate(posConfigProvider);
      unawaited(HapticFeedback.lightImpact());
      if (mounted) {
        showMessage(context, 'Pengaturan kasir berhasil diperbarui.');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(posConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Kasir'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AsyncView<PosConfig>(
        value: configAsync,
        onRetry: () => ref.invalidate(posConfigProvider),
        data: (config) => RefreshIndicator(
          onRefresh: () async => ref.refresh(posConfigProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Transaksi & Stok',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      AppSwitchListTile(
                        value: config.allowNegativeStock,
                        onChanged: _saving ? null : (val) => _update(allowNegativeStock: val),
                        secondary: Icon(
                          LucideIcons.packageMinus,
                          color: config.allowNegativeStock ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          'Bolehkan jual saat stok habis',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Produk dengan stok sistem 0 atau minus tetap bisa dimasukkan ke keranjang kasir. Cocok jika barang fisik sudah ada tapi belum sempat di-input stok masuk.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      AppSwitchListTile(
                        value: config.allowCredit,
                        onChanged: _saving ? null : (val) => _update(allowCredit: val),
                        secondary: Icon(
                          LucideIcons.handCoins,
                          color: config.allowCredit ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          'Bolehkan kasbon (piutang)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Izinkan metode pembayaran kasbon / tempo untuk pelanggan terdaftar.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Struk & Pencetakan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      AppSwitchListTile(
                        value: config.autoPrint,
                        onChanged: _saving ? null : (val) => _update(autoPrint: val),
                        secondary: Icon(
                          LucideIcons.printer,
                          color: config.autoPrint ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          'Cetak struk otomatis',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Otomatis kirim perintah cetak ke printer Bluetooth tersambung setelah transaksi selesai.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StatusColors.of(context).info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StatusColors.of(context).info.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, size: 18, color: StatusColors.of(context).info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pengaturan ini berlaku secara toko / global dan langsung disinkronkan ke kasir web serta perangkat lain.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StatusColors.of(context).info,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
