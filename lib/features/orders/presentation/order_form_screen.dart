import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/data/pos_models.dart';
import '../../pos/data/pos_repository.dart';
import '../../pos/pos_providers.dart';
import '../data/orders_repository.dart';
import '../orders_providers.dart';

class _Line {
  _Line({this.productId, String name = '', String price = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price);

  final int? productId;
  final TextEditingController name;
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController price;
  final TextEditingController note = TextEditingController();

  void dispose() {
    for (final controller in [name, quantity, price, note]) {
      controller.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
        'product_id': ?productId,
        'name': name.text.trim(),
        'quantity': double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 1,
        'price': parseRupiah(price.text),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      };
}

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _device = TextEditingController();
  final _serial = TextEditingController();
  final _complaint = TextEditingController();
  final _notes = TextEditingController();
  final _deposit = TextEditingController();
  final _lines = <_Line>[];
  String _type = 'order';
  String _method = 'cash';
  DateTime? _pickupAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _phone, _device, _serial, _complaint, _notes, _deposit]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPickup() async {
    final date = await showDatePicker(context: context, initialDate: _pickupAt ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_pickupAt ?? DateTime.now()));
    setState(() => _pickupAt = DateTime(date.year, date.month, date.day, time?.hour ?? 10, time?.minute ?? 0));
  }

  Future<void> _addProduct() async {
    final product = await showModalBottomSheet<Product>(context: context, isScrollControlled: true, builder: (_) => const _ProductPickerSheet());
    if (product != null) {
      setState(() => _lines.add(_Line(productId: product.id, name: product.name, price: thousands(product.price))));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = OrderStrings.errName);
      return;
    }
    if (_type == 'order' && _lines.isEmpty) {
      setState(() => _error = OrderStrings.errItems);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final order = await ref.read(ordersRepositoryProvider).create({
        'type': _type,
        'customer_name': _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'customer_phone': _phone.text.trim(),
        if (_pickupAt != null) 'pickup_at': _pickupAt!.toIso8601String(),
        if (_type == 'service') ...{'device': _device.text.trim(), 'device_serial': _serial.text.trim(), 'complaint': _complaint.text.trim()},
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': [for (final line in _lines) if (line.name.text.trim().isNotEmpty) line.toJson()],
        'deposit': parseRupiah(_deposit.text),
        'deposit_method': _method,
      });
      ref.invalidate(ordersProvider);
      if (mounted) {
        showMessage(context, OrderStrings.saved);
        context.pushReplacement(AppRoutes.orderDetail(order.id));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(posConfigProvider).value?.paymentMethods ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text(OrderStrings.newTitle)),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'order', label: Text(OrderStrings.typeOrder), icon: Icon(AppIcons.clipboardList)),
                ButtonSegment(value: 'service', label: Text(OrderStrings.typeService), icon: Icon(AppIcons.wrench)),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() => _type = value.first),
            ),
            const SectionTitle(OrderStrings.customer),
            TextField(controller: _name, decoration: const InputDecoration(labelText: OrderStrings.customerName)),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: OrderStrings.phone)),
            const SizedBox(height: AppSizes.s12),
            OutlinedButton.icon(
              onPressed: _pickPickup,
              icon: const Icon(AppIcons.calendar, size: AppSizes.s16),
              label: Text(_pickupAt == null ? (_type == 'service' ? OrderStrings.estimatedDone : OrderStrings.pickupLabel) : dateTime(_pickupAt!)),
            ),
            if (_type == 'service') ...[
              const SectionTitle(OrderStrings.device),
              TextField(controller: _device, decoration: const InputDecoration(labelText: OrderStrings.device)),
              const SizedBox(height: AppSizes.s12),
              TextField(controller: _serial, decoration: const InputDecoration(labelText: 'IMEI / SN')),
              const SizedBox(height: AppSizes.s12),
              TextField(controller: _complaint, maxLines: 2, decoration: const InputDecoration(labelText: OrderStrings.complaint)),
            ],
            SectionTitle(
              OrderStrings.items,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => setState(() => _lines.add(_Line())), child: const Text(OrderStrings.freeLine)),
                  TextButton.icon(onPressed: _addProduct, icon: const Icon(AppIcons.plus, size: AppSizes.s16), label: const Text(OrderStrings.addProduct)),
                ],
              ),
            ),
            for (final (index, line) in _lines.indexed)
              Card(
                key: ObjectKey(line),
                margin: const EdgeInsets.only(top: AppSpacing.s8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextField(controller: line.name, readOnly: line.productId != null, decoration: const InputDecoration(labelText: OrderStrings.itemName))),
                          IconButton(onPressed: () => setState(() => _lines.removeAt(index).dispose()), icon: const Icon(AppIcons.trash2, size: AppSizes.s18)),
                        ],
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: line.quantity,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: OrderStrings.qty),
                            ),
                          ),
                          const SizedBox(width: AppSizes.s12),
                          Expanded(child: TextField(controller: line.price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: OrderStrings.price, prefixText: 'Rp '))),
                        ],
                      ),
                      TextField(controller: line.note, decoration: const InputDecoration(labelText: OrderStrings.lineNote)),
                    ],
                  ),
                ),
              ),
            const SectionTitle(OrderStrings.notes),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(hintText: OrderStrings.notesHint)),
            const SectionTitle(OrderStrings.deposit),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deposit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: OrderStrings.amount, prefixText: 'Rp '),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(labelText: OrderStrings.method),
                    items: [for (final option in methods) DropdownMenuItem(value: option.value, child: Text(option.label))],
                    onChanged: (value) => setState(() => _method = value ?? _method),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.s12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSizes.s20),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? OrderStrings.saving : OrderStrings.save)),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  Timer? _debounce;
  List<Product> _results = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String term) async {
    try {
      final page = await ref.read(posRepositoryProvider).products(search: term);
      if (mounted) {
        setState(() => _results = page.items);
      }
    } on ApiException {
      // daftar lama tetap ditampilkan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHeader(title: OrderStrings.addProduct),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(AppIcons.search)),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () => _search(value.trim()));
                },
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final product = _results[index];

                  return ListTile(onTap: () => Navigator.pop(context, product), title: Text(product.name), trailing: Text(rupiah(product.price)));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
