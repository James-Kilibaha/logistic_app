import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_overview.dart';
import '../../data/models/invoice.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../claims/claim_flows.dart';
import '../invoices/invoice_flows.dart';
import '../reports/analytics_tabs.dart';
import '../sms/broadcast_page.dart';
import 'customers_page.dart';

/// Dashibodi ya mteja: takwimu, chati na kumbukumbu zote za biashara naye
/// (ankara na mizigo, malipo, makabidhiano, madai, SMS), kwa kipindi au tangu mwanzo.
class CustomerDetailPage extends StatefulWidget {
  final Customer customer;

  const CustomerDetailPage({super.key, required this.customer});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Customer _customer = widget.customer;
  CustomerOverview? _ov;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  DateTimeRange? _range; // null = tangu mwanzo
  Worker? _changes;

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
    try {
      final results = await Future.wait([
        CustomerRepo.overview(_customer.id, from: _range?.start, to: _range?.end),
        CustomerRepo.search(query: _customer.name, limit: 20),
      ]);
      final ov = results[0] as CustomerOverview;
      final customers = results[1] as List<Customer>;
      if (!mounted) return;
      setState(() {
        _ov = ov;
        for (final c in customers) {
          if (c.id == _customer.id) _customer = c;
        }
        _status = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range ?? DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  void _allTime() {
    setState(() => _range = null);
    _load();
  }

  String get _fileBase => 'mteja_${_customer.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';

  Future<void> _statementPdf() async {
    try {
      final bytes = await CustomerRepo.statement(_customer.id, 'pdf', from: _range?.start, to: _range?.end);
      await PdfViewerPage.open(title: '${'customerStatement'.tr} · ${_customer.name}', bytes: bytes, fileName: _fileBase);
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    final ov = _ov;
    final can = AppController.to.can;
    String count(List l) => l.isEmpty ? '' : ' (${l.length})';
    // Pesa (malipo, taarifa ya akaunti) zinaonekana kwa wenye ruhusa ya FINANCE tu.
    final money = (ov?.finance ?? true) && can(AppModule.finance);

    return DefaultTabController(
      length: money ? 6 : 5,
      child: AppPage(
        help: 'customerDetail',
        title: c.name,
        subtitle: Fmt.phone(c.phoneNumber),
        showBack: true,
        actions: [
          IconButton(tooltip: 'period'.tr, onPressed: _pickRange, icon: const Icon(Icons.date_range_rounded)),
          if (money)
            IconButton(tooltip: 'customerStatement'.tr, onPressed: _statementPdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
          if (money)
          IconButton(
            tooltip: 'downloadExcel'.tr,
            onPressed: () => saveExcel(
                () => CustomerRepo.statement(_customer.id, 'xlsx', from: _range?.start, to: _range?.end), _fileBase),
            icon: const Icon(Icons.grid_on_rounded),
          ),
          IconButton(tooltip: 'call'.tr, onPressed: () => callPhone(c.phoneNumber), icon: const Icon(Icons.call_outlined)),
          if (can(AppModule.sms, AppAction.insert))
            IconButton(
              tooltip: 'sendMessage'.tr,
              onPressed: () => BroadcastPage.open(customer: c),
              icon: const Icon(Icons.sms_outlined),
            ),
          CustomerMenu(customer: c, onChanged: _load),
        ],
        mainAction: c.isActive && can(AppModule.invoice, AppAction.insert)
            ? PageAction(
                icon: Icons.note_add_outlined,
                label: 'newInvoice'.tr,
                onPressed: () => InvoiceFlows.newInvoice(customer: c),
              )
            : null,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.insights_rounded, size: 20), text: 'tabOverview'.tr),
            Tab(icon: const Icon(Icons.receipt_long_outlined, size: 20), text: '${'navInvoices'.tr}${count(ov?.invoices ?? [])}'),
            if (money)
              Tab(icon: const Icon(Icons.payments_outlined, size: 20), text: '${'payments'.tr}${count(ov?.payments ?? [])}'),
            Tab(icon: const Icon(Icons.handshake_outlined, size: 20), text: '${'tabHandedOver'.tr}${count(ov?.handovers ?? [])}'),
            Tab(icon: const Icon(Icons.report_problem_outlined, size: 20), text: '${'navClaims'.tr}${count(ov?.claims ?? [])}'),
            Tab(icon: const Icon(Icons.sms_outlined, size: 20), text: '${'navSms'.tr}${count(ov?.sms ?? [])}'),
          ],
        ),
        body: _status == LoadStatus.loading && ov == null
            ? const LoadingList(rows: 4)
            : _status == LoadStatus.error && ov == null
                ? ErrorState(message: _error ?? '', onRetry: _load)
                : TabBarView(
                    children: [
                      _OverviewTab(customer: c, ov: ov!, range: _range, onPickRange: _pickRange, onAllTime: _allTime, onRefresh: _load),
                      _InvoicesTab(ov: ov, onRefresh: _load),
                      if (money) _PaymentsTab(ov: ov, onRefresh: _load),
                      _HandoversTab(ov: ov, onRefresh: _load),
                      _ClaimsTab(ov: ov, onRefresh: _load),
                      _SmsTab(ov: ov, onRefresh: _load),
                    ],
                  ),
      ),
    );
  }
}

String _carrier(String c) => c == 'SEA' ? 'sea'.tr : c == 'AIR' ? 'air'.tr : c;

Widget _carrierPills(List<String> carriers) => Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final c in carriers)
          Pill(_carrier(c),
              color: c == 'SEA' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
              icon: c == 'SEA' ? Icons.directions_boat_outlined : Icons.flight_outlined,
              dense: true),
      ],
    );

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Empty(this.icon, this.title);

  @override
  Widget build(BuildContext context) => EmptyState(icon: icon, title: title, message: 'customerNoRecordsMsg'.tr);
}

