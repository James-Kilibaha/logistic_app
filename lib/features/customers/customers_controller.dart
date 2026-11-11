import 'package:get/get.dart';

import '../../core/list_controller.dart';
import '../../data/models/customer.dart';
import '../../data/repositories.dart';

enum CustomerFilter { all, active, blocked }

class CustomersController extends PagedListController<Customer> {
  final Rx<CustomerFilter> filter = CustomerFilter.all.obs;
  final RxMap<String, int> counts = <String, int>{}.obs;

  @override
  Future<List<Customer>> fetchPage(int offset, int limit) {
    if (offset == 0) _loadCounts();
    return CustomerRepo.search(
      query: query.value,
      active: switch (filter.value) {
        CustomerFilter.all => null,
        CustomerFilter.active => 1,
        CustomerFilter.blocked => 0,
      },
      offset: offset,
      limit: limit,
    );
  }

  Future<void> _loadCounts() async {
    try {
      counts.assignAll(await CustomerRepo.counts());
    } catch (_) {}
  }

  void setFilter(CustomerFilter f) {
    if (filter.value == f) return;
    filter.value = f;
    items.clear();
    load();
  }

  int? countFor(CustomerFilter f) => counts[switch (f) {
        CustomerFilter.all => 'all',
        CustomerFilter.active => 'active',
        CustomerFilter.blocked => 'blocked',
      }];
}
