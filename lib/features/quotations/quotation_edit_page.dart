import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/quotation.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';

/// Bidhaa moja kwenye fomu (controllers zake).
class _Line {
  final TextEditingController description;
  final TextEditingController cartons;
  final TextEditingController kg;
  final TextEditingController cbm;
  final TextEditingController amount;
  String carrier;
  bool manual;
  String unit;
  double rate;
  String? priceId;

  _Line({QuotationItem? item})
      : description = TextEditingController(text: item?.description ?? ''),
        cartons = TextEditingController(text: item == null ? '1' : Fmt.money(item.quantities)),
        kg = TextEditingController(text: item == null || item.weight == 0 ? '' : Fmt.money2(item.weight)),
        cbm = TextEditingController(text: item == null || item.cbm == 0 ? '' : item.cbm.toStringAsFixed(3)),
        amount = TextEditingController(text: item == null ? '' : Fmt.money(item.amount)),
        carrier = item?.carrierType ?? 'AIR',
        // kiasi kisicholingana na hesabu (kipimo x bei) kiliandikwa kwa mkono - kisiandikwe upya
        manual = item != null && (item.amount - (item.unit == 'CBM' ? item.cbm : item.weight) * item.rate).abs() > 1,
        unit = item?.unit ?? 'KG',
        rate = item?.rate ?? 0,
        priceId = item?.priceId;

  bool get isSea => carrier == 'SEA';

  QuotationItem toItem() => QuotationItem(
        description: description.text.trim(),
        carrierType: carrier,
        quantities: Fmt.parse(cartons.text) ?? 0,
        weight: Fmt.parse(kg.text) ?? 0,
        cbm: isSea ? (Fmt.parse(cbm.text) ?? 0) : 0,
        priceId: null, // seva inachagua bei ya sasa ya usafiri huu
        amount: Fmt.parse(amount.text) ?? 0,
        manual: manual,
      );

  void dispose() {
    for (final c in [description, cartons, kg, cbm, amount]) {
      c.dispose();
    }
  }
}

/// Kuunda / kubadilisha makadirio ya bei. Bei inahesabiwa na seva kila unapobadilisha (ndege = kilo, meli = CBM).
class QuotationEditPage extends StatefulWidget {
  final Quotation? quotation;

  const QuotationEditPage({super.key, this.quotation});

  static Future<Quotation?> open({Quotation? quotation}) =>
      Get.to<Quotation>(() => QuotationEditPage(quotation: quotation)) ?? Future.value(null);

  @override
  State<QuotationEditPage> createState() => _QuotationEditPageState();
}

