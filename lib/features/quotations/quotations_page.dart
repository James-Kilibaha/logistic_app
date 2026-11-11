import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/quotation.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import 'quotation_edit_page.dart';
import 'quotation_flows.dart';

/// Makadirio ya bei: orodha, kutafuta na kuchuja kwa hali.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({super.key});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  final _search = TextEditingController();
  String? _status;
  List<Quotation> _items = const [];
  Map<String, int> _counts = const {};
  LoadStatus _state = LoadStatus.loading;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await QuotationRepo.search(query: _search.text, status: _status);
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _counts = res.counts;
        _state = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _new() async {
    final q = await QuotationEditPage.open();
    if (q != null) {
      await _load();
      await QuotationDetailPage.open(q.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = AppController.to.can(AppModule.quote, AppAction.insert);
    final all = _counts.values.fold<int>(0, (a, b) => a + b);
    return AppPage(
      help: 'quotations',
      title: 'navQuotations'.tr,
      subtitle: 'hintQuotations'.tr,
      actions: [IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      mainAction: canAdd ? PageAction(icon: Icons.request_quote_outlined, label: 'newQuotation'.tr, onPressed: _new) : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(
              controller: _search,
              hint: 'searchQuotationHint'.tr,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
            filters: FilterChips<String?>(
              values: const [null, ...quotationStatuses],
              selected: _status,
              label: (s) => s == null ? 'all'.tr : quotationStatusLabel(s),
              count: (s) => s == null ? all : _counts[s],
              onSelected: (s) {
                setState(() => _status = s);
                _load();
              },
            ),
          ),
          Expanded(
            child: AsyncBody(
              status: _state,
              error: _error,
              isEmpty: _items.isEmpty,
              onRetry: _load,
              empty: EmptyState(
                icon: Icons.request_quote_outlined,
                title: 'noQuotations'.tr,
                message: canAdd ? 'noQuotationsMsg'.tr : null,
              ),
              builder: () => PageScroll(
                onRefresh: _load,
                spacing: 10,
                children: [
                  for (final q in _items)
                    _QuotationTile(
                      quotation: q,
                      onTap: () async {
                        await QuotationDetailPage.open(q.id);
                        _load();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotationTile extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _QuotationTile({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = quotation;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: quotationStatusColor(context, q.status).withValues(alpha: .12),
                child: Icon(Icons.request_quote_outlined, color: quotationStatusColor(context, q.status)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('#${q.number}', style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
                        Pill(quotationStatusLabel(q.status), color: quotationStatusColor(context, q.status), dense: true),
                        if (q.expired) Pill('expired'.tr, color: p.warning, dense: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [q.customerName, if (q.phoneNumber != null) Fmt.phone(q.phoneNumber), Fmt.date(q.createdAt)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                    Text(
                      [
                        'itemsN'.trParams({'n': '${q.items.length}'}),
                        if (q.kg > 0) Fmt.kg(q.kg),
                        if (q.cbm > 0) '${q.cbm.toStringAsFixed(2)} CBM',
                      ].join(' · '),
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(Fmt.tsh(q.total), style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Makadirio moja: bidhaa, jumla na vitendo (PDF, SMS, kukubali/kukataa, kugeuza kuwa ankara).
class QuotationDetailPage extends StatefulWidget {
  final String id;

  const QuotationDetailPage({super.key, required this.id});

  static Future<void> open(String id) async {
    await Get.to<void>(() => QuotationDetailPage(id: id));
  }

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  Quotation? _q;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await QuotationRepo.get(widget.id);
      if (!mounted) return;
      setState(() {
        _q = q;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _status(String s) async {
    if (await runGuarded(() => QuotationRepo.setStatus(widget.id, s), success: quotationStatusLabel(s))) _load();
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      title: 'deleteQuotation'.tr,
      message: '#${_q?.number}',
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    if (await runGuarded(() => QuotationRepo.delete(widget.id), success: 'deleted'.tr)) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    if (q == null) {
      return AppPage(
        title: 'quotation'.tr,
        showBack: true,
        body: _error == null ? const LoadingList(rows: 4) : ErrorState(message: _error!, onRetry: _load),
      );
    }
    final p = context.palette;
    final can = AppController.to.can;
    final canUpdate = can(AppModule.quote, AppAction.update) && q.canEdit;
    return AppPage(
      help: 'quotations',
      title: '${'quotation'.tr} #${q.number}',
      subtitle: '${q.customerName}${q.phoneNumber == null ? '' : ' · ${Fmt.phone(q.phoneNumber)}'}',
      showBack: true,
      actions: [
        IconButton(tooltip: 'pdf'.tr, onPressed: () => QuotationFlows.pdf(q), icon: const Icon(Icons.picture_as_pdf_outlined)),
        if (QuotationFlows.canSms && q.phoneNumber != null)
          IconButton(
            tooltip: 'quotationSend'.tr,
            onPressed: () async {
              if (await QuotationFlows.sms(q)) _load();
            },
            icon: const Icon(Icons.sms_outlined),
          ),
        if (canUpdate)
          IconButton(
            tooltip: 'edit'.tr,
            onPressed: () async {
              if (await QuotationEditPage.open(quotation: q) != null) _load();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        if (can(AppModule.quote, AppAction.delete) && !q.isConverted)
          IconButton(tooltip: 'delete'.tr, onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: p.danger)),
      ],
      mainAction: q.isConverted && q.invoiceId != null
          ? PageAction(
              icon: Icons.receipt_long_outlined,
              label: '${'openInvoice'.tr} #${q.invoiceNumber ?? ''}',
              onPressed: () => InvoiceFlows.open(q.invoiceId!),
            )
          : (QuotationFlows.canConvert && q.status != 'REJECTED')
              ? PageAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'quotationConvert'.tr,
                  onPressed: () async {
                    if (await QuotationFlows.convert(q)) _load();
                  },
                )
              : null,
      body: PageScroll(
        onRefresh: _load,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(quotationStatusLabel(q.status), color: quotationStatusColor(context, q.status)),
              if (q.validUntil != null)
                Pill('validUntilD'.trParams({'d': Fmt.date(q.validUntil)}),
                    color: q.expired ? p.warning : p.muted, icon: Icons.event_outlined),
              if (q.expired) Pill('expired'.tr, color: p.warning),
              if (canUpdate && q.status != 'ACCEPTED')
                ActionChip(
                  avatar: Icon(Icons.thumb_up_alt_outlined, size: 18, color: p.success),
                  label: Text('quotationAccept'.tr),
                  onPressed: () => _status('ACCEPTED'),
                ),
              if (canUpdate && q.status != 'REJECTED')
                ActionChip(
                  avatar: Icon(Icons.thumb_down_alt_outlined, size: 18, color: p.danger),
                  label: Text('quotationReject'.tr),
                  onPressed: () => _status('REJECTED'),
                ),
            ],
          ),
          ResponsiveGrid(
            minItemWidth: 190,
            children: [
              StatCard(label: 'total'.tr, value: Fmt.tsh(q.total), icon: Icons.payments_outlined, color: p.primary),
              StatCard(label: 'cartons'.tr, value: Fmt.number(q.cartons), icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFD97706)),
              if (q.kg > 0)
                StatCard(label: 'airKg'.tr, value: Fmt.kg(q.kg), icon: Icons.flight_outlined, color: const Color(0xFF7C3AED)),
              if (q.cbm > 0)
                StatCard(label: 'seaCbm'.tr, value: '${q.cbm.toStringAsFixed(2)} CBM', icon: Icons.directions_boat_outlined,
                    color: const Color(0xFF0284C7)),
            ],
          ),
          SectionCard(
            title: 'items'.tr,
            icon: Icons.list_alt_rounded,
            child: Column(
              children: [
                for (final (n, i) in q.items.indexed) ...[
                  if (n > 0) Divider(height: 18, color: p.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 26, child: Text('${n + 1}.', style: TextStyle(color: p.muted))),
                      Icon(i.isSea ? Icons.directions_boat_outlined : Icons.flight_outlined, size: 18, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.description, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                            Text(
                              '${Fmt.number(i.quantities)} ${'ctn'.tr} · ${quotationMeasure(i)}'
                              '${i.rate > 0 ? ' · ${Fmt.tsh(i.rate)}/${i.unit == 'CBM' ? 'CBM' : 'kg'}' : ''}',
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Text(Fmt.tsh(i.amount), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (q.note != null)
            SectionCard(title: 'note'.tr, icon: Icons.notes_rounded, child: Text(q.note!)),
          Text('quotationDisclaimer'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
