import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/misc.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_sms_sheet.dart';
import 'broadcast_page.dart';
import 'sms_balance.dart';
import 'sms_controller.dart';

String smsKindLabel(SmsKind? k) => switch (k) {
      null => 'all'.tr,
      SmsKind.received => 'smsReceived'.tr,
      SmsKind.shipping => 'smsShipping'.tr,
      SmsKind.store => 'smsStore'.tr,
      SmsKind.reminder => 'smsReminder'.tr,
      SmsKind.whatsapp => 'WhatsApp',
      SmsKind.receipt => 'smsReceipt'.tr,
      SmsKind.handover => 'smsHandover'.tr,
      SmsKind.custom => 'smsCustom'.tr,
      SmsKind other => 'smsKind_${other.code}'.tr,
    };

class SmsPage extends GetView<SmsController> {
  const SmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canSend = AppController.to.can(AppModule.sms, AppAction.insert);
    return AppPage(
      title: 'navSms'.tr,
      subtitle: 'hintSms'.tr,
      help: 'sms',
      actions: [
        if (canSend)
          Obx(() => controller.view != 'PENDING'
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'sendAllPending'.tr,
                  onPressed: controller.sendAll,
                  icon: const Icon(Icons.send_and_archive_outlined),
                )),
        if (canSend)
          Obx(() => controller.view == 'SENT' || controller.view == 'FAILED'
              ? IconButton(
                  tooltip: 'resendAll'.tr,
                  onPressed: controller.resendVisible,
                  icon: const Icon(Icons.restart_alt_rounded),
                )
              : const SizedBox.shrink()),
        if (canSend && AppController.to.can(AppModule.invoice))
          IconButton(
            tooltip: 'invoiceSms'.tr,
            onPressed: () async {
              await pickInvoiceForSms();
              controller.load();
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: canSend
          ? PageAction(
              icon: Icons.campaign_outlined,
              label: 'newMessage'.tr,
              onPressed: () async {
                await BroadcastPage.open();
                controller.load();
              },
            )
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchSmsHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() => FilterChips<SmsKind?>(
                  values: [null, ...SmsKind.values.where((k) => !k.settingOnly)],
                  selected: controller.kind.value,
                  label: smsKindLabel,
                  onSelected: controller.setKind,
                )),
            trailing: [
              const SizedBox(width: 12),
              Obx(() => SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'ALL', label: Text('all'.tr)),
                      ButtonSegment(value: 'PENDING', label: Text('pending'.tr)),
                      ButtonSegment(value: 'SENT', label: Text('sent'.tr)),
                      ButtonSegment(value: 'FAILED', label: Text('notDelivered'.tr)),
                    ],
                    selected: {controller.view},
                    onSelectionChanged: (v) => controller.setView(v.first),
                  )),
            ],
          ),
          const SmsBalanceCard(),
          Obx(() {
            final progress = controller.sending.value;
            if (progress == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(6)),
            );
          }),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: controller.all.value
                      ? 'noSmsYet'.tr
                      : controller.failed.value
                          ? 'noFailedSms'.tr
                          : controller.sent.value
                              ? 'noSentSms'.tr
                              : 'noPendingSms'.tr,
                  message: controller.all.value
                      ? 'smsHistoryNote'.trParams({'days': '${SmsController.historyDays}'})
                      : controller.sent.value
                          ? null
                          : 'noPendingSmsMsg'.tr,
                ),
                builder: () => DataList<SmsMessage>(
                  items: list,
                  tableMinWidth: 100000, // ujumbe mrefu unasomeka vizuri kama kadi
                  onRefresh: controller.refreshList,
                  columns: const [],
                  cells: (context, m) => const [],
                  card: (context, m) => _SmsCard(message: m, canSend: canSend),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SmsCard extends StatelessWidget {
  final SmsMessage message;
  final bool canSend;

  const _SmsCard({required this.message, required this.canSend});

  Future<void> _editAndSend() async {
    final text = TextEditingController(text: message.text);
    final controller = Get.find<SmsController>();
    await showFormSheet(
      help: 'sms',
      title: 'editAndSend'.tr,
      subtitle: Fmt.phone(message.msisdn),
      icon: Icons.edit_note_rounded,
      submitLabel: 'send'.tr,
      submitIcon: Icons.send_rounded,
      builder: (context, setState) => AppField(
        controller: text,
        label: 'message'.tr,
        required: true,
        maxLines: 8,
        minLines: 5,
      ),
      onSubmit: () => controller.sendOne(message, text: text.text),
    );
  }

  /// Ujumbe uliokwisha tumwa: rekebisha maandishi na/au namba, kisha utume tena (nakala mpya).
  Future<void> _editAndResend() async {
    final text = TextEditingController(text: message.text);
    final phone = TextEditingController(text: message.msisdn);
    final controller = Get.find<SmsController>();
    await showFormSheet(
      help: 'sms',
      title: 'editAndResend'.tr,
      subtitle: 'resendNote'.tr,
      icon: Icons.edit_note_rounded,
      submitLabel: 'resend'.tr,
      submitIcon: Icons.refresh_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: phone, label: 'phone'.tr, icon: Icons.phone_outlined, required: true),
          const SizedBox(height: 14),
          AppField(controller: text, label: 'message'.tr, required: true, maxLines: 8, minLines: 5),
        ],
      ),
      // kosa likitokea, fomu inabaki wazi na inaonyesha sababu
      onSubmit: () async {
        await SmsRepo.resend(message.id,
            text: text.text, msisdn: phone.text.trim() == message.msisdn ? null : phone.text);
        await controller.load(silent: true);
        AppController.to.notifyChanged();
        Toast.success(Fmt.phone(phone.text), title: 'smsResent'.tr);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final controller = Get.find<SmsController>();
    final canDelete = AppController.to.can(AppModule.sms, AppAction.delete);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_iphone_rounded, size: 18, color: p.muted),
              const SizedBox(width: 6),
              Text(Fmt.phone(message.msisdn), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(width: 10),
              Pill(smsKindLabel(SmsKind.fromCode(message.smsFor)), color: p.primary, dense: true),
              if (message.isWhatsApp) ...[
                const SizedBox(width: 6),
                Pill('WhatsApp', color: const Color(0xFF16A34A), icon: Icons.chat_rounded, dense: true),
              ],
              if (message.error != null && !message.isSent) ...[
                const SizedBox(width: 6),
                Tooltip(message: message.error!, child: Icon(Icons.error_outline_rounded, size: 18, color: p.danger)),
              ],
              const Spacer(),
              Tooltip(
                message: Fmt.dateTime(message.createdAt),
                child: Text(Fmt.relative(message.createdAt), style: TextStyle(color: p.muted, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(message.text, style: TextStyle(color: p.text, height: 1.45, fontSize: 13.5)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canDelete)
                TextButton(
                  onPressed: () => controller.delete(message),
                  style: TextButton.styleFrom(foregroundColor: p.danger),
                  child: Text('delete'.tr),
                ),
              if (!message.isSent && canSend) ...[
                TextButton(onPressed: _editAndSend, child: Text('editAndSend'.tr)),
                const SizedBox(width: 4),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: () => controller.sendOne(message),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('send'.tr),
                ),
              ],
              // Uliokwisha tumwa (umefika, haukufika, au FastHub haikuutuma kweli): tuma tena kama nakala mpya
              if (message.isSent && canSend) ...[
                TextButton(onPressed: _editAndResend, child: Text('editAndResend'.tr)),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: () => controller.resendOne(message),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('resend'.tr),
                ),
                const SizedBox(width: 8),
              ],
              if (message.balanceAfter != null) ...[
                Tooltip(
                  message: 'balanceAfterSms'.tr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 15, color: p.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${'smsBalanceShort'.tr}: ${Fmt.number(message.balanceAfter)}',
                        style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (message.gatewayResponse != null)
                IconButton(
                  tooltip: 'gatewayResponse'.tr,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.receipt_long_outlined, size: 18, color: p.muted),
                  onPressed: () => _showGatewayResponse(context, message),
                ),
              _DeliveryPill(message: message),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hali ya ujumbe uliotumwa: imefika / haikufika / imetumwa (gateway imepokea).
class _DeliveryPill extends StatelessWidget {
  final SmsMessage message;

  const _DeliveryPill({required this.message});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (!message.isSent) {
      // haijatumwa: imeshindwa (ina sababu) au bado inasubiri
      if (message.error != null) {
        return Tooltip(
          message: message.error!,
          child: Pill('sendFailed'.tr, color: p.danger, icon: Icons.error_outline_rounded),
        );
      }
      return Pill('notSentYet'.tr, color: p.warning, icon: Icons.schedule_rounded);
    }
    if (message.isDelivered) {
      final pill = Pill('delivered'.tr, color: p.success, icon: Icons.done_all_rounded);
      return message.deliveredAt == null
          ? pill
          : Tooltip(message: Fmt.dateTime(message.deliveredAt), child: pill);
    }
    if (message.isFailed) {
      return Tooltip(
        message: message.error ?? 'notDelivered'.tr,
        child: Pill('notDelivered'.tr, color: p.danger, icon: Icons.error_outline_rounded),
      );
    }
    return Pill('sent'.tr, color: p.info, icon: Icons.done_rounded);
  }
}


/// Jibu kamili la FastHub kwa ujumbe huu (la kunakili na kutuma kwa FastHub support).
void _showGatewayResponse(BuildContext context, SmsMessage m) {
  final text = [
    'SMS: ${m.msisdn}',
    'Saa: ${Fmt.dateTime(m.createdAt)}',
    if (m.error != null) 'Kosa: ${m.error}',
    '',
    m.gatewayResponse ?? '',
  ].join('\n');
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('gatewayResponse'.tr, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Toast.success('copied'.tr);
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text('copy'.tr),
                  ),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr)),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
