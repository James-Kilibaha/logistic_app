import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../support/ticket_thread.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Tiketi za msaada kutoka kampuni zote (mpya na ambazo hazijasomwa kwanza).
class SaSupport extends StatefulWidget {
  const SaSupport({super.key});

  @override
  State<SaSupport> createState() => _SaSupportState();
}

class _SaSupportState extends State<SaSupport> {
  String? _status = 'OPEN';
  int _version = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final body = await PlatformApi.get('tickets', query: {if (_status != null) 'status': _status});
    return body is List ? body.whereType<Map>().map(Map<String, dynamic>.from).toList() : [];
  }

  Future<void> _open(Map<String, dynamic> t) async {
    await openPlatformTicket(J.str(t['id']), title: J.str(t['subject']));
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (String? value, String label) in [
                ('OPEN', 'tkStatus_OPEN'.tr),
                ('ANSWERED', 'tkStatus_ANSWERED'.tr),
                ('CLOSED', 'tkStatus_CLOSED'.tr),
                (null, 'saAll'.tr),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _status == value,
                  onSelected: (_) => setState(() {
                    _status = value;
                    _version++;
                  }),
                ),
            ],
          ),
        ),
        Expanded(
          child: SaLoader<List<Map<String, dynamic>>>(
            key: ValueKey('$_status$_version'),
            load: _load,
            builder: (context, items, reload) => PageScroll(
              onRefresh: reload,
              children: [
                SaHeader(title: 'tkTitle'.tr, subtitle: 'saSupportSub'.tr),
                if (items.isEmpty)
                  EmptyState(icon: Icons.support_agent_rounded, title: 'tkNone'.tr)
                else
                  SectionCard(
                    child: Column(children: [
                      for (final t in items)
                        ticketTile(context, t,
                            onTap: () => _open(t), unread: J.boolean(t['unreadAdmin']), showCompany: true),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inafungua mazungumzo ya tiketi moja (pia kutoka kwenye taarifa 🔔).
Future<void> openPlatformTicket(String id, {String? title}) async => await Get.to<void>(() => TicketThread(
          title: title ?? 'tkTitle'.tr,
          mine: 'ADMIN',
          load: () async => Map<String, dynamic>.from((await PlatformApi.get('tickets/$id')) as Map),
          reply: (text) async =>
              Map<String, dynamic>.from((await PlatformApi.post('tickets/$id/reply', {'text': text})) as Map),
          actions: (ticket, reload) => [
            if (J.str(ticket['status']) != 'CLOSED')
              TextButton.icon(
                onPressed: () async {
                  if (await runGuarded(() => PlatformApi.put('tickets/$id/status', {'status': 'CLOSED'}),
                      success: 'tkClosed'.tr)) {
                    await reload();
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text('tkClose'.tr),
              ),
          ],
        ));
