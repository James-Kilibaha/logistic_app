import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/ops.dart';
import '../../data/repositories.dart';
import '../boxes/box_flows.dart';
import '../invoices/invoice_flows.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';
import '../demands/demands.dart';
import '../store/overdue_page.dart';
import '../support/support_page.dart';
import '../whatsapp/whatsapp_inbox_page.dart';

/// Taarifa ndani ya app: inauliza server kila dakika na kuonyesha idadi ambazo hazijasomwa.
class NotificationsController extends GetxController {
  static NotificationsController get to => Get.find<NotificationsController>();

  final RxInt unread = 0.obs;
  final RxList<AppNotice> items = <AppNotice>[].obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    refreshNow();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refreshNow());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> refreshNow() async {
    try {
      final data = await NotificationRepo.list(limit: 40);
      unread.value = data.unread;
      items.assignAll(data.items);
      _maybePopup();
    } catch (_) {
      // kimya - inajaribu tena baadaye
    }
  }

  /// Taarifa zinazojitokeza kama dirisha (popup) - mf. mizigo iliyokaa stoo muda mrefu (kila siku 7).
  static const popupKinds = {'STORAGE_OVERDUE'};
  final Set<String> _popped = {};
  bool _popupOpen = false;

  Future<void> _maybePopup() async {
    if (_popupOpen) return;
    AppNotice? notice;
    for (final n in items) {
      if (!n.isRead && popupKinds.contains(n.kind) && !_popped.contains(n.id)) {
        notice = n;
        break;
      }
    }
    final ctx = Get.overlayContext ?? Get.context;
    if (notice == null || ctx == null) return;
    final n = notice;
    _popped.add(n.id);
    _popupOpen = true;
    final open = await showDialog<bool>(
      context: ctx,
      builder: (context) {
        final p = context.palette;
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.warning.withValues(alpha: .14), shape: BoxShape.circle),
            child: Icon(_icon(n.kind), color: p.warning, size: 30),
          ),
          title: Text(n.title, textAlign: TextAlign.center),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              [if (n.body != null) n.body!, 'overduePopupHint'.tr].join('\n\n'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: Text('later'.tr)),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.warehouse_outlined),
              label: Text('viewCargo'.tr),
            ),
          ],
        );
      },
    );
    _popupOpen = false;
    // imeonekana: haitajitokeza tena hadi taarifa mpya (baada ya siku 7)
    NotificationRepo.markRead(ids: [n.id]).then((_) => refreshNow()).catchError((_) {});
    if (open == true) await OverduePage.open();
  }

  Future<void> markAll() async {
    try {
      await NotificationRepo.markRead(all: true);
      unread.value = 0;
      items.assignAll(items.map((n) => AppNotice(
            id: n.id,
            kind: n.kind,
            title: n.title,
            body: n.body,
            link: n.link,
            isRead: true,
            createdAt: n.createdAt,
          )));
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> open(AppNotice n) async {
    if (!n.isRead) {
      NotificationRepo.markRead(ids: [n.id]).then((_) => refreshNow()).catchError((_) {});
    }
    await openAppLink(n.link);
  }

  /// Kufungua kiungo cha taarifa (🔔 au pop-up): invoice:<id>, box:<id>, sms, store-overdue ...
  static Future<void> openAppLink(String? value) async {
    final link = value ?? '';
    final i = link.indexOf(':');
    final kind = i < 0 ? link : link.substring(0, i);
    final id = i < 0 ? '' : link.substring(i + 1);
    switch (kind) {
      case 'invoice':
        await InvoiceFlows.open(id);
      case 'box':
        try {
          for (final box in await BoxRepo.all()) {
            if (box.id == id) {
              await BoxFlows.open(box);
              break;
            }
          }
        } catch (e) {
          Toast.error(e);
        }
      case 'aging':
        ShellController.to.go(NavSection.reports);
      case 'alert':
        ShellController.to.go(NavSection.settings);
      case 'claims':
        ShellController.to.go(NavSection.claims);
      case 'store-overdue':
        await OverduePage.open();
      case 'cashup':
        ShellController.to.go(NavSection.cashup);
      case 'sms':
        ShellController.to.go(NavSection.sms);
      case 'boxes':
        ShellController.to.go(NavSection.boxes);
      case 'invoices':
        ShellController.to.go(NavSection.invoices);
      case 'store':
        ShellController.to.go(NavSection.store);
      case 'wa':
        await WhatsappInboxPage.openThread(id);
      case 'ticket':
        await SupportPage.openTicket(id);
      case 'subscription':
        await Get.toNamed(Routes.subscription);
      case 'demands':
        await DemandsPage.open();
      case 'expenses':
        ShellController.to.go(NavSection.expenses);
    }
  }
}

IconData _icon(String kind) => switch (kind) {
      'BOX_SHIPPED' => Icons.local_shipping_outlined,
      'BOX_ARRIVED' => Icons.warehouse_outlined,
      'PAYMENT' => Icons.payments_outlined,
      'CLAIM' => Icons.report_problem_outlined,
      'CREDIT_HANDOVER' => Icons.handshake_outlined,
      'DEBT_OLD' => Icons.hourglass_bottom_rounded,
      'ALERT' => Icons.warning_amber_rounded,
      'STORAGE_OVERDUE' => Icons.hourglass_bottom_rounded,
      'CASHUP_DIFF' => Icons.point_of_sale_outlined,
      'BOX_LATE' => Icons.schedule_rounded,
      'SMS_LOW_BALANCE' => Icons.sms_failed_outlined,
      'WHATSAPP_IN' => Icons.forum_outlined,
      'ONLINE_PAYMENT' => Icons.phone_iphone_rounded,
      'SUPPORT_REPLY' => Icons.support_agent_rounded,
      'ONLINE_PAYMENT_FAILED' => Icons.phonelink_erase_rounded,
      'SUBSCRIPTION_EXPIRING' || 'SUBSCRIPTION_PAID' || 'SUBSCRIPTION_REJECTED' => Icons.workspace_premium_outlined,
      _ => Icons.notifications_none_rounded,
    };

/// Kengele 🔔 yenye idadi ya taarifa mpya.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NotificationsController>()) return const SizedBox.shrink();
    final c = NotificationsController.to;
    return Obx(() {
      final n = c.unread.value;
      return IconButton(
        tooltip: 'notifications'.tr,
        onPressed: () => _showPanel(context),
        icon: Badge(
          isLabelVisible: n > 0,
          label: Text(n > 99 ? '99+' : '$n'),
          child: Icon(n > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded),
        ),
      );
    });
  }

  void _showPanel(BuildContext context) {
    final c = NotificationsController.to;
    c.refreshNow();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final p = context.palette;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('notifications'.tr,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                      ),
                      Obx(() => c.unread.value == 0
                          ? const SizedBox.shrink()
                          : TextButton(onPressed: c.markAll, child: Text('markAllRead'.tr))),
                    ],
                  ),
                ),
                Flexible(
                  child: Obx(() {
                    if (c.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('noNotifications'.tr, style: TextStyle(color: p.muted)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: c.items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
                      itemBuilder: (context, i) {
                        final n = c.items[i];
                        final color = n.kind == 'ALERT' ? p.danger : p.primary;
                        return ListTile(
                          tileColor: n.isRead ? null : p.primarySoft.withValues(alpha: .5),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: .12),
                            child: Icon(_icon(n.kind), color: color, size: 20),
                          ),
                          title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                          subtitle: Text([if (n.body != null) n.body!, Fmt.relative(n.createdAt)].join('\n')),
                          isThreeLine: n.body != null,
                          onTap: () {
                            Navigator.of(context).pop();
                            c.open(n);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
