import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../notifications.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchGroup> _results = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String term) async {
    final request = ++_request;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await ref.read(notificationsRepositoryProvider).search(term);
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari pelanggan, transaksi, produk…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: _error != null
          ? EmptyState(icon: LucideIcons.circleAlert, title: 'Pencarian gagal', description: _error)
          : _results.isEmpty
              ? EmptyState(
                  icon: LucideIcons.search,
                  title: _controller.text.trim().length < 2 ? 'Ketik minimal 2 huruf' : 'Tidak ada hasil',
                )
              : ListView(
                  children: [
                    for (final group in _results) ...[
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SectionTitle(group.group)),
                      for (final item in group.items)
                        ListTile(
                          enabled: item.target != null,
                          onTap: () => openTarget(context, item.target),
                          title: Text(item.label),
                          subtitle: Text([?item.sub, ...item.flags].join(' · '), style: TextStyle(color: muted)),
                          trailing: item.target == null ? null : const Icon(LucideIcons.chevronRight, size: 18),
                        ),
                    ],
                  ],
                ),
    );
  }
}
