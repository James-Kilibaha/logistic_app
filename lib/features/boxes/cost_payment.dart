import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/accounting.dart';
import '../../data/models/finance.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import 'box_costs.dart';

const String _none = '';

String payStatusLabel(String? s) => 'costPay_${s ?? 'PAID'}'.tr;

Color payStatusColor(BuildContext context, String? s) {
  final p = context.palette;
  return switch (s) {
    'CREDIT' => p.danger,
    'PARTIAL' => p.warning,
    _ => p.success,
  };
}

/// Hali ya malipo ya gharama inayojazwa: yote / nusu (salio ni deni) / yote kwa deni.
class CostPayment {
  String status = 'PAID';
  final TextEditingController paid = TextEditingController();
  final TextEditingController supplier = TextEditingController();
  String accountId = _none;
  List<FinAccount> accounts = const [];

  /// Akaunti za fedha (kwa kuchagua iliyolipa) - kimya kama huna ruhusa.
  Future<void> loadAccounts() async {
    try {
      accounts = await AccountingRepo.options();
    } catch (_) {
      accounts = const [];
    }
  }

  double? get paidAmount => status == 'PARTIAL' ? Fmt.parse(paid.text) : null;

  String? get supplierName => supplier.text.trim().isEmpty ? null : supplier.text.trim();

  String? get account => accountId == _none ? null : accountId;

  /// Sehemu ya fomu. [currency] = sarafu ya gharama; [totalHint] = maelezo ya jumla (kwa mabox mengi).
  Widget fields(BuildContext context, StateSetter setState, {required String currency, String? totalHint}) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('payStatusLabel'.tr),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final s in const ['PAID', 'PARTIAL', 'CREDIT']) ButtonSegment(value: s, label: Text(payStatusLabel(s))),
          ],
          selected: {status},
          onSelectionChanged: (v) => setState(() => status = v.first),
        ),
        if (status == 'PARTIAL') ...[
          const SizedBox(height: 12),
          AppField.money(
            controller: paid,
            label: '${'payPaidNow'.tr} ($currency)',
            helper: totalHint ?? 'payPaidNowHint'.tr,
          ),
        ],
        if (status != 'PAID') ...[
          const SizedBox(height: 12),
          AppField(
            controller: supplier,
            label: 'paySupplier'.tr,
            hint: 'paySupplierHint'.tr,
            icon: Icons.local_shipping_outlined,
            required: true,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 4),
          Text('payDebtHint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
        if (status != 'CREDIT' && accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'paidFromAccount'.tr,
            value: accountId,
            required: false,
            items: [_none, ...accounts.map((a) => a.id)],
            icon: Icons.account_balance_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : accounts.firstWhere((a) => a.id == id).label,
            onChanged: (v) => setState(() => accountId = v ?? _none),
          ),
        ],
      ],
    );
  }
}

/// Kulipa deni la gharama (lote au sehemu).
Future<bool> showPayCost(BoxCost c) async {
  final pay = CostPayment();
  await pay.loadAccounts();
  final amount = TextEditingController(text: Fmt.money(c.owedTzs));
  final note = TextEditingController();
  final ok = await showFormSheet(
    title: 'payDebt'.tr,
    subtitle: '${c.boxId == null ? '' : 'Box ${c.boxId} · '}${costLabel(c.category)} · ${c.supplier ?? ''}',
    icon: Icons.payments_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow(label: 'payOwed'.tr, value: Fmt.tsh(c.owedTzs), emphasize: true),
        const SizedBox(height: 12),
        AppField.money(controller: amount, label: 'amountTsh'.tr),
        if (pay.accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'paidFromAccount'.tr,
            value: pay.accountId,
            required: false,
            items: [_none, ...pay.accounts.map((a) => a.id)],
            icon: Icons.account_balance_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : pay.accounts.firstWhere((a) => a.id == id).label,
            onChanged: (v) => setState(() => pay.accountId = v ?? _none),
          ),
        ],
        const SizedBox(height: 12),
        AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
      ],
    ),
    onSubmit: () => ShipmentRepo.payCost(c.id, amount: Fmt.parse(amount.text) ?? 0, accountId: pay.account, note: note.text),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success('${c.supplier ?? ''} · ${amount.text}', title: 'payDebtSaved'.tr);
  }
  return ok;
}

