import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/ops.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import '../reports/analytics_tabs.dart';

/// Mizigo iliyokabidhiwa: kutafuta kwa tarehe, mteja, aliyekabidhi, mchukuaji, jina la mzigo na usafiri.
class HandedOverTab extends StatefulWidget {
  const HandedOverTab({super.key});

  @override
  State<HandedOverTab> createState() => _HandedOverTabState();
}

class _HandedOverTabState extends State<HandedOverTab> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;

  final _search = TextEditingController();
  Timer? _debounce;
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  String? _carrier; // null = zote, AIR, SEA
  String? _staffId;
  bool _creditOnly = false;

  final List<HandoverRecord> _items = [];
  List<StaffRef> _staff = const [];
  int _total = 0;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _loadingMore = false;

  @override
  bool get wantKeepAlive => true;

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

  Future<HandoverPage> _fetch(int offset) => HandoverRepo.search(
        from: _range.start,
        to: _range.end,
        q: _search.text,
        staffId: _staffId,
        carrier: _carrier,
        onCredit: _creditOnly ? true : null,
        offset: offset,
        limit: _pageSize,
      );

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final page = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _staff = page.staff;
        _total = page.total;
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

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_items.length);
      if (mounted) setState(() => _items.addAll(page.items));
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openNote(HandoverRecord r) async {
    try {
      final bytes = await HandoverRepo.pdf(r.invoiceId, handoverId: r.id);
      await PdfViewerPage.open(
        title: '${'handoverNote'.tr} ${r.invoiceNumber}',
        bytes: bytes,
        fileName: 'makabidhiano_${r.invoiceNumber}',
      );
    } catch (e) {
      Toast.error(e);
    }
  }

  String _carrierLabel(String c) => c == 'SEA' ? 'sea'.tr : c == 'AIR' ? 'air'.tr : c;

  Widget _carrierPills(BuildContext context, HandoverRecord r) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final c in r.carriers)
            Pill(_carrierLabel(c),
                color: c == 'SEA' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                icon: c == 'SEA' ? Icons.directions_boat_outlined : Icons.flight_outlined,
                dense: true),
          if (r.onCredit) Pill('onCreditShort'.tr, color: context.palette.danger, dense: true),
        ],
      );

  Widget _filters(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PeriodBar(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  _load();
                },
              ),
            ),
            IconButton(
              tooltip: 'downloadExcel'.tr,
              onPressed: () => saveExcel(
                () => HandoverRepo.excel(
                  from: _range.start,
                  to: _range.end,
                  q: _search.text,
                  staffId: _staffId,
                  carrier: _carrier,
                  onCredit: _creditOnly ? true : null,
                ),
                'mizigo_iliyokabidhiwa_${DateTime.now().millisecondsSinceEpoch}',
              ),
              icon: const Icon(Icons.grid_on_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in const [null, 'AIR', 'SEA'])
              ChoiceChip(
                avatar: Icon(
                  c == null ? Icons.all_inclusive_rounded : c == 'SEA' ? Icons.directions_boat_outlined : Icons.flight_outlined,
                  size: 18,
                ),
                label: Text(c == null ? 'allCarriers'.tr : _carrierLabel(c)),
                selected: _carrier == c,
                onSelected: (_) {
                  setState(() => _carrier = c);
                  _load();
                },
              ),
            FilterChip(
              label: Text('onCreditOnly'.tr),
              selected: _creditOnly,
              onSelected: (v) {
                setState(() => _creditOnly = v);
                _load();
              },
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _staffId,
                decoration: InputDecoration(
                  labelText: 'handedOverBy'.tr,
                  isDense: true,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                ),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text('allStaff'.tr)),
                  for (final s in _staff) DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) {
                  setState(() => _staffId = v);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('handedOverCount'.trParams({'n': Fmt.number(_total)}),
            style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return Column(
      children: [
        ListToolbar(
          search: SearchBox(controller: _search, hint: 'searchHandedHint'.tr, onChanged: _onSearch),
        ),
        Expanded(
          child: AsyncBody(
            status: _status,
            error: _error,
            isEmpty: false,
            onRetry: _load,
            empty: const SizedBox.shrink(),
            builder: () => DataList<HandoverRecord>(
              items: _items,
              onRefresh: _load,
              header: Padding(padding: const EdgeInsets.only(bottom: 4), child: _filters(context)),
              footer: _items.isEmpty
                  ? EmptyState(icon: Icons.handshake_outlined, title: 'noHandedOver'.tr, message: 'noHandedOverMsg'.tr)
                  : _items.length < _total
                      ? LoadMoreButton(busy: _loadingMore, onPressed: _more, shown: _items.length)
                      : null,
              onTap: (r) => InvoiceFlows.open(r.invoiceId),
              columns: [
                ColumnSpec('date'.tr, flex: 2),
                ColumnSpec('customer'.tr, flex: 3),
                ColumnSpec('cargo'.tr, flex: 4),
                ColumnSpec('collectorName'.tr, flex: 3),
                ColumnSpec('handedOverBy'.tr, flex: 2),
                ColumnSpec('', flex: 1, align: TextAlign.end),
              ],
              cells: (context, r) => [
                CellText(Fmt.date(r.createdAt), sub: Fmt.time(r.createdAt), bold: true),
                CellText(r.customerName, sub: '${'invoice'.tr} ${r.invoiceNumber}'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.itemsLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text)),
                    const SizedBox(height: 3),
                    _carrierPills(context, r),
                  ],
                ),
                CellText(r.collectorName, sub: r.collectorPhone == null ? null : Fmt.phone(r.collectorPhone)),
                CellText(r.staffName ?? '—'),
                IconButton(
                  tooltip: 'handoverNote'.tr,
                  onPressed: () => _openNote(r),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
              card: (context, r) => Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              ),
                              Text(Fmt.dateTime(r.createdAt), style: TextStyle(color: p.muted, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${'invoice'.tr} ${r.invoiceNumber} · ${Fmt.number(r.cartons)} ${'ctn'.tr}',
                              style: TextStyle(color: p.muted, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text(r.itemsLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            '${'collectorName'.tr}: ${r.collectorName}'
                            '${r.staffName == null ? '' : ' · ${'handedOverBy'.tr}: ${r.staffName}'}',
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 6),
                          _carrierPills(context, r),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'handoverNote'.tr,
                      onPressed: () => _openNote(r),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
