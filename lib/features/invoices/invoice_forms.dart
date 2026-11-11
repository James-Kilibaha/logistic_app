import 'dart:math';
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
import '../../data/lookups.dart';
import '../../data/models/invoice.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../settings/rate_forms.dart';
import 'photo_qr.dart';

// ------------------------------------------------------------- code ya ofisi

/// Herufi zisizochanganya (hakuna 0/O, 1/I/L) - kama za backend.
const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String newOfficeCode() {
  final r = Random.secure();
  return List.generate(6, (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)]).join();
}

/// Kisanduku kinachoonyesha code ya ofisi (kwenye fomu na ukurasa wa ankara).
class OfficeCodeBadge extends StatelessWidget {
  final String code;
  final bool dense;

  const OfficeCodeBadge(this.code, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 4 : 8),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.primary.withValues(alpha: .4)),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: dense ? 15 : 20,
          letterSpacing: 2,
          color: p.primary,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bidhaa

/// Kuongeza bidhaa kwenye invoice ([product] == null) au kuibadilisha.
Future<bool> showProductForm(Invoice invoice, {Product? product}) async {
  List<Price> prices;
  try {
    prices = (await Lookups.to.loadPrices()).toList();
  } catch (e) {
    Toast.error(e);
    return false;
  }

  final description = TextEditingController(text: product?.description ?? '');
  final track = TextEditingController(text: product?.trackNumber ?? '');
  final quantity = TextEditingController(text: product == null ? '1' : Fmt.number(product.quantities));
  final weight = TextEditingController(text: product == null ? '' : Fmt.number(product.weight));
  final amount = TextEditingController(text: product == null ? '' : Fmt.money(product.unitPrice));
  final length = TextEditingController(text: product?.length == null ? '' : Fmt.number(product!.length));
  final width = TextEditingController(text: product?.width == null ? '' : Fmt.number(product!.width));
  final height = TextEditingController(text: product?.height == null ? '' : Fmt.number(product!.height));

  String carrier = product?.carrierType.toUpperCase() == 'SEA' ? 'SEA' : 'AIR';
  Price? price;
  for (final pr in prices) {
    if (pr.id == product?.priceId) price = pr;
  }
  price ??= (carrier == 'SEA'
          ? prices.where((p) => p.isCbm).followedBy(prices.where((p) => !p.isCbm))
          : prices.where((p) => !p.isCbm))
      .firstOrNull;
  PickedImage? image;
  bool autoAmount = product == null;

  // Code ya ofisi ya mzigo huu: mfumo unaitengeneza (au andika yako). Haibadiliki baada ya kusajiliwa
  // kwa sababu mteja ameshaipata kwa SMS.
  final officeCode = TextEditingController(text: product?.officeCode ?? newOfficeCode());

  // Web/kompyuta: QR ya code ya ofisi -> simu inapiga picha ya mzigo na inaonekana hapa (inaunganishwa ukihifadhi).
  final bool showQr = product == null && !isMobileDevice;
  Uint8List? phonePhoto;
  StateSetter? sheetSet;
  final watcher = showQr
      ? (PhotoWatcher(
          code: () => officeCode.text,
          onChange: (s) async {
            if (s['staged'] != true) return;
            try {
              final bytes = await PhotoRepo.staged(officeCode.text);
              sheetSet?.call(() => phonePhoto = bytes);
              Toast.success('photoWillAttach'.tr, title: 'photoFromPhone'.tr);
            } catch (_) {}
          },
        )..start())
      : null;

  /// CBM ya katoni moja (vipimo kwa cm).
  double cartonCbm() {
    final l = Fmt.parse(length.text) ?? 0, w = Fmt.parse(width.text) ?? 0, h = Fmt.parse(height.text) ?? 0;
    return l * w * h / 1000000;
  }

  /// CBM ya mzigo wote = katoni moja x idadi ya katoni.
  double cbm() {
    final cartons = Fmt.parse(quantity.text) ?? 1;
    return cartonCbm() * (cartons < 1 ? 1 : cartons);
  }

  /// Kiasi kinachotozwa: CBM (bei ya CBM) au kilo.
  double chargeQty() => price != null && price!.isCbm ? cbm() : (Fmt.parse(weight.text) ?? 0);

  // Ndege: bei za kilo tu. Meli: bei za CBM kwanza, kisha za kilo.
  List<Price> pricesFor(String c) {
    final kg = prices.where((p) => !p.isCbm).toList();
    if (c != 'SEA') return kg;
    return [...prices.where((p) => p.isCbm), ...kg];
  }

  void recalc() {
    if (!autoAmount || price == null) return;
    final qty = chargeQty();
    if (qty <= 0) return;
    amount.text = Fmt.money(price!.totalFor(qty).roundToDouble());
  }

  void pickDefaultPrice() {
    final list = pricesFor(carrier);
    if (price == null || !list.contains(price)) price = list.isEmpty ? null : list.first;
  }

  final ok = await showFormSheet(
    help: 'formProduct',
    title: product == null ? 'addProduct'.tr : 'editProduct'.tr,
    subtitle: '${'invoice'.tr} ${invoice.number} · ${invoice.customer?.name ?? ''}',
    icon: product == null ? Icons.add_box_outlined : Icons.edit_outlined,
    submitLabel: product == null ? 'addProduct'.tr : 'saveChanges'.tr,
    maxWidth: 640,
    builder: (context, setState) {
      sheetSet = setState;
      final p = context.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (product == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _withQr(
                showQr,
                officeCode,
                AppField(
                controller: officeCode,
                label: 'officeCode'.tr,
                helper: 'officeCodeHelp'.tr,
                icon: Icons.pin_outlined,
                required: true,
                capitalization: TextCapitalization.characters,
                suffix: IconButton(
                  tooltip: 'generate'.tr,
                  icon: Icon(Icons.autorenew_rounded, color: p.primary),
                  onPressed: () => setState(() => officeCode.text = newOfficeCode()),
                ),
              ),
              ),
            )
          else if (officeCode.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.pin_outlined, color: p.muted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('officeCode'.tr, style: TextStyle(color: p.muted))),
                  OfficeCodeBadge(officeCode.text, dense: true),
                ],
              ),
            ),
          AppField(
            controller: description,
            label: 'description'.tr,
            hint: 'descriptionHint'.tr,
            icon: Icons.inventory_2_outlined,
            required: true,
            capitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppField(
            controller: track,
            label: 'trackNumber'.tr,
            hint: 'trackNumberHint'.tr,
            icon: Icons.qr_code_2_rounded,
            suffix: IconButton(
              tooltip: 'scanCode'.tr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final code = await scanCode(title: 'trackNumber'.tr);
                if (code != null) setState(() => track.text = code);
              },
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel('carrierType'.tr, required: true),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'AIR', icon: const Icon(Icons.flight_takeoff_rounded), label: Text('air'.tr)),
              ButtonSegment(value: 'SEA', icon: const Icon(Icons.directions_boat_outlined), label: Text('sea'.tr)),
            ],
            selected: {carrier},
            onSelectionChanged: (v) => setState(() {
              carrier = v.first;
              if (carrier == 'SEA') {
                final cbmPrices = prices.where((p) => p.isCbm).toList();
                if (cbmPrices.isNotEmpty && autoAmount) price = cbmPrices.first;
              }
              pickDefaultPrice();
              recalc();
            }),
          ),
          const SizedBox(height: 16),
          FieldRow(children: [
            AppField.number(
              controller: quantity,
              label: 'cartons'.tr,
              icon: Icons.layers_outlined,
              onChanged: (_) => setState(recalc),
            ),
            AppField.number(
              controller: weight,
              label: 'weight'.tr,
              icon: Icons.scale_outlined,
              suffixText: 'kg',
              onChanged: (_) => setState(recalc),
            ),
          ]),
          if (carrier == 'SEA') ...[
            const SizedBox(height: 16),
            FieldLabel('cartonSize'.tr),
            FieldRow(children: [
              AppField.number(controller: length, label: 'length'.tr, suffixText: 'cm', onChanged: (_) => setState(recalc)),
              AppField.number(controller: width, label: 'width'.tr, suffixText: 'cm', onChanged: (_) => setState(recalc)),
              AppField.number(controller: height, label: 'height'.tr, suffixText: 'cm', onChanged: (_) => setState(recalc)),
            ]),
            const SizedBox(height: 6),
            Text(
              'cbmLine'.trParams({
                'one': cartonCbm().toStringAsFixed(3),
                'n': Fmt.number(Fmt.parse(quantity.text) ?? 1),
                'total': cbm().toStringAsFixed(3),
              }),
              style: TextStyle(color: p.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          PricePicker(
            prices: pricesFor(carrier),
            selected: price,
            onSelected: (v) => setState(() {
              price = v;
              autoAmount = true;
              recalc();
            }),
            onAddPrice: AppController.to.can(AppModule.price, AppAction.insert)
                ? () async {
                    if (await showPriceForm()) {
                      setState(() {
                        prices = Lookups.to.prices.toList();
                        if (prices.isNotEmpty) price = prices.first;
                        pickDefaultPrice();
                        autoAmount = true;
                        recalc();
                      });
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),
          AppField.money(
            controller: amount,
            label: 'amountTsh'.tr,
            helper: autoAmount ? 'amountAutoHint'.tr : null,
            onChanged: (_) => setState(() => autoAmount = false),
          ),
          if (price != null && chargeQty() > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined, size: 18, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${price!.isCbm ? '${chargeQty().toStringAsFixed(3)} CBM' : Fmt.kg(chargeQty())} × '
                      '${Fmt.tsh(price!.costPerKgLocal)} = ${Fmt.tsh(price!.totalFor(chargeQty()))}'
                      '  (≈ ${price!.name} ${Fmt.money2(chargeQty() / (price!.weight > 0 ? price!.weight : 1) * price!.cost)})',
                      style: TextStyle(color: p.text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (product == null) ...[
            const SizedBox(height: 16),
            FieldLabel('photo'.tr),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: image != null
                      ? Image.memory(image!.bytes, fit: BoxFit.cover)
                      : phonePhoto != null
                          ? Image.memory(phonePhoto!, fit: BoxFit.cover)
                          : Icon(Icons.image_outlined, color: p.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isMobileDevice)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await pickImage(camera: true);
                            if (picked != null) setState(() => image = picked);
                          },
                          icon: const Icon(Icons.photo_camera_outlined, size: 18),
                          label: Text('takePhoto'.tr),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await pickImage(camera: false);
                          if (picked != null) setState(() => image = picked);
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text('choosePhoto'.tr),
                      ),
                      if (image != null)
                        TextButton(onPressed: () => setState(() => image = null), child: Text('remove'.tr))
                      else if (phonePhoto != null)
                        TextButton(
                          onPressed: () {
                            PhotoRepo.discard(officeCode.text).catchError((_) {});
                            setState(() => phonePhoto = null);
                          },
                          child: Text('remove'.tr),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
    onSubmit: () async {
      final input = ProductInput(
        id: product?.id,
        invoiceId: invoice.id,
        description: description.text,
        trackNumber: track.text,
        carrierType: carrier,
        quantities: Fmt.parse(quantity.text) ?? 1,
        weight: Fmt.parse(weight.text) ?? 0,
        unitPrice: Fmt.parse(amount.text) ?? 0,
        priceId: price?.id,
        length: carrier == 'SEA' ? Fmt.parse(length.text) : null,
        width: carrier == 'SEA' ? Fmt.parse(width.text) : null,
        height: carrier == 'SEA' ? Fmt.parse(height.text) : null,
        officeCode: product == null ? officeCode.text : null,
      );
      if (product == null) {
        await InvoiceRepo.addProduct(input, imageBytes: image?.bytes, imageName: image?.name);
      } else {
        await InvoiceRepo.updateProduct(input);
      }
    },
  );
  watcher?.stop();

  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(description.text, title: product == null ? 'productAdded'.tr : 'changesSaved'.tr);
  }
  return ok;
}

/// Sehemu ya code ya ofisi pamoja na QR yake pembeni (web/kompyuta).
Widget _withQr(bool show, TextEditingController code, Widget field) {
  if (!show) return field;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: field),
      const SizedBox(width: 12),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: code,
        builder: (context, v, _) => OfficeCodeQr(v.text, size: 96),
      ),
    ],
  );
}

