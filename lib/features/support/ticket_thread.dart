import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';

/// Rangi ya hali ya tiketi.
Color ticketColor(BuildContext context, String status) {
  final p = context.palette;
  return switch (status) {
    'OPEN' => p.warning,
    'ANSWERED' => p.info,
    'CLOSED' => p.muted,
    _ => p.muted,
  };
}

/// Mazungumzo ya tiketi moja (yanatumika na kampuni na super admin).
/// [mine] = mwandishi wa upande huu ("COMPANY" au "ADMIN") - ujumbe wake upande wa kulia.
class TicketThread extends StatefulWidget {
  final String title;
  final String mine;
  final Future<Map<String, dynamic>> Function() load;
  final Future<Map<String, dynamic>> Function(String text) reply;
  final List<Widget> Function(Map<String, dynamic> ticket, Future<void> Function() reload)? actions;
  final bool canReply;

  const TicketThread({
    super.key,
    required this.title,
    required this.mine,
    required this.load,
    required this.reply,
    this.actions,
    this.canReply = true,
  });

  @override
  State<TicketThread> createState() => _TicketThreadState();
}

class _TicketThreadState extends State<TicketThread> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _t;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final t = await widget.load();
      if (!mounted) return;
      setState(() {
        _t = t;
        _error = null;
      });
      _bottom();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await runGuarded(() async {
      final t = await widget.reply(text);
      if (mounted) setState(() => _t = t);
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _text.clear();
      _bottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = _t;
    final messages = (t?['messages'] is List ? t!['messages'] as List : const []).whereType<Map>().toList();
    final status = J.str(t?['status']);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(t == null ? widget.title : '${J.str(t['number'])} · ${J.str(t['subject'])}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (t != null) ...(widget.actions?.call(t, _reload) ?? const []),
          IconButton(tooltip: 'refresh'.tr, onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: t == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _reload) : const LoadingList(rows: 4))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: p.surface,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill('tkStatus_$status'.tr, color: ticketColor(context, status), dense: true),
                      Pill('tkCat_${J.str(t['category'])}'.tr, color: p.primary, dense: true),
                      if (J.str(t['priority']) == 'HIGH') Pill('tkHigh'.tr, color: p.danger, dense: true),
                      if (J.strOrNull(t['companyName']) != null)
                        Text('${J.str(t['companyName'])} (${J.str(t['companySlug'])})', style: TextStyle(color: p.muted)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = J.str(m['author']) == widget.mine;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            decoration: BoxDecoration(
                              color: mine ? p.primarySoft : p.surface,
                              border: Border.all(color: p.border),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(J.str(m['text']), style: TextStyle(color: p.text, height: 1.4)),
                                const SizedBox(height: 4),
                                Text(
                                  '${J.str(m['author']) == 'ADMIN' ? 'tkSupportTeam'.tr : J.str(m['username'])} · '
                                  '${Fmt.dateTime(J.date(m['at']))}',
                                  style: TextStyle(color: p.muted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.canReply)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 6,
                              maxLength: 5000,
                              enabled: !_sending,
                              decoration: InputDecoration(
                                hintText: status == 'CLOSED' ? 'tkReopenHint'.tr : 'tkReplyHint'.tr,
                                counterText: '',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'waSend'.tr,
                            onPressed: _sending ? null : _send,
                            icon: _sending ? const ButtonSpinner() : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Safu ya tiketi kwenye orodha.
Widget ticketTile(BuildContext context, Map<String, dynamic> t, {required VoidCallback onTap, bool unread = false,
    bool showCompany = false}) {
  final p = context.palette;
  final status = J.str(t['status']);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    leading: Icon(unread ? Icons.mark_chat_unread_rounded : Icons.support_agent_rounded,
        color: unread ? p.primary : ticketColor(context, status)),
    title: Text('${J.str(t['number'])} · ${J.str(t['subject'])}',
        style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
    subtitle: Text([
      if (showCompany && J.strOrNull(t['companyName']) != null) J.str(t['companyName']),
      'tkCat_${J.str(t['category'])}'.tr,
      if (J.strOrNull(t['username']) != null) J.str(t['username']),
      Fmt.relative(J.date(t['lastMessageAt'])),
    ].join(' · ')),
    trailing: Pill('tkStatus_$status'.tr, color: ticketColor(context, status), dense: true),
  );
}
