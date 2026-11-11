import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/lookups.dart';
import '../../data/models/settings.dart';
import '../../data/repositories.dart';

/// Sarafu zinazotumika mara nyingi (zinaonekana kama vitufe vya haraka).
const List<String> commonCurrencies = ['USD', 'CNY', 'EUR', 'GBP', 'AED', 'KES'];

String currencySymbol(String code) => switch (code.toUpperCase()) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'CNY' => '¥',
      'AED' => 'د.إ',
      'KES' => 'KSh',
      _ => code.toUpperCase(),
    };

/// Kusajili sarafu mpya au kubadilisha kiwango chake.
/// Kiwango kipya kinachukua nafasi ya cha zamani (cha zamani kinabaki kwenye historia),
/// na bei zote za sarafu hiyo zinaanza kutumia kiwango kipya.
Future<bool> showCurrencyForm({String? currency}) async {
  final lookups = Lookups.to;
  try {
    await lookups.loadCurrencies();
  } catch (_) {}
  String code = (currency ?? 'USD').toUpperCase();
  final custom = TextEditingController(text: commonCurrencies.contains(code) ? '' : code);
  final rate = TextEditingController();

  Currency? current() {
    for (final c in lookups.currencies) {
      if (c.name.toUpperCase() == code) return c;
    }
    return null;
  }

  final ok = await showFormSheet(
    help: 'formRate',
    title: currency == null ? 'newRate'.tr : 'changeRate'.tr,
    subtitle: 'newRateSub'.tr,
    icon: Icons.currency_exchange_rounded,
    submitLabel: 'saveRate'.tr,
    builder: (context, setState) {
      final p = context.palette;
      final existing = current();
      final value = Fmt.parse(rate.text);
      final double? change =
          existing != null && value != null && existing.buy > 0 ? (value - existing.buy) / existing.buy * 100 : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('currency'.tr, required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in commonCurrencies)
                ChoiceChip(
                  selected: code == c,
                  label: Text('${currencySymbol(c)}  $c'),
                  onSelected: (_) => setState(() {
                    code = c;
                    custom.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: custom,
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
            onChanged: (v) => setState(() => code = v.trim().isEmpty ? 'USD' : v.trim().toUpperCase()),
            decoration: InputDecoration(
              hintText: 'otherCurrencyHint'.tr,
              counterText: '',
              prefixIcon: const Icon(Icons.edit_outlined, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          if (existing != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: p.muted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${'currentRate'.tr}: 1 $code = ${Fmt.tsh(existing.buy)} · ${Fmt.date(existing.createdAt)}',
                      style: TextStyle(color: p.text),
                    ),
                  ),
                ],
              ),
            ),
          AppField.money(
            controller: rate,
            label: 'rateFor'.trParams({'code': code}),
            icon: Icons.swap_horiz_rounded,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = Fmt.parse(v);
              if (n == null) return 'fieldRequired'.tr;
              if (n <= 0) return 'mustBePositive'.tr;
              if (existing != null && (n - existing.buy).abs() < 0.0001) return 'sameRate'.tr;
              return null;
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '1 $code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.primary),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, color: p.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? 'TSh —' : Fmt.tsh(value),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
                  ),
                ),
                if (change != null)
                  Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.w700, color: change >= 0 ? p.danger : p.success),
                  ),
              ],
            ),
          ),
        ],
      );
    },
    onSubmit: () async {
      if (code.trim().isEmpty) throw Exception('fieldRequired'.tr);
      await SettingsRepo.createCurrency(code, Fmt.parse(rate.text) ?? 0);
    },
  );
  if (ok) {
    await Future.wait([lookups.loadCurrencies(force: true), lookups.loadPrices(force: true)]);
    Toast.success('1 $code = ${Fmt.tsh(Fmt.parse(rate.text))}', title: 'rateSaved'.tr);
  }
  return ok;
}

/// Kurekebisha kiwango cha sasa (kosa la kuandika) bila kuweka historia mpya.
Future<bool> showCorrectRateForm(Currency currency) async {
  final rate = TextEditingController(text: Fmt.number(currency.buy));
  final ok = await showFormSheet(
    help: 'formRate',
    title: 'correctRate'.tr,
    subtitle: 'correctRateSub'.tr,
    icon: Icons.build_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField.money(
          controller: rate,
          label: 'rateFor'.trParams({'code': currency.name}),
          icon: Icons.swap_horiz_rounded,
          validator: (v) {
            final n = Fmt.parse(v);
            if (n == null) return 'fieldRequired'.tr;
            if (n <= 0) return 'mustBePositive'.tr;
            return null;
          },
        ),
      ],
    ),
    onSubmit: () => SettingsRepo.updateCurrency(currency.id, Fmt.parse(rate.text) ?? currency.buy),
  );
  if (ok) {
    final lookups = Lookups.to;
    await Future.wait([lookups.loadCurrencies(force: true), lookups.loadPrices(force: true)]);
    Toast.success('1 ${currency.name} = ${Fmt.tsh(Fmt.parse(rate.text))}', title: 'rateSaved'.tr);
  }
  return ok;
}

