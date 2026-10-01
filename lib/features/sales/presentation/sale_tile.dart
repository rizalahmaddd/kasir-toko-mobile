import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sale_models.dart';

class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.sale});

  final SaleSummary sale;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: () => context.push('/sale/${sale.id}'),
      title: Row(
        children: [
          Flexible(child: Text(sale.number, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          if (sale.isVoided)
            const StatusBadge(label: 'Dibatalkan', tone: BadgeTone.danger)
          else if (sale.dueAmount > 0)
            const StatusBadge(label: 'Kasbon', tone: BadgeTone.warning),
        ],
      ),
      subtitle: Text(
        '${timeOnly(sale.soldAt)} · ${sale.itemsCount} barang${sale.customer == null ? '' : ' · ${sale.customer!.name}'}',
        style: TextStyle(color: muted),
      ),
      trailing: Text(
        rupiah(sale.total),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: sale.isVoided ? TextDecoration.lineThrough : null,
          color: sale.isVoided ? muted : null,
        ),
      ),
    );
  }
}
