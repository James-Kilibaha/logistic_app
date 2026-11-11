import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import 'platform_api.dart';
import 'platform_models.dart';
import 'sa_common.dart';
import 'sa_coupons.dart';
import 'sa_online_payments.dart';

/// Risiti (PDF) ya malipo yaliyothibitishwa - inaweza kuhifadhiwa au kutumwa.
Future<void> openSubscriptionReceipt(String paymentId, {String? reference}) => openPdfFrom(
      () => PlatformApi.getBytes('subscriptions/payments/$paymentId/receipt'),
      title: 'subReceipt'.tr,
      fileName: 'risiti_${reference ?? paymentId.substring(0, 8)}',
    );

/// Kuthibitisha au kukataa malipo yaliyotumwa na kampuni. Inarudisha `true` ikifanikiwa.
Future<bool> reviewPayment(String paymentId, {required bool confirm}) async {
  final note = TextEditingController();
  final ok = await showFormSheet(
    title: confirm ? 'saConfirmPayment'.tr : 'saRejectPayment'.tr,
    subtitle: confirm ? 'saConfirmPaymentMsg'.tr : 'saRejectPaymentMsg'.tr,
    icon: confirm ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
    danger: !confirm,
    submitLabel: confirm ? 'saConfirm'.tr : 'saReject'.tr,
    builder: (context, setState) => AppField(
      controller: note,
      label: confirm ? 'note'.tr : 'saReason'.tr,
      maxLines: 3,
      minLines: 2,
    ),
    onSubmit: () => PlatformApi.put('subscriptions/payments/$paymentId/${confirm ? 'confirm' : 'reject'}',
        {if (note.text.trim().isNotEmpty) 'note': note.text.trim()}),
  );
  if (ok) Toast.success(confirm ? 'saPaymentConfirmed'.tr : 'saPaymentRejected'.tr);
  return ok;
}

/// Malipo ya kampuni zote (kawaida: yanayosubiri uthibitisho).
class SaPayments extends StatefulWidget {
  /// Kichupo cha kuanzia (PENDING, ONLINE, COUPONS ...); null = PENDING.
  final String? initialStatus;

  const SaPayments({super.key, this.initialStatus});

  @override
  State<SaPayments> createState() => _SaPaymentsState();
}

class _SaPaymentsState extends State<SaPayments> {
  late String? _status = widget.initialStatus ?? 'PENDING';
  int _version = 0;

  Future<List<PlatformPayment>> _load() async {
    final body = await PlatformApi.get('subscriptions/payments', query: {'status': _status});
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => PlatformPayment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  void _reload() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (String? value, String label) in [
                ('PENDING', 'subPending'.tr),
                ('CONFIRMED', 'subConfirmed'.tr),
                ('REJECTED', 'subRejected'.tr),
                (null, 'saAll'.tr),
                ('ONLINE', 'saOnlinePayments'.tr),
                ('COUPONS', 'saCoupons'.tr),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _status == value,
                  onSelected: (_) {
                    _status = value;
                    _reload();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: _status == 'ONLINE'
              ? const SaOnlinePayments()
              : _status == 'COUPONS'
                  ? const SaCoupons()
                  : SaLoader<List<PlatformPayment>>(
            key: ValueKey('$_status$_version'),
            load: _load,
            builder: (context, items, reload) => PageScroll(
              onRefresh: reload,
              children: [
                SaHeader(title: 'subPayments'.tr, subtitle: 'saPaymentsSub'.tr),
                if (items.isEmpty)
                  EmptyState(icon: Icons.payments_outlined, title: 'subNoPayments'.tr)
                else
                  Card(
                    child: Column(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.border),
                          _PaymentTile(item: items[i], onChanged: _reload),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PlatformPayment item;
  final VoidCallback onChanged;

  const _PaymentTile({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pay = item.payment;
    final (Color color, String label) = switch (pay.status) {
      'CONFIRMED' => (p.success, 'subConfirmed'.tr),
      'REJECTED' => (p.danger, 'subRejected'.tr),
      _ => (p.warning, 'subPending'.tr),
    };
    return ListTile(
      title: Text('${item.companyName} (${item.companySlug})', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        '${money(pay.currency, pay.amount)} · ${pay.planName} x${pay.periods}',
        Fmt.dateTime(pay.createdAt),
        if (pay.method != null) pay.method!,
        if (pay.reference != null) '${'transactionRef'.tr}: ${pay.reference}',
        if (pay.note != null) pay.note!,
        if (item.startMode == 'NOW') '⚠ ${'saStartNow'.tr}',
      ].join('\n')),
      isThreeLine: true,
      trailing: pay.status == 'PENDING'
          ? Wrap(
              spacing: 6,
              children: [
                FilledButton(
                  onPressed: () async {
                    if (await reviewPayment(pay.id, confirm: true)) onChanged();
                  },
                  child: Text('saConfirm'.tr),
                ),
                OutlinedButton(
                  onPressed: () async {
                    if (await reviewPayment(pay.id, confirm: false)) onChanged();
                  },
                  child: Text('saReject'.tr),
                ),
              ],
            )
          : pay.status == 'CONFIRMED'
              ? Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(label, color: color, dense: true),
                    IconButton(
                      tooltip: 'subReceipt'.tr,
                      icon: const Icon(Icons.receipt_rounded),
                      onPressed: () => openSubscriptionReceipt(pay.id, reference: pay.reference),
                    ),
                  ],
                )
              : Pill(label, color: color, dense: true),
    );
  }
}
