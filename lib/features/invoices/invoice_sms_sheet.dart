import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models/invoice.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// SMS ngapi kwa maandishi haya (GSM: 160 / 153 kwa kipande; Unicode: 70 / 67).
int smsParts(String text) {
  if (text.isEmpty) return 0;
  final unicode = text.runes.any((r) => r > 0x7E && r != 0x0A && r != 0x0D);
  final single = unicode ? 70 : 160;
  final multi = unicode ? 67 : 153;
  return text.length <= single ? 1 : (text.length / multi).ceil();
}

/// "Tuma SMS ya ankara": ujumbe unaoorodhesha kila bidhaa ya ankara (maelezo, katoni, kilo/CBM, usafiri, bei),
/// jumla, kilicholipwa na deni. Mtumiaji anaweza kuubadilisha kabla ya kutuma.
Future<void> showInvoiceSms(Invoice invoice) async {
  Map<String, dynamic> preview;
  try {
    preview = await SmsRepo.invoicePreview(invoice.id);
  } catch (e) {
    Toast.error(e);
    return;
  }
  final original = J.str(preview['text']);
  final text = TextEditingController(text: original);
  final customer = J.map(preview['customer']);
  final receiver = J.map(preview['receiver']);
  final customerPhone = customer == null ? null : customer['phone'] as String?;
  final receiverPhone = receiver == null ? null : receiver['phone'] as String?;
  final hasReceiver = receiverPhone != null && receiverPhone.isNotEmpty && receiverPhone != customerPhone;
  bool toCustomer = customerPhone != null && customerPhone.isNotEmpty;
  bool toReceiver = !toCustomer && hasReceiver;
  final whatsApp = AppController.to.can(AppModule.whatsapp, AppAction.insert) && await WhatsAppRepo.configured();
  String channel = 'SMS';
  int sent = 0;

  final ok = await showFormSheet(
    help: 'invoiceSms',
    title: 'invoiceSms'.tr,
    subtitle: 'invoiceSmsSub'.trParams({'no': J.str(preview['invoiceNumber']), 'n': '${J.integer(preview['items'])}'}),
    icon: Icons.sms_outlined,
    submitLabel: 'send'.tr,
    submitIcon: Icons.send_rounded,
    maxWidth: 620,
    builder: (context, setState) {
      final p = context.palette;
      final parts = smsParts(text.text);
      final people = (toCustomer ? 1 : 0) + (toReceiver ? 1 : 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: toCustomer,
            onChanged: customerPhone == null ? null : (v) => setState(() => toCustomer = v ?? false),
            title: Text('${'customer'.tr}: ${customer?['name'] ?? '—'}'),
            subtitle: Text(customerPhone == null ? 'noPhone'.tr : Fmt.phone(customerPhone)),
          ),
          if (hasReceiver)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: toReceiver,
              onChanged: (v) => setState(() => toReceiver = v ?? false),
              title: Text('${'receiver'.tr}: ${receiver?['name'] ?? '—'}'),
              subtitle: Text(Fmt.phone(receiverPhone)),
            ),
          if (whatsApp) ...[
            const SizedBox(height: 6),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'SMS', label: Text('ch_SMS'.tr), icon: const Icon(Icons.sms_outlined)),
                ButtonSegment(value: 'WHATSAPP', label: Text('ch_WHATSAPP'.tr), icon: const Icon(Icons.chat_outlined)),
                ButtonSegment(value: 'BOTH', label: Text('ch_BOTH'.tr), icon: const Icon(Icons.forum_outlined)),
              ],
              selected: {channel},
              onSelectionChanged: (v) => setState(() => channel = v.first),
            ),
          ],
          const SizedBox(height: 14),
          AppField(
            controller: text,
            label: 'message'.tr,
            icon: Icons.notes_rounded,
            required: true,
            maxLines: 14,
            minLines: 8,
            capitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'smsPartsInfo'.trParams({'c': '${text.text.length}', 'n': '$parts', 'p': '$people'}),
                  style: TextStyle(color: parts > 4 ? p.warning : p.muted, fontSize: 12.5),
                ),
              ),
              if (text.text != original)
                TextButton.icon(
                  onPressed: () => setState(() => text.text = original),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text('resetText'.tr),
                ),
            ],
          ),
          Text('invoiceSmsHint'.tr, style: TextStyle(color: p.muted, fontSize: 12)),
        ],
      );
    },
    onSubmit: () async {
      if (!toCustomer && !toReceiver) throw Exception('chooseRecipient'.tr);
      // Maandishi yasipobadilishwa, seva inaandaa ujumbe kwa jina la kila mpokeaji.
      sent = await SmsRepo.sendInvoice(
        invoice.id,
        text: text.text == original ? null : text.text,
        toCustomer: toCustomer,
        toReceiver: toReceiver,
        channel: channel,
      );
    },
  );
  if (ok) Toast.success('invoiceSmsSent'.trParams({'n': '$sent'}), title: 'invoiceSms'.tr);
}

/// Kutoka ukurasa wa SMS: andika namba ya ankara (au jina/simu ya mteja), kisha tuma SMS ya bidhaa zake.
Future<void> pickInvoiceForSms() async {
  final q = TextEditingController();
  Invoice? found;
  final ok = await showFormSheet(
    help: 'invoiceSms',
    title: 'invoiceSms'.tr,
    subtitle: 'invoiceSmsPickSub'.tr,
    icon: Icons.receipt_long_outlined,
    submitLabel: 'next'.tr,
    submitIcon: Icons.arrow_forward_rounded,
    builder: (context, setState) => AppField(
      controller: q,
      label: 'invoiceNo'.tr,
      hint: '0000123',
      icon: Icons.search_rounded,
      required: true,
      autofocus: true,
    ),
    onSubmit: () async {
      final term = q.text.trim();
      final list = await InvoiceRepo.search(query: term, limit: 10);
      if (list.isEmpty) throw Exception('invoiceNotFound'.tr);
      found = list.firstWhere((i) => i.invoiceNumber == term, orElse: () => list.first);
    },
  );
  if (ok && found != null) await showInvoiceSms(found!);
}
