import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/demand.dart';
import '../../data/models/role.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../boxes/box_costs.dart';
import '../boxes/box_costs_list.dart';
import '../boxes/cost_payment.dart';
import '../expenses/expenses_page.dart';

/// Jina la gharama zinazodaiwa (ANY = gharama yoyote).
String demandWhat(List<String> cats) =>
    cats.isEmpty ? 'cost_ANY'.tr : cats.map((c) => c == 'ANY' ? 'cost_ANY'.tr : costLabel(c)).join(', ');

String demandStatusLabel(String s) => 'demStatus_$s'.tr;

/// Inakagua madai ya gharama ya mtumiaji: kazi zikiwa zimezuiwa -> pop-up isiyofungika mpaka zijazwe;
/// muda wa kufunga kazi ukifika -> pop-up ya kukumbusha (mara moja kila saa).
class DemandGuardController extends GetxController {
  static DemandGuardController get to => Get.find<DemandGuardController>();

  static const _every = Duration(minutes: 3);
  static const _remindEvery = Duration(minutes: 60);

  final RxList<CostDemand> items = <CostDemand>[].obs;
  final RxBool blocked = false.obs;
  final RxBool remind = false.obs;

  Timer? _timer;
  Worker? _changes;
  bool _checking = false;
  bool _blockOpen = false;
  bool _remindOpen = false;
  DateTime? _remindShown;

  @override
  void onInit() {
    super.onInit();
    Api.onWorkBlocked = check;
    Future.delayed(const Duration(seconds: 6), check);
    _timer = Timer.periodic(_every, (_) => check());
    _changes = debounce<int>(AppController.to.changes, (_) => check(), time: const Duration(seconds: 2));
  }

  @override
  void onClose() {
    _timer?.cancel();
    _changes?.dispose();
    if (Api.onWorkBlocked == check) Api.onWorkBlocked = null;
    super.onClose();
  }

  Future<void> check() async {
    if (_checking || AppController.to.user.value == null) return;
    _checking = true;
    try {
      final r = await DemandRepo.mine();
      items.assignAll(r.items);
      blocked.value = r.blocked;
      remind.value = r.remind;
      if (r.blocked) {
        _showBlock();
      } else if (r.remind && !_remindOpen && !_blockOpen) {
        final last = _remindShown;
        if (last == null || DateTime.now().difference(last) >= _remindEvery) _showRemind();
      }
    } catch (_) {
      // kimya - tutajaribu tena
    } finally {
      _checking = false;
    }
  }

  Future<void> _showBlock() async {
    if (_blockOpen) return;
    _blockOpen = true;
    await Get.dialog<void>(const _BlockDialog(), barrierDismissible: false);
    _blockOpen = false;
  }

  Future<void> _showRemind() async {
    _remindOpen = true;
    _remindShown = DateTime.now();
    await Get.dialog<void>(const _RemindDialog());
    _remindOpen = false;
  }
}

/// Pop-up ya kuzuia kazi: haifungiki mpaka madai yajazwe (au mhasibu asamehe).
class _BlockDialog extends StatelessWidget {
  const _BlockDialog();

