import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../customers_providers.dart';
import '../data/customers_repository.dart';

class CustomerFormScreen extends ConsumerWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final int? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customerId == null) {
      return const _CustomerForm();
    }

    return ref.watch(customerProvider(customerId!)).when(
          data: (customer) => _CustomerForm(customer: customer),
          error: (error, _) => Scaffold(appBar: AppBar(), body: ErrorState(error: error, onRetry: () => ref.invalidate(customerProvider(customerId!)))),
          loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
        );
  }
}

class _CustomerForm extends ConsumerStatefulWidget {
  const _CustomerForm({this.customer});

  final Customer? customer;

  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final Customer? _c = widget.customer;
  late final _code = TextEditingController(text: _c?.code);
  late final _name = TextEditingController(text: _c?.name);
  late final _type = TextEditingController(text: _c?.type);
  late final _contact = TextEditingController(text: _c?.contactPerson);
  late final _phone = TextEditingController(text: _c?.phone);
  late final _email = TextEditingController(text: _c?.email);
  late final _address = TextEditingController(text: _c?.address);
  late final _npwp = TextEditingController(text: _c?.npwp);
  late final _term = TextEditingController(text: '${_c?.paymentTermDays ?? 0}');
  late bool _active = _c?.isActive ?? true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final controller in [_code, _name, _type, _contact, _phone, _email, _address, _npwp, _term]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final input = Customer(
      id: _c?.id ?? 0,
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      type: _v(_type),
      contactPerson: _v(_contact),
      phone: _v(_phone),
      email: _v(_email),
      address: _v(_address),
      npwp: _v(_npwp),
      paymentTermDays: int.tryParse(_term.text) ?? 0,
      isActive: _active,
    );

    try {
      final saved = await ref.read(customersRepositoryProvider).save(input, id: _c?.id);
      ref.invalidate(customersProvider);
      if (_c != null) {
        ref.invalidate(customerProvider(saved.id));
      }
      if (mounted) {
        showMessage(context, _c == null ? '${saved.name} ditambahkan.' : 'Perubahan disimpan.');
        if (_c == null) {
          context.pushReplacement('/customer/${saved.id}');
        } else {
          context.pop();
        }
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(TextEditingController controller, String label, String field, {TextInputType? keyboard, String? hint, bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, hintText: hint, errorText: _error?.fieldError(field)),
        validator: required ? (value) => (value ?? '').trim().isEmpty ? '$label wajib diisi.' : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return Scaffold(
      appBar: AppBar(title: Text(_c == null ? 'Pelanggan baru' : 'Ubah pelanggan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(_name, 'Nama', 'name', required: true),
                  _field(_code, 'Kode pelanggan', 'code', keyboard: TextInputType.text, hint: 'mis. PLG-0012', required: true),
                  _field(_phone, 'Nomor HP / WhatsApp', 'phone', keyboard: TextInputType.phone),
                  _field(_type, 'Tipe (opsional)', 'type', hint: 'mis. Member, Grosir, Warung'),
                  _field(_contact, 'Nama kontak (opsional)', 'contact_person'),
                  _field(_email, 'Email (opsional)', 'email', keyboard: TextInputType.emailAddress),
                  _field(_address, 'Alamat (opsional)', 'address', maxLines: 2),
                  _field(_npwp, 'NPWP (opsional)', 'npwp', keyboard: TextInputType.number),
                  _field(_term, 'Tempo bayar (hari)', 'payment_term_days', keyboard: TextInputType.number, hint: '0 = tunai'),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif'), value: _active, onChanged: (value) => setState(() => _active = value)),
                  if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
