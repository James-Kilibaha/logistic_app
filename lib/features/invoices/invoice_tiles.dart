import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/invoice.dart';
import 'invoice_flows.dart';

/// Mstari mmoja wa invoice (kwenye kadi au orodha fupi).
class InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  final bool showCustomer;

  const InvoiceRow({super.key, required this.invoice, this.showCustomer = true});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = StatusStyle.of(invoice.status);
    final title = showCustomer ? (invoice.customer?.name ?? invoice.number) : invoice.number;
    final parts = <String>[
      if (showCustomer) invoice.number,
      '${invoice.products.length} ${'items'.tr}',
      Fmt.kg(invoice.totalWeight),
      Fmt.relative(invoice.createdAt),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => InvoiceFlows.open(invoice.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: s.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(11)),
              child: Icon(s.icon, color: s.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(invoice.total), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 4),
                StatusChip(invoice.status, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kadi ya invoice kwenye orodha ya simu.
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const InvoiceCard({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final debt = invoice.debt;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Initials(invoice.customer?.initials ?? '?', size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customer?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    Text('${invoice.number} · ${Fmt.relative(invoice.createdAt)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusChip(invoice.status, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                _metric(context, Icons.inventory_2_outlined, '${invoice.products.length}'),
                _metric(context, Icons.scale_outlined, Fmt.kg(invoice.totalWeight)),
                const Spacer(),
                Text(Fmt.tsh(invoice.total), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
              ],
            ),
          ),
          if (debt != null && !debt.isPaid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 16, color: p.danger),
                const SizedBox(width: 6),
                Text('${'balanceDue'.tr}: ${Fmt.tsh(debt.balance)}', style: TextStyle(color: p.danger, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, IconData icon, String text) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.muted),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: p.text, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
