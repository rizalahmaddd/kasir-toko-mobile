import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/prescription_models.dart';
import '../pharmacy_providers.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(prescriptionsQueryProvider);
    final notifier = ref.read(prescriptionsQueryProvider.notifier);
    final canManage = ref.watch(currentUserProvider)?.canManagePrescriptions ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(PharmacyStrings.screenTitle),
        hint: PharmacyStrings.searchHint,
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, status: query.status)),
      ),
      floatingActionButton: canManage
          ? AppFloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.prescriptionNew),
              icon: const Icon(AppIcons.plus),
              label: const Text(PharmacyStrings.newTitle),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: PharmacyStrings.statusFilterLabel,
                  icon: AppIcons.fileHeart,
                  value: query.status,
                  items: const [
                    ('open', PharmacyStrings.statusOpen),
                    ('unverified', PharmacyStrings.statusUnverified),
                    ('dispensed', PharmacyStrings.statusDispensed),
                    ('cancelled', PharmacyStrings.statusCancelled),
                    ('all', PharmacyStrings.statusAll),
                  ],
                  onChanged: (value) => notifier.set((search: query.search, status: value ?? 'open')),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<Prescription>(
              value: ref.watch(prescriptionsProvider),
              onLoadMore: () => ref.read(prescriptionsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(prescriptionsProvider.future),
              padding: const EdgeInsets.only(bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.fileHeart, title: PharmacyStrings.empty, description: PharmacyStrings.emptyHint),
              itemBuilder: (context, prescription) => ListTile(
                onTap: () => context.push(AppRoutes.prescriptionDetail(prescription.id)),
                leading: const Icon(AppIcons.fileHeart),
                title: Text('${prescription.number} · ${prescription.patientName}'),
                subtitle: Text('dr. ${prescription.doctorName} · ${dateOnly(prescription.date)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: prescription.isOpen
                    ? StatusBadge(
                        label: prescription.isVerified ? PharmacyStrings.verified : PharmacyStrings.waiting,
                        tone: prescription.isVerified ? BadgeTone.success : BadgeTone.warning,
                      )
                    : StatusBadge(label: prescription.statusLabel.toUpperCase(), tone: prescription.status == 'cancelled' ? BadgeTone.muted : BadgeTone.info),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