Future<bool> deleteProduct(Product product) async {
  final ok = await confirmAction(
    title: 'deleteProduct'.tr,
    message: 'deleteProductMsg'.trParams({'name': product.description}),
    confirmText: 'delete'.tr,
    icon: Icons.delete_outline_rounded,
    danger: true,
  );
  if (!ok) return false;
  final done = await runGuarded(() => InvoiceRepo.deleteProduct(product.id), success: 'deleted'.tr);
  if (done) AppController.to.notifyChanged();
  return done;
}

// --------------------------------------------------------------- mpokeaji

/// Kusajili mpokeaji: invoice inakuwa tayari kupakiwa (PARKING). [current] != null = kuhariri.
Future<bool> showReceiverForm(Invoice invoice, {Receiver? current}) async {
  final customer = invoice.customer;

  String generate() {
    final r = Random().nextInt(9000) + 1000;
    return 'R${invoice.invoiceNumber}-$r';
  }

  // Kwa kawaida mpokeaji ni mteja mwenyewe (aliyetuma mzigo).
  bool sameAsCustomer = current == null
      ? customer != null
      : customer != null && current.name == customer.name && current.phoneNumber == customer.phoneNumber;
  final name = TextEditingController(text: current?.name ?? customer?.name ?? '');
  final phone = TextEditingController(text: current?.phoneNumber ?? customer?.phoneNumber ?? '');
  final track = TextEditingController(text: current?.trackNumber ?? generate());

  final ok = await showFormSheet(
    help: 'formReceiver',
    title: current == null ? 'registerReceiver'.tr : 'editReceiver'.tr,
    subtitle: 'registerReceiverSub'.tr,
    icon: Icons.person_pin_circle_outlined,
    submitLabel: current == null ? 'registerReceiver'.tr : 'saveChanges'.tr,
    builder: (context, setState) {
      final p = context.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (customer != null) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, icon: const Icon(Icons.person_rounded), label: Text('receiverIsSender'.tr)),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text('receiverIsOther'.tr),
                ),
              ],
              selected: {sameAsCustomer},
              onSelectionChanged: (v) => setState(() {
                sameAsCustomer = v.first;
                if (sameAsCustomer) {
                  name.text = customer.name;
                  phone.text = customer.phoneNumber;
                } else {
                  // Futa taarifa za mtumaji ili ujaze za mpokeaji mwingine.
                  name.clear();
                  phone.clear();
                }
              }),
            ),
            const SizedBox(height: 16),
          ],
          if (sameAsCustomer && customer != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: p.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                        Text(Fmt.phone(customer.phoneNumber), style: TextStyle(color: p.muted)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      sameAsCustomer = false;
                      name.clear();
                      phone.clear();
                    }),
                    child: Text('change'.tr),
                  ),
                ],
              ),
            )
          else ...[
            AppField(
              controller: name,
              label: 'receiverName'.tr,
              icon: Icons.badge_outlined,
              required: true,
              autofocus: customer != null,
              capitalization: TextCapitalization.words,
              suffix: name.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'clear'.tr,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(name.clear),
                    ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            PhoneField(controller: phone),
          ],
          const SizedBox(height: 16),
          AppField(
            controller: track,
            label: 'pickupCode'.tr,
            helper: 'pickupCodeHelp'.tr,
            icon: Icons.qr_code_2_rounded,
            required: true,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'generate'.tr,
                  icon: Icon(Icons.autorenew_rounded, color: p.primary),
                  onPressed: () => setState(() => track.text = generate()),
                ),
                IconButton(
                  tooltip: 'scanCode'.tr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () async {
                    final code = await scanCode(title: 'pickupCode'.tr);
                    if (code != null) setState(() => track.text = code);
                  },
                ),
              ],
            ),
          ),
        ],
      );
    },
    onSubmit: () => current == null
        ? InvoiceRepo.addReceiver(
            invoiceId: invoice.id,
            name: name.text,
            phone: Phone.forApi(phone.text),
            trackNumber: track.text,
            customerId: invoice.customerId,
          )
        : InvoiceRepo.updateReceiver(
            id: current.id,
            name: name.text,
            phone: Phone.forApi(phone.text),
            trackNumber: track.text,
          ),
  );
  if (ok) {
    AppController.to.notifyChanged();
    if (current == null) {
      Toast.success('readyForPackingMsg'.tr, title: 'receiverRegistered'.tr);
    } else {
      Toast.success(name.text, title: 'changesSaved'.tr);
    }
  }
  return ok;
}