  @override
  Widget build(BuildContext context) {
    final c = DemandGuardController.to;
    final p = context.palette;
    return PopScope(
      canPop: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Obx(() {
            final open = c.blocked.value;
            final list = c.items.where((d) => d.blocking).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  color: (open ? p.danger : p.success).withValues(alpha: .1),
                  child: Row(
                    children: [
                      Icon(open ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
                          color: open ? p.danger : p.success, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(open ? 'demBlockedTitle'.tr : 'demUnblockedTitle'.tr,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(open ? 'demBlockedMsg'.tr : 'demUnblockedMsg'.tr,
                                style: TextStyle(color: p.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (open)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      children: [for (final d in list) DemandTile(demand: d)],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: open
                        ? [
                            if (list.where((d) => d.canFill).length > 1)
                              FilledButton.icon(
                                onPressed: () async {
                                  if (await showDemandFillMany(list)) await c.check();
                                },
                                icon: const Icon(Icons.library_add_check_outlined),
                                label: Text('demFillAllN'.trParams({'n': '${list.where((d) => d.canFill).length}'})),
                              ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                AppController.to.logout();
                              },
                              icon: const Icon(Icons.logout_rounded),
                              label: Text('logout'.tr),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: c.check,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text('demCheckAgain'.tr),
                            ),
                          ]
                        : [
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_rounded),
                              label: Text('demContinue'.tr),
                            ),
                          ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Pop-up ya kukumbusha (saa ya kufunga kazi).
class _RemindDialog extends StatelessWidget {
  const _RemindDialog();

  @override
  Widget build(BuildContext context) {
    final c = DemandGuardController.to;
    final p = context.palette;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Obx(() {
          final list = c.items.where((d) => d.remind && (d.canFill || d.isResponsible)).toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(Icons.alarm_rounded, color: p.warning, size: 30),
                title: Text('demRemindTitle'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('demRemindMsg'.tr),
              ),
              Flexible(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('demAllDone'.tr, textAlign: TextAlign.center),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [for (final d in list) DemandTile(demand: d)],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (list.where((d) => d.canFill).length > 1)
                      FilledButton.icon(
                        onPressed: () async {
                          if (await showDemandFillMany(list)) await c.check();
                        },
                        icon: const Icon(Icons.library_add_check_outlined),
                        label: Text('demFillAllN'.trParams({'n': '${list.where((d) => d.canFill).length}'})),
                      ),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('demLater'.tr)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Dai moja: nini kinadaiwa, box lipi, nani ajaze, na vitufe vya kujaza / hakuna gharama / kusamehe.
class DemandTile extends StatelessWidget {
  final CostDemand demand;
  final VoidCallback? onChanged;

  const DemandTile({super.key, required this.demand, this.onChanged});

  Future<void> _after() async {
    AppController.to.notifyChanged();
    onChanged?.call();
    if (Get.isRegistered<DemandGuardController>()) await DemandGuardController.to.check();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = demand;
    final color = !d.isOpen
        ? p.success
        : d.blocking
            ? p.danger
            : d.remind
                ? p.warning
                : p.info;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Box ${d.boxId ?? '-'}${(d.trackNumber ?? '').isEmpty ? '' : ' · ${d.trackNumber}'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Pill(d.isOpen ? d.triggerLabel : demandStatusLabel(d.status), color: color, dense: true),
              ],
            ),
            const SizedBox(height: 8),
            if (d.isOpen)
              Text.rich(TextSpan(children: [
                TextSpan(text: '${'demWhat'.tr}: ', style: TextStyle(color: p.muted)),
                TextSpan(text: demandWhat(d.missing), style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${'demWho'.tr}: ', style: TextStyle(color: p.muted)),
              TextSpan(
                text: d.isResponsible ? '${d.responsible} (${'demYou'.tr})' : d.responsible,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ])),
            if (d.isOpen && d.blockLocal != null)
              Text('${'demBlockFrom'.tr}: ${d.blockLocal}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            if (!d.isOpen)
              Text(
                [if (d.closedBy != null) d.closedBy!, if (d.closedAt != null) Fmt.dateTime(d.closedAt), if (d.note != null) d.note!]
                    .join(' · '),
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            if (d.isOpen && (d.canFill || d.canWaive)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (d.canFill)
                    FilledButton.icon(
                      onPressed: () async {
                        if (await showDemandFill(d)) await _after();
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text('demFill'.tr),
                    ),
                  if (d.canFill)
                    OutlinedButton(
                      onPressed: () async {
                        if (await _reasonSheet(d, waive: false)) await _after();
                      },
                      child: Text('demNoCost'.tr),
                    ),
                  if (d.canWaive)
                    TextButton(
                      onPressed: () async {
                        if (await _reasonSheet(d, waive: true)) await _after();
                      },
                      child: Text('demWaive'.tr, style: TextStyle(color: p.warning)),
                    ),
                ],
              ),
            ] else if (d.isOpen) ...[
              const SizedBox(height: 6),
              Text('demWaitFor'.trParams({'name': d.responsible}), style: TextStyle(color: p.muted, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _reasonSheet(CostDemand d, {required bool waive}) {
  final reason = TextEditingController();
  return showFormSheet(
    title: waive ? 'demWaive'.tr : 'demNoCost'.tr,
    subtitle: 'Box ${d.boxId ?? '-'} · ${demandWhat(d.missing)}',
    icon: waive ? Icons.verified_user_outlined : Icons.money_off_rounded,
    submitLabel: waive ? 'demWaive'.tr : 'save'.tr,
    builder: (context, setState) => AppField(
      controller: reason,
      label: 'demReason'.tr,
      hint: waive ? 'demWaiveHint'.tr : 'demNoCostHint'.tr,
      icon: Icons.notes_rounded,
      required: true,
      capitalization: TextCapitalization.sentences,
    ),
    onSubmit: () => waive ? DemandRepo.waive(d.id, reason.text) : DemandRepo.noCost(d.id, reason.text),
  );
}

/// Fomu ya kujaza gharama zinazodaiwa (moja kwa kila aina inayokosekana).
Future<bool> showDemandFill(CostDemand d) async {
  final currencies = await loadCurrencyCodes();
  final any = d.missing.contains('ANY') || d.missing.isEmpty;
  final cats = any ? <String>['FREIGHT'] : [...d.missing];
  final amounts = {for (final c in costCategories) c: TextEditingController()};
  final note = TextEditingController();
  String currency = 'TZS';
  final pay = CostPayment();
  await pay.loadAccounts();

  final ok = await showFormSheet(
    title: 'demFill'.tr,
    subtitle: 'Box ${d.boxId ?? '-'} · ${d.triggerLabel}',
    icon: Icons.edit_note_rounded,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currencies.length > 1) ...[
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
          const SizedBox(height: 16),
        ],
        if (any) ...[
          FieldLabel('demPickCosts'.tr),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in costCategories)
                FilterChip(
                  label: Text(costLabel(c)),
                  selected: cats.contains(c),
                  onSelected: (v) => setState(() {
                    if (v) {
                      cats.add(c);
                    } else if (cats.length > 1) {
                      cats.remove(c);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (final c in costCategories)
          if (cats.contains(c)) ...[
            AppField.money(controller: amounts[c]!, label: '${costLabel(c)} ($currency)'),
            const SizedBox(height: 12),
          ],
        AppField(controller: note, label: 'noteOptional'.tr, icon: Icons.notes_rounded, required: false),
        const SizedBox(height: 16),
        pay.fields(context, setState, currency: currency),
      ],
    ),
    onSubmit: () async {
      final entered = {
        for (final c in costCategories)
          if (cats.contains(c) && (Fmt.parse(amounts[c]!.text) ?? 0) > 0) c: Fmt.parse(amounts[c]!.text)!,
      };
      if (entered.isEmpty) throw ApiException(null, 'demEnterAmount'.tr);
      final total = entered.values.fold<double>(0, (a, b) => a + b);
      final paidTotal = pay.paidAmount ?? 0;
      if (pay.status == 'PARTIAL' && (paidTotal <= 0 || paidTotal >= total)) {
        throw ApiException(null, 'payPartialInvalid'.tr);
      }
      final costs = [
        for (final e in entered.entries)
          {
            'category': e.key,
            'amount': e.value,
            'currency': currency,
            'note': note.text.trim(),
            'payStatus': pay.status,
            // nusu: kilicholipwa kinagawanywa kwa uwiano wa kila gharama
            if (pay.status == 'PARTIAL') 'paidAmount': double.parse((paidTotal * e.value / total).toStringAsFixed(2)),
            'supplier': pay.supplierName,
            'institute_id': pay.account,
          },
      ];
      final r = await DemandRepo.fill(d.id, costs);
      if (r.isOpen) {
        Toast.warning('${'demStillMissing'.tr}: ${demandWhat(r.missing)}');
      } else {
        Toast.success('Box ${d.boxId ?? ''}', title: 'demFilled'.tr);
      }
    },
  );
  return ok;
}

/// Gharama moja kwa mabox mengi kwa mara moja: kila box kiasi chake, au jumla ikigawanywa (sawa / uzito / kwa mkono).
Future<bool> showDemandFillMany(List<CostDemand> demands) async {
  final open = demands.where((d) => d.isOpen && d.canFill).toList();
  if (open.isEmpty) {
    Toast.warning('demNothingToFill'.tr);
    return false;
  }
  final currencies = await loadCurrencyCodes();
  final pay = CostPayment();
  await pay.loadAccounts();
  final selected = {for (final d in open) d.id};
  String category = 'FREIGHT';
  for (final d in open) {
    if (d.missing.isNotEmpty && d.missing.first != 'ANY') {
      category = d.missing.first;
      break;
    }
  }
  String currency = 'TZS';
  String mode = 'EACH';
  final amount = TextEditingController();
  final note = TextEditingController();
  final manual = {for (final d in open) d.id: TextEditingController()};
  List<Map<String, dynamic>> preview = const [];

  Map<String, double> manualAmounts() => {
        for (final id in selected)
          if ((Fmt.parse(manual[id]!.text) ?? 0) > 0) id: Fmt.parse(manual[id]!.text)!,
      };

  Future<Map<String, dynamic>> send({required bool dry}) => DemandRepo.fillMany(
        demandIds: [for (final d in open) if (selected.contains(d.id)) d.id],
        category: category,
        mode: mode,
        currency: currency,
        amount: mode == 'MANUAL' ? null : Fmt.parse(amount.text),
        amounts: mode == 'MANUAL' ? manualAmounts() : const {},
        payStatus: pay.status,
        paidAmount: pay.paidAmount,
        supplier: pay.supplierName,
        accountId: pay.account,
        note: note.text,
        preview: dry,
      );

  final ok = await showFormSheet(
    title: 'demFillMany'.tr,
    subtitle: 'demFillManySub'.trParams({'n': '${open.length}'}),
    icon: Icons.library_add_check_outlined,
    builder: (context, setState) {
      final p = context.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('costType'.tr, required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in costCategories)
                ChoiceChip(label: Text(costLabel(c)), selected: category == c, onSelected: (_) => setState(() => category = c)),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel('demBoxes'.tr),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => selected
                  ..clear()
                  ..addAll(open.map((d) => d.id))),
                child: Text('selectAll'.tr),
              ),
              TextButton(onPressed: () => setState(selected.clear), child: Text('clearSelection'.tr)),
              const Spacer(),
              Text('${selected.length}/${open.length}', style: TextStyle(color: p.muted)),
            ],
          ),
          for (final d in open)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(d.id),
              onChanged: (v) => setState(() => v == true ? selected.add(d.id) : selected.remove(d.id)),
              title: Text('Box ${d.boxId ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${d.triggerLabel} · ${demandWhat(d.missing)}'),
              secondary: mode == 'MANUAL' && selected.contains(d.id)
                  ? SizedBox(width: 130, child: AppField.money(controller: manual[d.id]!, label: currency, required: false))
                  : null,
            ),
          const SizedBox(height: 16),
          FieldLabel('demSplitMode'.tr),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final m in const ['EACH', 'EQUAL', 'WEIGHT', 'MANUAL']) ButtonSegment(value: m, label: Text('split_$m'.tr)),
              ],
              selected: {mode},
              onSelectionChanged: (v) => setState(() {
                mode = v.first;
                preview = const [];
              }),
            ),
          ),
          const SizedBox(height: 4),
          Text('split_${mode}_hint'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
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
          if (mode != 'MANUAL') ...[
            const SizedBox(height: 16),
            AppField.money(
              controller: amount,
              label: '${mode == 'EACH' ? 'demAmountEach'.tr : 'demAmountTotal'.tr} ($currency)',
            ),
          ],
          if (mode == 'EQUAL' || mode == 'WEIGHT') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final r = await send(dry: true);
                    final items = r['items'];
                    setState(() => preview = items is List
                        ? [for (final x in items.whereType<Map>()) Map<String, dynamic>.from(x)]
                        : const []);
                  } catch (e) {
                    Toast.error(e);
                  }
                },
                icon: const Icon(Icons.calculate_outlined),
                label: Text('demPreview'.tr),
              ),
            ),
            for (final x in preview)
              InfoRow(label: 'Box ${x['boxId'] ?? '-'}', value: '$currency ${Fmt.money2(Fmt.parse('${x['amount']}') ?? 0)}'),
          ],
          const SizedBox(height: 16),
          pay.fields(context, setState, currency: currency, totalHint: 'payPaidTotalHint'.tr),
          const SizedBox(height: 12),
          AppField(controller: note, label: 'noteOptional'.tr, hint: 'AWB / B/L, risiti...', icon: Icons.notes_rounded, required: false),
        ],
      );
    },
    onSubmit: () async {
      if (selected.isEmpty) throw ApiException(null, 'demPickBoxes'.tr);
      final r = await send(dry: false);
      Toast.success('${'demFillManyDone'.trParams({'n': '${selected.length}'})} · $currency ${Fmt.money2(Fmt.parse('${r['total']}') ?? 0)}',
          title: 'demFilled'.tr);
    },
  );
  return ok;
}

/// Orodha ya madai yote (mhasibu / msimamizi) + sheria.
class DemandsPage extends StatefulWidget {
  const DemandsPage({super.key});

  static Future<void> open() async => Get.to(() => const DemandsPage());

  @override
  State<DemandsPage> createState() => _DemandsPageState();
}

class _DemandsPageState extends State<DemandsPage> {
  String? _status = 'OPEN';
  List<CostDemand> _items = const [];
  LoadStatus _load = LoadStatus.loading;
  String? _error;
  Worker? _changes;

  bool get _canAll =>
      AppController.to.can(AppModule.accounting) || AppController.to.can(AppModule.profit);

  bool get _canRules =>
      AppController.to.can(AppModule.accounting, AppAction.update) ||
      AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    _changes = ever<int>(AppController.to.changes, (_) => _fetch());
    _fetch();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() => _load = LoadStatus.loading);
    try {
      final list = _canAll
          ? await DemandRepo.all(status: _status)
          : (await DemandRepo.mine()).items.where((d) => _status == null || d.status == _status).toList();
      if (mounted) {
        setState(() {
          _items = list;
          _load = LoadStatus.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _load = LoadStatus.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      showBack: true,
      title: 'navDemands'.tr,
      subtitle: 'hintDemands'.tr,
      actions: [
        if (_items.where((d) => d.isOpen && d.canFill).length > 1)
          IconButton(
            tooltip: 'demFillMany'.tr,
            onPressed: () async {
              if (await showDemandFillMany(_items)) {
                AppController.to.notifyChanged();
                _fetch();
              }
            },
            icon: const Icon(Icons.library_add_check_outlined),
          ),
        IconButton(
          tooltip: 'myBoxCosts'.tr,
          onPressed: () => BoxCostsPage.open(mine: true),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        if (_canRules)
          IconButton(tooltip: 'demRules'.tr, onPressed: showDemandRules, icon: const Icon(Icons.rule_rounded)),
        IconButton(tooltip: 'refresh'.tr, onPressed: _fetch, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in const ['OPEN', 'DONE', 'NONE', 'WAIVED', null]) ...[
                    ChoiceChip(
                      label: Text(s == null ? 'all'.tr : demandStatusLabel(s)),
                      selected: _status == s,
                      onSelected: (_) {
                        _status = s;
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncBody(
              status: _load,
              error: _error,
              isEmpty: _items.isEmpty,
              onRetry: _fetch,
              empty: EmptyState(icon: Icons.task_alt_rounded, title: 'demNone'.tr, message: 'demNoneMsg'.tr),
              builder: () => RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [for (final d in _items) DemandTile(demand: d, onChanged: _fetch)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheria: kazi ipi inadai gharama zipi, nani ajaze, saa ya kukumbusha na nani anazuiwa.
Future<void> showDemandRules() async {
  List<DemandRule> rules;
  List<Role> roles = const [];
  try {
    rules = await DemandRepo.rules();
    roles = await RoleRepo.all().catchError((_) => <Role>[]);
  } catch (e) {
    Toast.error(e);
    return;
  }
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return;
  await showDialog<void>(
    context: ctx,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text('demRules'.tr),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('demRulesHint'.tr, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                const SizedBox(height: 8),
                for (final r in rules)
                  Card(
                    child: ListTile(
                      leading: Icon(r.enabled ? Icons.rule_rounded : Icons.block_rounded,
                          color: r.enabled ? context.palette.primary : context.palette.muted),
                      title: Text('demTrigger_${r.trigger}'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(r.enabled
                          ? '${demandWhat(r.categories)} · ${'demWho'.tr}: '
                              '${r.responsible == 'ROLE' ? (r.role ?? '-') : 'demDoer'.tr} · '
                              '${r.remindHour.toString().padLeft(2, '0')}:00 · ${'demScope_${r.blockScope}'.tr}'
                          : 'demDisabled'.tr),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () async {
                        final saved = await _editRule(r, roles);
                        if (saved != null) setDialog(() => rules = [for (final x in rules) x.trigger == saved.trigger ? saved : x]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr))],
      ),
    ),
  );
}

Future<DemandRule?> _editRule(DemandRule r, List<Role> roles) async {
  bool enabled = r.enabled;
  final cats = [...r.categories];
  String responsible = r.responsible;
  String? roleId = r.roleId ?? (roles.isNotEmpty ? roles.first.id : null);
  int hour = r.remindHour;
  int grace = r.graceDays;
  String scope = r.blockScope;
  DemandRule? result;
  final ok = await showFormSheet(
    title: 'demTrigger_${r.trigger}'.tr,
    icon: Icons.rule_rounded,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          title: Text('demEnabled'.tr),
          onChanged: (v) => setState(() => enabled = v),
        ),
        FieldLabel('demWhatCosts'.tr),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in costCategories)
              FilterChip(
                label: Text(costLabel(c)),
                selected: cats.contains(c),
                onSelected: (v) => setState(() {
                  if (v) {
                    cats.add(c);
                  } else {
                    cats.remove(c);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(cats.isEmpty ? 'demAnyCostHint'.tr : 'demAllCostsHint'.tr,
            style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        const SizedBox(height: 16),
        FieldLabel('demWho'.tr),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'DOER', label: Text('demDoer'.tr)),
            ButtonSegment(value: 'ROLE', label: Text('role'.tr)),
          ],
          selected: {responsible},
          onSelectionChanged: (v) => setState(() => responsible = v.first),
        ),
        if (responsible == 'ROLE' && roles.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'role'.tr,
            value: roleId,
            items: [for (final x in roles) x.id],
            icon: Icons.badge_outlined,
            itemLabel: (id) => roles.firstWhere((x) => x.id == id).name,
            onChanged: (v) => setState(() => roleId = v),
          ),
        ],
        const SizedBox(height: 16),
        AppDropdown<int>(
          label: 'demRemindHour'.tr,
          value: hour,
          items: [for (var h = 6; h <= 23; h++) h],
          icon: Icons.alarm_rounded,
          itemLabel: (h) => '${h.toString().padLeft(2, '0')}:00',
          onChanged: (v) => setState(() => hour = v ?? hour),
        ),
        const SizedBox(height: 16),
        AppDropdown<int>(
          label: 'demGrace'.tr,
          value: grace,
          items: const [0, 1, 2, 3, 5, 7],
          icon: Icons.event_busy_rounded,
          itemLabel: (g) => g == 0 ? 'demGrace0'.tr : 'demGraceN'.trParams({'n': '$g'}),
          onChanged: (v) => setState(() => grace = v ?? grace),
        ),
        const SizedBox(height: 16),
        FieldLabel('demScope'.tr),
        for (final s in const ['EVERYONE', 'RESPONSIBLE', 'NONE'])
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: s,
            groupValue: scope,
            title: Text('demScope_$s'.tr),
            onChanged: (v) => setState(() => scope = v ?? scope),
          ),
      ],
    ),
    onSubmit: () async {
      final rule = DemandRule(
        trigger: r.trigger,
        label: r.label,
        enabled: enabled,
        categories: cats,
        responsible: responsible,
        roleId: responsible == 'ROLE' ? roleId : null,
        role: responsible == 'ROLE' ? _roleName(roles, roleId) : null,
        remindHour: hour,
        graceDays: grace,
        blockScope: scope,
      );
      await DemandRepo.saveRule(rule);
      result = rule;
    },
  );
  if (ok) Toast.success('demTrigger_${r.trigger}'.tr, title: 'saved'.tr);
  return result;
}

String? _roleName(List<Role> roles, String? id) {
  for (final r in roles) {
    if (r.id == id) return r.name;
  }
  return null;
}
