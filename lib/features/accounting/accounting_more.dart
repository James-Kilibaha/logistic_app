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
import '../../data/lookups.dart';
import '../../data/models/accounting.dart';
import '../../data/models/json.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../expenses/expenses_page.dart';

const String _none = '';
const List<String> assetCategories = ['VEHICLE', 'COMPUTER', 'FURNITURE', 'EQUIPMENT', 'BUILDING', 'OTHER'];

bool _can(AppAction a) => AppController.to.can(AppModule.accounting, a);

/// Msingi wa tab: kupakia, kosa, na kupakia upya data ikibadilika popote.
abstract class _TabState<T extends StatefulWidget> extends State<T> with AutomaticKeepAliveClientMixin {
  LoadStatus status = LoadStatus.loading;
  String? error;
  Worker? _changes;

  @override
  bool get wantKeepAlive => true;

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

  @override
  void initState() {
    super.initState();
    _changes = ever<int>(AppController.to.changes, (_) => load());
    load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }

  Widget body(BuildContext context);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncBody(
      status: status,
      error: error,
      isEmpty: false,
      onRetry: load,
      empty: const SizedBox.shrink(),
      builder: () => body(context),
    );
  }
}

Future<List<FinAccount>> _accounts() async {
  try {
    return await AccountingRepo.options();
  } catch (_) {
    return const [];
  }
}

Widget _accountPicker(List<FinAccount> accounts, String value, StateSetter setState, void Function(String) set,
        {String? label}) =>
    AppDropdown<String>(
      label: label ?? 'accAccount'.tr,
      value: value,
      required: false,
      items: [_none, ...accounts.map((a) => a.id)],
      icon: Icons.account_balance_outlined,
      itemLabel: (id) => id == _none ? 'noneOption'.tr : accounts.firstWhere((a) => a.id == id).label,
      onChanged: (v) => setState(() => set(v ?? _none)),
    );

// ===================================================================== mtaji
class EquityTab extends StatefulWidget {
  const EquityTab({super.key});

  @override
  State<EquityTab> createState() => _EquityTabState();
}

class _EquityTabState extends _TabState<EquityTab> {
  List<EquityEntry> _items = const [];
  double _capital = 0, _drawings = 0;

  @override
  Future<void> fetch() async {
    final r = await AccountingRepo.equity();
    _items = r.items;
    _capital = r.capital;
    _drawings = r.drawings;
  }

