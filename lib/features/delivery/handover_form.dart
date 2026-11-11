import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/signature_pad.dart';
import '../../data/models/invoice.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

const List<String> idTypes = ['NIDA', 'LESENI', 'MPIGA_KURA', 'PASIPOTI', 'NYINGINE'];

String idTypeLabel(String? t) => switch (t) {
      'NIDA' => 'idNida'.tr,
      'LESENI' => 'idLicence'.tr,
      'MPIGA_KURA' => 'idVoter'.tr,
      'PASIPOTI' => 'idPassport'.tr,
      'NYINGINE' => 'idOther'.tr,
      _ => '—',
    };

/// Kukabidhi mzigo: aliyechukua, kitambulisho, sahihi na picha (si lazima).
/// Inarudisha `true` mzigo ukikabidhiwa.
Future<bool> showHandoverForm(Invoice invoice, Debt debt) async {
  final receiver = invoice.receiver;
  final bool owing = !debt.isPaid;
  final bool canCredit = AppController.to.can(AppModule.handover, AppAction.update);
  if (owing && !canCredit) {
    Toast.warning('handoverNeedsPayment'.trParams({'amount': Fmt.tsh(debt.balance)}), title: 'balanceDue'.tr);
    return false;
  }

  // Kilichobaki stoo (kwa kukabidhi kwa awamu)
  HandoverStatus? status;
  try {
    status = await HandoverRepo.status(invoice.id);
  } catch (_) {}
  final lines = status?.remaining.where((r) => r.remaining > 0).toList() ?? const <RemainingLine>[];
  final take = <String, double>{for (final r in lines) r.productId: r.remaining};
  final bool chooseItems = lines.length > 1 || lines.any((r) => r.remaining > 1);
  bool takeAll() => lines.every((r) => (take[r.productId] ?? 0) >= r.remaining);
  double taking() => take.values.fold<double>(0, (s, v) => s + v);

  bool isReceiver = receiver != null;
  final name = TextEditingController(text: receiver?.name ?? '');
  final phone = TextEditingController(text: receiver?.phoneNumber ?? '');
  final idNumber = TextEditingController();
  final note = TextEditingController();
  final code = TextEditingController();
  final codes = <String>[]; // code za mizigo inayochukuliwa (SMS / lebo)
  final bool needsCode = status?.needsCode ?? invoice.products.any((e) => (e.officeCode ?? '').isNotEmpty);

  void addCodes(String raw) {
    for (final c in raw.toUpperCase().split(RegExp(r'[,;\s]+'))) {
      if (c.isNotEmpty && !codes.contains(c)) codes.add(c);
    }
    code.clear();
  }
  String? idType = 'NIDA';
  bool onCredit = false;
  PickedImage? photo;
  final signature = SignatureController();

  final ok = await showFormSheet(
    help: 'formHandover',
    title: 'handOver'.tr,
    subtitle: '${'invoice'.tr} ${invoice.number} · ${invoice.customer?.name ?? ''}',
    icon: Icons.handshake_outlined,
    submitLabel: 'confirmHandover'.tr,
    submitIcon: Icons.verified_outlined,
    maxWidth: 600,
    builder: (context, setState) {
      final p = context.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (owing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.warning.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('handoverOwing'.trParams({'amount': Fmt.tsh(debt.balance)}),
                      style: TextStyle(color: p.warning, fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: onCredit,
                    onChanged: (v) => setState(() => onCredit = v),
                    title: Text('handoverOnCredit'.tr),
                    subtitle: Text('handoverOnCreditSub'.tr),
                  ),
                ],
              ),
            ),
          if (owing) const SizedBox(height: 14),
          if (chooseItems) ...[
            FieldLabel('whatIsCollected'.tr),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  for (final r in lines)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(r.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    if (r.needsCode) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.pin_outlined, size: 15, color: p.muted),
                                    ],
                                  ],
                                ),
                                Text(
                                  'cartonsLeft'.trParams({'n': Fmt.number(r.remaining), 'total': Fmt.number(r.cartons)}),
                                  style: TextStyle(color: p.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: (take[r.productId] ?? 0) <= 0
                                ? null
                                : () => setState(() {
                                      final next = (take[r.productId] ?? 0) - 1;
                                      take[r.productId] = next < 0 ? 0 : next;
                                    }),
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              Fmt.number(take[r.productId] ?? 0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            onPressed: (take[r.productId] ?? 0) >= r.remaining
                                ? null
                                : () => setState(() {
                                      final next = (take[r.productId] ?? 0) + 1;
                                      take[r.productId] = next > r.remaining ? r.remaining : next;
                                    }),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              takeAll() ? 'takingAll'.tr : 'takingPart'.trParams({'n': Fmt.number(taking())}),
              style: TextStyle(color: takeAll() ? p.success : p.warning, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
          ],
          if (needsCode) ...[
            AppField(
              controller: code,
              label: 'officeCodes'.tr,
              helper: canCredit ? 'officeCodeAskSupervisor'.tr : 'officeCodeAsk'.tr,
              icon: Icons.pin_outlined,
              autofocus: true,
              capitalization: TextCapitalization.characters,
              onSubmitted: (v) => setState(() => addCodes(v)),
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'add'.tr,
                    icon: Icon(Icons.add_circle_outline_rounded, color: p.primary),
                    onPressed: () => setState(() => addCodes(code.text)),
                  ),
                  IconButton(
                    tooltip: 'scanCode'.tr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final v = await scanCode(title: 'officeCode'.tr);
                      if (v != null) setState(() => addCodes(v));
                    },
                  ),
                ],
              ),
            ),
            if (codes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in codes)
                    InputChip(
                      label: Text(c, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      avatar: Icon(Icons.pin_outlined, size: 16, color: p.primary),
                      onDeleted: () => setState(() => codes.remove(c)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (receiver != null)
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, icon: const Icon(Icons.person_outline_rounded), label: Text('theReceiver'.tr)),
                ButtonSegment(value: false, icon: const Icon(Icons.people_outline_rounded), label: Text('someoneElse'.tr)),
              ],
              selected: {isReceiver},
              onSelectionChanged: (v) => setState(() {
                isReceiver = v.first;
                name.text = isReceiver ? receiver.name : '';
                phone.text = isReceiver ? receiver.phoneNumber : '';
              }),
            ),
          const SizedBox(height: 16),
          AppField(
            controller: name,
            label: 'collectorName'.tr,
            icon: Icons.badge_outlined,
            required: true,
            readOnly: isReceiver && receiver != null,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          PhoneField(controller: phone, readOnly: isReceiver && receiver != null),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppDropdown<String>(
                  label: 'idType'.tr,
                  value: idType,
                  items: idTypes,
                  required: false,
                  itemLabel: idTypeLabel,
                  onChanged: (v) => setState(() => idType = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: AppField(controller: idNumber, label: 'idNumber'.tr, icon: Icons.numbers_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel('collectorSignature'.tr),
          SignaturePad(controller: signature),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final img = await pickImage();
                  if (img != null) setState(() => photo = img);
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(photo == null ? 'collectorPhoto'.tr : 'retakePhoto'.tr),
              ),
              if (photo != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(photo!.bytes, width: 52, height: 52, fit: BoxFit.cover),
                ),
                IconButton(onPressed: () => setState(() => photo = null), icon: Icon(Icons.close_rounded, color: p.muted)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded),
        ],
      );
    },
    onSubmit: () async {
      if (owing && !onCredit) {
        throw Exception('handoverNeedsPayment'.trParams({'amount': Fmt.tsh(debt.balance)}));
      }
      if (chooseItems && taking() <= 0) throw Exception('chooseCartons'.tr);
      if (code.text.trim().isNotEmpty) addCodes(code.text);
      if (needsCode && !canCredit && codes.isEmpty) throw Exception('officeCodeAsk'.tr);
      final Uint8List? png = await signature.toPng();
      if (png == null && idNumber.text.trim().isEmpty) {
        throw Exception('signatureOrId'.tr);
      }
      await HandoverRepo.create(
        items: chooseItems && !takeAll() ? Map<String, double>.from(take) : null,
        invoiceId: invoice.id,
        collectorName: name.text,
        collectorPhone: Phone.forApi(phone.text),
        idType: idNumber.text.trim().isEmpty ? null : idType,
        idNumber: idNumber.text,
        isReceiver: isReceiver,
        onCredit: onCredit,
        note: note.text,
        officeCodes: List<String>.from(codes),
        signaturePng: png,
        photoBytes: photo?.bytes,
        photoName: photo?.name,
      );
    },
  );
  signature.dispose();
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(name.text, title: 'handedOver'.tr);
  }
  return ok;
}

/// Hati ya makabidhiano (PDF). [handoverId] = makabidhiano maalum (null = ya mwisho).
Future<void> openHandoverNote(Invoice invoice, {String? handoverId}) async {
  try {
    final bytes = await HandoverRepo.pdf(invoice.id, handoverId: handoverId);
    await PdfViewerPage.open(
      title: '${'handoverNote'.tr} ${invoice.number}',
      bytes: bytes,
      fileName: 'makabidhiano_${invoice.invoiceNumber}',
    );
  } catch (e) {
    Toast.error(e);
  }
}
