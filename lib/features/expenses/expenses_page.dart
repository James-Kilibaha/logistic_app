import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/lookups.dart';
import '../../data/models/accounting.dart';
import '../../data/models/box.dart';
import '../../data/models/misc.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../boxes/cost_payment.dart';
import 'expenses_controller.dart';

const String _none = '';

Color expenseStatusColor(BuildContext context, Expense e) {
  final p = context.palette;
  if (e.isPending) return p.warning;
  if (e.isRejected) return p.danger;
  return p.success;
}

String expenseStatusLabel(Expense e) => 'expStatus_${e.status}'.tr;

class ExpensesPage extends GetView<ExpensesController> {
  const ExpensesPage({super.key});

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: controller.range.value,
    );
    if (picked != null) controller.setRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    return AppPage(
      help: 'expenses',
      title: 'navExpenses'.tr,
      subtitle: 'hintExpenses'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: can(AppModule.expenses, AppAction.insert)
          ? PageAction(icon: Icons.add_rounded, label: 'newExpense'.tr, onPressed: () => showExpenseForm())
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchExpenseHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() {
              final r = controller.range.value;
              final offices = controller.offices.toList();
              final status = controller.statusFilter.value;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text('${Fmt.date(r.start)} – ${Fmt.date(r.end)}'),
                      onPressed: () => _pickRange(context),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'office'.tr,
                      onSelected: (id) {
                        Office? selected;
                        for (final o in offices) {
                          if (o.id == id) selected = o;
                        }
                        controller.setOffice(selected);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: '', child: Text('allOffices'.tr)),
                        for (final o in offices) PopupMenuItem(value: o.id, child: Text(o.label)),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
                        label: Text(controller.office.value?.name ?? 'allOffices'.tr),
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (final s in const [null, 'PENDING', 'APPROVED', 'REJECTED']) ...[
                      ChoiceChip(
                        label: Text(s == null ? 'all'.tr : 'expStatus_$s'.tr),
                        selected: status == s,
                        onSelected: (_) => controller.setStatus(s),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              );
            }),
            trailing: [
              Obx(() => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Pill('${'total'.tr}: ${Fmt.tsh(controller.total)}', color: context.palette.success),
                        if (controller.pendingCount > 0)
                          Pill('${'expStatus_PENDING'.tr} (${controller.pendingCount}): ${Fmt.tsh(controller.pendingTotal)}',
                              color: context.palette.warning),
                      ],
                    ),
                  )),
            ],
          ),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'noExpenses'.tr,
                  message: 'noExpensesMsg'.tr,
                ),
                builder: () => DataList<Expense>(
                  items: list,
                  onRefresh: controller.refreshList,
                  onTap: (e) => showExpenseDetail(e),
                  columns: [
                    ColumnSpec('details'.tr, flex: 4),
                    ColumnSpec('accCategory'.tr, flex: 2),
                    ColumnSpec('office'.tr, flex: 2),
                    ColumnSpec('date'.tr, flex: 2),
                    ColumnSpec('expStatus'.tr, flex: 2),
                    ColumnSpec('amount'.tr, flex: 2, align: TextAlign.end),
                  ],
                  cells: (context, e) => [
                    CellText(e.details, bold: true, sub: [
                      if (e.account != null) e.account!,
                      if (e.boxLabel != null) 'Box ${e.boxLabel}',
                      if (e.hasDebt) '${'payOwed'.tr} ${Fmt.money(e.owedTzs)} · ${e.supplier ?? ''}',
                    ].join(' · ')),
                    CellText(e.category ?? '—'),
                    CellText(e.office?.name ?? '—', sub: e.createdBy),
                    CellText(Fmt.dateTime(e.createdAt)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pill(expenseStatusLabel(e), color: expenseStatusColor(context, e), dense: true),
                    ),
                    CellText(Fmt.money(e.amount), bold: true, align: TextAlign.end,
                        sub: e.amountOriginal != null ? '${e.currency} ${Fmt.money2(e.amountOriginal)}' : null),
                  ],
                  actions: (context, e) => _ExpenseMenu(expense: e),
                  card: (context, e) => Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: expenseStatusColor(context, e).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(e.hasReceipt ? Icons.receipt_long_rounded : Icons.receipt_outlined,
                              color: expenseStatusColor(context, e)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.details, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                [
                                  if (e.category != null) e.category!,
                                  e.office?.name ?? '—',
                                  Fmt.relative(e.createdAt),
                                ].join(' · '),
                                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                              ),
                              const SizedBox(height: 4),
                              Pill(expenseStatusLabel(e), color: expenseStatusColor(context, e), dense: true),
                            ],
                          ),
                        ),
                        Text(Fmt.money(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        _ExpenseMenu(expense: e),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

bool _canEdit(Expense e) {
  final can = AppController.to.can;
  if (can(AppModule.accounting, AppAction.update)) return true;
  return can(AppModule.expenses, AppAction.update) && !e.isApproved;
}

bool _canDelete(Expense e) {
  final can = AppController.to.can;
  if (can(AppModule.accounting, AppAction.delete)) return true;
  return can(AppModule.expenses, AppAction.delete) && !e.isApproved;
}

bool get _canApprove => AppController.to.can(AppModule.accounting, AppAction.update);

Future<void> approveExpense(Expense e) async {
  if (await runGuarded(() => ExpenseRepo.approve(e.id), success: 'expenseApproved'.tr)) {
    AppController.to.notifyChanged();
  }
}

Future<void> rejectExpense(Expense e) async {
  final reason = TextEditingController();
  final ok = await showFormSheet(
    title: 'rejectExpense'.tr,
    subtitle: '${e.details} · ${Fmt.tsh(e.amount)}',
    icon: Icons.block_rounded,
    danger: true,
    submitLabel: 'reject'.tr,
    builder: (context, setState) => AppField(
      controller: reason,
      label: 'rejectReason'.tr,
      hint: 'rejectReasonHint'.tr,
      icon: Icons.notes_rounded,
      required: true,
      capitalization: TextCapitalization.sentences,
    ),
    onSubmit: () => ExpenseRepo.reject(e.id, reason.text),
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(e.details, title: 'expenseRejected'.tr);
  }
}

Future<void> deleteExpense(Expense e) async {
  final ok = await confirmAction(
    title: 'deleteExpense'.tr,
    message: 'deleteExpenseMsg'.trParams({'name': e.details}),
    confirmText: 'delete'.tr,
    icon: Icons.delete_outline_rounded,
    danger: true,
  );
  if (ok && await runGuarded(() => ExpenseRepo.delete(e.id), success: 'deleted'.tr)) {
    AppController.to.notifyChanged();
  }
}

Future<void> showReceipt(Expense e) async {
  try {
    final bytes = await ExpenseRepo.receipt(e.id);
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('receipt'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(e.details),
              trailing: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  } catch (err) {
    Toast.error(err);
  }
}

Future<void> attachReceipt(Expense e) async {
  final img = await pickImage();
  if (img == null) return;
  if (await runGuarded(() => ExpenseRepo.uploadReceipt(e.id, img.bytes, img.name), success: 'receiptSaved'.tr)) {
    AppController.to.notifyChanged();
  }
}

class _ExpenseMenu extends StatelessWidget {
  final Expense expense;

  const _ExpenseMenu({required this.expense});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = expense;
    final canEdit = _canEdit(e);
    final canDelete = _canDelete(e);
    final canApprove = _canApprove && !e.isApproved;
    final canReject = _canApprove && e.isPending;
    final canAttach = AppController.to.can(AppModule.expenses, AppAction.insert) || _canApprove;
    return PopupMenuButton<String>(
      tooltip: 'actions'.tr,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) async {
        switch (v) {
          case 'approve':
            await approveExpense(e);
          case 'reject':
            await rejectExpense(e);
          case 'receipt':
            await showReceipt(e);
          case 'attach':
            await attachReceipt(e);
          case 'edit':
            await showExpenseForm(expense: e);
          case 'delete':
            await deleteExpense(e);
          case 'pay':
            await showPayDebt(Payable(
              id: e.id,
              source: 'EXPENSE',
              title: e.details,
              amountTzs: e.amount,
              owedTzs: e.owedTzs,
              payStatus: e.payStatus,
              supplier: e.supplier,
              createdAt: e.createdAt,
            ));
        }
      },
      itemBuilder: (context) => [
        if (canApprove)
          PopupMenuItem(value: 'approve', child: Text('approve'.tr, style: TextStyle(color: p.success))),
        if (e.hasDebt && e.isApproved && AppController.to.can(AppModule.accounting, AppAction.insert))
          PopupMenuItem(value: 'pay', child: Text('payDebt'.tr, style: TextStyle(color: p.success))),
        if (canReject) PopupMenuItem(value: 'reject', child: Text('reject'.tr, style: TextStyle(color: p.warning))),
        if (e.hasReceipt) PopupMenuItem(value: 'receipt', child: Text('viewReceipt'.tr)),
        if (canAttach) PopupMenuItem(value: 'attach', child: Text(e.hasReceipt ? 'replaceReceipt'.tr : 'attachReceipt'.tr)),
        if (canEdit) PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
        if (canDelete) PopupMenuItem(value: 'delete', child: Text('delete'.tr, style: TextStyle(color: p.danger))),
      ],
    );
  }
}

/// Maelezo kamili ya matumizi (kwa kubonyeza mstari).
Future<void> showExpenseDetail(Expense e) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return;
  await showDialog<void>(
    context: ctx,
    builder: (context) {
      final p = context.palette;
      return AlertDialog(
        title: Text(e.details),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(expenseStatusLabel(e), color: expenseStatusColor(context, e)),
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'amount'.tr, value: Fmt.tsh(e.amount), emphasize: true),
                if (e.amountOriginal != null)
                  InfoRow(label: 'currency'.tr, value: '${e.currency} ${Fmt.money2(e.amountOriginal)}'),
                InfoRow(label: 'accCategory'.tr, value: e.category ?? '—'),
                InfoRow(label: 'accAccount'.tr, value: e.account ?? '—'),
                InfoRow(label: 'office'.tr, value: e.office?.name ?? '—'),
                if (e.boxLabel != null) InfoRow(label: 'box'.tr, value: e.boxLabel!),
                InfoRow(label: 'date'.tr, value: Fmt.dateTime(e.createdAt)),
                InfoRow(label: 'createdBy'.tr, value: e.createdBy ?? '—'),
                if (e.approvedBy != null)
                  InfoRow(label: e.isRejected ? 'rejectedBy'.tr : 'approvedBy'.tr, value: e.approvedBy!),
                if (e.rejectReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${'rejectReason'.tr}: ${e.rejectReason}', style: TextStyle(color: p.danger)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (e.hasReceipt)
            TextButton.icon(
              onPressed: () => showReceipt(e),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text('viewReceipt'.tr),
            ),
          if (_canApprove && e.isPending)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                rejectExpense(e);
              },
              child: Text('reject'.tr, style: TextStyle(color: p.warning)),
            ),
          if (_canApprove && !e.isApproved)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                approveExpense(e);
              },
              child: Text('approve'.tr),
            ),
          if (_canEdit(e))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showExpenseForm(expense: e);
              },
              child: Text('edit'.tr),
            ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr)),
        ],
      );
    },
  );
}