/// Kulipa deni lolote (gharama ya box au matumizi) kutoka orodha ya madeni.
Future<bool> showPayDebt(Payable d) async {
  final pay = CostPayment();
  await pay.loadAccounts();
  final amount = TextEditingController(text: Fmt.money(d.owedTzs));
  final note = TextEditingController();
  final ok = await showFormSheet(
    title: 'payDebt'.tr,
    subtitle: '${d.title} · ${d.supplier ?? ''}',
    icon: Icons.payments_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow(label: 'payOwed'.tr, value: Fmt.tsh(d.owedTzs), emphasize: true),
        const SizedBox(height: 12),
        AppField.money(controller: amount, label: 'amountTsh'.tr),
        if (pay.accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'paidFromAccount'.tr,
            value: pay.accountId,
            required: false,
            items: [_none, ...pay.accounts.map((a) => a.id)],
            icon: Icons.account_balance_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : pay.accounts.firstWhere((a) => a.id == id).label,
            onChanged: (v) => setState(() => pay.accountId = v ?? _none),
          ),
        ],
        const SizedBox(height: 12),
        AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
      ],
    ),
    onSubmit: () => d.source == 'EXPENSE'
        ? ExpenseRepo.pay(d.id, amount: Fmt.parse(amount.text) ?? 0, accountId: pay.account, note: note.text)
        : ShipmentRepo.payCost(d.id, amount: Fmt.parse(amount.text) ?? 0, accountId: pay.account, note: note.text),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success('${d.supplier ?? ''} · ${amount.text}', title: 'payDebtSaved'.tr);
  }
  return ok;
}

/// Madeni yote tunayodaiwa (gharama za mabox + matumizi kama pango, mishahara/PAYE/NSSF ...) - kwa Uhasibu.
class PayablesView extends StatefulWidget {
  const PayablesView({super.key});

  @override
  State<PayablesView> createState() => _PayablesViewState();
}

class _PayablesViewState extends State<PayablesView> with AutomaticKeepAliveClientMixin {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<Payable> _items = const [];
  List<Map<String, dynamic>> _groups = const [];
  double _total = 0;
  String? _supplier;
  Worker? _changes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _changes = ever<int>(AppController.to.changes, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _status = LoadStatus.loading);
    try {
      final r = await AccountingRepo.payables();
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _groups = r.bySupplier;
        _total = r.total;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = LoadStatus.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final can = AppController.to.can;
    bool canPay(Payable d) => d.source == 'EXPENSE'
        ? can(AppModule.accounting, AppAction.insert)
        : can(AppModule.accounting, AppAction.insert) || can(AppModule.profit, AppAction.update);
    final list = _supplier == null ? _items : _items.where((c) => (c.supplier ?? '-') == _supplier).toList();
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: _items.isEmpty,
      onRetry: _load,
      empty: EmptyState(icon: Icons.task_alt_rounded, title: 'payNoDebts'.tr, message: 'payNoDebtsMsg'.tr),
      builder: () => PageScroll(
        onRefresh: _load,
        children: [
          ResponsiveGrid(
            minItemWidth: 200,
            children: [
              StatCard(label: 'payTotalOwed'.tr, value: Fmt.tsh(_total), icon: Icons.request_quote_outlined, color: p.danger),
              for (final g in _groups.take(3))
                StatCard(
                  label: '${g['supplier']}',
                  value: Fmt.tsh(Fmt.parse('${g['owed']}') ?? 0),
                  icon: Icons.local_shipping_outlined,
                  color: p.warning,
                  hint: '${g['count']}',
                  onTap: () => setState(() => _supplier = _supplier == '${g['supplier']}' ? null : '${g['supplier']}'),
                ),
            ],
          ),
          if (_groups.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: Text('all'.tr), selected: _supplier == null, onSelected: (_) => setState(() => _supplier = null)),
                for (final g in _groups)
                  ChoiceChip(
                    label: Text('${g['supplier']} · ${Fmt.compact(Fmt.parse('${g['owed']}') ?? 0)}'),
                    selected: _supplier == '${g['supplier']}',
                    onSelected: (_) => setState(() => _supplier = '${g['supplier']}'),
                  ),
              ],
            ),
          Card(
            child: Column(
              children: [
                for (final d in list) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: payStatusColor(context, d.payStatus).withValues(alpha: .12),
                      child: Icon(d.source == 'EXPENSE' ? Icons.receipt_long_outlined : Icons.inventory_2_outlined,
                          color: payStatusColor(context, d.payStatus), size: 20),
                    ),
                    title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      d.supplier ?? '-',
                      '${'payTotal'.tr} ${Fmt.money(d.amountTzs)}',
                      '${'payPaid'.tr} ${Fmt.money(d.paidTzs)}',
                      Fmt.date(d.createdAt),
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Fmt.tsh(d.owedTzs), style: TextStyle(fontWeight: FontWeight.w800, color: p.danger)),
                        if (canPay(d))
                          IconButton(
                            tooltip: 'payDebt'.tr,
                            onPressed: () async {
                              if (await showPayDebt(d)) _load();
                            },
                            icon: Icon(Icons.payments_outlined, color: p.success),
                          ),
                      ],
                    ),
                  ),
                  if (d != list.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
