import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/data/pos_models.dart';
import '../../pos/data/pos_repository.dart';
import '../data/prescription_models.dart';
import '../data/prescriptions_repository.dart';
import '../pharmacy_providers.dart';

class PrescriptionFormScreen extends ConsumerStatefulWidget {
  const PrescriptionFormScreen({super.key});

  @override
  ConsumerState<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends ConsumerState<PrescriptionFormScreen> {
  final _doctor = TextEditingController();
  final _sip = TextEditingController();
  final _clinic = TextEditingController();
  final _patient = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _lines = [PrescriptionInputLine()];
  XFile? _photo;
  bool _verify = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_doctor, _sip, _clinic, _patient, _age, _phone, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProduct(PrescriptionInputLine line) async {
    final product = await showModalBottomSheet<Product>(context: context, isScrollControlled: true, builder: (_) => const _DrugPickerSheet());
    if (product != null) {
      setState(() {
        line
          ..productId = product.id
          ..productName = product.name
          ..unit = product.unit;
      });
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (file != null) {
      setState(() => _photo = file);
    }
  }

  Future<void> _save() async {
    final lines = _lines.where((line) => line.productName.trim().isNotEmpty || line.productId != null).toList();
    if (_doctor.text.trim().isEmpty || _patient.text.trim().isEmpty) {
      setState(() => _error = PosStrings.prescriptionDraftRequired);
      return;
    }
    if (lines.isEmpty || lines.any((line) => (double.tryParse(line.quantity.replaceAll(',', '.')) ?? 0) <= 0)) {
      setState(() => _error = PharmacyStrings.errItems);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = ref.read(prescriptionsRepositoryProvider);
    try {
      var prescription = await repository.create({
        'doctor_name': _doctor.text.trim(),
        'doctor_sip': _sip.text.trim(),
        'clinic_name': _clinic.text.trim(),
        'patient_name': _patient.text.trim(),
        'patient_age': int.tryParse(_age.text.trim()),
        'patient_phone': _phone.text.trim(),
        'notes': _notes.text.trim(),
        'verify': _verify,
        'items': lines.map((line) => line.toJson()).toList(),
      });
      if (_photo != null) {
        prescription = await repository.uploadImage(prescription.id, _photo!.path);
      }
      ref.invalidate(prescriptionsProvider);
      if (mounted) {
        showMessage(context, PharmacyStrings.saved);
        context.pushReplacement(AppRoutes.prescriptionDetail(prescription.id));
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
    final canVerify = ref.watch(currentUserProvider)?.canVerifyPrescriptions ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text(PharmacyStrings.newTitle)),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            const SectionTitle(PharmacyStrings.doctor),
            TextField(controller: _doctor, decoration: const InputDecoration(labelText: PosStrings.prescriptionDoctor)),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _sip, decoration: const InputDecoration(labelText: PosStrings.prescriptionDoctorSip)),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _clinic, decoration: const InputDecoration(labelText: PosStrings.prescriptionClinic)),
            const SectionTitle(PharmacyStrings.patient),
            TextField(controller: _patient, decoration: const InputDecoration(labelText: PosStrings.prescriptionPatient)),
            const SizedBox(height: AppSizes.s12),
            Row(
              children: [
                Expanded(child: TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: PosStrings.prescriptionPatientAge))),
                const SizedBox(width: AppSizes.s12),
                Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP'))),
              ],
            ),
            SectionTitle(
              PharmacyStrings.drugs,
              trailing: TextButton.icon(
                onPressed: _lines.length >= 30 ? null : () => setState(() => _lines.add(PrescriptionInputLine())),
                icon: const Icon(AppIcons.plus, size: AppSizes.s16),
                label: const Text(PharmacyStrings.addDrug),
              ),
            ),
            Text(PharmacyStrings.drugsHint, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            for (final line in _lines)
              Card(
                key: ObjectKey(line),
                margin: const EdgeInsets.only(top: AppSpacing.s8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickProduct(line),
                              icon: const Icon(AppIcons.search, size: AppSizes.s16),
                              label: Text(line.productId == null ? PharmacyStrings.drugPick : line.productName, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          if (_lines.length > 1)
                            IconButton(onPressed: () => setState(() => _lines.remove(line)), icon: const Icon(AppIcons.trash2, size: AppSizes.s18)),
                        ],
                      ),
                      if (line.productId == null)
                        TextFormField(
                          initialValue: line.productName,
                          onChanged: (value) => line.productName = value,
                          decoration: const InputDecoration(labelText: PharmacyStrings.drugName),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: line.quantity,
                              onChanged: (value) => line.quantity = value,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: PharmacyStrings.drugQuantity, suffixText: line.unit),
                            ),
                          ),
                          const SizedBox(width: AppSizes.s12),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: line.iteration,
                              onChanged: (value) => line.iteration = value,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: PharmacyStrings.drugIteration),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        initialValue: line.dosage,
                        onChanged: (value) => line.dosage = value,
                        decoration: const InputDecoration(labelText: PharmacyStrings.drugDosage),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionTitle(PharmacyStrings.photo),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _takePhoto(ImageSource.camera), icon: const Icon(AppIcons.camera), label: const Text(PharmacyStrings.photoCamera))),
                const SizedBox(width: AppSizes.s12),
                Expanded(child: OutlinedButton(onPressed: () => _takePhoto(ImageSource.gallery), child: const Text(PharmacyStrings.photoGallery))),
              ],
            ),
            if (_photo != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.s8), child: Text(_photo!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: PharmacyStrings.notes)),
            if (canVerify)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _verify,
                onChanged: (value) => setState(() => _verify = value ?? false),
                title: const Text(PharmacyStrings.verifyNow),
              ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.s8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: AppSizes.s16),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '…' : PharmacyStrings.save)),
            const SizedBox(height: AppSizes.s24),
          ],
        ),
      ),
    );
  }
}

class _DrugPickerSheet extends ConsumerStatefulWidget {
  const _DrugPickerSheet();

  @override
  ConsumerState<_DrugPickerSheet> createState() => _DrugPickerSheetState();
}

class _DrugPickerSheetState extends ConsumerState<_DrugPickerSheet> {
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
            const BottomSheetHeader(title: PharmacyStrings.drugPick),
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

                  return ListTile(
                    onTap: () => Navigator.pop(context, product),
                    title: Text(product.name),
                    subtitle: Text([product.unit, ?product.drugClassLabel].join(' · ')),
                    trailing: product.requiresPrescription ? const StatusBadge(label: 'RESEP', tone: BadgeTone.danger) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