/// Kufuta mpokeaji aliyesajiliwa kimakosa: ankara inarudi kuwa wazi ili asajiliwe mpokeaji sahihi.
Future<bool> deleteReceiver(Invoice invoice, Receiver receiver) async {
  final ok = await confirmAction(
    title: 'deleteReceiver'.tr,
    message: 'deleteReceiverMsg'.trParams({'name': receiver.name}),
    confirmText: 'delete'.tr,
    icon: Icons.person_remove_outlined,
    danger: true,
  );
  if (!ok) return false;
  final done = await runGuarded(() => InvoiceRepo.deleteReceiver(receiver.id), success: 'deleted'.tr);
  if (done) AppController.to.notifyChanged();
  return done;
}

// ---------------------------------------------------------------- malipo

Future<bool> showPaymentForm(Invoice invoice, Debt debt) async {
  List<Institute> institutes;
  List<Currency> currencies;
  try {
    institutes = await Lookups.to.loadInstitutes();
    currencies = await Lookups.to.loadCurrencies();
  } catch (e) {
    Toast.error(e);
    return false;
  }
  if (institutes.isEmpty) {
    Toast.warning('noInstitutesMsg'.tr, title: 'noInstitutes'.tr);
    return false;
  }

  // TZS + sarafu zenye kiwango (USD ...)
  final codes = <String>['TZS', ...currencies.map((c) => c.name.toUpperCase()).where((c) => c != 'TZS').toSet()];
  double rateOf(String code) {
    if (code == 'TZS') return 1;
    for (final c in currencies) {
      if (c.name.toUpperCase() == code) return c.buy;
    }
    return 0;
  }

  String currency = 'TZS';
  final amount = TextEditingController(text: Fmt.money(debt.balance));
  final note = TextEditingController();
  Institute? institute = institutes.first;
  Payment? saved;

  double inTzs() => (Fmt.parse(amount.text) ?? 0) * rateOf(currency);

  final ok = await showFormSheet(
    help: 'formPayment',
    title: 'receivePayment'.tr,
    subtitle: '${'invoice'.tr} ${invoice.number} · ${invoice.customer?.name ?? ''}',
    icon: Icons.payments_outlined,
    submitLabel: 'savePayment'.tr,
    submitIcon: Icons.check_circle_outline_rounded,
    builder: (context, setState) {
      final p = context.palette;
      final rate = rateOf(currency);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtBreakdown(debt: debt),
          const SizedBox(height: 18),
          if (codes.length > 1) ...[
            FieldLabel('currency'.tr),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final c in codes) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (v) => setState(() {
                currency = v.first;
                final r = rateOf(currency);
                amount.text = r <= 0 ? '' : (currency == 'TZS' ? Fmt.money(debt.balance) : Fmt.money2(debt.balance / r));
              }),
            ),
            const SizedBox(height: 16),
          ],
          AppField.money(
            controller: amount,
            label: currency == 'TZS' ? 'amountPaid'.tr : '${'amountPaid'.tr} ($currency)',
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = Fmt.parse(v);
              if (n == null) return 'fieldRequired'.tr;
              if (n <= 0) return 'mustBePositive'.tr;
              if (rate <= 0) return 'noRateFor'.trParams({'c': currency});
              if (n * rate > debt.balance + 1) return 'amountTooHigh'.tr;
              return null;
            },
          ),
          if (currency != 'TZS' && rate > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'convertedTo'.trParams({'rate': Fmt.money(rate), 'tzs': Fmt.tsh(inTzs())}),
                style: TextStyle(color: p.primary, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),
          AppDropdown<Institute>(
            label: 'paidThrough'.tr,
            value: institute,
            items: institutes,
            icon: Icons.account_balance_outlined,
            itemLabel: (i) => i.label,
            onChanged: (v) => setState(() => institute = v),
          ),
          const SizedBox(height: 16),
          AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded),
        ],
      );
    },
    onSubmit: () async {
      saved = await PaymentRepo.pay(
        debtId: debt.id,
        instituteId: institute!.id,
        amount: Fmt.parse(amount.text) ?? 0,
        currency: currency,
        note: note.text,
      );
    },
  );
  if (ok) {
    AppController.to.notifyChanged();
    final pay = saved;
    Toast.success(
      pay?.receiptNumber == null ? Fmt.tsh(pay?.paid) : '${Fmt.tsh(pay!.paid)} · ${'receipt'.tr} ${pay.receiptNumber}',
      title: 'paymentSaved'.tr,
    );
    if (pay != null) await openReceipt(pay);
  }
  return ok;
}

