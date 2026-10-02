import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../products_providers.dart';
import 'movement_tile.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key, this.productId, this.productName});

  final int? productId;
  final String? productName;

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  String? _type;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = (productId: widget.productId, type: _type, search: _search);

    return Scaffold(
      appBar: AppBar(title: Text(widget.productName == null ? 'Kartu stok' : 'Kartu stok · ${widget.productName}')),
      body: Column(
        children: [
          if (widget.productId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SearchField(hint: 'Cari produk', onChanged: (term) => setState(() => _search = term)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: 'Jenis',
                  icon: LucideIcons.arrowLeftRight,
                  value: _type,
                  items: [
                    (null, 'Semua Jenis Mutasi'),
                    for (final entry in stockMovementTypes.entries) (entry.key, entry.value),
                  ],
                  onChanged: (type) => setState(() => _type = type),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PagedListView(
              value: ref.watch(movementsProvider(query)),
              onLoadMore: () => ref.read(movementsProvider(query).notifier).loadMore(),
              onRefresh: () => ref.refresh(movementsProvider(query).future),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
              empty: const EmptyState(icon: LucideIcons.history, title: 'Belum ada mutasi stok'),
              itemBuilder: (context, movement) => MovementTile(movement: movement, showProduct: widget.productId == null),
            ),
          ),
        ],
      ),
    );
  }
}
