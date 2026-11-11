import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../boxes/box_costs_list.dart';
import '../demands/demands.dart';

/// Dashibodi ya shughuli: kila mtumiaji anaona alichofanya (kwa moduli anazoruhusiwa);
/// mwenye ruhusa ya kumbukumbu (admin) anaweza kuchagua mtumiaji mwingine.
class MyActivityPage extends StatefulWidget {
  const MyActivityPage({super.key});

  @override
  State<MyActivityPage> createState() => _MyActivityPageState();
}

enum _Period { today, week, month, thisMonth, custom }

class _MyActivityPageState extends State<MyActivityPage> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Map<String, dynamic> _data = const {};
  List<AppUser> _users = const [];
  String? _userId; // null = mimi
  _Period _period = _Period.month;
  DateTimeRange? _custom;

  bool get _canOthers => AppController.to.can(AppModule.audit);

  @override
  void initState() {
    super.initState();
    _load();
    if (_canOthers && AppController.to.can(AppModule.user)) {
      UserRepo.all().then((u) {
        if (mounted) setState(() => _users = u);
      }).catchError((_) {});
    }
  }

  (DateTime, DateTime) _dates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.today => (today, today),
      _Period.week => (today.subtract(const Duration(days: 6)), today),
      _Period.month => (today.subtract(const Duration(days: 29)), today),
      _Period.thisMonth => (DateTime(now.year, now.month, 1), today),
      _Period.custom => (_custom?.start ?? today, _custom?.end ?? today),
    };
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    final (start, end) = _dates();
    try {
      final data = await ActivityRepo.summary(userId: _userId, start: _iso(start), end: _iso(end));
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _custom,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _Period.custom;
    });
    _load();
  }

  String _periodLabel(_Period p) => switch (p) {
        _Period.today => 'today'.tr,
        _Period.week => 'actLast7'.tr,
        _Period.month => 'actLast30'.tr,
        _Period.thisMonth => 'actThisMonth'.tr,
        _Period.custom => _custom == null ? 'actChooseDates'.tr : '${Fmt.date(_custom!.start)} – ${Fmt.date(_custom!.end)}',
      };

  @override
  Widget build(BuildContext context) {
    final user = J.map(_data['user']) ?? const <String, dynamic>{};
    final mine = _data['self'] != false;
    return AppPage(
      title: 'navMyActivity'.tr,
      subtitle: mine ? 'hintMyActivity'.tr : 'actOfUser'.trParams({'name': J.str(user['name'])}),
      actions: [
        IconButton(
          tooltip: 'myBoxCosts'.tr,
          onPressed: () => BoxCostsPage.open(mine: true),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        IconButton(tooltip: 'navDemands'.tr, onPressed: DemandsPage.open, icon: const Icon(Icons.assignment_late_outlined)),
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: PageScroll(
        onRefresh: _load,
        children: [
          _filters(context),
          if (_status == LoadStatus.loading && _data.isEmpty)
            const LoadingList(rows: 4)
          else if (_status == LoadStatus.error)
            ErrorState(message: _error ?? '', onRetry: _load)
          else ...[
            _stats(context),
            _chart(context),
            ResponsiveGrid(minItemWidth: 320, maxColumns: 2, children: [_modules(context), _devices(context)]),
            _recent(context),
          ],
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_canOthers && _users.isNotEmpty)
          DropdownButton<String?>(
            value: _userId,
            hint: Text('actMe'.tr),
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('actMe'.tr)),
              for (final u in _users)
                DropdownMenuItem<String?>(value: u.id, child: Text('${u.fullName} (${u.username})')),
            ],
            onChanged: (v) {
              setState(() => _userId = v);
              _load();
            },
          ),
        for (final p in _Period.values.where((p) => p != _Period.custom))
          ChoiceChip(
            label: Text(_periodLabel(p)),
            selected: _period == p,
            onSelected: (_) {
              setState(() => _period = p);
              _load();
            },
          ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(_periodLabel(_Period.custom)),
          selected: _period == _Period.custom,
          onSelected: (_) => _pickRange(),
        ),
      ],
    );
  }

  static IconData _metricIcon(String key) => switch (key) {
        'invoices' => Icons.receipt_long_outlined,
        'products' => Icons.inventory_outlined,
        'boxes' => Icons.inventory_2_outlined,
        'payments' => Icons.payments_outlined,
        'refunds' => Icons.undo_rounded,
        'handovers' => Icons.handshake_outlined,
        'expenses' => Icons.account_balance_wallet_outlined,
        'quotations' => Icons.request_quote_outlined,
        'claims' => Icons.report_problem_outlined,
        'sms' => Icons.sms_outlined,
        _ => Icons.insights_outlined,
      };

  Widget _stats(BuildContext context) {
    final p = context.palette;
    final metrics = J.list(_data['metrics'], (m) => m);
    final colors = [p.primary, p.success, p.info, p.warning, const Color(0xFF7C3AED), const Color(0xFF0891B2)];
    return ResponsiveGrid(
      minItemWidth: 220,
      children: [
        StatCard(
          label: 'actActions'.tr,
          value: Fmt.number(J.integer(_data['actions'])),
          icon: Icons.touch_app_outlined,
          color: p.primary,
          hint: 'actLoginsFailed'.trParams({
            'logins': Fmt.number(J.integer(_data['logins'])),
            'failed': Fmt.number(J.integer(_data['failed'])),
          }),
        ),
        for (var i = 0; i < metrics.length; i++)
          StatCard(
            label: 'act_${J.str(metrics[i]['key'])}'.tr,
            value: Fmt.number(J.integer(metrics[i]['count'])),
            icon: _metricIcon(J.str(metrics[i]['key'])),
            color: colors[(i + 1) % colors.length],
            hint: metrics[i]['amount'] != null
                ? Fmt.tsh(J.dbl(metrics[i]['amount']))
                : (metrics[i]['weight'] != null ? Fmt.kg(J.dbl(metrics[i]['weight'])) : null),
          ),
      ],
    );
  }

  Widget _chart(BuildContext context) {
    final p = context.palette;
    final days = J.list(_data['daily'], (d) => d);
    final maxCount = days.fold<int>(0, (m, d) => J.integer(d['count']) > m ? J.integer(d['count']) : m);
    return SectionCard(
      title: 'actPerDay'.tr,
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 140,
        child: days.isEmpty || maxCount == 0
            ? Center(child: Text('actNothing'.tr, style: TextStyle(color: p.muted)))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Tooltip(
                        message: '${J.str(d['date'])}: ${J.integer(d['count'])}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Container(
                            height: 4 + 130 * J.integer(d['count']) / maxCount,
                            decoration: BoxDecoration(
                              color: J.integer(d['count']) == 0 ? p.border : p.primary,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _modules(BuildContext context) {
    final p = context.palette;
    final rows = J.list(_data['modules'], (m) => m);
    return SectionCard(
      title: 'actByModule'.tr,
      icon: Icons.widgets_outlined,
      child: rows.isEmpty
          ? Text('actNothing'.tr, style: TextStyle(color: p.muted))
          : Column(
              children: [
                for (final m in rows)
                  InfoRow(label: J.str(m['module']), value: Fmt.number(J.integer(m['count']))),
              ],
            ),
    );
  }

  Widget _devices(BuildContext context) {
    final p = context.palette;
    final rows = J.list(_data['devices'], (m) => m);
    return SectionCard(
      title: 'actDevices'.tr,
      icon: Icons.devices_other_outlined,
      child: rows.isEmpty
          ? Text('actNothing'.tr, style: TextStyle(color: p.muted))
          : Column(
              children: [
                for (final d in rows)
                  InfoRow(
                    label: '${J.str(d['client']) == 'APP' ? 'auditViaApp'.tr : (J.str(d['client']) == 'WEB' ? 'auditViaWeb'.tr : J.str(d['client']))}'
                        ' · ${J.str(d['device'])}',
                    value: Fmt.number(J.integer(d['count'])),
                    icon: J.str(d['client']) == 'APP' ? Icons.phone_android_rounded : Icons.language_rounded,
                  ),
              ],
            ),
    );
  }

  Widget _recent(BuildContext context) {
    final p = context.palette;
    final rows = J.list(_data['recent'], (m) => m);
    return SectionCard(
      title: 'actRecent'.tr,
      icon: Icons.history_rounded,
      child: rows.isEmpty
          ? Text('actNothing'.tr, style: TextStyle(color: p.muted))
          : Column(
              children: [
                for (final r in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      J.integer(r['statusCode']) >= 400 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      color: J.integer(r['statusCode']) >= 400 ? p.danger : p.success,
                      size: 20,
                    ),
                    title: Text(
                      J.strOrNull(r['summary']) ?? '${J.str(r['action'])} · ${J.str(r['module'])}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text([
                      Fmt.dateTime(J.date(r['created_at'])),
                      if (J.strOrNull(r['device']) != null) J.str(r['device']),
                    ].join(' · ')),
                  ),
              ],
            ),
    );
  }
}