/// Kufungua risiti ya malipo (PDF) - inaweza kuchapishwa au kushirikiwa.
Future<void> openReceipt(Payment payment) async {
  try {
    final bytes = await PaymentRepo.receipt(payment.id);
    await PdfViewerPage.open(
      title: '${'receipt'.tr} ${payment.receiptNumber ?? ''}',
      bytes: bytes,
      fileName: 'risiti_${payment.receiptNumber ?? payment.id}',
    );
  } catch (e) {
    Toast.error(e);
  }
}

/// Punguzo kwa ankara (linabadilisha punguzo lililopo; 0 = kuondoa).
Future<bool> showDiscountForm(Invoice invoice, Debt debt) async {
  final amount = TextEditingController(text: debt.discount > 0 ? Fmt.money(debt.discount) : '');
  final note = TextEditingController(text: debt.discountNote ?? '');
  final gross = debt.amount + debt.storageCharge;
  final ok = await showFormSheet(
    help: 'formDiscount',
    title: 'giveDiscount'.tr,
    subtitle: '${'invoice'.tr} ${invoice.number} · ${'total'.tr} ${Fmt.tsh(gross)}',
    icon: Icons.percent_rounded,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField.money(
          controller: amount,
          label: 'discountAmount'.tr,
          helper: 'discountHelp'.tr,
          validator: (v) {
            final n = Fmt.parse(v);
            if (n == null) return 'fieldRequired'.tr;
            if (n < 0) return 'mustBePositive'.tr;
            if (n > gross) return 'amountTooHigh'.tr;
            return null;
          },
        ),
        const SizedBox(height: 16),
        AppField(controller: note, label: 'reason'.tr, icon: Icons.notes_rounded, required: true),
      ],
    ),
    onSubmit: () => PaymentRepo.discount(debtId: debt.id, amount: Fmt.parse(amount.text) ?? 0, note: note.text),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(Fmt.tsh(Fmt.parse(amount.text)), title: 'discountSaved'.tr);
  }
  return ok;
}

