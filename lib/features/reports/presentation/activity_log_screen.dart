import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Log aktivitas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Cari aktivitas', onChanged: (term) => notifier.set((search: term, logName: query.logName))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: 'Kategori Log',
                  icon: LucideIcons.listFilter,
                  value: query.logName,
                  items: [
                    (null, 'Semua Aktivitas'),
                    for (final e in _logNames.entries) (e.key, e.value),
                  ],
                  onChanged: (logName) => notifier.set((search: query.search, logName: logName)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PagedListView(
              value: ref.watch(activityProvider),
              onLoadMore: () => ref.read(activityProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(activityProvider.future),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
              empty: const EmptyState(icon: LucideIcons.scrollText, title: 'Belum ada aktivitas'),
              itemBuilder: (context, activity) => _ActivityCard(
                activity: activity,
                onTap: () => FormSheet.show<void>(context, _ActivitySheet(activity: activity)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final color = switch (activity.logName) {
      'auth' => const Color(0xFF3B82F6),
      'roles' => const Color(0xFF8B5CF6),
      'audit' => const Color(0xFF10B981),
      'export' => const Color(0xFFF59E0B),
      _ => const Color(0xFF64748B),
    };

    final icon = _icons[activity.logName] ?? LucideIcons.filePen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (activity.event != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                activity.event!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              dateTime(activity.createdAt),
                              style: TextStyle(fontSize: 11.5, color: muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      if (activity.causer != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(LucideIcons.user, size: 11, color: muted),
                            const SizedBox(width: 4),
                            Text(
                              activity.causer!,
                              style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
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
