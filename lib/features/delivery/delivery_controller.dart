import 'package:get/get.dart';

import '../../core/list_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories.dart';

enum DeliveryFilter { all, notBilled, owing }

class DeliveryController extends ListController<Invoice> {
  final Rx<DeliveryFilter> filter = DeliveryFilter.all.obs;

  @override
  Future<List<Invoice>> fetch() => InvoiceRepo.search(status: InvoiceStatus.store.code);

  @override
  bool matches(Invoice i, String q) {
    if (i.invoiceNumber.contains(q)) return true;
    final c = i.customer;
    if (c != null && (c.name.toLowerCase().contains(q) || Phone.matches(c.phoneNumber, q))) return true;
    final r = i.receiver;
    return r != null &&
        (r.name.toLowerCase().contains(q) || r.trackNumber.toLowerCase().contains(q) || Phone.matches(r.phoneNumber, q));
  }

  static bool inFilter(Invoice i, DeliveryFilter f) => switch (f) {
        DeliveryFilter.all => true,
        DeliveryFilter.notBilled => i.debt == null,
        DeliveryFilter.owing => i.debt != null && !i.debt!.isPaid,
      };

  @override
  List<Invoice> get visible {
    final f = filter.value;
    return super.visible.where((i) => inFilter(i, f)).toList();
  }

  int countFor(DeliveryFilter f) => items.where((i) => inFilter(i, f)).length;

  double get totalOwing => items.fold<double>(0, (s, i) => s + (i.debt?.balance ?? 0));
}