/// Kurudisha pesa kwa mteja (refund) - haiwezi kuzidi kilicholipwa.
Future<bool> showRefundForm(Invoice invoice, Debt debt) async {
  List<Institute> institutes;
  try {
    institutes = await Lookups.to.loadInstitutes();
  } catch (e) {
    Toast.error(e);
    return false;
  }
  if (institutes.isEmpty) return false;
  final amount = TextEditingController();
  final note = TextEditingController();
  Institute? institute = institutes.first;
  Payment? saved;
  final ok = await showFormSheet(
    help: 'formRefund',
    title: 'refund'.tr,
    subtitle: '${'invoice'.tr} ${invoice.number} · ${'paid'.tr} ${Fmt.tsh(debt.paid)}',
    icon: Icons.undo_rounded,
    danger: true,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField.money(
          controller: amount,
          label: 'refundAmount'.tr,
          validator: (v) {
            final n = Fmt.parse(v);
            if (n == null) return 'fieldRequired'.tr;
            if (n <= 0) return 'mustBePositive'.tr;
            if (n > debt.paid + 1) return 'amountTooHigh'.tr;
            return null;
          },
        ),
        const SizedBox(height: 16),
        AppDropdown<Institute>(
          label: 'refundThrough'.tr,
          value: institute,
          items: institutes,
          icon: Icons.account_balance_outlined,
          itemLabel: (i) => i.label,
          onChanged: (v) => setState(() => institute = v),
        ),
        const SizedBox(height: 16),
        AppField(controller: note, label: 'reason'.tr, icon: Icons.notes_rounded, required: true),
      ],
    ),
    onSubmit: () async {
      saved = await PaymentRepo.refund(
        debtId: debt.id,
        instituteId: institute!.id,
        amount: Fmt.parse(amount.text) ?? 0,
        note: note.text,
      );
    },
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(Fmt.tsh(Fmt.parse(amount.text)), title: 'refundSaved'.tr);
    if (saved != null) await openReceipt(saved!);
  }
  return ok;
}

/// Mchanganuo wa deni: usafirishaji + stoo - punguzo, kilicholipwa na kilichobaki.
class DebtBreakdown extends StatelessWidget {
  final Debt debt;

  const DebtBreakdown({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _line(p, 'freight'.tr, Fmt.tsh(debt.amount)),
          if (debt.storageCharge > 0)
            _line(p, 'storageDays'.trParams({'n': '${debt.days}'}), Fmt.tsh(debt.storageCharge), color: p.warning),
          if (debt.discount > 0) _line(p, 'discount'.tr, '- ${Fmt.tsh(debt.discount)}', color: p.success),
          if (debt.storageCharge > 0 || debt.discount > 0) _line(p, 'invoiceTotal'.tr, Fmt.tsh(debt.total), bold: true),
          _line(p, 'paid'.tr, Fmt.tsh(debt.paid), color: p.success),
          Divider(color: p.border),
          _line(p, 'balanceDue'.tr, Fmt.tsh(debt.balance < 0 ? 0 : debt.balance),
              color: debt.isPaid ? p.success : p.danger, bold: true),
        ],
      ),
    );
  }
}

Widget _line(AppPalette p, String label, String value, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: p.muted))),
          Text(
            value,
            style: TextStyle(
              color: color ?? p.text,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
