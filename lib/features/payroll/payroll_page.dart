import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/lookups.dart';
import '../../data/models/accounting.dart';
import '../../data/models/json.dart';
import '../../data/models/payroll.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../reports/analytics_tabs.dart';

const String _none = '';

bool _can(AppAction a) => AppController.to.can(AppModule.payroll, a);

/// Mishahara: mishahara ya kila mwezi, wafanyakazi na viwango (PAYE / NSSF / SDL / WCF).
class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppPage(
        title: 'navPayroll'.tr,
        subtitle: 'hintPayroll'.tr,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.payments_outlined, size: 20), text: 'prRuns'.tr),
            Tab(icon: const Icon(Icons.badge_outlined, size: 20), text: 'prEmployees'.tr),
            Tab(icon: const Icon(Icons.percent_rounded, size: 20), text: 'prRates'.tr),
          ],
        ),
        body: const TabBarView(children: [_RunsTab(), _EmployeesTab(), _RatesTab()]),
      ),
    );
  }
}

mixin _Load<T extends StatefulWidget> on State<T> {
  LoadStatus status = LoadStatus.loading;
  String? error;
  Worker? _w;

  Future<void> fetch();

  Future<void> load() async {
    if (mounted) setState(() => status = LoadStatus.loading);
    try {
      await fetch();
      if (mounted) setState(() => status = LoadStatus.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          status = LoadStatus.error;
        });
      }
    }
  }

  void start() {
    _w = ever<int>(AppController.to.changes, (_) => load());
    load();
  }

  @override
  void dispose() {
    _w?.dispose();
    super.dispose();
  }
}

String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ===================================================================== mishahara ya mwezi
class _RunsTab extends StatefulWidget {
  const _RunsTab();

  @override
  State<_RunsTab> createState() => _RunsTabState();
}

class _RunsTabState extends State<_RunsTab> with AutomaticKeepAliveClientMixin, _Load {
  List<PayrollRunData> _runs = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  Future<void> fetch() async => _runs = await PayrollRepo.runs();

