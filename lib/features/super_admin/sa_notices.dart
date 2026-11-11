import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';

/// Taarifa za super admin (🔔): zinavutwa kila baada ya sekunde 45.
/// - Mara ya kwanza baada ya kuingia: popup ya mambo yanayosubiri hatua (malipo, kampuni mpya, tiketi ...).
/// - Taarifa mpya ya HARAKA ikiingia: popup papo hapo; ya kawaida: ujumbe mfupi chini.
class SaNotices extends ChangeNotifier {
  /// Inafungua kiungo cha taarifa (payments, payment:<id>, company:<id>, ticket:<id>, onlinepay, companies ...).
  final void Function(String link) onOpen;

  SaNotices({required this.onOpen});

  static const _every = Duration(seconds: 45);
  static bool _summaryShown = false; // mara moja kwa kila kuingia (inawekwa upya ukitoka)

  Timer? _timer;
  bool _loading = false;
  bool _dialogOpen = false;
  bool _disposed = false;
  Set<String>? _seen;

  int unread = 0;
  int urgentUnread = 0;
  int pendingTotal = 0;
  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> pending = const [];

  /// Idadi ya kuonyesha kwenye kengele: zisizosomwa, au yanayosubiri hatua (kubwa zaidi).
  int get badge => unread > pendingTotal ? unread : pendingTotal;

  static void resetSession() => _summaryShown = false;

  void start() {
    refresh();
    _timer = Timer.periodic(_every, (_) => refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    try {
      final body = await PlatformApi.get('notices');
      if (_disposed || body is! Map) return;
      final d = Map<String, dynamic>.from(body);
      List<Map<String, dynamic>> maps(dynamic v) =>
          v is List ? v.whereType<Map>().map(Map<String, dynamic>.from).toList() : <Map<String, dynamic>>[];
      unread = J.integer(d['unread']);
      urgentUnread = J.integer(d['urgentUnread']);
      pendingTotal = J.integer(d['pendingTotal']);
      items = maps(d['items']);
      pending = maps(d['pending']);
      notifyListeners();
      _alertNew();
    } catch (_) {
      // mtandao ukikatika: tunajaribu tena baadaye
    } finally {
      _loading = false;
    }
  }

  void _alertNew() {
    final ids = {for (final n in items) J.str(n['id'])};
    final first = _seen == null;
    final fresh = first
        ? const <Map<String, dynamic>>[]
        : items.where((n) => !_seen!.contains(J.str(n['id'])) && !J.boolean(n['isRead'])).toList();
    _seen = {...?_seen, ...ids};

    if (first) {
      if (!_summaryShown && pending.isNotEmpty) {
        _summaryShown = true;
        _showSummary();
      }
      return;
    }
    if (fresh.isEmpty) return;
    final urgent = fresh.where((n) => J.str(n['priority']) == 'URGENT').toList();
    if (urgent.isNotEmpty) {
      SystemSound.play(SystemSoundType.alert);
      _showUrgent(urgent);
    } else {
      _snack(fresh.first, more: fresh.length - 1);
    }
  }

  Future<void> markRead({List<String>? ids, bool all = false}) async {
    try {
      await PlatformApi.post('notices/read', {'ids': ids, 'all': all});
    } catch (_) {}
    await refresh();
  }

  Future<void> open(Map<String, dynamic> n) async {
    if (!J.boolean(n['isRead'])) unawaited(markRead(ids: [J.str(n['id'])]));
    final link = J.strOrNull(n['link']);
    if (link != null) onOpen(link);
  }

  // ---------------------------------------------------------------- popups

  BuildContext? get _ctx => Get.overlayContext ?? Get.context;

  Future<void> _showSummary() async {
    final ctx = _ctx;
    if (ctx == null || _dialogOpen) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.notifications_active_rounded, color: context.palette.warning, size: 34),
        title: Text('saNeedsAction'.tr),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('saNeedsActionSub'.tr, style: TextStyle(color: context.palette.muted)),
                const SizedBox(height: 10),
                for (final p in pending)
                  PendingTile(
                    item: p,
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpen(J.str(p['target']));
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('later'.tr))],
      ),
    );
    _dialogOpen = false;
  }

  Future<void> _showUrgent(List<Map<String, dynamic>> list) async {
    final ctx = _ctx;
    if (ctx == null) return;
    if (_dialogOpen) {
      _snack(list.first, more: list.length - 1);
      return;
    }
    _dialogOpen = true;
    await showDialog<void>(
      context: ctx,
      builder: (context) {
        final p = context.palette;
        return AlertDialog(
          icon: Icon(Icons.priority_high_rounded, color: p.danger, size: 34),
          title: Text(list.length == 1 ? 'saUrgentTitle'.tr : 'saUrgentNew'.trParams({'n': '${list.length}'})),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final n in list.take(5))
                    NoticeTile(
                      notice: n,
                      onTap: () {
                        Navigator.of(context).pop();
                        open(n);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('later'.tr)),
            if (list.length == 1)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  open(list.first);
                },
                child: Text('saOpenNow'.tr),
              ),
          ],
        );
      },
    );
    _dialogOpen = false;
  }

  void _snack(Map<String, dynamic> n, {int more = 0}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Text(more > 0 ? '${J.str(n['title'])}  (+$more)' : J.str(n['title'])),
      action: J.strOrNull(n['link']) == null ? null : SnackBarAction(label: 'saOpenNow'.tr, onPressed: () => open(n)),
    ));
  }
}