class _QuotationEditPageState extends State<QuotationEditPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.quotation?.customerName ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.quotation?.phoneNumber ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.quotation?.note ?? '');
  late String? _customerId = widget.quotation?.customerId;
  int _validDays = 14;
  late final List<_Line> _lines = [
    for (final i in widget.quotation?.items ?? const <QuotationItem>[]) _Line(item: i),
    if (widget.quotation == null || widget.quotation!.items.isEmpty) _Line(),
  ];
  double _total = 0;
  bool _calculating = false;
  bool _saving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _total = widget.quotation?.total ?? 0;
    _recalculate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final l in _lines) {
      l.dispose();
    }
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _recalculate);
  }

  Future<void> _recalculate() async {
    final items = [for (final l in _lines) l.toItem()];
    if (items.every((i) => i.description.isEmpty && i.weight == 0 && i.cbm == 0)) return;
    setState(() => _calculating = true);
    try {
      final res = await QuotationRepo.calculate([
        for (final i in items) i.description.isEmpty ? i.copyWith(description: '-') : i,
      ]);
      if (!mounted) return;
      setState(() {
        for (int k = 0; k < _lines.length && k < res.items.length; k++) {
          final line = _lines[k];
          final r = res.items[k];
          line.unit = r.unit;
          line.rate = r.rate;
          line.priceId = r.priceId;
          if (!line.manual) line.amount.text = Fmt.money(r.amount);
        }
        _total = res.total;
      });
    } catch (_) {
      // hesabu itajaribiwa tena ukibadilisha kitu
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _pickCustomer() async {
    final c = await InvoiceFlows.pickCustomer();
    if (c == null) return;
    setState(() {
      _customerId = c.id;
      _name.text = c.name;
      _phone.text = c.phoneNumber;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final items = [for (final l in _lines) l.toItem()].where((i) => i.description.isNotEmpty).toList();
    if (items.isEmpty) {
      Toast.warning('quotationNeedsItem'.tr);
      return;
    }
    setState(() => _saving = true);
    try {
      final q = await QuotationRepo.save(
        id: widget.quotation?.id,
        customerId: _customerId,
        customerName: _name.text,
        phoneNumber: _phone.text.trim().isEmpty ? null : Phone.forApi(_phone.text),
        validDays: _validDays,
        note: _note.text,
        items: items,
      );
      Toast.success(q.number, title: 'saved'.tr);
      Get.back(result: q);
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppPage(
      help: 'quotations',
      title: widget.quotation == null ? 'newQuotation'.tr : '${'quotation'.tr} #${widget.quotation!.number}',
      subtitle: 'quotationEditSub'.tr,
      showBack: true,
      mainAction: PageAction(
        icon: Icons.save_outlined,
        label: 'save'.tr,
        onPressed: () {
          if (!_saving) _save();
        },
      ),
      body: Form(
        key: _form,
        child: PageScroll(
          children: [
            SectionCard(
              title: 'customer'.tr,
              icon: Icons.person_outline_rounded,
              trailing: TextButton.icon(
                onPressed: _pickCustomer,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: Text('chooseCustomer'.tr),
              ),
              child: Column(
                children: [
                  AppField(
                    controller: _name,
                    label: 'fullName'.tr,
                    icon: Icons.badge_outlined,
                    required: true,
                    onChanged: (_) => _customerId = null,
                  ),
                  const SizedBox(height: 14),
                  PhoneField(controller: _phone, onChanged: (_) => _customerId = null),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<int>(
                          label: 'quotationValid'.tr,
                          value: _validDays,
                          items: const [7, 14, 30, 60],
                          itemLabel: (d) => 'daysN'.trParams({'n': '$d'}),
                          icon: Icons.event_available_outlined,
                          onChanged: (v) => setState(() => _validDays = v ?? 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'items'.tr,
              subtitle: 'quotationItemsSub'.tr,
              icon: Icons.inventory_2_outlined,
              trailing: _calculating
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < _lines.length; i++) ...[
                    if (i > 0) Divider(height: 28, color: p.border),
                    _lineEditor(context, i),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _lines.add(_Line())),
                    icon: const Icon(Icons.add_rounded),
                    label: Text('addItem'.tr),
                  ),
                ],
              ),
            ),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('total'.tr, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(Fmt.tsh(_total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppField(controller: _note, label: 'note'.tr, icon: Icons.notes_rounded, maxLines: 3, minLines: 1),
                  const SizedBox(height: 8),
                  Text('quotationDisclaimer'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineEditor(BuildContext context, int i) {
    final p = context.palette;
    final l = _lines[i];
    final rateText = l.rate > 0 ? '${Fmt.tsh(l.rate)} / ${l.unit == 'CBM' ? 'CBM' : 'kg'}' : 'noPriceYet'.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: l.description,
                label: '${'description'.tr} ${i + 1}',
                icon: Icons.inventory_2_outlined,
                required: true,
                onChanged: (_) => _changed(),
              ),
            ),
            if (_lines.length > 1)
              IconButton(
                tooltip: 'remove'.tr,
                onPressed: () {
                  setState(() => _lines.removeAt(i).dispose());
                  _changed();
                },
                icon: Icon(Icons.delete_outline_rounded, color: p.danger),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'AIR', icon: const Icon(Icons.flight_outlined), label: Text('airKg'.tr)),
            ButtonSegment(value: 'SEA', icon: const Icon(Icons.directions_boat_outlined), label: Text('seaCbm'.tr)),
          ],
          selected: {l.carrier},
          onSelectionChanged: (v) {
            setState(() => l.carrier = v.first);
            _changed();
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 120,
              child: AppField.number(controller: l.cartons, label: 'cartons'.tr, onChanged: (_) => _changed()),
            ),
            SizedBox(
              width: 150,
              child: AppField.number(
                controller: l.kg,
                label: l.isSea ? 'weightKgTons'.tr : 'weightKg'.tr,
                required: !l.isSea,
                onChanged: (_) => _changed(),
              ),
            ),
            if (l.isSea)
              SizedBox(
                width: 150,
                child: AppField.number(controller: l.cbm, label: 'CBM', required: true, onChanged: (_) => _changed()),
              ),
            SizedBox(
              width: 190,
              child: AppField.money(
                controller: l.amount,
                label: 'amount'.tr,
                helper: l.manual ? 'amountManual'.tr : rateText,
                onChanged: (_) => setState(() => l.manual = true),
              ),
            ),
            if (l.manual)
              TextButton.icon(
                onPressed: () {
                  setState(() => l.manual = false);
                  _recalculate();
                },
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: Text('recalculate'.tr),
              ),
          ],
        ),
        if (l.isSea && (Fmt.parse(l.kg.text) ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${'tons'.tr}: ${((Fmt.parse(l.kg.text) ?? 0) / 1000).toStringAsFixed(2)}',
                style: TextStyle(color: p.muted, fontSize: 12.5)),
          ),
      ],
    );
  }
}
