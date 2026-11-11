import 'package:get/get.dart';

import '../../core/list_controller.dart';
import '../../data/models/box.dart';
import '../../data/repositories.dart';

enum StoreFilter { expected, arrived }

class StoreController extends ListController<Box> {
  final Rx<StoreFilter> filter = StoreFilter.expected.obs;

  /// Mizigo iliyokaa stoo zaidi ya siku za bure (kitufe cha juu).
  final RxInt overdue = 0.obs;

  Future<void> loadOverdue() async {
    try {
      overdue.value = (await StorageRepo.overdue()).items.length;
    } catch (_) {
      // kimya - si muhimu kwa orodha ya mabox
    }
  }

  @override
  Future<List<Box>> fetch() async {
    loadOverdue();
    final boxes = await BoxRepo.all();
    return boxes.where((b) => b.isBoxClose || b.isCollect).toList();
  }

  @override
  bool matches(Box b, String q) => b.boxId.toLowerCase().contains(q) || b.trackNumber.toLowerCase().contains(q);

  @override
  List<Box> get visible {
    final f = filter.value;
    return super.visible.where((b) => f == StoreFilter.expected ? b.inTransit : b.arrived).toList();
  }

  int countFor(StoreFilter f) => items.where((b) => f == StoreFilter.expected ? b.inTransit : b.arrived).length;
}
