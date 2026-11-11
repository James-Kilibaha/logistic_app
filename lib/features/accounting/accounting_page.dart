import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/lookups.dart';
import '../../data/models/accounting.dart';
import '../../data/models/json.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../boxes/box_costs_list.dart';
import '../boxes/cost_payment.dart';
import '../demands/demands.dart';
import 'accounting_more.dart';
import '../expenses/expenses_controller.dart';
import '../expenses/expenses_page.dart';
import '../reports/analytics_tabs.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';

const String _none = '';

bool _can(AppAction a) => AppController.to.can(AppModule.accounting, a);

String accountKindLabel(String kind) => 'accKind_$kind'.tr;

/// Kiasi kwa sarafu ya akaunti (TSh -> "TSh 1,000"; USD -> "USD 1,000.00").
String accMoney(String currency, double v) {
  final c = currency.toUpperCase();
  return const ['TZS', 'TSH'].contains(c) ? Fmt.tsh(v) : '$c ${Fmt.money2(v)}';
}

/// Salio la akaunti kwa sarafu yake.
String accBalance(FinAccount a) => accMoney(a.currencyType, a.nativeBalance ?? a.balance ?? 0);

IconData accountKindIcon(String kind) => switch (kind) {
      'CASH' => Icons.payments_outlined,
      'MOBILE' => Icons.phone_android_rounded,
      _ => Icons.account_balance_outlined,
    };

/// Uhasibu: muhtasari wa faida/hasara, akaunti na salio, mapato mengine, uhamisho na makundi.
class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 10,
      child: AppPage(
        title: 'navAccounting'.tr,
        subtitle: 'hintAccounting'.tr,
        actions: [
          IconButton(tooltip: 'accMonthLocks'.tr, onPressed: showMonthLocks, icon: const Icon(Icons.lock_clock_outlined)),
          IconButton(
            tooltip: 'navDemands'.tr,
            onPressed: DemandsPage.open,
            icon: const Icon(Icons.assignment_late_outlined),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.insights_rounded, size: 20), text: 'accSummary'.tr),
            Tab(icon: const Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'accAccounts'.tr),
            Tab(icon: const Icon(Icons.savings_outlined, size: 20), text: 'accOtherIncome'.tr),
            Tab(icon: const Icon(Icons.swap_horiz_rounded, size: 20), text: 'accTransfers'.tr),
            Tab(icon: const Icon(Icons.inventory_2_outlined, size: 20), text: 'allBoxCosts'.tr),
            Tab(icon: const Icon(Icons.request_quote_outlined, size: 20), text: 'accPayables'.tr),
            Tab(icon: const Icon(Icons.diamond_outlined, size: 20), text: 'accEquity'.tr),
            Tab(icon: const Icon(Icons.balance_rounded, size: 20), text: 'accBalanceSheet'.tr),
            Tab(icon: const Icon(Icons.precision_manufacturing_outlined, size: 20), text: 'accAssets'.tr),
            Tab(icon: const Icon(Icons.category_outlined, size: 20), text: 'accCategories'.tr),
          ],
        ),
        body: const TabBarView(
          children: [_SummaryTab(), _AccountsTab(), _IncomeTab(), _TransfersTab(), BoxCostsView(), PayablesView(), EquityTab(), BalanceSheetTab(), AssetsTab(), _CategoriesTab()],
        ),
      ),
    );
  }
}

/// Hali ya kupakia ya kila tab (loading / kosa / data) + kupakia upya data ikibadilika popote.
mixin _Loading<T extends StatefulWidget> on State<T> {
  LoadStatus status = LoadStatus.loading;
  String? error;
  Worker? _changes;

  Future<void> fetch();

  Future<void> load() async {
    if (mounted) setState(() => status = LoadStatus.loading);
    try {
      await fetch();
      if (mounted) setState(() => status = LoadStatus.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          status = LoadStatus.error;
          error = e.toString();
        });
      }
    }
  }

  void startLoading() {
    _changes = ever<int>(AppController.to.changes, (_) => load());
    load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }
}

Widget _addButton(String label, VoidCallback onPressed) => Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.add_rounded), label: Text(label)),
    );

