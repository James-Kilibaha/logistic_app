import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// Kadi ya juu ya ukurasa wa SMS: salio la SMS (FastHub au makadirio), matumizi ya mwezi na hali ya kufika.
class SmsBalanceCard extends StatefulWidget {
  const SmsBalanceCard({super.key});

  @override
  State<SmsBalanceCard> createState() => _SmsBalanceCardState();
}

class _SmsBalanceCardState extends State<SmsBalanceCard> {
  Map<String, dynamic>? _balance;
  Map<String, dynamic>? _delivery;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([SmsRepo.balance(), SmsRepo.deliverySummary()]);
      if (!mounted) return;
      setState(() {
        _balance = results[0];
        _delivery = results[1];
      });
    } catch (_) {
      // kadi ni ya ziada; ikishindikana ukurasa unaendelea
    }
  }

  Future<void> _record(String kind) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showFormSheet(
      help: 'smsBalance',
      title: kind == 'SET' ? 'smsSetBalance'.tr : 'smsAddCredit'.tr,
      subtitle: kind == 'SET' ? 'smsSetBalanceSub'.tr : 'smsAddCreditSub'.tr,
      icon: Icons.account_balance_wallet_outlined,
      builder: (context, setState) => Column(
        children: [
          AppField.money(controller: amount, label: 'smsCount'.tr, required: true),
          const SizedBox(height: 14),
          AppField(controller: note, label: 'note'.tr, icon: Icons.notes_rounded),
        ],
      ),
      onSubmit: () async {
        final n = Fmt.parse(amount.text)?.round() ?? -1;
        final b = await SmsRepo.recordBalance(kind: kind, amount: n, note: note.text);
        if (mounted) setState(() => _balance = b);
      },
    );
    if (ok) Toast.success('saved'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final b = _balance;
    if (b == null) return const SizedBox.shrink();
    final p = context.palette;
    final balance = b['balance'] == null ? null : J.dbl(b['balance']);
    final low = b['low'] == true;
    final canRecord = AppController.to.can(AppModule.setting, AppAction.update);
    final sms = J.map(J.map(_delivery?['byChannel'])?['SMS']) ?? const <String, dynamic>{};
    final delivered = J.integer(sms['DELIVERED']);
    final failed = J.integer(sms['FAILED']);
    final color = balance == null ? p.muted : (low ? p.danger : p.success);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(low ? Icons.warning_amber_rounded : Icons.sms_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                balance == null ? 'smsBalanceUnknown'.tr : 'smsBalanceN'.trParams({'n': Fmt.number(balance)}),
                style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
              ),
              if (b['source'] == 'ESTIMATE') ...[
                const SizedBox(width: 6),
                Text('(${'estimated'.tr})', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ]),
            if (b['source'] == 'GATEWAY' && J.date(b['gatewaySeenAt']) != null)
              Text('smsBalanceSeen'.trParams({'when': Fmt.relative(J.date(b['gatewaySeenAt']))}),
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
            Text('smsUsedMonth'.trParams({'n': Fmt.number(J.dbl(b['usedThisMonth']))}),
                style: TextStyle(color: p.muted, fontSize: 13)),
            if (delivered + failed > 0)
              Text('smsDeliveryN'.trParams({'ok': Fmt.number(delivered), 'bad': Fmt.number(failed)}),
                  style: TextStyle(color: failed > 0 ? p.warning : p.muted, fontSize: 13)),
            if (low) Text('smsLowHint'.tr, style: TextStyle(color: p.danger, fontSize: 13)),
            if (canRecord)
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  onPressed: () => _record('ADD'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('smsAddCredit'.tr),
                ),
                TextButton(onPressed: () => _record('SET'), child: Text('smsSetBalance'.tr)),
              ]),
          ],
        ),
      ),
    );
  }
}
