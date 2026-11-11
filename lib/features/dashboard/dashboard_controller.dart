import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/widgets/states.dart';
import '../../data/models/misc.dart';
import '../../data/repositories.dart';

class DashboardController extends GetxController {
  final Rx<DashboardSummary> summary = const DashboardSummary().obs;
  final Rx<LoadStatus> status = LoadStatus.loading.obs;
  final RxnString error = RxnString();
  bool _loadedOnce = false;
  Worker? _changes;

  @override
  void onInit() {
    super.onInit();
    _changes = ever<int>(AppController.to.changes, (_) => load());
    load();
  }

  @override
  void onClose() {
    _changes?.dispose();
    super.onClose();
  }

  bool get hasData => _loadedOnce;

  Future<void> load() async {
    if (!_loadedOnce) status.value = LoadStatus.loading;
    try {
      summary.value = await DashboardRepo.summary();
      _loadedOnce = true;
      error.value = null;
      status.value = LoadStatus.ready;
    } catch (e) {
      error.value = e.toString();
      status.value = LoadStatus.error;
    }
  }
}