  Future<void> _prepare() async {
    final now = DateTime.now();
    final months = [for (var i = -1; i < 6; i++) _month(DateTime(now.year, now.month - i))];
    String month = _month(now);
    PayrollRunData? run;
    final ok = await showFormSheet(
      title: 'prPrepare'.tr,
      subtitle: 'prPrepareHint'.tr,
      icon: Icons.calculate_outlined,
      builder: (context, setState) => AppDropdown<String>(
        label: 'month'.tr,
        value: month,
        items: months,
        icon: Icons.calendar_month_rounded,
        itemLabel: (m) => m,
        onChanged: (v) => setState(() => month = v ?? month),
      ),
      onSubmit: () async => run = await PayrollRepo.prepare(month),
    );
    if (ok && run != null) {
      await load();
      await Get.to(() => PayrollRunPage(runId: run!.id));
      load();
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
          if (_can(AppAction.insert))
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: _prepare, icon: const Icon(Icons.calculate_outlined), label: Text('prPrepare'.tr)),
            ),
          if (_runs.isEmpty)
            EmptyState(icon: Icons.payments_outlined, title: 'prNoRuns'.tr, message: 'prNoRunsMsg'.tr)
          else
            Card(
              child: Column(
                children: [
                  for (final r in _runs) ...[
                    ListTile(
                      leading: Icon(r.posted ? Icons.verified_rounded : Icons.edit_note_rounded,
                          color: r.posted ? p.success : p.warning),
                      title: Text(r.month, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${'prStatus_${r.status}'.tr} · Gross ${Fmt.money(r.t('gross'))} · '
                          'Net ${Fmt.money(r.t('net'))} · PAYE ${Fmt.money(r.t('paye'))}'),
                      trailing: Text(Fmt.tsh(r.t('employerCost')), style: const TextStyle(fontWeight: FontWeight.w800)),
                      onTap: () async {
                        await Get.to(() => PayrollRunPage(runId: r.id));
                        load();
                      },
                    ),
                    if (r != _runs.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mishahara ya mwezi mmoja: kila mfanyakazi, kubadili posho/makato, kuidhinisha, PDF/Excel.
class PayrollRunPage extends StatefulWidget {
  final String runId;

  const PayrollRunPage({super.key, required this.runId});

  @override
  State<PayrollRunPage> createState() => _PayrollRunPageState();
}

class _PayrollRunPageState extends State<PayrollRunPage> with _Load {
  PayrollRunData? _run;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  Future<void> fetch() async => _run = await PayrollRepo.run(widget.runId);

  Future<void> _edit(Map<String, dynamic> line) async {
    final basic = TextEditingController(text: Fmt.money(J.dbl(line['basic'])));
    final allowance = TextEditingController(text: Fmt.money(J.dbl(line['allowance'])));
    final deduction = TextEditingController(text: Fmt.money(J.dbl(line['deduction'])));
    final ok = await showFormSheet(
      title: J.str(line['name']),
      subtitle: 'prEditLineHint'.tr,
      icon: Icons.edit_note_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField.money(controller: basic, label: 'prBasic'.tr),
          const SizedBox(height: 12),
          AppField.money(controller: allowance, label: 'prAllowance'.tr, required: false),
          const SizedBox(height: 12),
          AppField.money(controller: deduction, label: 'prDeduction'.tr, helper: 'prDeductionHint'.tr, required: false),
        ],
      ),
      onSubmit: () async => _run = await PayrollRepo.editLine(widget.runId, J.str(line['id']),
          basic: Fmt.parse(basic.text), allowance: Fmt.parse(allowance.text) ?? 0, deduction: Fmt.parse(deduction.text) ?? 0),
    );
    if (ok && mounted) setState(() {});
  }

  Future<void> _post() async {
    List<FinAccount> accounts = const [];
    try {
      accounts = await AccountingRepo.options();
    } catch (_) {}
    String account = accounts.isEmpty ? _none : accounts.first.id;
    final r = _run!;
    final ok = await showFormSheet(
      title: 'prPost'.tr,
      subtitle: 'prPostHint'.tr,
      icon: Icons.verified_rounded,
      submitLabel: 'prPost'.tr,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(label: 'Net', value: Fmt.tsh(r.t('net')), emphasize: true),
          InfoRow(label: 'PAYE + NSSF', value: Fmt.tsh(r.t('paye') + r.t('nssfEmployee'))),
          InfoRow(label: 'prEmployerShare'.tr, value: Fmt.tsh(r.t('nssfEmployer') + r.t('sdl') + r.t('wcf'))),
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'prPaidFrom'.tr,
            value: account,
            required: false,
            items: [_none, ...accounts.map((a) => a.id)],
            icon: Icons.account_balance_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : accounts.firstWhere((a) => a.id == id).label,
            onChanged: (v) => setState(() => account = v ?? _none),
          ),
        ],
      ),
      onSubmit: () async => _run = await PayrollRepo.post(widget.runId, accountId: account == _none ? null : account),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(r.month, title: 'prPosted'.tr);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      title: 'prDelete'.tr,
      message: 'prDeleteMsg'.tr,
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => PayrollRepo.deleteRun(widget.runId), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = _run;
    return AppPage(
      showBack: true,
      title: '${'navPayroll'.tr} ${r?.month ?? ''}',
      subtitle: r == null ? null : 'prStatus_${r.status}'.tr,
      actions: [
        if (r != null) ...[
          IconButton(
            tooltip: 'PDF',
            onPressed: () => openPdfFrom(() => PayrollRepo.sheet(r.id, 'pdf'), title: 'navPayroll'.tr, fileName: 'mishahara_${r.month}'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Excel',
            onPressed: () => saveExcel(() => PayrollRepo.sheet(r.id, 'xlsx'), 'mishahara_${r.month}'),
            icon: const Icon(Icons.grid_on_rounded),
          ),
          if (_can(AppAction.delete))
            IconButton(tooltip: 'delete'.tr, onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: p.danger)),
        ],
      ],
      body: AsyncBody(
        status: status,
        error: error,
        isEmpty: r == null,
        onRetry: load,
        empty: const SizedBox.shrink(),
        builder: () => PageScroll(
          onRefresh: load,
          children: [
            ResponsiveGrid(
              minItemWidth: 170,
              children: [
                StatCard(label: 'Gross', value: Fmt.tsh(r!.t('gross')), icon: Icons.payments_outlined, color: p.primary),
                StatCard(label: 'PAYE', value: Fmt.tsh(r.t('paye')), icon: Icons.account_balance_rounded, color: p.warning),
                StatCard(label: 'NSSF', value: Fmt.tsh(r.t('nssfEmployee') + r.t('nssfEmployer')), icon: Icons.shield_outlined, color: p.info),
                StatCard(label: 'Net', value: Fmt.tsh(r.t('net')), icon: Icons.wallet_rounded, color: p.success),
                StatCard(label: 'prEmployerCost'.tr, value: Fmt.tsh(r.t('employerCost')), icon: Icons.business_rounded, color: p.danger),
              ],
            ),
            if (!r.posted && _can(AppAction.update))
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(onPressed: _post, icon: const Icon(Icons.verified_rounded), label: Text('prPost'.tr)),
              ),
            Card(
              child: Column(
                children: [
                  for (final l in r.lines) ...[
                    ListTile(
                      title: Text(J.str(l['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if (l['position'] != null) J.str(l['position']),
                        'Gross ${Fmt.money(J.dbl(l['gross']))}',
                        'NSSF ${Fmt.money(J.dbl(l['nssfEmployee']))}',
                        'PAYE ${Fmt.money(J.dbl(l['paye']))}',
                        if (J.dbl(l['deduction']) > 0) '${'prDeduction'.tr} ${Fmt.money(J.dbl(l['deduction']))}',
                      ].join(' · ')),
                      trailing: Text('Net ${Fmt.money(J.dbl(l['net']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      onTap: !r.posted && _can(AppAction.update) ? () => _edit(l) : null,
                    ),
                    if (l != r.lines.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            Text('prRatesNote'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== wafanyakazi
class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> with AutomaticKeepAliveClientMixin, _Load {
  List<StaffMember> _items = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  Future<void> fetch() async => _items = await PayrollRepo.employees(all: true);

  Future<void> _form({StaffMember? e}) async {
    List<Office> offices = const [];
    try {
      offices = await Lookups.to.loadOffices();
    } catch (_) {}
    final name = TextEditingController(text: e?.name ?? '');
    final phone = TextEditingController(text: e?.phone ?? '');
    final position = TextEditingController(text: e?.position ?? '');
    final basic = TextEditingController(text: e == null ? '' : Fmt.money(e.basic));
    final allowance = TextEditingController(text: e == null ? '0' : Fmt.money(e.allowance));
    final deduction = TextEditingController(text: e == null ? '0' : Fmt.money(e.deduction));
    final tin = TextEditingController(text: e?.tin ?? '');
    final nssfNo = TextEditingController(text: e?.nssfNo ?? '');
    final bank = TextEditingController(text: e?.bank ?? '');
    bool nssf = e?.nssf ?? true, paye = e?.paye ?? true, active = e?.active ?? true;
    String office = e?.officeId ?? _none;
    if (office != _none && !offices.any((o) => o.id == office)) office = _none;
    final ok = await showFormSheet(
      title: e == null ? 'prNewEmployee'.tr : 'prEditEmployee'.tr,
      icon: Icons.badge_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: name, label: 'name'.tr, icon: Icons.person_outline_rounded, required: true,
              capitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          AppField(controller: position, label: 'prPosition'.tr, icon: Icons.work_outline_rounded, required: false),
          const SizedBox(height: 12),
          AppField(controller: phone, label: 'phone'.tr, icon: Icons.phone_outlined, required: false, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'office'.tr,
            value: office,
            required: false,
            items: [_none, ...offices.map((o) => o.id)],
            icon: Icons.store_mall_directory_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : offices.firstWhere((o) => o.id == id).label,
            onChanged: (v) => setState(() => office = v ?? _none),
          ),
          const SizedBox(height: 12),
          AppField.money(controller: basic, label: 'prBasic'.tr),
          const SizedBox(height: 12),
          AppField.money(controller: allowance, label: 'prAllowance'.tr, required: false),
          const SizedBox(height: 12),
          AppField.money(controller: deduction, label: 'prDeduction'.tr, helper: 'prDeductionHint'.tr, required: false),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: nssf, title: Text('prHasNssf'.tr), onChanged: (v) => setState(() => nssf = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: paye, title: Text('prHasPaye'.tr), onChanged: (v) => setState(() => paye = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: Text('prActive'.tr), onChanged: (v) => setState(() => active = v)),
          AppField(controller: tin, label: 'TIN', icon: Icons.numbers_rounded, required: false),
          const SizedBox(height: 12),
          AppField(controller: nssfNo, label: 'prNssfNo'.tr, icon: Icons.numbers_rounded, required: false),
          const SizedBox(height: 12),
          AppField(controller: bank, label: 'prBank'.tr, icon: Icons.account_balance_outlined, required: false),
        ],
      ),
      onSubmit: () => PayrollRepo.saveEmployee({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'position': position.text.trim(),
        'office_id': office == _none ? null : office,
        'basic': Fmt.parse(basic.text) ?? 0,
        'allowance': Fmt.parse(allowance.text) ?? 0,
        'deduction': Fmt.parse(deduction.text) ?? 0,
        'nssf': nssf,
        'paye': paye,
        'tin': tin.text.trim(),
        'nssfNo': nssfNo.text.trim(),
        'bank': bank.text.trim(),
        'active': active,
      }, id: e?.id),
    );
    if (ok) {
      load();
      Toast.success(name.text, title: 'saved'.tr);
    }
  }

  Future<void> _delete(StaffMember e) async {
    final ok = await confirmAction(title: 'delete'.tr, message: e.name, confirmText: 'delete'.tr, danger: true, icon: Icons.delete_outline_rounded);
    if (ok && await runGuarded(() => PayrollRepo.deleteEmployee(e.id), success: 'deleted'.tr)) load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final total = _items.where((e) => e.active).fold<double>(0, (s, e) => s + e.basic + e.allowance);
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
              Pill('${_items.where((e) => e.active).length} ${'prEmployees'.tr.toLowerCase()} · Gross ${Fmt.tsh(total)}', color: p.primary),
              if (_can(AppAction.insert))
                FilledButton.icon(onPressed: () => _form(), icon: const Icon(Icons.person_add_alt_rounded), label: Text('prNewEmployee'.tr)),
            ],
          ),
          if (_items.isEmpty)
            EmptyState(icon: Icons.badge_outlined, title: 'prNoEmployees'.tr)
          else
            Card(
              child: Column(
                children: [
                  for (final e in _items) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (e.active ? p.primary : p.muted).withValues(alpha: .12),
                        child: Icon(Icons.person_rounded, color: e.active ? p.primary : p.muted, size: 20),
                      ),
                      title: Text(e.name, style: TextStyle(fontWeight: FontWeight.w700, color: e.active ? null : p.muted)),
                      subtitle: Text([
                        if (e.position != null) e.position!,
                        if (e.office != null) e.office!,
                        if (!e.nssf) 'bila NSSF',
                        if (!e.active) 'prInactive'.tr,
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.tsh(e.basic + e.allowance), style: const TextStyle(fontWeight: FontWeight.w800)),
                          if (_can(AppAction.update) || _can(AppAction.delete))
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _form(e: e);
                                if (v == 'delete') _delete(e);
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
                    if (e != _items.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===================================================================== viwango
class _RatesTab extends StatefulWidget {
  const _RatesTab();

  @override
  State<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<_RatesTab> with AutomaticKeepAliveClientMixin, _Load {
  Map<String, dynamic> _d = const {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  Future<void> fetch() async => _d = await PayrollRepo.settings();

  List<List<double?>> get _bands {
    final b = _d['payeBands'];
    if (b is! List) return const [];
    return [
      for (final x in b.whereType<List>()) [for (final v in x) v == null ? null : J.dbl(v)],
    ];
  }

  Future<void> _edit() async {
    final ee = TextEditingController(text: '${_d['nssfEmployee']}');
    final er = TextEditingController(text: '${_d['nssfEmployer']}');
    final sdl = TextEditingController(text: '${_d['sdl']}');
    final wcf = TextEditingController(text: '${_d['wcf']}');
    bool sdlOn = J.boolean(_d['sdlEnabled']);
    final rows = [
      for (final b in _bands)
        [
          TextEditingController(text: Fmt.money(b[0] ?? 0)),
          TextEditingController(text: b[1] == null ? '' : Fmt.money(b[1]!)),
          TextEditingController(text: Fmt.money(b[2] ?? 0)),
          TextEditingController(text: '${b[3] ?? 0}'),
        ],
    ];
    Widget num(TextEditingController c, String label) =>
        AppField(controller: c, label: label, keyboardType: const TextInputType.numberWithOptions(decimal: true), required: false);
    final ok = await showFormSheet(
      title: 'prRates'.tr,
      subtitle: 'prRatesNote'.tr,
      icon: Icons.percent_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          num(ee, 'NSSF (mfanyakazi) %'),
          const SizedBox(height: 12),
          num(er, 'NSSF (mwajiri) %'),
          const SizedBox(height: 12),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: sdlOn, title: Text('prSdlOn'.tr), onChanged: (v) => setState(() => sdlOn = v)),
          num(sdl, 'SDL %'),
          const SizedBox(height: 12),
          num(wcf, 'WCF %'),
          const SizedBox(height: 16),
          FieldLabel('prPayeBands'.tr),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: num(r[0], 'prFrom'.tr)),
                  const SizedBox(width: 6),
                  Expanded(child: num(r[1], 'prTo'.tr)),
                  const SizedBox(width: 6),
                  Expanded(child: num(r[2], 'prFixed'.tr)),
                  const SizedBox(width: 6),
                  Expanded(child: num(r[3], '%')),
                ],
              ),
            ),
        ],
      ),
      onSubmit: () => PayrollRepo.saveSettings({
        'nssfEmployee': double.tryParse(ee.text.trim()) ?? 10,
        'nssfEmployer': double.tryParse(er.text.trim()) ?? 10,
        'sdl': double.tryParse(sdl.text.trim()) ?? 3.5,
        'sdlEnabled': sdlOn,
        'wcf': double.tryParse(wcf.text.trim()) ?? 0.5,
        'payeBands': [
          for (final r in rows)
            [Fmt.parse(r[0].text) ?? 0, r[1].text.trim().isEmpty ? null : Fmt.parse(r[1].text), Fmt.parse(r[2].text) ?? 0, double.tryParse(r[3].text.trim()) ?? 0],
        ],
      }),
    );
    if (ok) load();
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
          SectionCard(
            title: 'prRates'.tr,
            icon: Icons.percent_rounded,
            trailing: _can(AppAction.update)
                ? TextButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_outlined, size: 18), label: Text('edit'.tr))
                : null,
            child: Column(
              children: [
                InfoRow(label: 'NSSF (mfanyakazi)', value: '${_d['nssfEmployee']}%'),
                InfoRow(label: 'NSSF (mwajiri)', value: '${_d['nssfEmployer']}%'),
                InfoRow(label: 'SDL', value: J.boolean(_d['sdlEnabled']) ? '${_d['sdl']}%' : 'prOff'.tr),
                InfoRow(label: 'WCF', value: '${_d['wcf']}%'),
              ],
            ),
          ),
          SectionCard(
            title: 'prPayeBands'.tr,
            icon: Icons.account_balance_rounded,
            child: Column(
              children: [
                for (final b in _bands)
                  InfoRow(
                    label: '${Fmt.money(b[0] ?? 0)} – ${b[1] == null ? '∞' : Fmt.money(b[1]!)}',
                    value: '${Fmt.money(b[2] ?? 0)} + ${b[3]}%',
                  ),
              ],
            ),
          ),
          Text('prRatesNote'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
