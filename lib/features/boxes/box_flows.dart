import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/media.dart';
import '../../data/models/box.dart';
import '../../data/repositories.dart';
import 'arrivals_page.dart';
import 'box_detail_page.dart';

class BoxFlows {
  BoxFlows._();

  /// AIR = box la ndege, SEA = container ya meli.
  static const List<String> types = ['AIR', 'SEA'];

  static IconData iconFor(Box box) => box.isContainer ? Icons.directions_boat_outlined : Icons.flight_takeoff_rounded;

  static Future<void> open(Box box) async {
    await Get.to(() => BoxDetailPage(boxId: box.id, initial: box), preventDuplicates: false);
  }

  static Future<void> newBox({String carrier = 'AIR'}) async {
    String type = carrier;
    Box? created;
    final ok = await showFormSheet(
      help: 'formBox',
      title: 'newBox'.tr,
      subtitle: 'newBoxSub'.tr,
      icon: Icons.add_box_outlined,
      submitLabel: 'createBox'.tr,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('boxType'.tr, required: true),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'AIR', icon: const Icon(Icons.flight_takeoff_rounded), label: Text('box_AIR'.tr)),
              ButtonSegment(value: 'SEA', icon: const Icon(Icons.directions_boat_outlined), label: Text('box_SEA'.tr)),
            ],
            selected: {type},
            onSelectionChanged: (v) => setState(() => type = v.first),
          ),
          const SizedBox(height: 12),
          Text(
            type == 'SEA' ? 'containerHint'.tr : 'airBoxHint'.tr,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
      onSubmit: () async => created = await BoxRepo.create(type: type),
    );
    if (!ok || created == null) return;
    AppController.to.notifyChanged();
    Toast.success('Box ${created!.boxId}', title: 'boxCreated'.tr);
    await open(created!);
  }

  /// Kufunga box na kulisafirisha.
  static Future<bool> close(Box box, {required double suggestedWeight}) async {
    final weight = TextEditingController(text: Fmt.number(suggestedWeight));
    final track = TextEditingController(text: box.trackNumber == 'NO QRCODE NO BARCODE' ? '' : box.trackNumber);
    if (track.text.trim().isEmpty) {
      // mfumo unatengeneza track number ya safari (inaweza kubadilishwa au kuskaniwa)
      try {
        track.text = await BoxRepo.nextTrack(box.id);
      } catch (_) {}
    }
    DateTime? eta; // tupu = siku za kawaida za mfumo (ndege / meli)
    final ok = await showFormSheet(
      help: 'formBox',
      title: 'closeAndShip'.tr,
      subtitle: 'Box ${box.boxId}',
      icon: Icons.local_shipping_outlined,
      submitLabel: 'closeAndShip'.tr,
      submitIcon: Icons.local_shipping_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('closeBoxInfo'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          AppField.number(controller: weight, label: 'finalWeight'.tr, icon: Icons.scale_outlined, suffixText: 'kg'),
          const SizedBox(height: 16),
          AppField(
            controller: track,
            label: 'shippingTrack'.tr,
            hint: 'shippingTrackHint'.tr,
            helper: 'shippingTrackAuto'.tr,
            icon: Icons.qr_code_2_rounded,
            suffix: IconButton(
              tooltip: 'scanCode'.tr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final code = await scanCode(title: 'shippingTrack'.tr);
                if (code != null) setState(() => track.text = code);
              },
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text('etaLabel'.tr),
            subtitle: Text(eta == null ? 'etaDefault'.tr : Fmt.date(eta)),
            trailing: TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: eta ?? now.add(Duration(days: box.isContainer ? 45 : 10)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => eta = picked);
              },
              child: Text('choose'.tr),
            ),
          ),
        ],
      ),
      onSubmit: () => BoxRepo.close(box.id, weight: Fmt.parse(weight.text) ?? 0, trackNumber: track.text, eta: eta),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success('boxShippedMsg'.tr, title: 'boxShipped'.tr);
    }
    return ok;
  }

  /// Kubadilisha tarehe ya kutarajia kufika (ETA) ya box lililo safarini; hiari: SMS kwa wateja wake.
  static Future<bool> changeEta(Box box) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: Get.context!,
      helpText: 'etaLabel'.tr,
      initialDate: box.eta != null && box.eta!.isAfter(now) ? box.eta! : now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return false;
    final reason = TextEditingController();
    bool notify = true;
    final ok = await showFormSheet(
      help: 'boxEta',
      title: 'etaChange'.tr,
      subtitle: 'Box ${box.boxId} · ${Fmt.date(picked)}',
      icon: Icons.event_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: notify,
            onChanged: (v) => setState(() => notify = v),
            title: Text('etaNotify'.tr),
            subtitle: Text('etaNotifySub'.trParams({'n': '${box.invoiceIds.length}'})),
          ),
          if (notify)
            AppField(controller: reason, label: 'etaReason'.tr, hint: 'etaReasonHint'.tr, required: false,
                icon: Icons.notes_rounded),
        ],
      ),
      onSubmit: () => BoxRepo.setEta(box.id, picked, notify: notify, reason: reason.text),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(Fmt.date(picked), title: 'etaChanged'.tr);
    }
    return ok;
  }

  /// Box limefika stoo (Tanzania).
  /// Kawaida hakuna SMS: baada ya kupokea, ukurasa wa mizigo iliyofika unafunguka ili kutuma SMS
  /// kwa mmoja mmoja, waliochaguliwa au wote. Mtumiaji anaweza kuchagua kutuma kwa wote papo hapo.
  static Future<bool> receive(Box box) async {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return false;
    bool sendNow = false;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.warehouse_outlined),
          title: Text('receiveBox'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('receiveBoxMsg'.trParams({'box': box.boxId, 'track': box.trackNumber})),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sendNow,
                onChanged: (v) => setState(() => sendNow = v ?? false),
                title: Text('receiveSendAllNow'.tr),
                subtitle: Text('receiveSendLater'.tr),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text('receive'.tr)),
          ],
        ),
      ),
    );
    if (ok != true) return false;
    final done = await runGuarded(() => BoxRepo.receive(box.id, sendSms: sendNow), success: 'boxReceivedMsg'.tr);
    if (done) {
      AppController.to.notifyChanged();
      if (!sendNow) await ArrivalsPage.open(box); // tuma SMS kwa mmoja mmoja au wote
    }
    return done;
  }

  static Future<bool> delete(Box box) async {
    final ok = await confirmAction(
      title: 'deleteBox'.tr,
      message: 'deleteBoxMsg'.trParams({'box': box.boxId}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return false;
    final done = await runGuarded(() => BoxRepo.delete(box.id), success: 'deleted'.tr);
    if (done) AppController.to.notifyChanged();
    return done;
  }
}
