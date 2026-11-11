import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/list_controller.dart';
import '../../data/lookups.dart';
import '../../data/models/misc.dart';
import '../../data/models/settings.dart';
import '../../data/repositories.dart';

class ExpensesController extends ListController<Expense> {
  final Rx<DateTimeRange> range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  ).obs;
  final Rxn<Office> office = Rxn<Office>();

  /// null = zote; PENDING | APPROVED | REJECTED
  final RxnString statusFilter = RxnString();

  RxList<Office> get offices => Lookups.to.offices;

  @override
  void onInit() {
    super.onInit();
    Lookups.to.loadOffices().catchError((_) => <Office>[]);
  }

  @override
  Future<List<Expense>> fetch() => ExpenseRepo.search(
        from: range.value.start,
        to: range.value.end,
        officeId: office.value?.id,
        status: statusFilter.value,
      );

  @override
  bool matches(Expense e, String q) =>
      e.details.toLowerCase().contains(q) ||
      (e.office?.name ?? '').toLowerCase().contains(q) ||
      (e.category ?? '').toLowerCase().contains(q) ||
      (e.account ?? '').toLowerCase().contains(q) ||
      (e.boxLabel ?? '').toLowerCase().contains(q);

  /// Jumla ya yaliyoidhinishwa tu (ndiyo yanayohesabiwa).
  double get total => visible.where((e) => e.isApproved).fold<double>(0, (s, e) => s + e.amount);

  double get pendingTotal => visible.where((e) => e.isPending).fold<double>(0, (s, e) => s + e.amount);

  int get pendingCount => visible.where((e) => e.isPending).length;

  void setRange(DateTimeRange r) {
    range.value = r;
    load();
  }

  void setOffice(Office? o) {
    office.value = o;
    load();
  }

  void setStatus(String? s) {
    statusFilter.value = s;
    load();
  }
}
