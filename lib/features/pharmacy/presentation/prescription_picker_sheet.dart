import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../outlets/outlet_controller.dart';
import '../../auth/auth_controller.dart';
import '../../pos/cart_controller.dart';
import '../../pos/data/pos_models.dart';
import '../../pos/pos_providers.dart';
import '../data/prescription_models.dart';
import '../data/prescriptions_repository.dart';

/// Menautkan resep tersimpan ke keranjang, atau mengisi dokter & pasien langsung (mode peringatan / apoteker).
class PrescriptionPickerSheet extends ConsumerStatefulWidget {
  const PrescriptionPickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const PrescriptionPickerSheet(),
      );

  @override
  ConsumerState<PrescriptionPickerSheet> createState() => _PrescriptionPickerSheetState();
}

class _PrescriptionPickerSheetState extends ConsumerState<PrescriptionPickerSheet> {
  final _doctor = TextEditingController();
  final _sip = TextEditingController();
  final _patient = TextEditingController();
  final _age = TextEditingController();
  final _clinic = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool _draftTab = false;
  bool _loading = false;
  String? _error;
  List<Prescription> _results = const [];

  PosConfig? get _config => ref.read(posConfigProvider).value;

  bool get _canView => ref.read(currentUserProvider)?.canViewPrescriptionsAt(ref.read(currentOutletIdProvider)) ?? false;

  bool get _canDraft => _config?.canDraftPrescription ?? false;

  @override
  void initState() {
    super.initState();
    _draftTab = !_canView;
    if (_canView) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final controller in [_doctor, _sip, _patient, _age, _clinic]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await ref.read(prescriptionsRepositoryProvider).list(search: _search);
      if (mounted) {
        setState(() => _results = page.items);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(Prescription prescription) {
    if ((_config?.strictPrescription ?? true) && !prescription.isVerified) {
      setState(() => _error = PosStrings.prescriptionNotVerified(prescription.number));
      return;
    }

    ref.read(cartProvider.notifier).setPrescription(LinkedPrescription(id: prescription.id, number: prescription.number, patient: prescription.patientName));
    Navigator.pop(context);
  }

  void _saveDraft() {
    if (_doctor.text.trim().isEmpty || _patient.text.trim().isEmpty) {
      setState(() => _error = PosStrings.prescriptionDraftRequired);
      return;
    }

    ref.read(cartProvider.notifier).setPrescriptionDraft(
          PrescriptionDraft(
            doctorName: _doctor.text.trim(),
            patientName: _patient.text.trim(),
            patientAge: int.tryParse(_age.text.trim()),
            doctorSip: _sip.text.trim(),
            clinicName: _clinic.text.trim(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strict = _config?.strictPrescription ?? true;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BottomSheetHeader(
              title: PosStrings.prescriptionSheetTitle,
              subtitle: strict ? PosStrings.prescriptionStrictHint : PosStrings.prescriptionWarnHint,
            ),
            if (_canView && _canDraft)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text(PosStrings.prescriptionSavedTab)),
                    ButtonSegment(value: true, label: Text(PosStrings.prescriptionDraftTab)),
                  ],
                  selected: {_draftTab},
                  onSelectionChanged: (value) => setState(() {
                    _draftTab = value.first;
                    _error = null;
                  }),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s0),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Flexible(child: _draftTab ? _draftForm(context) : _savedList(context)),
          ],
        ),
      ),
    );
  }

  Widget _savedList(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: PosStrings.prescriptionSearchHint),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                _search = value.trim();
                unawaited(_load());
              });
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Flexible(
          child: _results.isEmpty && !_loading
              ? const Padding(padding: EdgeInsets.all(AppSpacing.s24), child: Text(PosStrings.prescriptionEmpty))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final prescription = _results[index];

                    return ListTile(
                      onTap: () => _select(prescription),
                      title: Text('${prescription.number} · ${prescription.patientName}'),
                      subtitle: Text(
                        prescription.items.map((item) => '${item.productName} (${PharmacyStrings.remaining(quantity(item.remaining), item.unit ?? '')})').join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted),
                      ),
                      trailing: StatusBadge(
                        label: prescription.isVerified ? PosStrings.prescriptionVerified : PosStrings.prescriptionWaiting,
                        tone: prescription.isVerified ? BadgeTone.success : BadgeTone.warning,
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSizes.s16),
      ],
    );
  }

  Widget _draftForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_canDraft)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Text(PosStrings.prescriptionStrictDraftBlocked, style: TextStyle(color: StatusColors.of(context).warning)),
            ),
          TextField(controller: _doctor, decoration: const InputDecoration(labelText: PosStrings.prescriptionDoctor)),
          const SizedBox(height: AppSizes.s12),
          TextField(controller: _sip, decoration: const InputDecoration(labelText: PosStrings.prescriptionDoctorSip)),
          const SizedBox(height: AppSizes.s12),
          TextField(controller: _patient, decoration: const InputDecoration(labelText: PosStrings.prescriptionPatient)),
          const SizedBox(height: AppSizes.s12),
          TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: PosStrings.prescriptionPatientAge)),
          const SizedBox(height: AppSizes.s12),
          TextField(controller: _clinic, decoration: const InputDecoration(labelText: PosStrings.prescriptionClinic)),
          const SizedBox(height: AppSizes.s16),
          FilledButton(onPressed: _canDraft ? _saveDraft : null, child: const Text(PosStrings.prescriptionUseDraft)),
        ],
      ),
    );
  }
}