Future<List<String>> loadCurrencyCodes() async {
  try {
    final list = await Lookups.to.loadCurrencies();
    return ['TZS', ...list.map((c) => c.name.toUpperCase()).where((c) => c != 'TZS').toSet()];
  } catch (_) {
    return ['TZS'];
  }
}

Future<void> showExpenseForm({Expense? expense, String? boxId}) async {
  List<Office> offices;
  List<AccCategory> categories = const [];
  List<FinAccount> accounts = const [];
  List<Box> boxes = const [];
  try {
    offices = await Lookups.to.loadOffices();
    final results = await Future.wait([
      AccountingRepo.categories(kind: 'EXPENSE').catchError((_) => <AccCategory>[]),
      AccountingRepo.options().catchError((_) => <FinAccount>[]),
    ]);
    categories = results[0] as List<AccCategory>;
    accounts = results[1] as List<FinAccount>;
    if (AppController.to.can(AppModule.package)) {
      final all = await BoxRepo.all().catchError((_) => <Box>[]);
      all.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      boxes = all.take(60).toList();
    }
  } catch (e) {
    Toast.error(e);
    return;
  }
  if (offices.isEmpty) {
    Toast.warning('noOfficesMsg'.tr, title: 'noOffices'.tr);
    return;
  }
  final currencies = await loadCurrencyCodes();
  final details = TextEditingController(text: expense?.details ?? '');
  final amount = TextEditingController(text: expense == null ? '' : Fmt.money2(expense.entered));
  String currency = expense?.currency ?? 'TZS';
  if (!currencies.contains(currency)) currencies.add(currency);
  Office? office = offices.first;
  for (final o in offices) {
    if (o.id == (expense?.officeId ?? AppController.to.user.value?.officeId)) office = o;
  }
  String categoryId = expense?.categoryId ?? _none;
  if (categoryId != _none && !categories.any((c) => c.id == categoryId)) categoryId = _none;
  String accountId = expense?.accountId ?? _none;
  if (accountId != _none && !accounts.any((a) => a.id == accountId)) accountId = _none;
  String box = expense?.boxId ?? boxId ?? _none;
  if (box != _none && !boxes.any((b) => b.id == box)) {
    if (expense?.boxLabel != null || boxId != null) {
      boxes = [Box.fromJson({'id': box, 'boxId': expense?.boxLabel ?? boxId}), ...boxes];
    } else {
      box = _none;
    }
  }
  PickedImage? receipt;
  final willApprove = _canApprove;
  final pay = CostPayment();
  if (expense != null) {
    pay.status = expense.payStatus;
    pay.supplier.text = expense.supplier ?? '';
  }

  final ok = await showFormSheet(
    help: 'formExpense',
    title: expense == null ? 'newExpense'.tr : 'editExpense'.tr,
    subtitle: willApprove ? null : 'expenseNeedsApproval'.tr,
    icon: Icons.account_balance_wallet_outlined,
    builder: (context, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          controller: details,
          label: 'details'.tr,
          hint: 'expenseDetailsHint'.tr,
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
        AppDropdown<Office>(
          label: 'office'.tr,
          value: office,
          items: offices,
          icon: Icons.store_mall_directory_outlined,
          itemLabel: (o) => o.label,
          onChanged: (v) => setState(() => office = v),
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'paidFromAccount'.tr,
          value: accountId,
          required: false,
          items: [_none, ...accounts.map((a) => a.id)],
          icon: Icons.account_balance_outlined,
          itemLabel: (id) => id == _none ? 'noneOption'.tr : accounts.firstWhere((a) => a.id == id).label,
          onChanged: (v) => setState(() => accountId = v ?? _none),
        ),
        const SizedBox(height: 16),
        pay.fields(context, setState, currency: currency),
        if (boxes.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'expenseForBox'.tr,
            value: box,
            required: false,
            items: [_none, ...boxes.map((b) => b.id)],
            icon: Icons.inventory_2_outlined,
            itemLabel: (id) {
              if (id == _none) return 'noneOption'.tr;
              final b = boxes.firstWhere((x) => x.id == id);
              return b.trackNumber.isEmpty ? 'Box ${b.boxId}' : 'Box ${b.boxId} · ${b.trackNumber}';
            },
            onChanged: (v) => setState(() => box = v ?? _none),
          ),
        ],
        if (expense == null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final img = await pickImage();
              if (img != null) setState(() => receipt = img);
            },
            icon: Icon(receipt == null ? Icons.add_a_photo_outlined : Icons.check_circle_rounded),
            label: Text(receipt == null ? 'attachReceipt'.tr : '${'receipt'.tr}: ${receipt!.name}'),
          ),
        ],
      ],
    ),
    onSubmit: () async {
      final saved = await ExpenseRepo.save(
        id: expense?.id,
        details: details.text,
        amount: Fmt.parse(amount.text) ?? 0,
        officeId: office!.id,
        currency: currency,
        categoryId: categoryId == _none ? null : categoryId,
        accountId: accountId == _none ? null : accountId,
        boxId: box == _none ? null : box,
        payStatus: pay.status,
        paidAmount: pay.paidAmount,
        supplier: pay.supplierName,
      );
      final img = receipt;
      if (img != null) await ExpenseRepo.uploadReceipt(saved.id, img.bytes, img.name);
    },
  );
  if (ok) {
    AppController.to.notifyChanged();
    Toast.success(details.text,
        title: expense != null
            ? 'changesSaved'.tr
            : willApprove
                ? 'expenseSaved'.tr
                : 'expenseSentForApproval'.tr);
  }
}
