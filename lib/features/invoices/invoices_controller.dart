import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/list_controller.dart';
import '../../core/widgets/feedback.dart';
import '../../data/lookups.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories.dart';

class InvoicesController extends PagedListController<Invoice> {
  /// `null` = zote.
  final Rxn<InvoiceStatus> filter = Rxn<InvoiceStatus>();

  /// Ofisi iliyochaguliwa (`null` = zote).
  final RxnString officeId = RxnString();

  static const List<InvoiceStatus?> filters = [
    null,
    InvoiceStatus.open,
    InvoiceStatus.parking,
    InvoiceStatus.shipping,
    InvoiceStatus.store,
    InvoiceStatus.delivered,
    InvoiceStatus.completed,
    InvoiceStatus.blocked,
  ];

  @override
  Future<List<Invoice>> fetchPage(int offset, int limit) => InvoiceRepo.search(
        status: filter.value?.code,
        officeId: officeId.value,
        query: query.value,
        offset: offset,
        limit: limit,
      );

  @override
  void onInit() {
    super.onInit();
    Lookups.to.loadOffices().catchError((_) => Lookups.to.offices.toList());
  }

  void setOffice(String? id) {
    if (officeId.value == id) return;
    officeId.value = id;
    items.clear();
    load();
  }

  void setFilter(InvoiceStatus? status) {
    if (filter.value == status) return;
    filter.value = status;
    items.clear();
    load();
  }

  /// Inafuta ankara zote zilizozuiwa baada ya kuthibitisha.
  Future<void> deleteAllBlocked() async {
    final ok = await confirmAction(
      title: 'deleteAllBlocked'.tr,
      message: 'deleteAllBlockedMsg'.trParams({'n': hasMore.value ? '${items.length}+' : '${items.length}'}),
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_sweep_rounded,
    );
    if (!ok) return;
    try {
      final n = await InvoiceRepo.deleteBlocked();
      Toast.success('blockedDeleted'.trParams({'n': '$n'}));
      AppController.to.notifyChanged();
    } catch (e) {
      Toast.error(e);
    }
  }


}
