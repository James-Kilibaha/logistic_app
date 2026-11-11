import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/ops.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// Kufunga hesabu ya siku: malipo ya mfumo kwa kila njia dhidi ya pesa halisi iliyohesabiwa.
class CashUpPage extends StatelessWidget {
  const CashUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPage(
        help: 'cashup',
        title: 'navCashup'.tr,
        subtitle: 'hintCashup'.tr,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.point_of_sale_outlined, size: 20), text: 'cashupCloseDay'.tr),
            Tab(icon: const Icon(Icons.history_rounded, size: 20), text: 'cashupHistory'.tr),
          ],
        ),
        body: const TabBarView(children: [_CloseDayTab(), _HistoryTab()]),
      ),
    );
  }
}

Future<void> _openPdf(CashUp c) async {
  try {
    final bytes = await CashUpRepo.pdf(c.id);
    await PdfViewerPage.open(title: '${'navCashup'.tr} ${c.day}', bytes: bytes, fileName: 'hesabu_${c.day}');
  } catch (e) {
    Toast.error(e);
  }
}

Color _diffColor(BuildContext context, double d) {
  final p = context.palette;
  if (d.abs() < 1) return p.success;
  return d < 0 ? p.danger : p.warning;
}

// ------------------------------------------------------------------- kufunga siku
class _CloseDayTab extends StatefulWidget {
  const _CloseDayTab();

  @override
  State<_CloseDayTab> createState() => _CloseDayTabState();
}

class _CloseDayTabState extends State<_CloseDayTab> with AutomaticKeepAliveClientMixin {
  DateTime _day = DateTime.now();
  CashExpected? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _busy = false;
  final Map<String, TextEditingController> _counted = {};
  final Map<String, TextEditingController> _notes = {};
  final _note = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._counted.values, ..._notes.values, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(CashLine m) => m.instituteId ?? '_none';

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final data = await CashUpRepo.expected(_day);
      if (!mounted) return;
      for (final c in [..._counted.values, ..._notes.values]) {
        c.dispose();
      }
      _counted.clear();
      _notes.clear();
      for (final m in data.methods) {
        _counted[_key(m)] = TextEditingController();
        _notes[_key(m)] = TextEditingController();
      }
      setState(() {
        _data = data;
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

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: now);
    if (picked != null) {
      setState(() => _day = picked);
      _load();
    }
  }

  double _countedOf(CashLine m) => Fmt.parse(_counted[_key(m)]?.text) ?? 0;