// ===================================================================== muhtasari
class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> with AutomaticKeepAliveClientMixin, _Loading {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  Office? _office;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _accounts;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Lookups.to.loadOffices().catchError((_) => <Office>[]);
    startLoading();
  }

  @override
  Future<void> fetch() async {
    final results = await Future.wait([
      AccountingRepo.summary(from: _range.start, to: _range.end, office: _office?.id),
      AccountingRepo.accounts(office: _office?.id),
    ]);
    _data = results[0];
    _accounts = results[1];
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? [for (final x in v.whereType<Map>()) Map<String, dynamic>.from(x)] : const [];

  Future<void> _pdf() => openPdfFrom(
        () => AccountingRepo.summaryFile('pdf', from: _range.start, to: _range.end, office: _office?.id),
        title: 'profitAndLoss'.tr,
        fileName: 'faida_hasara_${Fmt.date(_range.start).replaceAll('/', '-')}',
      );

  Future<void> _excel() => saveExcel(
        () => AccountingRepo.summaryFile('xlsx', from: _range.start, to: _range.end, office: _office?.id),
        'faida_hasara_${Fmt.date(_range.start).replaceAll('/', '-')}',
      );

  void _openPending() {
    ShellController.to.go(NavSection.expenses);
    if (Get.isRegistered<ExpensesController>()) Get.find<ExpensesController>().setStatus('PENDING');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: _data == null,
      onRetry: load,
      empty: EmptyState(icon: Icons.insights_rounded, title: 'noData'.tr),
      builder: () {
        final d = _data!;
        final months = _list(d['months']);
        final spent = _list(d['expensesByCategory']);
        final other = _list(d['otherIncomeByCategory']);
        final box = _list(d['boxCostsByCategory']);
        final profit = J.dbl(d['profit']);
        final accounts = _list(_accounts?['items']);
        final offices = Lookups.to.offices.toList();
        return PageScroll(
          onRefresh: load,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PeriodBar(
                  range: _range,
                  onChanged: (r) {
                    _range = r;
                    load();
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'office'.tr,
                  onSelected: (id) {
                    Office? selected;
                    for (final o in offices) {
                      if (o.id == id) selected = o;
                    }
                    _office = selected;
                    load();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: '', child: Text('allOffices'.tr)),
                    for (final o in offices) PopupMenuItem(value: o.id, child: Text(o.label)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
                    label: Text(_office?.name ?? 'allOffices'.tr),
                  ),
                ),
                IconButton(tooltip: 'PDF', onPressed: _pdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
                IconButton(tooltip: 'Excel', onPressed: _excel, icon: const Icon(Icons.grid_on_rounded)),
              ],
            ),
            ResponsiveGrid(
              minItemWidth: 200,
              children: [
                StatCard(
                  label: 'accIncome'.tr,
                  value: Fmt.tsh(J.dbl(d['income'])),
                  icon: Icons.south_west_rounded,
                  color: p.success,
                  hint: '${'accFromInvoices'.tr}: ${Fmt.compact(J.dbl(d['invoiceIncome']))}',
                ),
                StatCard(
                  label: 'accCosts'.tr,
                  value: Fmt.tsh(J.dbl(d['costs'])),
                  icon: Icons.north_east_rounded,
                  color: p.warning,
                  hint: '${'navExpenses'.tr}: ${Fmt.compact(J.dbl(d['expenses']))} · '
                      '${'accBoxCosts'.tr}: ${Fmt.compact(J.dbl(d['boxCosts']))}',
                ),
                StatCard(
                  label: profit >= 0 ? 'accProfit'.tr : 'accLoss'.tr,
                  value: Fmt.tsh(profit),
                  icon: profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: profit >= 0 ? p.info : p.danger,
                  hint: '${J.dbl(d['margin'])}%',
                ),
                StatCard(
                  label: 'accTotalBalance'.tr,
                  value: Fmt.tsh(J.dbl(_accounts?['total'])),
                  icon: Icons.account_balance_wallet_outlined,
                  color: p.primary,
                  hint: '${accounts.length} ${'accAccounts'.tr.toLowerCase()}',
                ),
                StatCard(
                  label: 'accPending'.tr,
                  value: Fmt.tsh(J.dbl(d['pendingAmount'])),
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFFDB2777),
                  hint: '${Fmt.number(J.dbl(d['pendingExpenses']))}'
                      '${AppController.to.can(AppModule.expenses) ? ' · ${'accTapToReview'.tr}' : ''}',
                  onTap: AppController.to.can(AppModule.expenses) ? _openPending : null,
                ),
                StatCard(
                  label: 'accReceivables'.tr,
                  value: Fmt.tsh(J.dbl(d['receivables'])),
                  icon: Icons.request_quote_outlined,
                  color: const Color(0xFF7C3AED),
                ),
                StatCard(
                  label: 'accPayables'.tr,
                  value: Fmt.tsh(J.dbl(d['payables'])),
                  icon: Icons.local_shipping_outlined,
                  color: p.danger,
                  hint: 'accPayablesHint'.tr,
                  onTap: () => DefaultTabController.of(context).animateTo(5),
                ),
              ],
            ),
            if (J.dbl(d['paymentsWithoutAccount']).abs() >= 1)
              Card(
                color: p.warning.withValues(alpha: .08),
                child: ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: p.warning),
                  title: Text('accPaymentsNoAccount'.trParams({'amount': Fmt.tsh(J.dbl(d['paymentsWithoutAccount']))})),
                ),
              ),
            if (months.length > 1)
              SectionCard(
                title: 'accByMonth'.tr,
                icon: Icons.bar_chart_rounded,
                child: GroupedBarChart(
                  labels: [for (final m in months) J.str(m['month'])],
                  series: [
                    BarSeries('accIncome'.tr, [for (final m in months) J.dbl(m['income'])], p.success),
                    BarSeries('accCosts'.tr, [for (final m in months) J.dbl(m['expenses'])], p.warning),
                    BarSeries('accProfit'.tr, [for (final m in months) J.dbl(m['profit'])], p.info),
                  ],
                ),
              ),
            ResponsiveGrid(
              minItemWidth: 340,
              maxColumns: 2,
              children: [
                SectionCard(
                  title: 'accIncome'.tr,
                  icon: Icons.south_west_rounded,
                  child: Column(
                    children: [
                      InfoRow(label: 'accInvoicePayments'.tr, value: Fmt.tsh(J.dbl(d['invoicePayments']))),
                      InfoRow(label: 'accRefunds'.tr, value: '- ${Fmt.tsh(J.dbl(d['refunds']))}'),
                      for (final x in other) InfoRow(label: J.str(x['name']), value: Fmt.tsh(J.dbl(x['amount']))),
                      const Divider(),
                      InfoRow(label: 'total'.tr, value: Fmt.tsh(J.dbl(d['income'])), emphasize: true),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'accCosts'.tr,
                  icon: Icons.north_east_rounded,
                  child: Column(
                    children: [
                      if (spent.isEmpty && box.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('noData'.tr, style: TextStyle(color: p.muted)),
                        ),
                      for (final x in spent) InfoRow(label: J.str(x['name']), value: Fmt.tsh(J.dbl(x['amount']))),
                      for (final x in box)
                        InfoRow(label: '${'accBoxCosts'.tr}: ${'cost_${J.str(x['name'])}'.tr}', value: Fmt.tsh(J.dbl(x['amount']))),
                      const Divider(),
                      InfoRow(label: 'total'.tr, value: Fmt.tsh(J.dbl(d['costs'])), emphasize: true),
                    ],
                  ),
                ),
              ],
            ),
            if (spent.isNotEmpty)
              PieChartCard(
                title: 'accExpensesByCategory'.tr,
                icon: Icons.pie_chart_outline_rounded,
                slices: slicesFrom({for (final x in spent) J.str(x['name']): J.dbl(x['amount'])}),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================== akaunti
class _AccountsTab extends StatefulWidget {
  const _AccountsTab();

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab> with AutomaticKeepAliveClientMixin, _Loading {
  List<FinAccount> _items = const [];
  Map<String, double> _byKind = const {};
  double _total = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    startLoading();
  }

  @override
  Future<void> fetch() async {
    final d = await AccountingRepo.accounts();
    _items = J.list(d['items'], FinAccount.fromJson);
    _total = J.dbl(d['total']);
    final k = d['byKind'];
    _byKind = k is Map ? {for (final e in k.entries) e.key.toString(): J.dbl(e.value)} : const {};
  }

  Future<void> _delete(FinAccount a) async {
    final ok = await confirmAction(
      title: 'accDeleteAccount'.tr,
      message: 'accDeleteAccountMsg'.trParams({'name': a.name}),
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => AccountingRepo.deleteAccount(a.id), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: false,
      onRetry: load,
      empty: const SizedBox.shrink(),
      builder: () => PageScroll(
        onRefresh: load,
        children: [
          ResponsiveGrid(
            minItemWidth: 200,
            children: [
              StatCard(label: 'accTotalBalance'.tr, value: Fmt.tsh(_total), icon: Icons.account_balance_wallet_outlined, color: p.primary),
              for (final k in const ['CASH', 'BANK', 'MOBILE'])
                StatCard(label: accountKindLabel(k), value: Fmt.tsh(_byKind[k] ?? 0), icon: accountKindIcon(k), color: p.info),
            ],
          ),
          if (_can(AppAction.insert)) _addButton('accNewAccount'.tr, () => showAccountForm()),
          if (_items.isEmpty)
            EmptyState(icon: Icons.account_balance_outlined, title: 'accNoAccounts'.tr, message: 'accNoAccountsMsg'.tr)
          else
            Card(
              child: Column(
                children: [
                  for (final a in _items) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.primarySoft,
                        child: Icon(accountKindIcon(a.kind), color: p.primary, size: 20),
                      ),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        accountKindLabel(a.kind),
                        a.accountNo,
                        a.currencyType.toUpperCase(),
                        if (a.office != null) a.office!,
                      ].join(' · ')),
                      onTap: () => Get.to(() => AccountStatementPage(account: a)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                accBalance(a),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: (a.balance ?? 0) < 0 ? p.danger : p.text,
                                ),
                              ),
                              if (!a.isLocal)
                                Text('≈ ${Fmt.tsh(a.balance ?? 0)}', style: TextStyle(fontSize: 12, color: p.muted)),
                            ],
                          ),
                          if (_can(AppAction.update) || _can(AppAction.delete))
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') showAccountForm(account: a);
                                if (v == 'delete') _delete(a);
                              },
                              itemBuilder: (context) => [
                                if (_can(AppAction.update)) PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
                                if (_can(AppAction.delete))
                                  PopupMenuItem(value: 'delete', child: Text('delete'.tr, style: TextStyle(color: p.danger))),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (a != _items.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          Text('accBalanceHint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

Future<void> showAccountForm({FinAccount? account}) async {
  List<Office> offices = const [];
  try {
    offices = await Lookups.to.loadOffices();
  } catch (_) {}
  final currencies = await loadCurrencyCodes();
  final name = TextEditingController(text: account?.name ?? '');
  final number = TextEditingController(text: account?.accountNo ?? '');
  final opening = TextEditingController(text: account == null ? '0' : Fmt.money(account.openingBalance));
  String kind = account?.kind ?? 'CASH';
  String currency = account?.currencyType.toUpperCase() ?? 'TZS';
  if (currency == 'TSH') currency = 'TZS';
  if (!currencies.contains(currency)) currencies.add(currency);
  String officeId = account?.officeId ?? _none;
  if (officeId != _none && !offices.any((o) => o.id == officeId)) officeId = _none;
  DateTime? openingDate = account?.openingDate == null ? null : DateTime.tryParse(account!.openingDate!);

  final ok = await showFormSheet(
    title: account == null ? 'accNewAccount'.tr : 'accEditAccount'.tr,
    icon: Icons.account_balance_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('accKind'.tr, required: true),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final k in const ['CASH', 'BANK', 'MOBILE'])
              ButtonSegment(value: k, label: Text(accountKindLabel(k)), icon: Icon(accountKindIcon(k), size: 18)),
          ],
          selected: {kind},
          onSelectionChanged: (v) => setState(() => kind = v.first),
        ),
        const SizedBox(height: 16),
        AppField(
          controller: name,
          label: 'name'.tr,
          hint: 'accNameHint'.tr,
          icon: Icons.badge_outlined,
          required: true,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        AppField(
          controller: number,
          label: 'accountNo'.tr,
          hint: kind == 'CASH' ? 'accCashNoHint'.tr : null,
          icon: Icons.numbers_rounded,
          required: kind != 'CASH',
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'office'.tr,
          value: officeId,
          required: false,
          items: [_none, ...offices.map((o) => o.id)],
          icon: Icons.store_mall_directory_outlined,
          itemLabel: (id) => id == _none ? 'allOffices'.tr : offices.firstWhere((o) => o.id == id).label,
          onChanged: (v) => setState(() => officeId = v ?? _none),
        ),
        if (currencies.length > 1) ...[
          const SizedBox(height: 16),
          FieldLabel('currency'.tr),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppField.money(controller: opening, label: '${'accOpeningBalanceIn'.tr} ($currency)', helper: 'accOpeningHint'.tr, required: false),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDate: openingDate ?? DateTime.now(),
            );
            if (picked != null) setState(() => openingDate = picked);
          },
          icon: const Icon(Icons.event_rounded),
          label: Text(openingDate == null ? 'accOpeningDateAny'.tr : '${'accOpeningDate'.tr}: ${Fmt.date(openingDate)}'),
        ),
      ],
    ),
    onSubmit: () => AccountingRepo.saveAccount(
      id: account?.id,
      name: name.text,
      kind: kind,
      accountNo: number.text,
      currency: currency,
      officeId: officeId == _none ? null : officeId,
      openingBalance: Fmt.parse(opening.text) ?? 0,
      openingDate: openingDate,
    ),
  );
  if (ok) {
    Lookups.to.loadInstitutes(force: true).catchError((_) => <Institute>[]);
    AppController.to.notifyChanged();
    Toast.success(name.text, title: 'saved'.tr);
  }
}

/// Mwenendo wa akaunti moja: salio la kuanzia, kila pesa iliyoingia / kutoka, salio la kufunga.
class AccountStatementPage extends StatefulWidget {
  final FinAccount account;

  const AccountStatementPage({super.key, required this.account});

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> with _Loading {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    startLoading();
  }

  @override
  Future<void> fetch() async {
    _data = await AccountingRepo.statement(widget.account.id, from: _range.start, to: _range.end);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = widget.account;
    return AppPage(
      showBack: true,
      title: a.name,
      subtitle: '${accountKindLabel(a.kind)} · ${a.accountNo} · ${a.currencyType.toUpperCase()}',
      actions: [
        IconButton(
          tooltip: 'Excel',
          onPressed: () => saveExcel(
            () => AccountingRepo.statementExcel(a.id, from: _range.start, to: _range.end),
            'akaunti_${a.name.replaceAll(' ', '_')}',
          ),
          icon: const Icon(Icons.grid_on_rounded),
        ),
      ],
      body: AsyncBody(
        status: status,
        error: error,
        isEmpty: _data == null,
        onRetry: load,
        empty: EmptyState(icon: Icons.receipt_long_outlined, title: 'noData'.tr),
        builder: () {
          final d = _data!;
          final lines = J.list(d['lines'], StatementLine.fromJson);
          final cur = J.str(d['currency'], a.currencyType);
          return PageScroll(
            onRefresh: load,
            children: [
              PeriodBar(
                range: _range,
                onChanged: (r) {
                  _range = r;
                  load();
                },
              ),
              ResponsiveGrid(
                minItemWidth: 180,
                children: [
                  StatCard(label: 'accOpening'.tr, value: accMoney(cur, J.dbl(d['opening'])), icon: Icons.flag_outlined, color: p.muted),
                  StatCard(label: 'accMoneyIn'.tr, value: accMoney(cur, J.dbl(d['moneyIn'])), icon: Icons.south_west_rounded, color: p.success),
                  StatCard(label: 'accMoneyOut'.tr, value: accMoney(cur, J.dbl(d['moneyOut'])), icon: Icons.north_east_rounded, color: p.warning),
                  StatCard(label: 'accClosing'.tr, value: accMoney(cur, J.dbl(d['closing'])), icon: Icons.account_balance_wallet_outlined, color: p.primary),
                ],
              ),
              if (lines.isEmpty)
                EmptyState(icon: Icons.receipt_long_outlined, title: 'accNoMovements'.tr)
              else
                Card(
                  child: Column(
                    children: [
                      for (final l in lines) ...[
                        ListTile(
                          dense: true,
                          leading: Icon(
                            l.moneyIn > 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                            color: l.moneyIn > 0 ? p.success : p.warning,
                          ),
                          title: Text(l.details, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([Fmt.dateTime(l.at), 'stmt_${l.type}'.tr, if (l.ref.isNotEmpty) l.ref].join(' · ')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l.moneyIn > 0 ? '+${Fmt.money(l.moneyIn)}' : '-${Fmt.money(l.moneyOut)}',
                                style: TextStyle(fontWeight: FontWeight.w800, color: l.moneyIn > 0 ? p.success : p.warning),
                              ),
                              Text(Fmt.money(l.balance), style: TextStyle(fontSize: 12, color: p.muted)),
                            ],
                          ),
                        ),
                        if (l != lines.last) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ===================================================================== mapato mengine
class _IncomeTab extends StatefulWidget {
  const _IncomeTab();

  @override
  State<_IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<_IncomeTab> with AutomaticKeepAliveClientMixin, _Loading {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  List<OtherIncome> _items = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    startLoading();
  }

  @override
  Future<void> fetch() async {
    _items = await AccountingRepo.incomes(from: _range.start, to: _range.end);
  }

  Future<void> _delete(OtherIncome x) async {
    final ok = await confirmAction(
      title: 'accDeleteIncome'.tr,
      message: '${x.details} · ${Fmt.tsh(x.amount)}',
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => AccountingRepo.deleteIncome(x.id), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final total = _items.fold<double>(0, (s, x) => s + x.amount);
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: false,
      onRetry: load,
      empty: const SizedBox.shrink(),
      builder: () => PageScroll(
        onRefresh: load,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PeriodBar(
                range: _range,
                onChanged: (r) {
                  _range = r;
                  load();
                },
              ),
              Pill('${'total'.tr}: ${Fmt.tsh(total)}', color: p.success),
            ],
          ),
          if (_can(AppAction.insert)) _addButton('accNewIncome'.tr, () => showIncomeForm()),
          if (_items.isEmpty)
            EmptyState(icon: Icons.savings_outlined, title: 'accNoIncome'.tr, message: 'accNoIncomeMsg'.tr)
          else
            Card(
              child: Column(
                children: [
                  for (final x in _items) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.success.withValues(alpha: .12),
                        child: Icon(Icons.savings_outlined, color: p.success, size: 20),
                      ),
                      title: Text(x.details, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if (x.category != null) x.category!,
                        if (x.account != null) x.account!,
                        if (x.office != null) x.office!,
                        Fmt.dateTime(x.createdAt),
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.tsh(x.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                          if (_can(AppAction.update) || _can(AppAction.delete))
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') showIncomeForm(income: x);
                                if (v == 'delete') _delete(x);
                              },
                              itemBuilder: (context) => [
                                if (_can(AppAction.update)) PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
                                if (_can(AppAction.delete))
                                  PopupMenuItem(value: 'delete', child: Text('delete'.tr, style: TextStyle(color: p.danger))),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (x != _items.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showIncomeForm({OtherIncome? income}) async {
  List<AccCategory> categories = const [];
  List<FinAccount> accounts = const [];
  List<Office> offices = const [];
  try {
    final r = await Future.wait([
      AccountingRepo.categories(kind: 'INCOME'),
      AccountingRepo.options(),
      Lookups.to.loadOffices(),
    ]);
    categories = r[0] as List<AccCategory>;
    accounts = r[1] as List<FinAccount>;
    offices = r[2] as List<Office>;
  } catch (e) {
    Toast.error(e);
    return;
  }
  final currencies = await loadCurrencyCodes();
  final details = TextEditingController(text: income?.details ?? '');
  final amount = TextEditingController(text: income == null ? '' : Fmt.money2(income.amountOriginal ?? income.amount));
  String currency = income?.currency ?? 'TZS';
  if (!currencies.contains(currency)) currencies.add(currency);
  String categoryId = income?.categoryId ?? _none;
  if (categoryId != _none && !categories.any((c) => c.id == categoryId)) categoryId = _none;
  String accountId = income?.accountId ?? (accounts.isNotEmpty ? accounts.first.id : _none);
  if (accountId != _none && !accounts.any((a) => a.id == accountId)) accountId = _none;
  String officeId = income?.officeId ?? AppController.to.user.value?.officeId ?? _none;
  if (officeId != _none && !offices.any((o) => o.id == officeId)) officeId = _none;

  final ok = await showFormSheet(
    title: income == null ? 'accNewIncome'.tr : 'accEditIncome'.tr,
    icon: Icons.savings_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          controller: details,
          label: 'details'.tr,
          hint: 'accIncomeHint'.tr,
          icon: Icons.notes_rounded,
          required: true,
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'accCategory'.tr,
          value: categoryId,
          required: false,
          items: [_none, ...categories.map((c) => c.id)],
          icon: Icons.category_outlined,
          itemLabel: (id) => id == _none ? 'noneOption'.tr : categories.firstWhere((c) => c.id == id).name,
          onChanged: (v) => setState(() => categoryId = v ?? _none),
        ),
        if (currencies.length > 1) ...[
          const SizedBox(height: 16),
          FieldLabel('currency'.tr),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppField.money(controller: amount, label: currency == 'TZS' ? 'amountTsh'.tr : '${'amount'.tr} ($currency)'),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'accReceivedInto'.tr,
          value: accountId,
          required: false,
          items: [_none, ...accounts.map((a) => a.id)],
          icon: Icons.account_balance_outlined,
          itemLabel: (id) => id == _none ? 'noneOption'.tr : accounts.firstWhere((a) => a.id == id).label,
          onChanged: (v) => setState(() => accountId = v ?? _none),
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'office'.tr,
          value: officeId,
          required: false,
          items: [_none, ...offices.map((o) => o.id)],
          icon: Icons.store_mall_directory_outlined,
          itemLabel: (id) => id == _none ? 'noneOption'.tr : offices.firstWhere((o) => o.id == id).label,
          onChanged: (v) => setState(() => officeId = v ?? _none),
        ),
      ],
    ),
    onSubmit: () => AccountingRepo.saveIncome(
      id: income?.id,
      details: details.text,
      amount: Fmt.parse(amount.text) ?? 0,
      currency: currency,
      categoryId: categoryId == _none ? null : categoryId,
      accountId: accountId == _none ? null : accountId,
      officeId: officeId == _none ? null : officeId,
    ),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(details.text, title: 'saved'.tr);
  }
}

// ===================================================================== uhamisho
class _TransfersTab extends StatefulWidget {
  const _TransfersTab();

  @override
  State<_TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends State<_TransfersTab> with AutomaticKeepAliveClientMixin, _Loading {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  List<AccTransfer> _items = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    startLoading();
  }

  @override
  Future<void> fetch() async {
    _items = await AccountingRepo.transfers(from: _range.start, to: _range.end);
  }

  Future<void> _delete(AccTransfer t) async {
    final ok = await confirmAction(
      title: 'accDeleteTransfer'.tr,
      message: '${t.from} → ${t.to} · ${accMoney(t.fromCurrency, t.fromAmount ?? t.amount)}',
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => AccountingRepo.deleteTransfer(t.id), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: false,
      onRetry: load,
      empty: const SizedBox.shrink(),
      builder: () => PageScroll(
        onRefresh: load,
        children: [
          PeriodBar(
            range: _range,
            onChanged: (r) {
              _range = r;
              load();
            },
          ),
          if (_can(AppAction.insert)) _addButton('accNewTransfer'.tr, showTransferForm),
          if (_items.isEmpty)
            EmptyState(icon: Icons.swap_horiz_rounded, title: 'accNoTransfers'.tr, message: 'accNoTransfersMsg'.tr)
          else
            Card(
              child: Column(
                children: [
                  for (final t in _items) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.primarySoft,
                        child: Icon(Icons.swap_horiz_rounded, color: p.primary, size: 20),
                      ),
                      title: Text('${t.from}  →  ${t.to}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        Fmt.dateTime(t.createdAt),
                        if (t.note != null) t.note!,
                        if (t.createdBy != null) t.createdBy!,
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(accMoney(t.fromCurrency, t.fromAmount ?? t.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (t.fromCurrency != t.toCurrency && t.toAmount != null)
                                Text('→ ${accMoney(t.toCurrency, t.toAmount!)}', style: TextStyle(fontSize: 12, color: p.muted)),
                            ],
                          ),
                          if (_can(AppAction.delete))
                            IconButton(
                              tooltip: 'delete'.tr,
                              onPressed: () => _delete(t),
                              icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                            ),
                        ],
                      ),
                    ),
                    if (t != _items.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showTransferForm() async {
  List<FinAccount> accounts;
  try {
    accounts = J.list((await AccountingRepo.accounts())['items'], FinAccount.fromJson);
  } catch (e) {
    Toast.error(e);
    return;
  }
  if (accounts.length < 2) {
    Toast.warning('accNeedTwoAccounts'.tr);
    return;
  }
  String from = accounts.first.id;
  String to = accounts[1].id;
  final amount = TextEditingController();
  final received = TextEditingController();
  final note = TextEditingController();
  FinAccount acc(String id) => accounts.firstWhere((x) => x.id == id);
  String label(String id) {
    final a = acc(id);
    return '${a.label} · ${accBalance(a)}';
  }

  bool sameCurrency() => acc(from).currencyType.toUpperCase() == acc(to).currencyType.toUpperCase() ||
      (acc(from).isLocal && acc(to).isLocal);

  final ok = await showFormSheet(
    title: 'accNewTransfer'.tr,
    icon: Icons.swap_horiz_rounded,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdown<String>(
          label: 'accFromAccount'.tr,
          value: from,
          items: [for (final a in accounts) a.id],
          icon: Icons.north_east_rounded,
          itemLabel: label,
          onChanged: (v) => setState(() => from = v ?? from),
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'accToAccount'.tr,
          value: to,
          items: [for (final a in accounts) a.id],
          icon: Icons.south_west_rounded,
          itemLabel: label,
          onChanged: (v) => setState(() => to = v ?? to),
          validator: (v) => v == from ? 'accSameAccount'.tr : null,
        ),
        const SizedBox(height: 16),
        AppField.money(controller: amount, label: '${'accAmountSent'.tr} (${acc(from).currencyType.toUpperCase()})'),
        if (!sameCurrency()) ...[
          const SizedBox(height: 16),
          AppField.money(
            controller: received,
            label: '${'accAmountReceived'.tr} (${acc(to).currencyType.toUpperCase()})',
            helper: 'accAmountReceivedHint'.tr,
            required: false,
          ),
        ],
        const SizedBox(height: 16),
        AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
      ],
    ),
    onSubmit: () => AccountingRepo.transfer(
      fromId: from,
      toId: to,
      amount: Fmt.parse(amount.text) ?? 0,
      toAmount: sameCurrency() ? null : Fmt.parse(received.text),
      note: note.text,
    ),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success('${label(from)} → ${label(to)}', title: 'saved'.tr);
  }
}

// ===================================================================== makundi
class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> with AutomaticKeepAliveClientMixin, _Loading {
  List<AccCategory> _items = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    startLoading();
  }

  @override
  Future<void> fetch() async {
    _items = await AccountingRepo.categories();
  }

  Future<void> _form({AccCategory? cat, String kind = 'EXPENSE'}) async {
    final name = TextEditingController(text: cat?.name ?? '');
    final desc = TextEditingController(text: cat?.description ?? '');
    String k = cat?.kind ?? kind;
    final ok = await showFormSheet(
      title: cat == null ? 'accNewCategory'.tr : 'accEditCategory'.tr,
      icon: Icons.category_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'EXPENSE', label: Text('navExpenses'.tr)),
              ButtonSegment(value: 'INCOME', label: Text('accOtherIncome'.tr)),
            ],
            selected: {k},
            onSelectionChanged: (v) => setState(() => k = v.first),
          ),
          const SizedBox(height: 16),
          AppField(controller: name, label: 'name'.tr, icon: Icons.label_outline_rounded, required: true,
              capitalization: TextCapitalization.sentences),
          const SizedBox(height: 16),
          AppField(controller: desc, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
        ],
      ),
      onSubmit: () => AccountingRepo.saveCategory(id: cat?.id, name: name.text, kind: k, description: desc.text),
    );
    if (ok) {
      load();
      Toast.success(name.text, title: 'saved'.tr);
    }
  }

  Future<void> _delete(AccCategory c) async {
    final ok = await confirmAction(
      title: 'accDeleteCategory'.tr,
      message: c.name,
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => AccountingRepo.deleteCategory(c.id), success: 'deleted'.tr)) load();
  }

  Widget _group(BuildContext context, String kind, String title, IconData icon) {
    final p = context.palette;
    final items = _items.where((c) => c.kind == kind).toList();
    final canEdit = _can(AppAction.update);
    return SectionCard(
      title: title,
      icon: icon,
      trailing: canEdit
          ? TextButton.icon(onPressed: () => _form(kind: kind), icon: const Icon(Icons.add_rounded, size: 20), label: Text('add'.tr))
          : null,
      child: items.isEmpty
          ? Text('noData'.tr, style: TextStyle(color: p.muted))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in items)
                  InputChip(
                    label: Text(c.name),
                    onPressed: canEdit ? () => _form(cat: c) : null,
                    onDeleted: canEdit ? () => _delete(c) : null,
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: false,
      onRetry: load,
      empty: const SizedBox.shrink(),
      builder: () => PageScroll(
        onRefresh: load,
        children: [
          _group(context, 'EXPENSE', 'accExpenseCategories'.tr, Icons.north_east_rounded),
          _group(context, 'INCOME', 'accIncomeCategories'.tr, Icons.south_west_rounded),
        ],
      ),
    );
  }
}
