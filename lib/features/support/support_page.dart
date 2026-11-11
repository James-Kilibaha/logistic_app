import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../../data/repositories.dart';
import 'ticket_thread.dart';

/// Msaada: kampuni inamtumia mtoa huduma tatizo/swali na kuona majibu.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  static Future<void> open() async {
    await Get.to(() => const SupportPage());
  }

  /// Kufungua tiketi moja (mf. kutoka kwenye taarifa).
  static Future<void> openTicket(String id) async {
    await Get.to(() => TicketThread(
          title: 'tkTitle'.tr,
          mine: 'COMPANY',
          load: () => SupportRepo.ticket(id),
          reply: (text) => SupportRepo.reply(id, text),
          actions: (t, reload) => [
            if (J.str(t['status']) != 'CLOSED')
              TextButton.icon(
                onPressed: () async {
                  if (await runGuarded(() => SupportRepo.close(id), success: 'tkClosed'.tr)) await reload();
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text('tkClose'.tr),
              ),
          ],
        ));
  }

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await SupportRepo.mine();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _new() async {
    final subject = TextEditingController();
    final text = TextEditingController();
    String category = 'TECH';
    bool high = false;
    Map<String, dynamic>? created;
    final ok = await showFormSheet(
      title: 'tkNew'.tr,
      subtitle: 'tkNewSub'.tr,
      icon: Icons.support_agent_rounded,
      submitLabel: 'waSend'.tr,
      builder: (context, setState) => Column(
        children: [
          AppDropdown<String>(
            label: 'tkCategory'.tr,
            value: category,
            items: const ['TECH', 'BILLING', 'FEATURE', 'OTHER'],
            itemLabel: (c) => 'tkCat_$c'.tr,
            onChanged: (v) => setState(() => category = v ?? category),
          ),
          const SizedBox(height: 14),
          AppField(controller: subject, label: 'tkSubject'.tr, required: true, validator: Validators.minLength(3)),
          const SizedBox(height: 14),
          AppField(
            controller: text,
            label: 'tkMessage'.tr,
            hint: 'tkMessageHint'.tr,
            maxLines: 8,
            minLines: 4,
            required: true,
            validator: Validators.minLength(3),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('tkHigh'.tr),
            subtitle: Text('tkHighHelp'.tr),
            value: high,
            onChanged: (v) => setState(() => high = v),
          ),
        ],
      ),
      onSubmit: () async => created = await SupportRepo.create(
          subject: subject.text.trim(), text: text.text.trim(), category: category, high: high),
    );
    if (!ok) return;
    Toast.success('tkSentMsg'.tr, title: 'tkSent'.tr);
    await _load();
    if (created != null) await SupportPage.openTicket(J.str(created!['id']));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AppPage(
      title: 'tkTitle'.tr,
      subtitle: 'tkSub'.tr,
      showBack: true,
      mainAction: PageAction(icon: Icons.add_comment_outlined, label: 'tkNew'.tr, onPressed: _new),
      body: items == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const LoadingList(rows: 4))
          : PageScroll(
              onRefresh: _load,
              children: [
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.support_agent_rounded,
                    title: 'tkNoneCompany'.tr,
                    message: 'tkNoneCompanyMsg'.tr,
                    action: FilledButton.icon(
                      onPressed: _new,
                      icon: const Icon(Icons.add_comment_outlined, size: 18),
                      label: Text('tkNew'.tr),
                    ),
                  )
                else
                  SectionCard(
                    child: Column(children: [
                      for (final t in items)
                        ticketTile(context, t, unread: J.boolean(t['unreadCompany']), onTap: () async {
                          await SupportPage.openTicket(J.str(t['id']));
                          await _load();
                        }),
                    ]),
                  ),
                Text('tkContactNote'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
              ],
            ),
    );
  }
}
