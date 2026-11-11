import 'package:get/get.dart';

import 'models/settings.dart';
import 'repositories.dart';

/// Orodha ndogo zinazotumika kwenye fomu nyingi (bei, sarafu, taasisi, ofisi).
/// Zinapakuliwa mara moja na kutumika tena; Settings ikibadilisha, zinapakiwa upya.
class Lookups extends GetxService {
  static Lookups get to => Get.isRegistered<Lookups>() ? Get.find<Lookups>() : Get.put(Lookups(), permanent: true);

  final RxList<Price> prices = <Price>[].obs;
  final RxList<Currency> currencies = <Currency>[].obs;
  final RxList<Institute> institutes = <Institute>[].obs;
  final RxList<Office> offices = <Office>[].obs;

  Future<List<Price>> loadPrices({bool force = false}) async {
    if (force || prices.isEmpty) prices.assignAll(await SettingsRepo.prices(blocked: false));
    return prices;
  }

  Future<List<Currency>> loadCurrencies({bool force = false}) async {
    if (force || currencies.isEmpty) currencies.assignAll(await SettingsRepo.currencies(blocked: false));
    return currencies;
  }

  Future<List<Institute>> loadInstitutes({bool force = false}) async {
    if (force || institutes.isEmpty) institutes.assignAll(await SettingsRepo.institutes(blocked: false));
    return institutes;
  }

  Future<List<Office>> loadOffices({bool force = false}) async {
    if (force || offices.isEmpty) offices.assignAll(await SettingsRepo.offices(blocked: false));
    return offices;
  }

  /// Sarafu ya USD ya sasa (kwa kuonyesha thamani ya dola).
  Currency? get usd {
    for (final c in currencies) {
      if (c.name.toUpperCase() == 'USD') return c;
    }
    return currencies.isEmpty ? null : currencies.first;
  }

  void clear() {
    prices.clear();
    currencies.clear();
    institutes.clear();
    offices.clear();
  }
}