// ----------------------------------------------------------------------- muhtasari
class _OverviewTab extends StatelessWidget {
  final Customer customer;
  final CustomerOverview ov;
  final DateTimeRange? range;
  final VoidCallback onPickRange;
  final VoidCallback onAllTime;
  final Future<void> Function() onRefresh;

  const _OverviewTab({
    required this.customer,
    required this.ov,
    required this.range,
    required this.onPickRange,
    required this.onAllTime,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = customer;
    final balance = ov.stat('balance');
    final money = ov.finance;
    return PageScroll(
      onRefresh: onRefresh,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Initials(c.initials, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(Fmt.phone(c.phoneNumber), style: TextStyle(color: p.muted)),
                          c.isActive
                              ? Pill('active'.tr, color: p.success, dense: true)
                              : Pill('blocked'.tr, color: p.danger, dense: true),
                          Text('${'since'.tr} ${Fmt.date(c.createdAt)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                          if (ov.lastAt != null)
                            Text('lastBusiness'.trParams({'d': Fmt.date(ov.lastAt)}),
                                style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(label: Text('allTime'.tr), selected: range == null, onSelected: (_) => onAllTime()),
            InputChip(
              avatar: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(range == null ? 'choosePeriod'.tr : '${Fmt.date(range!.start)} – ${Fmt.date(range!.end)}'),
              selected: range != null,
              onPressed: onPickRange,
            ),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(
              label: 'navInvoices'.tr,
              value: Fmt.number(ov.stat('invoices')),
              icon: Icons.receipt_long_outlined,
              color: p.primary,
              hint: 'activeN'.trParams({'n': Fmt.number(ov.stat('active'))}),
            ),
            if (money) ...[
            StatCard(label: 'billedTotal'.tr, value: Fmt.tsh(ov.stat('billed')), icon: Icons.request_quote_outlined, color: p.info),
            StatCard(label: 'paid'.tr, value: Fmt.tsh(ov.stat('paid')), icon: Icons.payments_outlined, color: p.success,
                hint: 'paymentsN'.trParams({'n': Fmt.number(ov.stat('payments'))})),
            StatCard(label: 'balanceDue'.tr, value: Fmt.tsh(balance), icon: Icons.account_balance_outlined,
                color: balance > 0 ? p.danger : p.muted),
            StatCard(
              label: 'creditAvailable'.tr,
              value: ov.creditLimit == null ? 'creditUnlimited'.tr : Fmt.tsh(ov.creditAvailable),
              icon: Icons.credit_score_outlined,
              color: ov.creditLimit != null && (ov.creditAvailable ?? 0) <= 0 ? p.danger : const Color(0xFF0891B2),
              hint: ov.creditLimit == null
                  ? '${'creditUsed'.tr}: ${Fmt.compact(ov.creditUsed)}'
                  : '${'creditLimit'.tr} ${Fmt.compact(ov.creditLimit)} · ${'creditUsed'.tr} ${Fmt.compact(ov.creditUsed)}',
            ),
            StatCard(label: 'incomeStorage'.tr, value: Fmt.tsh(ov.stat('storage')), icon: Icons.warehouse_outlined,
                color: const Color(0xFF0F766E)),
            StatCard(label: 'discount'.tr, value: Fmt.tsh(ov.stat('discount')), icon: Icons.discount_outlined,
                color: p.warning, hint: '${'refund'.tr}: ${Fmt.compact(ov.stat('refunds'))}'),
            ],
            StatCard(label: 'cartons'.tr, value: Fmt.number(ov.stat('cartons')), icon: Icons.inventory_2_outlined,
                color: const Color(0xFFD97706), hint: '${Fmt.number(ov.stat('products'))} ${'items'.tr}'),
            StatCard(label: 'weight'.tr, value: Fmt.kg(ov.stat('kg')), icon: Icons.scale_outlined, color: const Color(0xFF7C3AED),
                hint: ov.stat('cbm') > 0 ? '${ov.stat('cbm').toStringAsFixed(2)} CBM' : null),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 340,
          maxColumns: 3,
          children: [
            if (money)
            PieChartCard(
              title: 'piePaidVsDebt'.tr,
              icon: Icons.donut_large_rounded,
              slices: [
                ChartSlice('paid'.tr, ov.stat('paid'), p.success),
                ChartSlice('balanceDue'.tr, balance, p.danger),
              ],
            ),
            PieChartCard(
              title: 'pieCarrierKg'.tr,
              icon: Icons.flight_takeoff_rounded,
              slices: [
                for (final e in ov.carrierKg.entries)
                  ChartSlice(_carrier(e.key), e.value, e.key == 'SEA' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED)),
              ],
              format: (v) => Fmt.kg(v),
            ),
            if (money)
            PieChartCard(
              title: 'piePaymentMethods'.tr,
              icon: Icons.account_balance_outlined,
              slices: slicesFrom(ov.byMethod),
            ),
            PieChartCard(
              title: 'pieInvoiceStatus'.tr,
              icon: Icons.receipt_long_outlined,
              slices: [
                for (final (i, e) in ov.byStatus.entries.indexed)
                  ChartSlice(StatusStyle.of(InvoiceStatus.fromCode(e.key)).label, e.value, chartPalette[i % chartPalette.length]),
              ],
              format: (v) => Fmt.number(v),
            ),
          ],
        ),
        if (money)
        SectionCard(
          title: 'businessByMonth'.tr,
          subtitle: 'businessByMonthSub'.tr,
          icon: Icons.bar_chart_rounded,
          child: GroupedBarChart(
            labels: [for (final m in ov.monthly) m.month],
            series: [
              BarSeries('billedTotal'.tr, [for (final m in ov.monthly) m.billed], p.primary),
              BarSeries('paid'.tr, [for (final m in ov.monthly) m.paid], p.success),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------- ankara
class _InvoicesTab extends StatelessWidget {
  final CustomerOverview ov;
  final Future<void> Function() onRefresh;

  const _InvoicesTab({required this.ov, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (ov.invoices.isEmpty) return _Empty(Icons.receipt_long_outlined, 'noInvoicesYet'.tr);
    return PageScroll(
      onRefresh: onRefresh,
      spacing: 12,
      children: [
        for (final i in ov.invoices)
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => InvoiceFlows.open(i.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${'invoice'.tr} ${i.invoiceNumber}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: p.text)),
                        StatusChip(InvoiceStatus.fromCode(i.status), dense: true),
                        _carrierPills(i.carriers),
                        Text(Fmt.date(i.createdAt), style: TextStyle(color: p.muted, fontSize: 12.5)),
                        if (i.storageDays > 0)
                          Pill('daysN'.trParams({'n': '${i.storageDays}'}), color: p.warning, icon: Icons.warehouse_outlined, dense: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final pr in i.products)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 16, color: p.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${pr.description}${pr.trackNumber == null ? '' : ' · ${pr.trackNumber}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('${Fmt.number(pr.cartons)} ${'ctn'.tr} · ${Fmt.kg(pr.kg)}',
                                style: TextStyle(color: p.muted, fontSize: 12.5)),
                            if (ov.finance)
                              SizedBox(
                                width: 96,
                                child: Text(Fmt.money(pr.price), textAlign: TextAlign.end,
                                    style: TextStyle(color: p.text, fontSize: 12.5)),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 18),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        if (ov.finance) ...[
                          _Money('billedTotal'.tr, i.billed > 0 ? i.billed : i.value),
                          _Money('paid'.tr, i.paid, color: p.success),
                          _Money('balanceDue'.tr, i.balance, color: i.balance > 0 ? p.danger : p.muted),
                          if (i.storageCharge > 0) _Money('incomeStorage'.tr, i.storageCharge),
                          if (i.discount > 0) _Money('discount'.tr, i.discount),
                        ],
                        if (i.receiverName != null)
                          Text('${'receiver'.tr}: ${i.receiverName}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Money extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;

  const _Money(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$label: ', style: TextStyle(color: p.muted, fontSize: 12.5)),
      TextSpan(text: Fmt.tsh(value), style: TextStyle(color: color ?? p.text, fontWeight: FontWeight.w700, fontSize: 13)),
    ]));
  }
}

// ----------------------------------------------------------------------- malipo
class _PaymentsTab extends StatelessWidget {
  final CustomerOverview ov;
  final Future<void> Function() onRefresh;

  const _PaymentsTab({required this.ov, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (ov.payments.isEmpty) return _Empty(Icons.payments_outlined, 'noPaymentsYet'.tr);
    return DataList<CoPayment>(
      items: ov.payments,
      onRefresh: onRefresh,
      onTap: (x) => InvoiceFlows.open(x.invoiceId),
      columns: [
        ColumnSpec('date'.tr, flex: 2),
        ColumnSpec('receipt'.tr, flex: 2),
        ColumnSpec('invoice'.tr, flex: 2),
        ColumnSpec('paidVia'.tr, flex: 3),
        ColumnSpec('amount'.tr, flex: 2, align: TextAlign.end),
        ColumnSpec('receivedBy'.tr, flex: 2),
      ],
      cells: (context, x) => [
        CellText(Fmt.date(x.createdAt), sub: Fmt.time(x.createdAt)),
        CellText(x.receiptNumber ?? '—'),
        CellText(x.invoiceNumber ?? '—'),
        CellText(x.institute, sub: x.currency == 'TZS' ? null : x.currency),
        CellText(Fmt.money(x.amount), align: TextAlign.end, bold: true, color: x.isRefund ? p.danger : p.success,
            sub: x.isRefund ? 'refund'.tr : null),
        CellText(x.staff ?? '—'),
      ],
      card: (context, x) => ListTile(
        title: Text('${Fmt.tsh(x.amount)} · ${x.institute}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${Fmt.dateTime(x.createdAt)} · ${'invoice'.tr} ${x.invoiceNumber ?? ''}'
            '${x.staff == null ? '' : ' · ${x.staff}'}'),
        trailing: x.isRefund ? Pill('refund'.tr, color: p.danger, dense: true) : null,
      ),
    );
  }
}

// ----------------------------------------------------------------------- makabidhiano
class _HandoversTab extends StatelessWidget {
  final CustomerOverview ov;
  final Future<void> Function() onRefresh;

  const _HandoversTab({required this.ov, required this.onRefresh});

  Future<void> _note(CoHandover h) async {
    try {
      final bytes = await HandoverRepo.pdf(h.invoiceId, handoverId: h.id);
      await PdfViewerPage.open(title: '${'handoverNote'.tr} ${h.invoiceNumber}', bytes: bytes,
          fileName: 'makabidhiano_${h.invoiceNumber}');
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (ov.handovers.isEmpty) return _Empty(Icons.handshake_outlined, 'noHandedOver'.tr);
    return DataList<CoHandover>(
      items: ov.handovers,
      onRefresh: onRefresh,
      onTap: (h) => InvoiceFlows.open(h.invoiceId),
      columns: [
        ColumnSpec('date'.tr, flex: 2),
        ColumnSpec('invoice'.tr, flex: 2),
        ColumnSpec('collectorName'.tr, flex: 3),
        ColumnSpec('handedOverBy'.tr, flex: 3),
        ColumnSpec('', flex: 1, align: TextAlign.end),
      ],
      cells: (context, h) => [
        CellText(Fmt.date(h.createdAt), sub: Fmt.time(h.createdAt)),
        CellText(h.invoiceNumber, sub: h.onCredit ? 'onCreditShort'.tr : null, color: h.onCredit ? p.danger : null),
        CellText(h.collectorName, sub: h.collectorPhone == null ? null : Fmt.phone(h.collectorPhone)),
        CellText(h.staff ?? '—'),
        IconButton(tooltip: 'handoverNote'.tr, onPressed: () => _note(h), icon: const Icon(Icons.picture_as_pdf_outlined)),
      ],
      card: (context, h) => ListTile(
        title: Text(h.collectorName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${Fmt.dateTime(h.createdAt)} · ${'invoice'.tr} ${h.invoiceNumber}'
            '${h.staff == null ? '' : ' · ${h.staff}'}'),
        trailing: IconButton(onPressed: () => _note(h), icon: const Icon(Icons.picture_as_pdf_outlined)),
      ),
    );
  }
}

// ----------------------------------------------------------------------- madai
class _ClaimsTab extends StatelessWidget {
  final CustomerOverview ov;
  final Future<void> Function() onRefresh;

  const _ClaimsTab({required this.ov, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (ov.claims.isEmpty) return _Empty(Icons.verified_outlined, 'noClaims'.tr);
    return PageScroll(
      onRefresh: onRefresh,
      spacing: 10,
      children: [
        for (final x in ov.claims)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => InvoiceFlows.open(x.invoiceId),
              leading: Icon(Icons.report_problem_outlined, color: p.warning),
              title: Text('${claimTypeLabel(x.type)} · ${'invoice'.tr} ${x.invoiceNumber ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${Fmt.date(x.createdAt)} · ${x.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pill(claimStatusLabel(x.status), color: p.primary, dense: true),
                  if (x.compensation > 0) Text(Fmt.tsh(x.compensation), style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------------- sms
class _SmsTab extends StatelessWidget {
  final CustomerOverview ov;
  final Future<void> Function() onRefresh;

  const _SmsTab({required this.ov, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (ov.sms.isEmpty) return _Empty(Icons.sms_outlined, 'noSmsYet'.tr);
    return PageScroll(
      onRefresh: onRefresh,
      spacing: 10,
      children: [
        for (final s in ov.sms)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(Fmt.dateTime(s.createdAt), style: TextStyle(color: p.muted, fontSize: 12.5)),
                      Pill(s.kind, color: p.primary, dense: true),
                      if (s.channel == 'WHATSAPP') Pill('WhatsApp', color: const Color(0xFF16A34A), dense: true),
                      s.sent
                          ? Pill('sent'.tr, color: p.success, icon: Icons.done_all_rounded, dense: true)
                          : Pill('pending'.tr, color: p.warning, dense: true),
                      if (s.invoiceNumber != null)
                        Text('${'invoice'.tr} ${s.invoiceNumber}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(s.text, style: TextStyle(color: p.text, height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
