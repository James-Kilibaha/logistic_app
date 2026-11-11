import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/box.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../notifications/notifications.dart';
import '../reports/analytics_tabs.dart' show saveExcel;

/// Box limefika: mizigo yote iliyomo (kwa ankara), na kutuma SMS ya "mzigo umefika"
/// kwa mteja mmoja mmoja, waliochaguliwa, au wote ambao bado hawajatumiwa. Orodha inatolewa Excel.
class ArrivalsPage extends StatefulWidget {
  final Box box;

  const ArrivalsPage({super.key, required this.box});

  static Future<void> open(Box box) async {
    await Get.to(() => ArrivalsPage(box: box));
  }

  @override
  State<ArrivalsPage> createState() => _ArrivalsPageState();
}

class _ArrivalsPageState extends State<ArrivalsPage> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  final Set<String> _selected = {};
  bool _toReceiver = true;
  bool _sending = false;
  String _query = '';

  bool get _canSend => AppController.to.can(AppModule.sms, AppAction.insert);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _rows.isEmpty ? LoadStatus.loading : _status);
    try {
      final data = await BoxRepo.arrivals(widget.box.id);
      if (!mounted) return;
      setState(() {
        _rows = J.list(data['invoices'], (m) => m);
        _selected.removeWhere((id) => !_rows.any((r) => r['invoiceId'] == id));
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = LoadStatus.error;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      final c = J.map(r['customer']) ?? const {};
      final hay = [r['invoiceNumber'], c['name'], c['phone'], r['descriptions'], ...J.list(r['officeCodes'], (x) => x)]
          .join(' ')
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<String> get _pendingIds =>
      _rows.where((r) => J.integer(r['smsSent']) == 0).map((r) => J.str(r['invoiceId'])).toList();

  Future<void> _send(List<String> ids, {required String title}) async {
    if (ids.isEmpty || _sending) return;
    final ok = await confirmAction(
      title: title,
      message: 'arrSendMsg'.trParams({'n': '${ids.length}'}) + (_toReceiver ? '\n${'arrAlsoReceiver'.tr}' : ''),
      confirmText: 'send'.tr,
      icon: Icons.send_rounded,
    );
    if (!ok) return;
    setState(() => _sending = true);
    Map<String, dynamic>? result;
    final done = await runGuarded(() async {
      result = await BoxRepo.notifyStore(widget.box.id, invoiceIds: ids, toReceiver: _toReceiver);
    });
    if (mounted) setState(() => _sending = false);
    if (!done) return;
    Toast.success('arrSent'.trParams({'n': '${J.integer(result?['messages'])}'}), title: 'smsSent'.tr);
    _selected.clear();
    AppController.to.notifyChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = _visible;
    final pending = _pendingIds;
    return AppPage(
      title: 'arrTitle'.trParams({'box': widget.box.boxId}),
      subtitle: 'arrSub'.trParams({'n': '${_rows.length}', 'pending': '${pending.length}'}),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'exportExcel'.tr,
          onPressed: () => saveExcel(() => BoxRepo.arrivalsExcel(widget.box.id), 'box_${widget.box.boxId}_mizigo'),
          icon: const Icon(Icons.table_view_outlined),
        ),
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: _status == LoadStatus.loading
          ? const LoadingList(rows: 5)
          : _status == LoadStatus.error
              ? ErrorState(message: _error ?? '', onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 280,
                            child: TextField(
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: 'arrSearch'.tr,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.person_pin_circle_outlined, size: 18),
                            label: Text('arrAlsoReceiverChip'.tr),
                            selected: _toReceiver,
                            onSelected: (v) => setState(() => _toReceiver = v),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              final ids = rows.map((r) => J.str(r['invoiceId']));
                              if (ids.every(_selected.contains)) {
                                _selected.removeAll(ids);
                              } else {
                                _selected.addAll(ids);
                              }
                            }),
                            icon: const Icon(Icons.select_all_rounded),
                            label: Text('selectAll'.tr),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: rows.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 60),
                                Center(child: Text('arrEmpty'.tr, style: TextStyle(color: p.muted))),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) => _tile(context, rows[i]),
                              ),
                      ),
                    ),
                    if (_canSend) _bottomBar(context, pending),
                  ],
                ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> r) {
    final p = context.palette;
    final id = J.str(r['invoiceId']);
    final customer = J.map(r['customer']) ?? const {};
    final receiver = J.map(r['receiver']);
    final sent = J.integer(r['smsSent']);
    final codes = J.list(r['officeCodes'], (x) => x).join(', ');
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _selected.contains(id) ? p.primary : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _canSend ? () => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id)) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canSend)
                Checkbox(
                  value: _selected.contains(id),
                  onChanged: (v) => setState(() => v == true ? _selected.add(id) : _selected.remove(id)),
                )
              else
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
                        Text('${J.str(customer['name'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('#${J.str(r['invoiceNumber'])}', style: TextStyle(color: p.muted)),
                        sent > 0
                            ? Pill('arrSmsSentN'.trParams({'n': '$sent'}), color: p.success, icon: Icons.done_all_rounded)
                            : Pill('arrSmsNotSent'.tr, color: p.warning, icon: Icons.schedule_rounded),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(Fmt.phone(J.str(customer['phone'])), style: TextStyle(color: p.muted, fontSize: 12.5)),
                    if (receiver != null)
                      Text('${'receiver'.tr}: ${J.str(receiver['name'])} · ${Fmt.phone(J.str(receiver['phone']))}',
                          style: TextStyle(color: p.muted, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(J.str(r['descriptions']), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        'arrCartons'.trParams({'n': Fmt.number(J.dbl(r['cartons']))}),
                        Fmt.kg(J.dbl(r['kg'])),
                        Fmt.tsh(J.dbl(r['amount'])),
                        if (codes.isNotEmpty) '${'officeCode'.tr}: $codes',
                      ].join(' · '),
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'openInvoice'.tr,
                    onPressed: () => NotificationsController.openAppLink('invoice:$id'),
                    icon: Icon(Icons.open_in_new_rounded, color: p.muted, size: 20),
                  ),
                  if (_canSend)
                    IconButton(
                      tooltip: sent > 0 ? 'resend'.tr : 'send'.tr,
                      onPressed: _sending ? null : () => _send([id], title: 'arrSendOne'.tr),
                      icon: Icon(sent > 0 ? Icons.refresh_rounded : Icons.send_rounded, color: p.primary, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, List<String> pending) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _selected.isEmpty || _sending
                  ? null
                  : () => _send(_selected.toList(), title: 'arrSendSelected'.trParams({'n': '${_selected.length}'})),
              icon: const Icon(Icons.checklist_rounded),
              label: Text('arrSendSelected'.trParams({'n': '${_selected.length}'})),
            ),
            FilledButton.icon(
              onPressed: pending.isEmpty || _sending
                  ? null
                  : () => _send(pending, title: 'arrSendPending'.trParams({'n': '${pending.length}'})),
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.campaign_outlined),
              label: Text('arrSendPending'.trParams({'n': '${pending.length}'})),
            ),
          ],
        ),
      ),
    );
  }
}