/// Kengele ya juu (AppBar) yenye idadi.
class SaBell extends StatelessWidget {
  final SaNotices notices;

  const SaBell({super.key, required this.notices});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notices,
      builder: (context, _) {
        final p = context.palette;
        final n = notices.badge;
        return IconButton(
          tooltip: 'notifications'.tr,
          onPressed: () => showNoticePanel(context, notices),
          icon: Badge(
            isLabelVisible: n > 0,
            backgroundColor: notices.urgentUnread > 0 || notices.pending.any((e) => J.boolean(e['urgent']))
                ? p.danger
                : p.primary,
            label: Text(n > 99 ? '99+' : '$n'),
            child: Icon(n > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }
}

/// Orodha ya taarifa: yanayosubiri hatua juu, kisha taarifa zote.
Future<void> showNoticePanel(BuildContext context, SaNotices notices) {
  unawaited(notices.refresh());
  final wide = context.screenWidth >= Breakpoints.medium;
  Widget panel(BuildContext context) => _NoticePanel(notices: notices, close: () => Navigator.of(context).pop());
  if (wide) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 60, right: 16),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: 420, height: 560, child: panel(context)),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * .85, child: panel(context)),
  );
}

class _NoticePanel extends StatelessWidget {
  final SaNotices notices;
  final VoidCallback close;

  const _NoticePanel({required this.notices, required this.close});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notices,
      builder: (context, _) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: p.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('notifications'.tr,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.text)),
                  ),
                  if (notices.unread > 0)
                    TextButton(onPressed: () => notices.markRead(all: true), child: Text('markAllRead'.tr)),
                  IconButton(tooltip: 'close'.tr, onPressed: close, icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  if (notices.pending.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                      child: Text('saNeedsAction'.tr,
                          style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                    for (final it in notices.pending)
                      PendingTile(
                        item: it,
                        onTap: () {
                          close();
                          notices.onOpen(J.str(it['target']));
                        },
                      ),
                    const Divider(),
                  ],
                  if (notices.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 40, color: p.muted),
                          const SizedBox(height: 8),
                          Text('noNotifications'.tr, style: TextStyle(color: p.muted)),
                        ],
                      ),
                    )
                  else
                    for (final n in notices.items)
                      NoticeTile(
                        notice: n,
                        onTap: () {
                          close();
                          notices.open(n);
                        },
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

(IconData, Color) _look(BuildContext context, String kind, String area) {
  final p = context.palette;
  return switch (kind) {
    'PAYMENT_SUBMITTED' => (Icons.payments_rounded, p.warning),
    'ONLINE_PAID' => (Icons.phone_iphone_rounded, p.success),
    'ONLINE_UNAPPLIED' => (Icons.report_gmailerrorred_rounded, p.danger),
    'SIGNUP' => (Icons.add_business_rounded, p.info),
    'TICKET' || 'TICKET_REPLY' => (Icons.support_agent_rounded, p.primary),
    'EXPIRING' => (Icons.hourglass_bottom_rounded, p.warning),
    'SYSTEM' => (Icons.dns_rounded, p.danger),
    _ => (area == 'PAYMENTS' ? Icons.payments_outlined : Icons.notifications_rounded, p.muted),
  };
}

/// Taarifa moja.
class NoticeTile extends StatelessWidget {
  final Map<String, dynamic> notice;
  final VoidCallback onTap;

  const NoticeTile({super.key, required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final n = notice;
    final read = J.boolean(n['isRead']);
    final urgent = J.str(n['priority']) == 'URGENT';
    final (icon, color) = _look(context, J.str(n['kind']), J.str(n['area']));
    return Material(
      color: read ? Colors.transparent : p.primarySoft.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(J.str(n['title']),
                        style: TextStyle(color: p.text, fontWeight: read ? FontWeight.w500 : FontWeight.w800)),
                    if (J.strOrNull(n['body']) != null) ...[
                      const SizedBox(height: 2),
                      Text(J.str(n['body']),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(Fmt.relative(J.date(n['created_at'])), style: TextStyle(color: p.muted, fontSize: 11.5)),
                        if (urgent) ...[
                          const SizedBox(width: 8),
                          Pill('saUrgent'.tr, color: p.danger, dense: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!read)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: CircleAvatar(radius: 4, backgroundColor: urgent ? p.danger : p.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jambo moja linalosubiri hatua (mf. "Malipo ya kuthibitisha (3)").
class PendingTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const PendingTile({super.key, required this.item, required this.onTap});

  static const _icons = {
    'payments': Icons.payments_rounded,
    'onlineUnapplied': Icons.report_gmailerrorred_rounded,
    'signups': Icons.add_business_rounded,
    'tickets': Icons.mark_chat_unread_rounded,
    'ticketsHigh': Icons.priority_high_rounded,
    'expiring': Icons.hourglass_bottom_rounded,
    'system': Icons.dns_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final key = J.str(item['key']);
    final urgent = J.boolean(item['urgent']);
    final color = urgent ? p.danger : p.warning;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      dense: true,
      leading: Icon(_icons[key] ?? Icons.flag_rounded, color: color),
      title: Text('saPending_$key'.tr, style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pill('${J.integer(item['count'])}', color: color, dense: true),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
      onTap: onTap,
    );
  }
}