  Future<void> _add(String kind) async {
    final accounts = await _accounts();
    final currencies = await loadCurrencyCodes();
    final amount = TextEditingController();
    final owner = TextEditingController();
    final details = TextEditingController();
    String currency = 'TZS';
    String account = accounts.isEmpty ? _none : accounts.first.id;
    final ok = await showFormSheet(
      title: kind == 'CAPITAL' ? 'accAddCapital'.tr : 'accAddDrawing'.tr,
      subtitle: 'accEquityHint'.tr,
      icon: kind == 'CAPITAL' ? Icons.add_card_rounded : Icons.output_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currencies.length > 1) ...[
            FieldLabel('currency'.tr),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
            const SizedBox(height: 16),
          ],
          AppField.money(controller: amount, label: '${'amount'.tr} ($currency)'),
          const SizedBox(height: 16),
          _accountPicker(accounts, account, setState, (v) => account = v,
              label: kind == 'CAPITAL' ? 'accReceivedInto'.tr : 'paidFromAccount'.tr),
          const SizedBox(height: 16),
          AppField(controller: owner, label: 'accOwner'.tr, icon: Icons.person_outline_rounded, required: false),
          const SizedBox(height: 16),
          AppField(controller: details, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
        ],
      ),
      onSubmit: () => AccountingRepo.saveEquity(
        kind: kind,
        amount: Fmt.parse(amount.text) ?? 0,
        currency: currency,
        accountId: account == _none ? null : account,
        owner: owner.text,
        details: details.text,
      ),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(amount.text, title: 'saved'.tr);
    }
  }

  Future<void> _delete(EquityEntry e) async {
    final ok = await confirmAction(
      title: 'delete'.tr,
      message: '${e.isCapital ? 'accCapital'.tr : 'accDrawings'.tr} · ${Fmt.tsh(e.amount)}',
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && await runGuarded(() => AccountingRepo.deleteEquity(e.id), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  @override
  Widget body(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      onRefresh: load,
      children: [
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(label: 'accCapital'.tr, value: Fmt.tsh(_capital), icon: Icons.add_card_rounded, color: p.success),
            StatCard(label: 'accDrawings'.tr, value: Fmt.tsh(_drawings), icon: Icons.output_rounded, color: p.warning),
            StatCard(label: 'accNetCapital'.tr, value: Fmt.tsh(_capital - _drawings), icon: Icons.diamond_outlined, color: p.primary),
          ],
        ),
        Text('accEquityHint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        if (_can(AppAction.insert))
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                  onPressed: () => _add('DRAWING'), icon: const Icon(Icons.output_rounded), label: Text('accAddDrawing'.tr)),
              FilledButton.icon(
                  onPressed: () => _add('CAPITAL'), icon: const Icon(Icons.add_card_rounded), label: Text('accAddCapital'.tr)),
            ],
          ),
        if (_items.isEmpty)
          EmptyState(icon: Icons.diamond_outlined, title: 'noData'.tr)
        else
          Card(
            child: Column(
              children: [
                for (final e in _items) ...[
                  ListTile(
                    leading: Icon(e.isCapital ? Icons.add_card_rounded : Icons.output_rounded,
                        color: e.isCapital ? p.success : p.warning),
                    title: Text(e.isCapital ? 'accCapital'.tr : 'accDrawings'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (e.owner != null) e.owner!,
                      if (e.account != null) e.account!,
                      if (e.details != null) e.details!,
                      Fmt.dateTime(e.createdAt),
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.amountOriginal != null ? '${e.currency} ${Fmt.money2(e.amountOriginal!)}' : Fmt.tsh(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (_can(AppAction.delete))
                          IconButton(
                              onPressed: () => _delete(e), icon: Icon(Icons.delete_outline_rounded, color: p.danger)),
                      ],
                    ),
                  ),
                  if (e != _items.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ===================================================================== mizania
class BalanceSheetTab extends StatefulWidget {
  const BalanceSheetTab({super.key});

  @override
  State<BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends _TabState<BalanceSheetTab> {
  Map<String, dynamic> _d = const {};

  @override
  Future<void> fetch() async => _d = await AccountingRepo.balanceSheet();

  Map<String, dynamic> _m(String k) => _d[k] is Map ? Map<String, dynamic>.from(_d[k] as Map) : const {};

  @override
  Widget body(BuildContext context) {
    final p = context.palette;
    final a = _m('assets'), l = _m('liabilities'), e = _m('equity');
    final accounts = a['accounts'] is List ? [for (final x in (a['accounts'] as List).whereType<Map>()) x] : const [];
    return PageScroll(
      onRefresh: load,
      children: [
        Text('${'accBalanceSheetAt'.tr} ${J.str(_d['date'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(label: 'bsAssets'.tr, value: Fmt.tsh(J.dbl(a['total'])), icon: Icons.account_balance_rounded, color: p.success),
            StatCard(label: 'bsLiabilities'.tr, value: Fmt.tsh(J.dbl(l['total'])), icon: Icons.request_quote_outlined, color: p.danger),
            StatCard(label: 'bsEquity'.tr, value: Fmt.tsh(J.dbl(e['total'])), icon: Icons.diamond_outlined, color: p.primary),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 340,
          maxColumns: 3,
          children: [
            SectionCard(
              title: 'bsAssets'.tr,
              icon: Icons.account_balance_rounded,
              child: Column(
                children: [
                  for (final x in accounts)
                    InfoRow(
                      label: '${x['name']} (${x['currency']})',
                      value: Fmt.tsh(J.dbl(x['amount'])),
                    ),
                  InfoRow(label: 'bsCash'.tr, value: Fmt.tsh(J.dbl(a['cash'])), emphasize: true),
                  InfoRow(label: 'accReceivables'.tr, value: Fmt.tsh(J.dbl(a['receivables']))),
                  InfoRow(label: 'accAssets'.tr, value: Fmt.tsh(J.dbl(a['fixedAssets']))),
                  const Divider(),
                  InfoRow(label: 'total'.tr, value: Fmt.tsh(J.dbl(a['total'])), emphasize: true),
                ],
              ),
            ),
            SectionCard(
              title: 'bsLiabilities'.tr,
              icon: Icons.request_quote_outlined,
              child: Column(
                children: [
                  InfoRow(label: 'bsBoxCostDebts'.tr, value: Fmt.tsh(J.dbl(l['boxCosts']))),
                  InfoRow(label: 'bsExpenseDebts'.tr, value: Fmt.tsh(J.dbl(l['expenses']))),
                  const Divider(),
                  InfoRow(label: 'total'.tr, value: Fmt.tsh(J.dbl(l['total'])), emphasize: true),
                ],
              ),
            ),
            SectionCard(
              title: 'bsEquity'.tr,
              icon: Icons.diamond_outlined,
              child: Column(
                children: [
                  InfoRow(label: 'accCapital'.tr, value: Fmt.tsh(J.dbl(e['capital']))),
                  InfoRow(label: 'accDrawings'.tr, value: '- ${Fmt.tsh(J.dbl(e['drawings']))}'),
                  InfoRow(label: 'bsRetained'.tr, value: Fmt.tsh(J.dbl(e['retained']))),
                  const Divider(),
                  InfoRow(label: 'total'.tr, value: Fmt.tsh(J.dbl(e['total'])), emphasize: true),
                ],
              ),
            ),
          ],
        ),
        Text('bsHint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
      ],
    );
  }
}

// ===================================================================== mali za kudumu
class AssetsTab extends StatefulWidget {
  const AssetsTab({super.key});

  @override
  State<AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends _TabState<AssetsTab> {
  List<FixedAssetItem> _items = const [];
  double _cost = 0, _acc = 0, _book = 0;

  @override
  Future<void> fetch() async {
    final r = await AssetRepo.all();
    _items = r.items;
    _cost = r.cost;
    _acc = r.accumulated;
    _book = r.bookValue;
  }

  Future<void> _form({FixedAssetItem? asset}) async {
    final accounts = await _accounts();
    final currencies = await loadCurrencyCodes();
    List<Office> offices = const [];
    try {
      offices = await Lookups.to.loadOffices();
    } catch (_) {}
    final name = TextEditingController(text: asset?.name ?? '');
    final cost = TextEditingController(text: asset == null ? '' : Fmt.money2(asset.amountOriginal ?? asset.cost));
    final life = TextEditingController(text: '${asset?.lifeMonths ?? 60}');
    final salvage = TextEditingController(text: asset == null ? '0' : Fmt.money(asset.salvage));
    final serial = TextEditingController(text: asset?.serial ?? '');
    final note = TextEditingController(text: asset?.note ?? '');
    String category = asset?.category ?? 'COMPUTER';
    String currency = asset?.currency ?? 'TZS';
    if (!currencies.contains(currency)) currencies.add(currency);
    String account = asset?.accountId ?? _none;
    if (account != _none && !accounts.any((a) => a.id == account)) account = _none;
    String office = asset?.officeId ?? _none;
    if (office != _none && !offices.any((o) => o.id == office)) office = _none;
    DateTime bought = DateTime.tryParse(asset?.purchaseDate ?? '') ?? DateTime.now();
    final ok = await showFormSheet(
      title: asset == null ? 'assetNew'.tr : 'assetEdit'.tr,
      icon: Icons.precision_manufacturing_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: name, label: 'name'.tr, hint: 'assetNameHint'.tr, icon: Icons.badge_outlined, required: true),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in assetCategories)
                ChoiceChip(label: Text('asset_$c'.tr), selected: category == c, onSelected: (_) => setState(() => category = c)),
            ],
          ),
          if (currencies.length > 1) ...[
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
          ],
          const SizedBox(height: 16),
          AppField.money(controller: cost, label: '${'assetCost'.tr} ($currency)'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                  context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: bought);
              if (d != null) setState(() => bought = d);
            },
            icon: const Icon(Icons.event_rounded),
            label: Text('${'assetBought'.tr}: ${Fmt.date(bought)}'),
          ),
          const SizedBox(height: 16),
          AppField(
            controller: life,
            label: 'assetLife'.tr,
            helper: 'assetLifeHint'.tr,
            icon: Icons.timelapse_rounded,
            keyboardType: TextInputType.number,
            required: true,
          ),
          const SizedBox(height: 16),
          AppField.money(controller: salvage, label: 'assetSalvage'.tr, helper: 'assetSalvageHint'.tr, required: false),
          const SizedBox(height: 16),
          _accountPicker(accounts, account, setState, (v) => account = v, label: 'paidFromAccount'.tr),
          const SizedBox(height: 4),
          Text('assetAccountHint'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'office'.tr,
            value: office,
            required: false,
            items: [_none, ...offices.map((o) => o.id)],
            icon: Icons.store_mall_directory_outlined,
            itemLabel: (id) => id == _none ? 'noneOption'.tr : offices.firstWhere((o) => o.id == id).label,
            onChanged: (v) => setState(() => office = v ?? _none),
          ),
          const SizedBox(height: 16),
          AppField(controller: serial, label: 'assetSerial'.tr, icon: Icons.qr_code_2_rounded, required: false),
          const SizedBox(height: 16),
          AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
        ],
      ),
      onSubmit: () => AssetRepo.save(
        id: asset?.id,
        name: name.text,
        category: category,
        cost: Fmt.parse(cost.text) ?? 0,
        currency: currency,
        purchaseDate: bought,
        lifeMonths: int.tryParse(life.text.trim()) ?? 60,
        salvage: Fmt.parse(salvage.text) ?? 0,
        accountId: account == _none ? null : account,
        officeId: office == _none ? null : office,
        serial: serial.text,
        note: note.text,
      ),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(name.text, title: 'saved'.tr);
    }
  }

  Future<void> _dispose(FixedAssetItem a) async {
    final accounts = await _accounts();
    final amount = TextEditingController(text: '0');
    String account = _none;
    DateTime day = DateTime.now();
    final ok = await showFormSheet(
      title: 'assetDispose'.tr,
      subtitle: '${a.name} · ${'assetBookValue'.tr}: ${Fmt.tsh(a.bookValue)}',
      icon: Icons.sell_outlined,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField.money(controller: amount, label: 'assetDisposeAmount'.tr, helper: 'assetDisposeHint'.tr, required: false),
          const SizedBox(height: 16),
          _accountPicker(accounts, account, setState, (v) => account = v, label: 'accReceivedInto'.tr),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: day);
              if (d != null) setState(() => day = d);
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(Fmt.date(day)),
          ),
        ],
      ),
      onSubmit: () => AssetRepo.dispose(a.id, date: day, amount: Fmt.parse(amount.text) ?? 0, accountId: account == _none ? null : account),
    );
    if (ok) AppController.to.notifyChanged();
  }

  Future<void> _delete(FixedAssetItem a) async {
    final ok = await confirmAction(
        title: 'delete'.tr, message: a.name, confirmText: 'delete'.tr, danger: true, icon: Icons.delete_outline_rounded);
    if (ok && await runGuarded(() => AssetRepo.delete(a.id), success: 'deleted'.tr)) AppController.to.notifyChanged();
  }

  @override
  Widget body(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      onRefresh: load,
      children: [
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(label: 'assetCost'.tr, value: Fmt.tsh(_cost), icon: Icons.shopping_bag_outlined, color: p.info),
            StatCard(label: 'assetAccumulated'.tr, value: Fmt.tsh(_acc), icon: Icons.trending_down_rounded, color: p.warning),
            StatCard(label: 'assetBookValue'.tr, value: Fmt.tsh(_book), icon: Icons.precision_manufacturing_outlined, color: p.primary),
          ],
        ),
        Text('assetHint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
        if (_can(AppAction.insert))
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: Text('assetNew'.tr)),
          ),
        if (_items.isEmpty)
          EmptyState(icon: Icons.precision_manufacturing_outlined, title: 'assetNone'.tr)
        else
          Card(
            child: Column(
              children: [
                for (final a in _items) ...[
                  ListTile(
                    leading: Icon(Icons.precision_manufacturing_outlined, color: a.disposed ? p.muted : p.primary),
                    title: Text(a.name, style: TextStyle(fontWeight: FontWeight.w700, color: a.disposed ? p.muted : null)),
                    subtitle: Text([
                      'asset_${a.category}'.tr,
                      '${'assetBought'.tr} ${a.purchaseDate}',
                      '${Fmt.tsh(a.cost)} / ${a.lifeMonths} ${'months'.tr}',
                      '${'assetMonthly'.tr} ${Fmt.money(a.monthly)}',
                      if (a.disposed) '${'assetDisposed'.tr} ${a.disposedOn}',
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Fmt.tsh(a.bookValue), style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (!a.disposed && (_can(AppAction.update) || _can(AppAction.delete)))
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _form(asset: a);
                              if (v == 'dispose') _dispose(a);
                              if (v == 'delete') _delete(a);
                            },
                            itemBuilder: (context) => [
                              if (_can(AppAction.update)) PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
                              if (_can(AppAction.update)) PopupMenuItem(value: 'dispose', child: Text('assetDispose'.tr)),
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
      ],
    );
  }
}

// ===================================================================== kufunga mwezi
Future<void> showMonthLocks() async {
  List<Map<String, dynamic>> locks;
  try {
    locks = await AccountingRepo.locks();
  } catch (e) {
    Toast.error(e);
    return;
  }
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return;
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1);
  String month = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  final months = [
    for (var i = 0; i < 18; i++)
      () {
        final d = DateTime(now.year, now.month - i);
        return '${d.year}-${d.month.toString().padLeft(2, '0')}';
      }(),
  ];
  await showDialog<void>(
    context: ctx,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) {
        final p = context.palette;
        Future<void> reload() async {
          try {
            final l = await AccountingRepo.locks();
            setDialog(() => locks = l);
          } catch (_) {}
        }

        return AlertDialog(
          title: Text('accMonthLocks'.tr),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('accLockHint'.tr, style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (_can(AppAction.update))
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: month,
                            isExpanded: true,
                            items: [
                              for (final m in months)
                                DropdownMenuItem(value: m, enabled: !locks.any((l) => l['month'] == m), child: Text(m)),
                            ],
                            onChanged: (v) => setDialog(() => month = v ?? month),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            if (await runGuarded(() => AccountingRepo.lockMonth(month), success: 'accLocked'.tr)) await reload();
                          },
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: Text('accLock'.tr),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (locks.isEmpty)
                    Text('accNoLocks'.tr, style: TextStyle(color: p.muted))
                  else
                    for (final l in locks)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_rounded, color: p.warning),
                        title: Text(J.str(l['month']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(J.str(l['lockedBy'])),
                        trailing: _can(AppAction.delete)
                            ? TextButton(
                                onPressed: () async {
                                  if (await runGuarded(() => AccountingRepo.unlockMonth(J.str(l['month'])),
                                      success: 'accUnlocked'.tr)) {
                                    await reload();
                                  }
                                },
                                child: Text('accUnlock'.tr),
                              )
                            : null,
                      ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr))],
        );
      },
    ),
  );
}