/// Kuweka bei ya usafirishaji (gharama kwa kilo, kwa sarafu fulani).
/// Bei mpya yenye sarafu na uzito ule ule inachukua nafasi ya ya zamani.
Future<bool> showPriceForm({Price? current}) async {
  final lookups = Lookups.to;
  List<Currency> currencies;
  try {
    currencies = await lookups.loadCurrencies();
  } catch (e) {
    Toast.error(e);
    return false;
  }
  if (currencies.isEmpty) {
    Toast.warning('addRateFirst'.tr, title: 'noRates'.tr);
    final added = await showCurrencyForm();
    if (!added) return false;
    currencies = lookups.currencies.toList();
    if (currencies.isEmpty) return false;
  }

  Currency? currency = currencies.first;
  for (final c in currencies) {
    if (current != null && c.name.toUpperCase() == current.name.toUpperCase()) currency = c;
  }
  final weight = TextEditingController(text: current == null ? '1' : Fmt.number(current.weight));
  final cost = TextEditingController(text: current == null ? '' : Fmt.number(current.cost));
  String unit = current?.unit ?? 'KG';

  final ok = await showFormSheet(
    help: 'formRate',
    title: current == null ? 'newPrice'.tr : 'changePrice'.tr,
    subtitle: 'newPriceSub'.tr,
    icon: Icons.sell_outlined,
    builder: (context, setState) {
      final p = context.palette;
      final c = currency;
      final kg = Fmt.parse(weight.text) ?? 0;
      final amount = Fmt.parse(cost.text) ?? 0;
      final perKgLocal = c == null || kg <= 0 ? 0.0 : amount / kg * c.buy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('currency'.tr, required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in currencies)
                ChoiceChip(
                  selected: c?.id == item.id,
                  label: Text('${item.name}  ·  ${Fmt.tsh(item.buy)}'),
                  onSelected: (_) => setState(() => currency = item),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text('newRate'.tr),
                onPressed: () async {
                  if (await showCurrencyForm()) {
                    setState(() {
                      currencies = lookups.currencies.toList();
                      currency = currencies.isEmpty ? null : currencies.first;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel('priceUnit'.tr, required: true),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'KG', icon: const Icon(Icons.scale_outlined), label: Text('perKgUnit'.tr)),
              ButtonSegment(value: 'CBM', icon: const Icon(Icons.view_in_ar_outlined), label: Text('perCbmUnit'.tr)),
            ],
            selected: {unit},
            onSelectionChanged: (v) => setState(() => unit = v.first),
          ),
          const SizedBox(height: 16),
          FieldRow(children: [
            AppField.number(
              controller: cost,
              label: 'costIn'.trParams({'code': c?.name ?? ''}),
              icon: Icons.sell_outlined,
              onChanged: (_) => setState(() {}),
            ),
            AppField.number(
              controller: weight,
              label: unit == 'CBM' ? 'perVolume'.tr : 'perWeight'.tr,
              suffixText: unit == 'CBM' ? 'CBM' : 'kg',
              onChanged: (_) => setState(() {}),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined, color: p.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    perKgLocal <= 0 ? 'pricePreviewEmpty'.tr : '≈ ${Fmt.tsh(perKgLocal)} / ${unit == 'CBM' ? 'CBM' : 'kg'}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 15.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
    onSubmit: () => SettingsRepo.createPrice(
      currencyId: currency!.id,
      weight: Fmt.parse(weight.text) ?? 1,
      cost: Fmt.parse(cost.text) ?? 0,
      unit: unit,
    ),
  );
  if (ok) {
    await lookups.loadPrices(force: true);
    Toast.success('${currency?.name} ${cost.text} / ${weight.text} ${unit == 'CBM' ? 'CBM' : 'kg'}', title: 'priceSaved'.tr);
  }
  return ok;
}

/// Kuchagua bei ya usafirishaji kwenye fomu ya bidhaa (kadi badala ya dropdown).
class PricePicker extends StatelessWidget {
  final List<Price> prices;
  final Price? selected;
  final ValueChanged<Price> onSelected;
  final VoidCallback? onAddPrice;

  const PricePicker({
    super.key,
    required this.prices,
    required this.selected,
    required this.onSelected,
    this.onAddPrice,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('priceRate'.tr),
        if (prices.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.warning.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.warning.withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: p.warning),
                const SizedBox(width: 10),
                Expanded(child: Text('noPricesMsg'.tr, style: TextStyle(color: p.text))),
                if (onAddPrice != null) TextButton(onPressed: onAddPrice, child: Text('add'.tr)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final pr in prices) _PriceTile(price: pr, selected: pr.id == selected?.id, onTap: () => onSelected(pr)),
              if (onAddPrice != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAddPrice,
                  child: Container(
                    width: 120,
                    height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: p.primary, size: 18),
                        const SizedBox(width: 4),
                        Text('newPrice'.tr, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PriceTile extends StatelessWidget {
  final Price price;
  final bool selected;
  final VoidCallback onTap;

  const _PriceTile({required this.price, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final per = price.weight == 1 ? price.unitLabel : '${Fmt.number(price.weight)} ${price.unitLabel}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 170),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected ? p.primarySoft : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currencySymbol(price.name)}${Fmt.number(price.cost)} / $per',
                  style: TextStyle(fontWeight: FontWeight.w700, color: selected ? p.primary : p.text, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text('≈ ${Fmt.tsh(price.costPerKgLocal)} / ${price.unitLabel}', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? p.primary : p.border,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
