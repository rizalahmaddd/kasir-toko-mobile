import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../reports.dart';

const _logNames = {'audit': 'Perubahan data', 'auth': 'Login', 'settings': 'Pengaturan', 'roles': 'Peran', 'export': 'Ekspor'};

const _icons = {
  'auth': LucideIcons.logIn,
  'settings': LucideIcons.settings,
  'roles': LucideIcons.shieldCheck,
  'export': LucideIcons.download,
};

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(activityQueryProvider);
    final notifier = ref.read(activityQueryProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Log aktivitas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Cari aktivitas', onChanged: (term) => notifier.set((search: term, logName: query.logName))),
          ),
          ChoiceChips<String>(
            options: [(null, 'Semua'), for (final e in _logNames.entries) (e.key, e.value)],
            selected: query.logName,
            onSelected: (logName) => notifier.set((search: query.search, logName: logName)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedListView(
              value: ref.watch(activityProvider),
              onLoadMore: () => ref.read(activityProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(activityProvider.future),
              empty: const EmptyState(icon: LucideIcons.scrollText, title: 'Belum ada aktivitas'),
              itemBuilder: (context, activity) => ListTile(
                onTap: () => FormSheet.show<void>(context, _ActivitySheet(activity: activity)),
                leading: Icon(_icons[activity.logName] ?? LucideIcons.filePen, size: 20, color: muted),
                title: Text(activity.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [?activity.causer, dateTime(activity.createdAt), ?activity.event].join(' · '),
                  style: TextStyle(color: muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({required this.activity});

  final Activity activity;

  String _format(dynamic value) => value == null ? '–' : (value is Map || value is List ? value.toString() : '$value');

  @override
  Widget build(BuildContext context) {
    final after = asMap(activity.changes['attributes']);
    final before = asMap(activity.changes['old']);
    final keys = {...after.keys, ...before.keys}.toList();

    return FormSheet(
      title: activity.event ?? 'Aktivitas',
      subtitle: activity.description,
      children: [
        InfoRow('Waktu', dateTime(activity.createdAt)),
        InfoRow('Oleh', activity.causer ?? 'Sistem'),
        if (activity.subject != null) InfoRow('Data', activity.subject!),
        if (activity.ipAddress != null) InfoRow('Alamat IP', activity.ipAddress!),
        if (activity.reason != null) InfoRow('Alasan', activity.reason!),
        if (keys.isNotEmpty) ...[
          const SectionTitle('Perubahan'),
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(before.containsKey(key) ? '${_format(before[key])} → ${_format(after[key])}' : _format(after[key])),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
