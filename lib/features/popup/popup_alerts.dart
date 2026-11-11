import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/popup.dart';
import '../../data/repositories.dart';
import '../notifications/notifications.dart';
import '../store/overdue_page.dart';

/// Jina, maelezo, ikoni na rangi ya kila aina ya taarifa ya pop-up.
String popupTitle(String kind) => 'pop_$kind'.tr;

String popupDesc(String kind) => 'popDesc_$kind'.tr;

IconData popupIcon(String kind) => switch (kind) {
      'DEBTORS' => Icons.account_balance_wallet_outlined,
      'STORE_LONG' => Icons.hourglass_bottom_rounded,
      'BOX_OPEN' => Icons.inventory_2_outlined,
      'BOX_LATE' => Icons.schedule_rounded,
      'INVOICE_EMPTY' => Icons.receipt_long_outlined,
      'PARKING_LONG' => Icons.pending_actions_outlined,
      'SMS_FAILED' => Icons.sms_failed_outlined,
      'SMS_LOW_BALANCE' => Icons.money_off_csred_outlined,
      _ => Icons.notifications_active_outlined,
    };

/// Ukurasa wa "ona zote" kwa kila aina.
Future<void> _openAll(String kind) => switch (kind) {
      'STORE_LONG' => OverduePage.open(),
      'BOX_OPEN' || 'BOX_LATE' => NotificationsController.openAppLink('boxes'),
      'INVOICE_EMPTY' || 'PARKING_LONG' || 'DEBTORS' => NotificationsController.openAppLink('invoices'),
      'SMS_FAILED' || 'SMS_LOW_BALANCE' => NotificationsController.openAppLink('sms'),
      _ => Future.value(),
    };

/// Inauliza server kila dakika; aina ambayo muda wake wa kujirudia (everyMinutes) umefika inajitokeza.
/// Muda wa mwisho kuonyeshwa unahifadhiwa kwenye kifaa (kwa kila mtumiaji), hivyo haijitokezi kila ukifungua app.
class PopupAlertsController extends GetxController {
  static const _firstCheck = Duration(seconds: 20);
  static const _every = Duration(seconds: 60);

  Timer? _timer;
  bool _open = false;
  SharedPreferences? _prefs;

  String get _key => 'popup.shown.${Session.user?.id ?? '-'}';

  @override
  void onInit() {
    super.onInit();
    Future.delayed(_firstCheck, check);
    _timer = Timer.periodic(_every, (_) => check());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<Map<String, int>> _shown() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw == null) return {};
      return Map<String, int>.from((jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', (v as num).toInt())));
    } catch (_) {
      return {};
    }
  }

  Future<void> _remember(Iterable<String> kinds, DateTime when) async {
    final shown = await _shown();
    for (final k in kinds) {
      shown[k] = when.millisecondsSinceEpoch;
    }
    await _prefs!.setString(_key, jsonEncode(shown));
  }

  Future<void> check() async {
    if (_open || Session.token.isEmpty) return;
    List<PopupGroup> groups;
    try {
      groups = await PopupRepo.due();
    } catch (_) {
      return; // kimya - inajaribu tena dakika ijayo
    }
    final shown = await _shown();
    final now = DateTime.now();
    final ready = groups.where((g) {
      final last = shown[g.kind];
      if (last == null) return true;
      return now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inMinutes >= g.everyMinutes;
    }).toList();
    if (ready.isEmpty) return;
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;

    _open = true;
    final result = await showDialog<_Result>(
      context: ctx,
      builder: (context) => _PopupDialog(groups: ready),
    );
    _open = false;
    final kinds = ready.map((g) => g.kind);
    if (result?.snoozeToday == true) {
      // usionyeshe tena leo: kama vile ilionyeshwa usiku wa manane wa kesho ukitoa muda wa kujirudia
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      for (final g in ready) {
        await _remember([g.kind], tomorrow.subtract(Duration(minutes: g.everyMinutes)));
      }
    } else {
      await _remember(kinds, now);
    }
    if (result?.link != null) await NotificationsController.openAppLink(result!.link);
    if (result?.all != null) await _openAll(result!.all!);
  }
}

class _Result {
  final String? link;
  final String? all;
  final bool snoozeToday;

  const _Result({this.link, this.all, this.snoozeToday = false});
}

class _PopupDialog extends StatelessWidget {
  final List<PopupGroup> groups;

  const _PopupDialog({required this.groups});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.warning.withValues(alpha: .14), shape: BoxShape.circle),
        child: Icon(Icons.notifications_active_outlined, color: p.warning, size: 28),
      ),
      title: Text('popupTitle'.tr, textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final g in groups) _Section(group: g)],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _Result(snoozeToday: true)),
          child: Text('popupSnoozeToday'.tr),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(const _Result()), child: Text('ok'.tr)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final PopupGroup group;

  const _Section({required this.group});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final more = group.count - group.items.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
            child: Row(
              children: [
                Icon(popupIcon(group.kind), color: p.warning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(popupTitle(group.kind), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (group.total != null)
                        Text('${'total'.tr}: ${Fmt.tsh(group.total)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Pill('${group.count}', color: p.warning, dense: true),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_Result(all: group.kind)),
                  child: Text('viewAll'.tr),
                ),
              ],
            ),
          ),
          for (final it in group.items)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: it.subtitle.isEmpty ? null : Text(it.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: it.link == null ? null : Icon(Icons.chevron_right_rounded, color: p.muted),
              onTap: it.link == null ? null : () => Navigator.of(context).pop(_Result(link: it.link)),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text('andNMore'.trParams({'n': '$more'}), style: TextStyle(color: p.muted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
