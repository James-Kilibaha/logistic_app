import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/list_controller.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/misc.dart';
import '../../data/repositories.dart';

class SmsController extends ListController<SmsMessage> {
  /// `null` = aina zote.
  final Rxn<SmsKind> kind = Rxn<SmsKind>();
  final RxBool sent = false.obs;

  /// Historia: SMS zote (zinazosubiri, zilizotumwa, zilizoshindwa) za siku [historyDays] zilizopita.
  final RxBool all = true.obs;
  static const int historyDays = 90;

  /// Zilizotumwa lakini hazikumfikia mteja (ripoti ya kufika = FAILED).
  final RxBool failed = false.obs;

  /// Maendeleo ya kutuma zote (0..1), `null` ikiwa haitumi.
  final RxnDouble sending = RxnDouble();

  @override
  Future<List<SmsMessage>> fetch() =>
      SmsRepo.list(
        kind: kind.value,
        sent: all.value ? null : sent.value,
        delivery: failed.value ? 'FAILED' : null,
        days: all.value ? historyDays : null,
        limit: all.value ? 2000 : null,
      );

  @override
  bool matches(SmsMessage m, String q) => m.text.toLowerCase().contains(q) || Phone.matches(m.msisdn, q);

  void setKind(SmsKind? k) {
    kind.value = k;
    items.clear();
    load();
  }

  void setSent(bool value) => setView(value ? 'SENT' : 'PENDING');

  /// ALL / PENDING / SENT / FAILED
  void setView(String v) {
    all.value = v == 'ALL';
    sent.value = v == 'SENT' || v == 'FAILED';
    failed.value = v == 'FAILED';
    items.clear();
    load();
  }

  String get view => all.value ? 'ALL' : (failed.value ? 'FAILED' : (sent.value ? 'SENT' : 'PENDING'));

  Future<void> sendOne(SmsMessage m, {String? text}) async {
    final ok = await runGuarded(() => SmsRepo.send(m.id, text: text), success: 'smsSent'.tr);
    if (ok) {
      if (all.value) {
        await load(silent: true); // historia: ujumbe unabaki, hali yake inabadilika
      } else {
        items.removeWhere((e) => e.id == m.id);
      }
      AppController.to.notifyChanged();
    }
  }

  /// Kutuma tena ujumbe mmoja (nakala mpya). [ask]=false kwa fomu ya kuhariri (imeshathibitishwa).
  Future<bool> resendOne(SmsMessage m, {String? text, String? msisdn, bool ask = true}) async {
    if (ask) {
      final ok = await confirmAction(
        title: 'resend'.tr,
        message: 'resendConfirmMsg'.trParams({'phone': Fmt.phone(m.msisdn)}),
        confirmText: 'resend'.tr,
        icon: Icons.refresh_rounded,
      );
      if (!ok) return false;
    }
    final ok = await runGuarded(() => SmsRepo.resend(m.id, text: text, msisdn: msisdn), success: 'smsResent'.tr);
    if (ok) {
      await load(silent: true);
      AppController.to.notifyChanged();
    }
    return ok;
  }

  /// Kutuma tena SMS zote zilizotumwa zinazoonekana sasa (kwa vichujio vilivyowekwa).
  Future<void> resendVisible() async {
    final list = visible.where((m) => m.isSent).toList();
    if (list.isEmpty || sending.value != null) return;
    final ok = await confirmAction(
      title: 'resendAll'.tr,
      message: 'resendAllMsg'.trParams({'n': '${list.length}'}),
      confirmText: 'resend'.tr,
      icon: Icons.refresh_rounded,
    );
    if (!ok) return;
    int done = 0, failed = 0;
    Object? lastError;
    sending.value = 0;
    for (final m in list) {
      try {
        await SmsRepo.resend(m.id);
        done++;
      } catch (e) {
        failed++;
        lastError = e;
      }
      sending.value = (done + failed) / list.length;
    }
    sending.value = null;
    await load(silent: true);
    AppController.to.notifyChanged();
    if (failed == 0) {
      Toast.success('smsSentN'.trParams({'n': '$done'}), title: 'smsResent'.tr);
    } else {
      Toast.error(lastError ?? '', title: 'smsPartial'.trParams({'ok': '$done', 'failed': '$failed'}));
    }
  }

  Future<void> sendAll() async {
    final list = visible.where((m) => !m.isSent).toList(); // zinazosubiri tu
    if (list.isEmpty || sending.value != null) return;
    final ok = await confirmAction(
      title: 'sendAll'.tr,
      message: 'sendAllMsg'.trParams({'n': '${list.length}'}),
      confirmText: 'send'.tr,
    );
    if (!ok) return;
    int done = 0, failed = 0;
    Object? lastError;
    sending.value = 0;
    for (final m in list) {
      try {
        await SmsRepo.send(m.id);
        done++;
        if (!all.value) items.removeWhere((e) => e.id == m.id);
      } catch (e) {
        failed++;
        lastError = e;
      }
      sending.value = (done + failed) / list.length;
    }
    sending.value = null;
    if (all.value) await load(silent: true);
    AppController.to.notifyChanged();
    if (failed == 0) {
      Toast.success('smsSentN'.trParams({'n': '$done'}), title: 'smsSent'.tr);
    } else {
      Toast.error(lastError ?? '', title: 'smsPartial'.trParams({'ok': '$done', 'failed': '$failed'}));
    }
  }

  Future<void> delete(SmsMessage m) async {
    final ok = await confirmAction(
      title: 'deleteSms'.tr,
      message: 'deleteSmsMsg'.tr,
      confirmText: 'delete'.tr,
      danger: true,
    );
    if (!ok) return;
    if (await runGuarded(() => SmsRepo.delete(m.id), success: 'deleted'.tr)) {
      items.removeWhere((e) => e.id == m.id);
    }
  }
}
