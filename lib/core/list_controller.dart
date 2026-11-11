import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app/app_controller.dart';
import 'widgets/feedback.dart';
import 'widgets/states.dart';

/// Msingi wa kurasa za orodha: kupakia, kutafuta, kupakia upya data ikibadilika.
abstract class ListController<T> extends GetxController {
  final RxList<T> items = <T>[].obs;
  final Rx<LoadStatus> status = LoadStatus.loading.obs;
  final RxnString error = RxnString();
  final RxString query = ''.obs;
  final TextEditingController search = TextEditingController();

  Worker? _changes;

  /// Kupakua data kutoka kwa server.
  Future<List<T>> fetch();

  /// Kama [item] inalingana na maneno ya kutafuta [q] (herufi ndogo).
  bool matches(T item, String q) => true;

  /// Orodha baada ya kutafuta.
  List<T> get visible {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items.toList();
    return items.where((e) => matches(e, q)).toList();
  }

  bool get isLoading => status.value == LoadStatus.loading;

  @override
  void onInit() {
    super.onInit();
    _changes = ever<int>(AppController.to.changes, (_) => load(silent: true));
    load();
  }

  @override
  void onClose() {
    _changes?.dispose();
    search.dispose();
    super.onClose();
  }

  void onSearch(String value) => query.value = value;

  Future<void> load({bool silent = false}) async {
    if (!silent) status.value = LoadStatus.loading;
    try {
      final data = await fetch();
      items.assignAll(data);
      error.value = null;
      status.value = LoadStatus.ready;
    } catch (e) {
      error.value = e.toString();
      status.value = LoadStatus.error;
      if (items.isNotEmpty) Toast.error(e);
    }
  }

  Future<void> refreshList() => load(silent: true);
}

/// Orodha kubwa: data inaletwa kwa kurasa kutoka kwa server, na kutafuta kunafanyika kwenye server.
abstract class PagedListController<T> extends ListController<T> {
  int get pageSize => 50;

  final RxBool hasMore = false.obs;
  final RxBool loadingMore = false.obs;
  Timer? _debounce;

  /// Ukurasa mmoja: [offset] na [limit]; maneno ya kutafuta yako kwenye [query].
  Future<List<T>> fetchPage(int offset, int limit);

  @override
  Future<List<T>> fetch() async {
    // Ikipakiwa upya (data imebadilika) tunaleta angalau idadi iliyokuwa inaonekana.
    final want = items.length > pageSize ? items.length : pageSize;
    final page = await fetchPage(0, want);
    hasMore.value = page.length >= want;
    return page;
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value) return;
    loadingMore.value = true;
    try {
      final page = await fetchPage(items.length, pageSize);
      items.addAll(page);
      hasMore.value = page.length >= pageSize;
    } catch (e) {
      Toast.error(e);
    } finally {
      loadingMore.value = false;
    }
  }

  /// Kutafuta kunasubiri mtumiaji aache kuandika kidogo, kisha kunaenda kwa server.
  @override
  void onSearch(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      items.clear();
      load();
    });
  }

  /// Server imeshachuja - hakuna kuchuja tena hapa.
  @override
  bool matches(T item, String q) => true;

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
