import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';

class CustomerPicker extends ConsumerStatefulWidget {
  const CustomerPicker({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: CustomerPicker()),
      );

  @override
  ConsumerState<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<CustomerPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  AsyncValue<List<CustomerOption>> _results = const AsyncLoading();

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String term) async {
    setState(() => _results = const AsyncLoading());
    final result = await AsyncValue.guard(() => ref.read(posRepositoryProvider).customers(term));
    if (mounted) {
      setState(() => _results = result);
    }
  }

  void _pick(CustomerOption? customer) {
    ref.read(cartProvider.notifier).setCustomer(customer);
    Navigator.pop(context);
  }

  Future<void> _create() async {
    final created = await showDialog<CustomerOption>(context: context, builder: (_) => _QuickCustomerDialog(initialName: _search.text.trim()));
    if (created != null) {
      _pick(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(cartProvider).customer;
    final warning = StatusColors.of(context).warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: Text('Pilih pelanggan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              TextButton.icon(onPressed: _create, icon: const Icon(LucideIcons.userPlus, size: 18), label: const Text('Pelanggan Baru')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nama, nomor HP, atau kode', prefixIcon: Icon(LucideIcons.search, size: 18)),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => _load(value.trim()));
            },
          ),
        ),
        if (current != null)
          ListTile(
            leading: const Icon(LucideIcons.x, size: 18),
            title: Text('Lepas ${current.name}'),
            subtitle: const Text('Transaksi tanpa nama pelanggan'),
            onTap: () => _pick(null),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncView(
            value: _results,
            onRetry: () => _load(_search.text.trim()),
            data: (customers) => customers.isEmpty
                ? EmptyState(
                    icon: LucideIcons.users,
                    title: 'Pelanggan tidak ditemukan',
                    action: OutlinedButton(onPressed: _create, child: const Text('Tambah Pelanggan Baru')),
                  )
                : ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return ListTile(
                        selected: customer.id == current?.id,
                        title: Text(customer.name),
                        subtitle: Text([customer.code, customer.phone].nonNulls.join(' · ')),
                        trailing: customer.due > 0
                            ? Text('Kasbon ${rupiah(customer.due)}', style: TextStyle(color: warning, fontSize: 12, fontWeight: FontWeight.w600))
                            : null,
                        onTap: () => _pick(customer),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuickCustomerDialog extends ConsumerStatefulWidget {
  const _QuickCustomerDialog({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_QuickCustomerDialog> createState() => _QuickCustomerDialogState();
}

class _QuickCustomerDialogState extends ConsumerState<_QuickCustomerDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _phone = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final customer = await ref.read(posRepositoryProvider).createCustomer(name: _name.text.trim(), phone: _phone.text.trim());
      if (mounted) {
        Navigator.pop(context, customer);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pelanggan baru'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nama', errorText: _error?.fieldError('name')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'Nomor HP / WhatsApp', errorText: _error?.fieldError('phone')),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan Pelanggan')),
      ],
    );
  }
}