  Future<void> _close() async {
    final data = _data;
    if (data == null || _busy) return;
    final missing = data.methods.where((m) => m.expected != 0 && (_counted[_key(m)]?.text.trim().isEmpty ?? true));
    if (missing.isNotEmpty) {
      Toast.warning('cashupFillAll'.trParams({'name': missing.first.name}));
      return;
    }
    final counted = data.methods.fold<double>(0, (s, m) => s + _countedOf(m));
    final diff = counted - data.total;
    final ok = await confirmAction(
      title: 'cashupConfirm'.tr,
      message: 'cashupConfirmMsg'.trParams({
        'day': Fmt.date(_day),
        'expected': Fmt.tsh(data.total),
        'counted': Fmt.tsh(counted),
        'diff': Fmt.tsh(diff),
      }),
      confirmText: 'cashupCloseDay'.tr,
      icon: Icons.lock_clock_outlined,
    );
    if (!ok) return;
    setState(() => _busy = true);
    final done = await runGuarded(() async {
      final c = await CashUpRepo.close(
        _day,
        [
          for (final m in data.methods)
            {
              'instituteId': m.instituteId,
              'counted': _countedOf(m),
              if ((_notes[_key(m)]?.text.trim() ?? '').isNotEmpty) 'note': _notes[_key(m)]!.text.trim(),
            },
        ],
        note: _note.text,
      );
      Toast.success('cashupClosedMsg'.trParams({'diff': Fmt.tsh(c.difference)}), title: 'cashupClosed'.tr);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      _note.clear();
      AppController.to.notifyChanged();
      _load();
    }
  }

  Future<void> _reopen(CashUp c) async {
    final ok = await confirmAction(
      title: 'cashupReopen'.tr,
      message: 'cashupReopenMsg'.trParams({'day': c.day}),
      confirmText: 'cashupReopen'.tr,
      danger: true,
      icon: Icons.lock_open_rounded,
    );
    if (!ok) return;
    if (await runGuarded(() => CashUpRepo.reopen(c.id), success: 'changesSaved'.tr)) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final data = _data;
    final can = AppController.to.can;
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: data == null,
      onRetry: _load,
      empty: const SizedBox.shrink(),
      builder: () {
        final closed = data!.closed;
        return PageScroll(
          onRefresh: _load,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InputChip(
                  avatar: const Icon(Icons.event_rounded, size: 18),
                  label: Text(Fmt.date(_day)),
                  onPressed: _pickDay,
                ),
                ActionChip(
                  label: Text('today'.tr),
                  onPressed: () {
                    setState(() => _day = DateTime.now());
                    _load();
                  },
                ),
                Text('cashupPaymentsN'.trParams({'n': '${data.payments}'}), style: TextStyle(color: p.muted)),
              ],
            ),
            if (closed != null)
              _ClosedCard(
                cashup: closed,
                onPdf: () => _openPdf(closed),
                onReopen: can(AppModule.cashup, AppAction.delete) ? () => _reopen(closed) : null,
              )
            else ...[
              ResponsiveGrid(
                minItemWidth: 220,
                children: [
                  StatCard(label: 'cashupExpected'.tr, value: Fmt.tsh(data.total), icon: Icons.computer_rounded, color: p.primary),
                  StatCard(
                    label: 'cashupCounted'.tr,
                    value: Fmt.tsh(data.methods.fold<double>(0, (s, m) => s + _countedOf(m))),
                    icon: Icons.payments_outlined,
                    color: p.success,
                  ),
                  StatCard(
                    label: 'cashupDifference'.tr,
                    value: Fmt.tsh(data.methods.fold<double>(0, (s, m) => s + _countedOf(m)) - data.total),
                    icon: Icons.compare_arrows_rounded,
                    color: _diffColor(context, data.methods.fold<double>(0, (s, m) => s + _countedOf(m)) - data.total),
                  ),
                ],
              ),
              SectionCard(
                title: 'cashupCountTitle'.tr,
                subtitle: 'cashupCountSub'.tr,
                icon: Icons.calculate_outlined,
                child: Column(
                  children: [
                    for (final m in data.methods)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: LayoutBuilder(builder: (context, c) {
                          final wide = c.maxWidth >= 640;
                          final diff = _countedOf(m) - m.expected;
                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                              Text('${'cashupExpected'.tr}: ${Fmt.tsh(m.expected)} · ${'cashupPaymentsN'.trParams({'n': '${m.payments}'})}',
                                  style: TextStyle(color: p.muted, fontSize: 12.5)),
                              if ((_counted[_key(m)]?.text ?? '').isNotEmpty)
                                Text('${'cashupDifference'.tr}: ${Fmt.tsh(diff)}',
                                    style: TextStyle(color: _diffColor(context, diff), fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ],
                          );
                          final amount = TextField(
                            controller: _counted[_key(m)],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [ThousandsFormatter(allowDecimal: true)],
                            decoration: InputDecoration(labelText: 'cashupCounted'.tr, isDense: true),
                            onChanged: (_) => setState(() {}),
                          );
                          final note = TextField(
                            controller: _notes[_key(m)],
                            decoration: InputDecoration(labelText: 'noteOptional'.tr, isDense: true),
                          );
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: info),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: amount),
                                const SizedBox(width: 12),
                                Expanded(flex: 3, child: note),
                              ],
                            );
                          }
                          return Column(children: [info, const SizedBox(height: 8), amount, const SizedBox(height: 8), note]);
                        }),
                      ),
                    TextField(
                      controller: _note,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'cashupNote'.tr),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _busy || !can(AppModule.cashup, AppAction.insert) ? null : _close,
                        icon: _busy ? const ButtonSpinner() : const Icon(Icons.lock_clock_outlined),
                        label: Text('cashupCloseDay'.tr),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ClosedCard extends StatelessWidget {
  final CashUp cashup;
  final VoidCallback onPdf;
  final VoidCallback? onReopen;

  const _ClosedCard({required this.cashup, required this.onPdf, this.onReopen});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = cashup;
    return SectionCard(
      title: 'cashupClosedOn'.trParams({'day': c.day}),
      subtitle: 'cashupClosedBy'.trParams({'name': c.closedBy ?? '—', 'time': Fmt.dateTime(c.closedAt)}),
      icon: Icons.lock_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: 'PDF', onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
          if (onReopen != null)
            IconButton(tooltip: 'cashupReopen'.tr, onPressed: onReopen, icon: const Icon(Icons.lock_open_rounded)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(
            minItemWidth: 200,
            children: [
              StatCard(label: 'cashupExpected'.tr, value: Fmt.tsh(c.expected), icon: Icons.computer_rounded, color: p.primary),
              StatCard(label: 'cashupCounted'.tr, value: Fmt.tsh(c.counted), icon: Icons.payments_outlined, color: p.success),
              StatCard(label: 'cashupDifference'.tr, value: Fmt.tsh(c.difference), icon: Icons.compare_arrows_rounded,
                  color: _diffColor(context, c.difference)),
            ],
          ),
          if (c.lateCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('cashupLate'.trParams({'n': '${c.lateCount}', 'amount': Fmt.tsh(c.lateAmount)}),
                  style: TextStyle(color: p.warning, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 10),
          for (final l in c.lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${'cashupExpected'.tr} ${Fmt.tsh(l.expected)} · ${'cashupCounted'.tr} ${Fmt.tsh(l.counted)}'
                  '${l.note == null ? '' : ' · ${l.note}'}'),
              trailing: Text(Fmt.tsh(l.difference),
                  style: TextStyle(color: _diffColor(context, l.difference), fontWeight: FontWeight.w800)),
            ),
          if (c.note != null) Text('${'note'.tr}: ${c.note}', style: TextStyle(color: p.muted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- historia
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> with AutomaticKeepAliveClientMixin {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  List<CashUp> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final items = await CashUpRepo.history(from: _range.start, to: _range.end);
      if (!mounted) return;
      setState(() {
        _items = items;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final short = _items.where((c) => c.difference < 0).fold<double>(0, (s, c) => s + c.difference);
    final over = _items.where((c) => c.difference > 0).fold<double>(0, (s, c) => s + c.difference);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InputChip(
              avatar: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('${Fmt.date(_range.start)} – ${Fmt.date(_range.end)}'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _range,
                );
                if (picked != null) {
                  setState(() => _range = picked);
                  _load();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(label: 'cashupDaysClosed'.tr, value: Fmt.number(_items.length), icon: Icons.event_available_rounded,
                color: p.primary),
            StatCard(label: 'cashupShort'.tr, value: Fmt.tsh(short), icon: Icons.trending_down_rounded, color: p.danger),
            StatCard(label: 'cashupOver'.tr, value: Fmt.tsh(over), icon: Icons.trending_up_rounded, color: p.warning),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: false,
      onRetry: _load,
      empty: const SizedBox.shrink(),
      builder: () => DataList<CashUp>(
        items: _items,
        onRefresh: _load,
        header: header,
        footer: _items.isEmpty ? EmptyState(icon: Icons.point_of_sale_outlined, title: 'cashupNone'.tr) : null,
        onTap: _openPdf,
        columns: [
          ColumnSpec('date'.tr, flex: 2),
          ColumnSpec('cashupExpected'.tr, flex: 2, align: TextAlign.end),
          ColumnSpec('cashupCounted'.tr, flex: 2, align: TextAlign.end),
          ColumnSpec('cashupDifference'.tr, flex: 2, align: TextAlign.end),
          ColumnSpec('cashupClosedByShort'.tr, flex: 3),
        ],
        cells: (context, c) => [
          CellText(c.day, bold: true, sub: c.lateCount > 0 ? 'cashupLateShort'.trParams({'n': '${c.lateCount}'}) : null),
          CellText(Fmt.money(c.expected), align: TextAlign.end),
          CellText(Fmt.money(c.counted), align: TextAlign.end),
          CellText(Fmt.money(c.difference), align: TextAlign.end, bold: true, color: _diffColor(context, c.difference)),
          CellText(c.closedBy ?? '—', sub: Fmt.time(c.closedAt)),
        ],
        card: (context, c) => ListTile(
          title: Text(c.day, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${'cashupExpected'.tr} ${Fmt.compact(c.expected)} · ${'cashupCounted'.tr} ${Fmt.compact(c.counted)}'
              '${c.closedBy == null ? '' : ' · ${c.closedBy}'}'),
          trailing: Text(Fmt.tsh(c.difference),
              style: TextStyle(color: _diffColor(context, c.difference), fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
