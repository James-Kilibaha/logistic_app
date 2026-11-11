import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/media.dart';
import '../../data/models/quotation.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import '../invoices/invoice_sms_sheet.dart';

String quotationStatusLabel(String s) => 'qst_$s'.tr;

Color quotationStatusColor(BuildContext context, String s) {
  final p = context.palette;
  return switch (s) {
    'SENT' => p.info,
    'ACCEPTED' => p.success,
    'REJECTED' => p.danger,
    'CONVERTED' => p.primary,
    _ => p.muted,
  };
}

/// "Ndege: Kg 45.0" / "Meli: CBM 1.50, Tani 0.90"
String quotationMeasure(QuotationItem i) {
  if (i.isSea) {
    final parts = <String>[if (i.cbm > 0) 'CBM ${i.cbm.toStringAsFixed(2)}', if (i.weight > 0) '${'tons'.tr} ${i.tons.toStringAsFixed(2)}'];
    return parts.isEmpty ? 'CBM 0' : parts.join(', ');
  }
  return Fmt.kg(i.weight);
}

class QuotationFlows {
  QuotationFlows._();

  static bool get canSms =>
      AppController.to.can(AppModule.quote) && AppController.to.can(AppModule.sms, AppAction.insert);

  static bool get canConvert =>
      AppController.to.can(AppModule.quote, AppAction.update) &&
      AppController.to.can(AppModule.invoice, AppAction.insert) &&
      AppController.to.can(AppModule.product, AppAction.insert);

  static Future<void> pdf(Quotation q) =>
      openPdfFrom(() => QuotationRepo.pdf(q.id), title: '${'quotation'.tr} #${q.number}', fileName: 'makadirio_${q.number}');

  /// SMS / WhatsApp ya makadirio: bidhaa moja moja, jumla na muda wa kuwa halali. Inarudisha true ikitumwa.
  static Future<bool> sms(Quotation q) async {
    if (q.phoneNumber == null) {
      Toast.warning('quotationNoPhone'.tr);
      return false;
    }
    String original;
    try {
      original = await QuotationRepo.message(q.id);
    } catch (e) {
      Toast.error(e);
      return false;
    }
    final text = TextEditingController(text: original);
    final whatsApp = AppController.to.can(AppModule.whatsapp, AppAction.insert) && await WhatsAppRepo.configured();
    String channel = 'SMS';
    final ok = await showFormSheet(
      help: 'quotations',
      title: 'quotationSend'.tr,
      subtitle: '${q.customerName} · ${Fmt.phone(q.phoneNumber)}',
      icon: Icons.sms_outlined,
      submitLabel: 'send'.tr,
      submitIcon: Icons.send_rounded,
      maxWidth: 620,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (whatsApp) ...[
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
            const SizedBox(height: 14),
          ],
          AppField(
            controller: text,
            label: 'message'.tr,
            icon: Icons.notes_rounded,
            required: true,
            maxLines: 14,
            minLines: 8,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text('smsPartsInfo'.trParams({'c': '${text.text.length}', 'n': '${smsParts(text.text)}', 'p': '1'}),
              style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        ],
      ),
      onSubmit: () => QuotationRepo.sendSms(q.id, channel: channel, text: text.text == original ? null : text.text),
    );
    if (ok) Toast.success(Fmt.phone(q.phoneNumber), title: 'quotationSent'.tr);
    return ok;
  }

  /// Makadirio yaliyokubaliwa -> ankara mpya (mteja anasajiliwa kama hayupo), kisha ankara inafunguliwa.
  static Future<bool> convert(Quotation q) async {
    final ok = await confirmAction(
      title: 'quotationConvert'.tr,
      message: 'quotationConvertMsg'.trParams({'name': q.customerName, 'n': '${q.items.length}'}),
      confirmText: 'quotationConvert'.tr,
      icon: Icons.receipt_long_outlined,
    );
    if (!ok) return false;
    try {
      final invoiceId = await QuotationRepo.convert(q.id);
      AppController.to.notifyChanged();
      Toast.success('quotationConverted'.tr);
      await InvoiceFlows.open(invoiceId);
      return true;
    } catch (e) {
      Toast.error(e);
      return false;
    }
  }
}
