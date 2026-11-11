import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/lookups.dart';
import '../../data/models/box.dart';
import '../../data/models/finance.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import 'cost_payment.dart';

const List<String> costCategories = ['FREIGHT', 'CUSTOMS', 'CLEARING', 'TRANSPORT', 'HANDLING', 'OTHER'];

String costLabel(String c) => 'cost_$c'.tr;

/// Gharama za kusafirisha box hili na faida yake.
class BoxCostsCard extends StatefulWidget {
  final Box box;

  const BoxCostsCard({super.key, required this.box});

  @override
  State<BoxCostsCard> createState() => _BoxCostsCardState();
}

class _BoxCostsCardState extends State<BoxCostsCard> {
  List<BoxCost> _costs = const [];
  BoxProfit? _profit;
  bool _loading = true;

  bool get _canSeeProfit => AppController.to.can(AppModule.profit);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final costs = await ShipmentRepo.costs(widget.box.id);
      final profit = _canSeeProfit ? await ShipmentRepo.profit(widget.box.id) : null;
      if (!mounted) return;
      setState(() {
        _costs = costs;
        _profit = profit;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    List<String> currencies = ['TZS'];
    try {
      currencies = ['TZS', ...(await Lookups.to.loadCurrencies()).map((c) => c.name.toUpperCase()).where((c) => c != 'TZS').toSet()];
    } catch (_) {}
    String category = 'FREIGHT';
    String currency = currencies.length > 1 ? currencies[1] : 'TZS';
    final amount = TextEditingController();
    final note = TextEditingController();
    final pay = CostPayment();
    await pay.loadAccounts();
    final ok = await showFormSheet(
      help: 'boxDetail',
      title: 'addBoxCost'.tr,
      subtitle: 'Box ${widget.box.boxId}',
      icon: Icons.request_quote_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('costType'.tr, required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in costCategories)
                ChoiceChip(label: Text(costLabel(c)), selected: category == c, onSelected: (_) => setState(() => category = c)),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel('currency'.tr),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
            selected: {currency},
            onSelectionChanged: (v) => setState(() => currency = v.first),
          ),
          const SizedBox(height: 16),
          AppField.money(controller: amount, label: '${'amount'.tr} ($currency)'),
          const SizedBox(height: 16),
          AppField(controller: note, label: 'noteOptional'.tr, hint: 'AWB / B/L, risiti...', icon: Icons.notes_rounded),
          const SizedBox(height: 16),
          pay.fields(context, setState, currency: currency),
        ],
      ),
      onSubmit: () => ShipmentRepo.addCost(
        widget.box.id,
        category: category,
        amount: Fmt.parse(amount.text) ?? 0,
        currency: currency,
        note: note.text,
        payStatus: pay.status,
        paidAmount: pay.paidAmount,
        supplier: pay.supplierName,
        accountId: pay.account,
      ),
    );
    if (ok) {
      Toast.success('${costLabel(category)} · $currency ${amount.text}', title: 'saved'.tr);
      _load();
    }
  }

  Future<void> _delete(BoxCost c) async {
    final ok = await confirmAction(
      title: 'deleteCost'.tr,
      message: '${costLabel(c.category)} · ${Fmt.tsh(c.amountTzs)}',
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    if (await runGuarded(() => ShipmentRepo.deleteCost(c.id), success: 'deleted'.tr)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    final profit = _profit;
    return SectionCard(
      title: 'boxCosts'.tr,
      subtitle: 'boxCostsSub'.tr,
      icon: Icons.request_quote_outlined,
      trailing: can(AppModule.profit, AppAction.update)
          ? TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 20), label: Text('add'.tr))
          : null,
      child: _loading
          ? const LinearProgressIndicator()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profit != null)
                  ResponsiveGrid(
                    minItemWidth: 150,
                    spacing: 10,
                    children: [
                      _Figure(label: 'revenue'.tr, value: Fmt.tsh(profit.income), color: p.primary),
                      _Figure(label: 'costs'.tr, value: Fmt.tsh(profit.costs), color: p.warning),
                      _Figure(
                        label: 'profit'.tr,
                        value: Fmt.tsh(profit.profit),
                        color: profit.profit >= 0 ? p.success : p.danger,
                        hint: '${profit.margin.toStringAsFixed(1)}%',
                      ),
                      _Figure(label: 'costPerKg'.tr, value: Fmt.tsh(profit.costPerKg), color: p.info),
                    ],
                  ),
                if (profit != null) const SizedBox(height: 12),
                if (_costs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('noBoxCosts'.tr, style: TextStyle(color: p.muted)),
                  )
                else
                  for (final c in _costs)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.receipt_outlined, color: p.muted),
                      title: Text(costLabel(c.category), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if (c.currency != 'TZS') '${c.currency} ${Fmt.money2(c.amount)} @ ${Fmt.money(c.rate)}',
                        if (c.supplier != null) c.supplier!,
                        if (c.hasDebt) '${'payOwed'.tr}: ${Fmt.tsh(c.owedTzs)}',
                        if (c.note != null) c.note!,
                        Fmt.date(c.createdAt),
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.payStatus != null && c.payStatus != 'PAID') ...[
                            Pill(payStatusLabel(c.payStatus), color: payStatusColor(context, c.payStatus), dense: true),
                            const SizedBox(width: 6),
                          ],
                          Text(Fmt.tsh(c.amountTzs), style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (c.hasDebt &&
                              (can(AppModule.accounting, AppAction.insert) || can(AppModule.profit, AppAction.update)))
                            IconButton(
                              tooltip: 'payDebt'.tr,
                              onPressed: () async {
                                if (await showPayCost(c)) _load();
                              },
                              icon: Icon(Icons.payments_outlined, size: 18, color: p.success),
                            ),
                          if (can(AppModule.profit, AppAction.delete))
                            IconButton(
                              tooltip: 'delete'.tr,
                              onPressed: () => _delete(c),
                              icon: Icon(Icons.close_rounded, size: 18, color: p.danger),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? hint;

  const _Figure({required this.label, required this.value, required this.color, this.hint});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          if (hint != null) Text(hint!, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
