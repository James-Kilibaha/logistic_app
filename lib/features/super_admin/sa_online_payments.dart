import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Malipo ya simu (AzamPay): akaunti yako (subscription) na malipo yote ya kampuni.
class SaOnlinePayments extends StatefulWidget {
  const SaOnlinePayments({super.key});

  @override
  State<SaOnlinePayments> createState() => _SaOnlinePaymentsState();
}

class _SaOnlinePaymentsState extends State<SaOnlinePayments> {
  String? _purpose = 'SUBSCRIPTION';
  int _version = 0;

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _load() async {
    final cfg = await PlatformApi.get('online-payments/config');
    final list = await PlatformApi.get('online-payments', query: {if (_purpose != null) 'purpose': _purpose});
    return (
      cfg is Map ? Map<String, dynamic>.from(cfg) : <String, dynamic>{},
      list is List ? list.whereType<Map>().map(Map<String, dynamic>.from).toList() : <Map<String, dynamic>>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SaLoader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      key: ValueKey('$_purpose$_version'),
      load: _load,
      builder: (context, data, reload) {
        final (cfg, items) = data;
        final enabled = J.boolean(cfg['enabled']);
        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(title: 'saOnlinePayments'.tr, subtitle: 'saOnlinePaymentsSub'.tr),
            SectionCard(
              title: 'saAzamAccount'.tr,
              icon: Icons.phone_iphone_rounded,
              trailing: Pill(enabled ? 'waOn'.tr : 'waOff'.tr, color: enabled ? p.success : p.warning, dense: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!enabled) Text('saAzamNotSet'.tr, style: TextStyle(color: p.text, height: 1.45)),
                  if (enabled) ...[
                    InfoRow(label: 'saAzamEnv'.tr, value: J.str(cfg['env']).toUpperCase()),
                    InfoRow(label: 'App', value: J.str(cfg['appName'])),
                  ],
                  const SizedBox(height: 8),
                  Text('payCallbackUrl'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  Row(
                    children: [
                      Expanded(child: SelectableText(J.str(cfg['callbackUrl']), style: const TextStyle(fontSize: 12.5))),
                      IconButton(
                        tooltip: 'copy'.tr,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: J.str(cfg['callbackUrl'])));
                          Toast.success('copied'.tr);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                  Text('payCallbackSecret'.tr, style: TextStyle(color: p.warning, fontSize: 12)),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final (String? value, String label) in [
                  ('SUBSCRIPTION', 'saOnlineSubs'.tr),
                  ('INVOICE', 'saOnlineInvoices'.tr),
                  (null, 'saAll'.tr),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _purpose == value,
                    onSelected: (_) => setState(() {
                      _purpose = value;
                      _version++;
                    }),
                  ),
              ],
            ),
            if (items.isEmpty)
              EmptyState(icon: Icons.phone_iphone_rounded, title: 'payNone'.tr)
            else
              SectionCard(
                child: Column(children: [for (final r in items) onlinePaymentTile(context, r, showCompany: true)]),
              ),
          ],
        );
      },
    );
  }
}

/// Safu moja ya malipo ya simu (inatumika pia upande wa kampuni).
Widget onlinePaymentTile(BuildContext context, Map<String, dynamic> r, {bool showCompany = false}) {
  final p = context.palette;
  final status = J.str(r['status']);
  final color = switch (status) {
    'SUCCESS' => p.success,
    'FAILED' => p.danger,
    'EXPIRED' => p.muted,
    _ => p.warning,
  };
  final what = J.str(r['purpose']) == 'SUBSCRIPTION'
      ? 'saOnlineSubOne'.trParams({'n': '${J.integer(r['periods'], 1)}'})
      : 'payForInvoice'.trParams({'n': J.str(r['invoiceNumber'], '-')});
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.phone_iphone_rounded, color: color),
    title: Text('${Fmt.tsh(J.dbl(r['amount']))} · ${J.str(r['provider'])} ${Fmt.phone(J.str(r['msisdn']))}'),
    subtitle: Text([
      if (showCompany && J.strOrNull(r['companyName']) != null) J.str(r['companyName']),
      what,
      Fmt.dateTime(J.date(r['createdAt'])),
      if (J.strOrNull(r['operatorRef']) != null) J.str(r['operatorRef']),
      if (status != 'SUCCESS' && J.strOrNull(r['message']) != null) J.str(r['message']),
    ].join(' · ')),
    trailing: Pill('payStatus_$status'.tr, color: color, dense: true),
  );
}
