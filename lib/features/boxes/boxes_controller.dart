import 'package:get/get.dart';

import '../../core/list_controller.dart';
import '../../data/models/box.dart';
import '../../data/repositories.dart';

enum BoxFilter { open, transit, arrived }

class BoxesController extends ListController<Box> {
  final Rx<BoxFilter> filter = BoxFilter.open.obs;

  /// Bidhaa zinazosubiri kupakiwa (invoice za PARKING) - zinaburutwa kwenda kwenye box.
  final RxList<BoxProduct> waitingItems = <BoxProduct>[].obs;

  int get waiting => waitingItems.length;

  @override
  Future<List<Box>> fetch() async {
    final results = await Future.wait([BoxRepo.all(), BoxRepo.available()]);
    waitingItems.assignAll(results[1] as List<BoxProduct>);
    return results[0] as List<Box>;
  }

  @override
  bool matches(Box b, String q) => b.boxId.toLowerCase().contains(q) || b.trackNumber.toLowerCase().contains(q);

  static bool inFilter(Box b, BoxFilter f) => switch (f) {
        BoxFilter.open => b.isOpen,
        BoxFilter.transit => b.inTransit,
        BoxFilter.arrived => b.arrived,
      };

  @override
  List<Box> get visible {
    final f = filter.value;
    return super.visible.where((b) => inFilter(b, f)).toList();
  }

  int countFor(BoxFilter f) => items.where((b) => inFilter(b, f)).length;
}
