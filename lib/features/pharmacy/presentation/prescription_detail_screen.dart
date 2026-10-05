import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/prescription_models.dart';
import '../data/prescriptions_repository.dart';
import '../pharmacy_providers.dart';

class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  final int prescriptionId;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<Prescription> Function() action, String done) async {
    try {
      await action();
      ref
        ..invalidate(prescriptionProvider(prescriptionId))
        ..invalidate(prescriptionsProvider);
      if (context.mounted) {
        showMessage(context, done);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(PharmacyStrings.cancelButton),
        content: const Text(PharmacyStrings.cancelConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(PharmacyStrings.back)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(PharmacyStrings.cancelButton)),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _run(context, ref, () => ref.read(prescriptionsRepositoryProvider).cancel(prescriptionId), PharmacyStrings.cancelled);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final value = ref.watch(prescriptionProvider(prescriptionId));

    return Scaffold(
      appBar: AppBar(title: Text(value.value?.number ?? PharmacyStrings.screenTitle)),
      body: AsyncView<Prescription>(
        value: value,
        onRetry: () => ref.invalidate(prescriptionProvider(prescriptionId)),
        data: (prescription) => MaxWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Wrap(
                spacing: AppSpacing.s8,
                children: [
                  StatusBadge(label: prescription.statusLabel.toUpperCase(), tone: prescription.isOpen ? BadgeTone.info : BadgeTone.muted),
                  if (prescription.isOpen)
                    StatusBadge(
                      label: prescription.isVerified ? PharmacyStrings.verified : PharmacyStrings.waiting,
                      tone: prescription.isVerified ? BadgeTone.success : BadgeTone.warning,
                    ),
                ],
              ),
              const SectionTitle(PharmacyStrings.patient),
              InfoRow(PharmacyStrings.patient, prescription.patientAge == null ? prescription.patientName : '${prescription.patientName}, ${PharmacyStrings.age(prescription.patientAge!)}'),
              if (prescription.patientPhone != null) InfoRow('HP', prescription.patientPhone!),
              const SectionTitle(PharmacyStrings.doctor),
              InfoRow(PharmacyStrings.doctor, 'dr. ${prescription.doctorName}'),
              if (prescription.clinicName != null) InfoRow(PosStrings.prescriptionClinic, prescription.clinicName!),
              InfoRow(PharmacyStrings.date, dateOnly(prescription.date)),
              const SectionTitle(PharmacyStrings.drugs),
              for (final item in prescription.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text([
                    PharmacyStrings.dispensed(quantity(item.dispensed), quantity(item.prescribed)),
                    if (item.dosage != null) item.dosage!,
                  ].join(' · ')),
                  trailing: Text(PharmacyStrings.remaining(quantity(item.remaining), item.unit ?? ''), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              if (prescription.imageUrl != null) ...[
                const SectionTitle(PharmacyStrings.photo),
                _PrescriptionPhoto(prescriptionId: prescription.id),
              ],
              const SizedBox(height: AppSizes.s24),
              if (prescription.isOpen && !prescription.isVerified && (user?.canVerifyPrescriptions ?? false))
                FilledButton.icon(
                  onPressed: () => _run(context, ref, () => ref.read(prescriptionsRepositoryProvider).verify(prescriptionId), PharmacyStrings.verifiedDone),
                  icon: const Icon(AppIcons.badgeCheck),
                  label: const Text(PharmacyStrings.verifyButton),
                ),
              if (prescription.isPending && (user?.canManagePrescriptions ?? false)) ...[
                const SizedBox(height: AppSizes.s8),
                OutlinedButton.icon(onPressed: () => _cancel(context, ref), icon: const Icon(AppIcons.ban), label: const Text(PharmacyStrings.cancelButton)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto diambil lewat API berotorisasi, bukan URL publik.
class _PrescriptionPhoto extends ConsumerWidget {
  const _PrescriptionPhoto({required this.prescriptionId});

  final int prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<List<int>>(
      value: ref.watch(prescriptionImageProvider(prescriptionId)),
      data: (bytes) => ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.s12),
        child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
      ),
    );
  }
}
