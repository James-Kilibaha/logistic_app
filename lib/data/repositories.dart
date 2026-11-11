import 'dart:convert';
import 'dart:typed_data';

import '../core/api/api_client.dart';
import 'models/accounting.dart';
import 'models/admin.dart';
import 'models/demand.dart';
import 'models/box.dart';
import 'models/claim.dart';
import 'models/company.dart';
import 'models/customer.dart';
import 'models/customer_overview.dart';
import 'models/finance.dart';
import 'models/invoice.dart';
import 'models/json.dart';
import 'models/misc.dart';
import 'models/payroll.dart';
import 'models/ops.dart';
import 'models/popup.dart';
import 'models/quotation.dart';
import 'models/role.dart';
import 'models/settings.dart';
import 'models/user.dart';

/// Njia zote za backend (REST) zimekusanywa hapa - controllers hazijui URL.

/// Kampuni (tenant): branding ya umma, usajili, wasifu, mipangilio na subscription.
class CompanyRepo {
  CompanyRepo._();

  /// Branding ya kampuni ya sasa (kwa domain au `X-Company`). [slug] = kuangalia code mpya ya kampuni.
  static Future<Map<String, dynamic>> brandingJson({String? slug}) async {
    final body = await Api.get('public/branding', query: {if (slug != null && slug.isNotEmpty) 'company': slug});
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<List<Plan>> publicPlans() => Api.list(Api.get('public/plans'), Plan.fromJson);

  /// `{slug, available, reason}`
  static Future<Map<String, dynamic>> checkSlug(String slug) async {
    final body = await Api.get('public/company-check/${Uri.encodeComponent(slug.trim().toLowerCase())}');
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    final body = await Api.post('public/signup', data);
    return Map<String, dynamic>.from(body as Map);
  }

  /// Kwa kila mtumiaji: branding + hali ya subscription.
  static Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await Api.get('company/me') as Map);

  static Future<CompanyProfile> profile() => Api.one(Api.get('company'), CompanyProfile.fromJson);

  static Future<void> updateProfile(Map<String, dynamic> data) => Api.put('company/profile', data);

  static Future<void> updateSettings(Map<String, dynamic> values) => Api.put('company/settings', {'values': values});

  static Future<void> uploadLogo(Uint8List bytes, String name) =>
      Api.multipart('company/logo', fields: const {}, fileBytes: bytes, fileName: name);

  static Future<void> deleteLogo() => Api.delete('company/logo');

  static Future<SubscriptionOverview> subscription() =>
      Api.one(Api.get('company/subscription'), SubscriptionOverview.fromJson);

  static Future<void> submitPayment(Map<String, dynamic> data) => Api.post('company/subscription/payment', data);

  /// Kabla ya kulipa: mpango mpya ni mkubwa/mdogo kuliko uliolipiwa, unaanza lini, siku zinazoongezwa/kufutwa.
  static Future<Map<String, dynamic>> planChange(String planId, int periods) async {
    final body = await Api.get('company/subscription/plan-change', query: {'plan_id': planId, 'periods': '$periods'});
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  /// Risiti (PDF) ya malipo ya subscription yaliyothibitishwa.
  /// Hatua za kwanza za kampuni: {steps: [{key, done, target, optional}], done, total, complete, hidden}.
  static Future<Map<String, dynamic>> onboarding() async =>
      Map<String, dynamic>.from((await Api.get('company/onboarding')) as Map);

  static Future<void> hideOnboarding() => Api.put('company/onboarding/hide');

  /// Bei kabla/baada ya coupon: {code, gross, discount, amount}. Coupon isiyofaa -> kosa lenye maelezo.
  static Future<Map<String, dynamic>> checkCoupon(String code, String planId, int periods) async =>
      Map<String, dynamic>.from((await Api.post('company/subscription/coupon',
          {'code': code.trim(), 'plan_id': planId, 'periods': periods})) as Map);

  /// Data yote ya kampuni (ZIP: kila table kama JSON + CSV, na picha/PDF zake).
  static Future<Uint8List> exportData() => Api.getBytes('company/export');

  static Future<Uint8List> subscriptionReceipt(String paymentId) =>
      Api.getBytes('company/subscription/payments/$paymentId/receipt');

  // ---------------------------------------------------------- WhatsApp Business ya kampuni
  static Future<Map<String, dynamic>> _map(Future<dynamic> f) async => Map<String, dynamic>.from((await f) as Map);

  static Future<Map<String, dynamic>> whatsapp() => _map(Api.get('company/whatsapp'));

  static Future<Map<String, dynamic>> whatsappConnect(Map<String, dynamic> data) =>
      _map(Api.put('company/whatsapp', data));

  static Future<Map<String, dynamic>> whatsappTest() => _map(Api.post('company/whatsapp/test', const {}));

  static Future<Map<String, dynamic>> whatsappRotateToken() => _map(Api.post('company/whatsapp/verify-token', const {}));

  static Future<Map<String, dynamic>> whatsappDisconnect() => _map(Api.delete('company/whatsapp'));

  static Future<List<Map<String, dynamic>>> whatsappTemplates() async {
    final body = await Api.get('company/whatsapp/templates');
    return (body is List ? body : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> whatsappTestMessage(String phone, String? text) =>
      Api.post('company/whatsapp/test-message', {'phone': phone, if (text != null && text.isNotEmpty) 'text': text});
}

class AuthRepo {
  AuthRepo._();

  /// Inarudisha `{access_token, refresh_token, user}`, au `{otpRequired: true, otpToken, phoneHint}` (2FA).
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final body = await Api.post('login', {'username': username.trim(), 'password': password});
    return Map<String, dynamic>.from(body as Map);
  }

  /// Hatua ya pili: code iliyotumwa kwa SMS.
  static Future<Map<String, dynamic>> verifyOtp(String otpToken, String code) async {
    final body = await Api.post('login/otp', {'otpToken': otpToken, 'code': code.trim()});
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> resendOtp(String otpToken) async {
    final body = await Api.post('login/otp/resend', {'otpToken': otpToken});
    return Map<String, dynamic>.from(body as Map);
  }

  /// Kusahau nywila, hatua 1: `{resetToken, ttlMinutes, message}` (jibu ni lile lile hata kama jina halipo).
  static Future<Map<String, dynamic>> forgot(String username) async {
    final body = await Api.post('auth/forgot', {'username': username.trim()});
    return Map<String, dynamic>.from(body as Map);
  }

  /// Hatua 2: code ya SMS + nywila mpya.
  static Future<void> resetPassword(String resetToken, String code, String newPassword) =>
      Api.post('auth/forgot/reset', {'resetToken': resetToken, 'code': code.trim(), 'newPassword': newPassword});
}

/// Usalama wa akaunti yako mwenyewe.
class AccountRepo {
  AccountRepo._();

  /// Inarudisha `{access_token, refresh_token, user}` mpya (vifaa vingine vinatolewa).
  static Future<Map<String, dynamic>> changeOwnPassword(String oldPassword, String newPassword) async {
    final body = await Api.put('auth/password', {'oldPassword': oldPassword, 'newPassword': newPassword});
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<void> logoutEverywhere() => Api.post('auth/logout-all');
}

class RoleRepo {
  RoleRepo._();

  static Future<List<Role>> all() => Api.list(Api.get('role'), Role.fromJson);

  static Future<Role> save({
    String? id,
    required String name,
    String? description,
    required List<RoleFlags> permissions,
    bool applyToUsers = true,
  }) {
    final body = {
      'name': name.trim(),
      'description': description?.trim(),
      'permissions': permissions.map((p) => p.toJson()).toList(),
      'applyToUsers': applyToUsers,
    };
    return Api.one(id == null ? Api.post('role', body) : Api.put('role/$id', body), Role.fromJson);
  }

  static Future<void> delete(String id) => Api.delete('role/$id');

  /// [roleId] == null = kuondoa role (ruhusa zinabaki).
  static Future<void> assign(String userId, String? roleId) =>
      Api.put('role/assign', {'user_id': userId, 'role_id': roleId});
}

class DashboardRepo {
  DashboardRepo._();

  static Future<DashboardSummary> summary() => Api.one(Api.get('dashboard/summary'), DashboardSummary.fromJson);
}

class CustomerRepo {
  CustomerRepo._();

  static Future<List<Customer>> all() => Api.list(Api.get('customer'), Customer.fromJson);

  /// Kurasa kutoka kwa server. [active]: 1 = hai, 0 = wamezuiwa, null = wote.
  static Future<List<Customer>> search({String? query, int? active, int offset = 0, int limit = 50}) => Api.list(
        Api.post('customer/search', {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (active != null) 'active': active,
          'offset': offset,
          'limit': limit,
        }),
        Customer.fromJson,
      );

  /// Idadi: {all, active, blocked}.
  static Future<Map<String, int>> counts() async {
    final body = await Api.get('customer/counts');
    if (body is! Map) return const {};
    return body.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
  }

  static Future<Customer> create({required String name, required String phone}) =>
      Api.one(Api.post('customer', {'name': name.trim(), 'phoneNumber': phone.trim(), 'active': 1}), Customer.fromJson);

  static Future<Customer> update({required String id, required String name, required String phone}) =>
      Api.one(Api.put('customer/update', {'id': id, 'name': name.trim(), 'phoneNumber': phone.trim()}),
          Customer.fromJson);

  /// Kuzuia / kuruhusu mteja.
  static Future<Customer> toggleBlock(String id) => Api.one(Api.put('customer/block', {'id': id}), Customer.fromJson);

  static Future<void> delete(String id) => Api.delete('customer/$id');

  /// Kikomo cha mkopo: `null` = kikomo cha kawaida; 0 = hakopeshwi.
  static Future<Customer> setCreditLimit(String id, double? limit) =>
      Api.one(Api.put('customer/credit-limit', {'id': id, 'creditLimit': limit}), Customer.fromJson);

  /// Dashibodi ya mteja: takwimu na kumbukumbu zote (kwa kipindi, au tangu mwanzo).
  static Future<CustomerOverview> overview(String id, {DateTime? from, DateTime? to}) =>
      Api.one(Api.get('customer/$id/overview${_rangeQuery(from, to)}'), CustomerOverview.fromJson);

  /// Taarifa ya mteja: [fmt] = 'pdf' au 'xlsx'.
  static Future<Uint8List> statement(String id, String fmt, {DateTime? from, DateTime? to}) =>
      Api.getBytes('customer/$id/statement/$fmt${_rangeQuery(from, to)}');
}

/// Taarifa za bidhaa mpya au iliyobadilishwa.
class ProductInput {
  final String? id;
  final String invoiceId;
  final String description;
  final String? trackNumber;
  final String carrierType;
  final double quantities;
  final double weight;
  final double unitPrice;
  final String? priceId;
  final double? length;
  final double? width;
  final double? height;

  /// Code ya ofisi ya mzigo mpya; null = mfumo unatengeneza.
  final String? officeCode;

  const ProductInput({
    this.id,
    required this.invoiceId,
    required this.description,
    this.trackNumber,
    this.carrierType = 'AIR',
    required this.quantities,
    required this.weight,
    required this.unitPrice,
    this.priceId,
    this.length,
    this.width,
    this.height,
    this.officeCode,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'invoiceId': invoiceId,
        'description': description.trim(),
        'trackNumber': (trackNumber ?? '').trim(),
        'carrierType': carrierType,
        'quantities': quantities,
        'weight': weight,
        'unitPrice': unitPrice,
        if (priceId != null) 'priceId': priceId,
        'length': length ?? 0,
        'width': width ?? 0,
        'height': height ?? 0,
        if (officeCode != null && officeCode!.trim().isNotEmpty) 'officeCode': officeCode!.trim().toUpperCase(),
      };
}

class InvoiceRepo {
  InvoiceRepo._();

  /// [query] inatafutwa kwenye server (namba ya ankara, mteja, mpokeaji, track number).
  /// [limit] == null = zote.
  static Future<List<Invoice>> search({
    String? id,
    String? status,
    List<String>? statuses,
    String? customerId,
    String? number,
    String? officeId,
    String? query,
    int offset = 0,
    int? limit,
  }) {
    return Api.list(
      Api.post('invoice/search', {
        if (id != null) 'id': id,
        if (status != null) 'status': status,
        if (statuses != null) 'statuses': statuses,
        if (customerId != null) 'customer_id': customerId,
        if (number != null) 'invoiceNumber': number,
        if (officeId != null) 'office_id': officeId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (offset > 0) 'offset': offset,
        if (limit != null) 'limit': limit,
      }),
      Invoice.fromJson,
    );
  }

  /// Kuhamisha ankara kwenda ofisi nyingine (null = bila ofisi).
  static Future<void> setOffice(String id, String? officeId) =>
      Api.put('invoice/office', {'id': id, 'office_id': officeId});

  static Future<Invoice?> byId(String id) async {
    final list = await search(id: id);
    return list.isEmpty ? null : list.first;
  }

  static Future<Invoice> create(String customerId) =>
      Api.one(Api.post('invoice', {'customer_id': customerId}), Invoice.fromJson);

  static Future<void> changeStatus(String id, String status) =>
      Api.put('invoice/change-status', {'id': id, 'status': status});

  /// Inafuta ankara iliyozuiwa pamoja na bidhaa, mpokeaji, deni na sms zake.
  static Future<void> delete(String id) => Api.delete('invoice/$id');

  /// Inafuta ankara zote zilizozuiwa. Inarudisha idadi iliyofutwa.
  static Future<int> deleteBlocked() async {
    final body = await Api.delete('invoice/blocked');
    final n = body is Map ? body['deleted'] : null;
    return n is num ? n.toInt() : 0;
  }

  /// PDF ya invoice. Ikiwa iko stoo, inafungua pia deni la malipo.
  static Future<Uint8List> pdf(Invoice invoice) {
    final path = invoice.status == InvoiceStatus.store ||
            invoice.status == InvoiceStatus.completed ||
            invoice.status == InvoiceStatus.delivered
        ? 'store/generate-invoice'
        : 'invoice/generate-invoice';
    return Api.postBytes(path, {'id': invoice.id, 'status': invoice.statusCode});
  }

  // ------------------------------------------------------------- bidhaa

  static Future<Product> addProduct(ProductInput input, {Uint8List? imageBytes, String? imageName}) => Api.one(
        Api.multipart(
          'product',
          fields: {'stringValue': jsonEncode(input.toJson())},
          fileBytes: imageBytes,
          fileName: imageName,
        ),
        Product.fromJson,
      );

  static Future<Product> updateProduct(ProductInput input) {
    final json = input.toJson()..remove('invoiceId');
    return Api.one(Api.put('product', json), Product.fromJson);
  }

  static Future<void> deleteProduct(String id) => Api.delete('product/$id');

  // ----------------------------------------------------------- mpokeaji

  /// Kusajili mpokeaji: invoice inahamia hatua ya PARKING (tayari kupakiwa kwenye box).
  static Future<void> addReceiver({
    required String invoiceId,
    required String name,
    required String phone,
    required String trackNumber,
    String? customerId,
  }) =>
      Api.post('receiver', {
        'invoice_id': invoiceId,
        'name': name.trim(),
        'phoneNumber': phone.trim(),
        'trackNumber': trackNumber.trim(),
        if (customerId != null) 'customer_id': customerId,
      });

  static Future<void> updateReceiver({
    required String id,
    required String name,
    required String phone,
    required String trackNumber,
  }) =>
      Api.put('receiver/update', {
        'id': id,
        'name': name.trim(),
        'phoneNumber': phone.trim().isEmpty ? null : phone.trim(),
        'trackNumber': trackNumber.trim(),
      });

  static Future<void> deleteReceiver(String id) => Api.delete('receiver/$id');
}

class PaymentRepo {
  PaymentRepo._();

  /// Deni la invoice pamoja na malipo yake (404 kama bado halijafunguliwa).
  static Future<Debt?> debtFor(String invoiceId) async {
    try {
      return await Api.one(Api.post('payment/search-payment', {'invoiceId': invoiceId}), Debt.fromJson);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// [amount] ni kwa sarafu [currency] (TZS, USD ...). Inarudisha malipo pamoja na namba ya risiti.
  static Future<Payment> pay({
    required String debtId,
    required String instituteId,
    required double amount,
    String currency = 'TZS',
    String? note,
  }) =>
      Api.one(
        Api.post('payment', {
          'debtId': debtId,
          'instituteId': instituteId,
          'paid': amount,
          'currency': currency,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
        Payment.fromJson,
      );

  static Future<void> discount({required String debtId, required double amount, required String note}) =>
      Api.put('payment/discount', {'debtId': debtId, 'amount': amount, 'note': note.trim()});

  static Future<Payment> refund({
    required String debtId,
    required String instituteId,
    required double amount,
    required String note,
  }) =>
      Api.one(
        Api.post('payment/refund', {'debtId': debtId, 'instituteId': instituteId, 'amount': amount, 'note': note.trim()}),
        Payment.fromJson,
      );

  static Future<Uint8List> receipt(String paymentId) => Api.getBytes('payment/$paymentId/receipt');
}

class HandoverRepo {
  HandoverRepo._();

  static Future<HandoverStatus> status(String invoiceId) =>
      Api.one(Api.get('handover/$invoiceId/status'), HandoverStatus.fromJson);

  /// [items]: productId -> katoni (null = mzigo wote uliobaki).
  static Future<Handover> create({
    Map<String, double>? items,
    required String invoiceId,
    required String collectorName,
    required String collectorPhone,
    String? idType,
    String? idNumber,
    bool isReceiver = true,
    bool onCredit = false,
    String? note,
    List<String> officeCodes = const [],
    Uint8List? signaturePng,
    Uint8List? photoBytes,
    String? photoName,
  }) =>
      Api.one(
        Api.multipart(
          'handover',
          fields: {
            'stringValue': jsonEncode({
              'invoiceId': invoiceId,
              'collectorName': collectorName.trim(),
              'collectorPhone': collectorPhone.trim(),
              'idType': idType,
              'idNumber': idNumber?.trim(),
              'isReceiver': isReceiver,
              'onCredit': onCredit,
              'note': note?.trim(),
              if (officeCodes.isNotEmpty) 'officeCodes': officeCodes,
              if (items != null)
                'items': [
                  for (final e in items.entries)
                    if (e.value > 0) {'productId': e.key, 'cartons': e.value},
                ],
            }),
          },
          files: [
            if (signaturePng != null) UploadFile('signature', signaturePng, 'signature.png'),
            if (photoBytes != null) UploadFile('photo', photoBytes, photoName ?? 'photo.jpg'),
          ],
        ),
        Handover.fromJson,
      );

  static Future<Uint8List> pdf(String invoiceId, {String? handoverId}) =>
      Api.getBytes('handover/$invoiceId/pdf${handoverId == null ? '' : '?handoverId=$handoverId'}');

  static Future<Uint8List> file(String invoiceId, String kind, {String? handoverId}) =>
      Api.getBytes('handover/$invoiceId/file/$kind${handoverId == null ? '' : '?handoverId=$handoverId'}');

  static Map<String, dynamic> _filter({
    DateTime? from,
    DateTime? to,
    String? q,
    String? staffId,
    String? carrier,
    bool? onCredit,
    int offset = 0,
    int limit = 50,
  }) =>
      {
        if (from != null) 'startDate': ExpenseRepo._day(from),
        if (to != null) 'endDate': ExpenseRepo._day(to),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (staffId != null) 'staffId': staffId,
        if (carrier != null) 'carrier': carrier,
        if (onCredit != null) 'onCredit': onCredit,
        'offset': offset,
        'limit': limit,
      };

  /// Mizigo iliyokabidhiwa (makabidhiano yote, pamoja na awamu).
  static Future<HandoverPage> search({
    DateTime? from,
    DateTime? to,
    String? q,
    String? staffId,
    String? carrier,
    bool? onCredit,
    int offset = 0,
    int limit = 50,
  }) =>
      Api.one(
        Api.post('handover/search', _filter(
            from: from, to: to, q: q, staffId: staffId, carrier: carrier, onCredit: onCredit, offset: offset, limit: limit)),
        HandoverPage.fromJson,
      );

  /// Excel ya mizigo iliyokabidhiwa kwa vichujio vile vile.
  static Future<Uint8List> excel({DateTime? from, DateTime? to, String? q, String? staffId, String? carrier, bool? onCredit}) =>
      Api.postBytes('handover/export', _filter(
          from: from, to: to, q: q, staffId: staffId, carrier: carrier, onCredit: onCredit, limit: 5000));
}

class BoxRepo {
  BoxRepo._();

  static Future<List<Box>> all() => Api.list(Api.get('package'), Box.fromJson);

  static Future<Box> create({String type = 'GENERAL'}) =>
      Api.one(Api.post('package', {'packageType': type}), Box.fromJson);

  /// Bidhaa zilizo tayari kupakiwa (invoice za PARKING ambazo bado hazipo kwenye box).
  static Future<List<BoxProduct>> available() =>
      Api.list(Api.get('package/available-products'), BoxProduct.fromJson);

  static Future<List<BoxProduct>> products(String boxId) =>
      Api.list(Api.get('package/$boxId/products'), BoxProduct.fromJson);

  static Future<Box> addProduct(String boxId, BoxProduct product) => Api.one(
        Api.put('package/add-product-package', {
          'packageId': boxId,
          'productId': product.id,
          'invoiceId': product.invoiceId,
          'productWeight': product.weight,
        }),
        Box.fromJson,
      );

  static Future<Box> removeProduct(String boxId, String productId) => Api.one(
        Api.put('package/remove-product-package', {'packageId': boxId, 'productId': productId}),
        Box.fromJson,
      );

  /// Kufunga box na kulisafirisha: invoice zake zote zinakuwa SHIPPING.
  /// [eta] tupu = seva inaweka siku za kawaida (ndege / meli).
  /// Track number ya safari inayopendekezwa na mfumo (mf. ACME-A261110-001), au iliyopo tayari.
  static Future<String> nextTrack(String boxId) async {
    final body = await Api.get('package/$boxId/next-track');
    return body is Map ? (body['trackNumber'] ?? '').toString() : '';
  }

  static Future<Box> close(String boxId, {required double weight, required String trackNumber, DateTime? eta}) =>
      Api.one(
        Api.put('package/close-package', {
          'id': boxId,
          'productWeight': weight,
          'trackNumber': trackNumber.trim(),
          if (eta != null) 'eta': _day(eta),
        }),
        Box.fromJson,
      );

  /// Kubadilisha ETA ya box lililo safarini; [notify] = SMS kwa wateja wake.
  static Future<Box> setEta(String boxId, DateTime eta, {bool notify = false, String? reason}) => Api.one(
        Api.put('package/$boxId/eta', {
          'eta': _day(eta),
          'notify': notify,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }),
        Box.fromJson,
      );

  /// Mabox yaliyochelewa: [{id, boxId, packageType, trackNumber, eta, daysLate, invoices, products}].
  static Future<List<Map<String, dynamic>>> late() async {
    final body = await Api.get('package/late');
    return body is List ? [for (final e in body) Map<String, dynamic>.from(e as Map)] : const [];
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Box limefika stoo: invoice zake zote zinakuwa STORE. [sendSms]=false: SMS zinatumwa baadaye (ArrivalsPage).
  static Future<Box> receive(String boxId, {bool sendSms = false}) =>
      Api.one(Api.put('store/is-correct-package', {'id': boxId, 'sendSms': sendSms}), Box.fromJson);

  /// Ankara za box lililofika (wateja, mizigo, pesa) na hali ya SMS ya "mzigo umefika".
  static Future<Map<String, dynamic>> arrivals(String boxId) async {
    final body = await Api.get('package/$boxId/arrivals');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  /// SMS ya "mzigo umefika" kwa ankara zilizochaguliwa (null = zote za box).
  static Future<Map<String, dynamic>> notifyStore(String boxId, {List<String>? invoiceIds, bool toReceiver = true}) async {
    final body = await Api.post('package/$boxId/notify-store', {
      if (invoiceIds != null) 'invoiceIds': invoiceIds,
      'toReceiver': toReceiver,
    });
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<Uint8List> arrivalsExcel(String boxId) => Api.getBytes('package/$boxId/arrivals.xlsx');

  static Future<void> delete(String boxId) => Api.delete('package/$boxId');

  /// Orodha ya mizigo yote ndani ya box (PDF ya kuchapisha).
  static Future<Uint8List> manifest(String boxId) => Api.getBytes('package/$boxId/manifest');

  /// Lebo za QR: box lenyewe + kila mzigo (au kila katoni kama [perCarton]).
  static Future<Uint8List> labels(String boxId, {bool perCarton = false}) =>
      Api.getBytes('package/$boxId/labels?perCarton=$perCarton');

  /// Lebo za mizigo ya ankara moja (kabla ya kupakia).
  static Future<Uint8List> invoiceLabels(String invoiceId, {bool perCarton = false}) =>
      Api.getBytes('package/invoice/$invoiceId/labels?perCarton=$perCarton');
}

class SettingsRepo {
  SettingsRepo._();

  static Future<List<Currency>> currencies({bool? blocked}) => Api.list(
        Api.post('settings/currency-search', {if (blocked != null) 'isBlocked': blocked}),
        Currency.fromJson,
      );

  static Future<Currency> createCurrency(String name, double buy) => Api.one(
        Api.post('settings/currency-create', {'name': name.trim().toUpperCase(), 'buy': buy}),
        Currency.fromJson,
      );

  /// Kurekebisha kiwango cha sasa (kosa la kuandika) bila historia mpya.
  static Future<void> updateCurrency(String id, double buy) =>
      Api.put('settings/currency-update', {'id': id, 'buy': buy});

  /// Kuondoa sarafu nzima (viwango vyake vinazuiwa; historia inabaki).
  static Future<void> deleteCurrency(String id) => Api.delete('settings/currency/$id');

  /// Kufuta kiwango kilichokosewa: kiwango cha awali kinarudi. Inarudisha kiwango kilichorudi (null = hakuna).
  static Future<double?> deleteCurrencyRate(String id) async {
    final body = await Api.delete('settings/currency-rate/$id');
    final v = body is Map ? body['restored'] : null;
    return v is num ? v.toDouble() : null;
  }

  static Future<void> deletePrice(String id) => Api.delete('settings/price/$id');

  static Future<List<Price>> prices({bool? blocked}) => Api.list(
        Api.post('settings/price-search', {if (blocked != null) 'isBlocked': blocked}),
        Price.fromJson,
      );

  static Future<void> createPrice({
    required String currencyId,
    required double weight,
    required double cost,
    String unit = 'KG',
  }) =>
      Api.post('settings/price-create', {'currency_id': currencyId, 'weight': weight, 'cost': cost, 'unit': unit});

  static Future<List<Institute>> institutes({bool? blocked}) => Api.list(
        Api.post('settings/institute-search', {if (blocked != null) 'isBlocked': blocked}),
        Institute.fromJson,
      );

  static Future<void> createInstitute({
    required String name,
    required String accountNo,
    required String currencyType,
  }) =>
      Api.post('settings/institute-create', {
        'name': name.trim(),
        'accountNo': accountNo.trim(),
        'currencyType': currencyType.trim().toUpperCase(),
      });

  static Future<void> updateInstitute({
    required String id,
    required String name,
    required String accountNo,
    required String currencyType,
  }) =>
      Api.put('settings/institute-update', {
        'id': id,
        'name': name.trim(),
        'accountNo': accountNo.trim(),
        'currencyType': currencyType.trim().toUpperCase(),
      });

  /// `true` = imefichwa (ina malipo), `false` = imefutwa kabisa.
  static Future<bool> deleteInstitute(String id) async =>
      ((await Api.delete('settings/institute/$id')) as Map?)?['archived'] == true;

  static Future<List<Office>> offices({bool? blocked}) => Api.list(
        Api.post('settings/office-search', {if (blocked != null) 'isBlocked': blocked}),
        Office.fromJson,
      );

  static Future<void> createOffice({required String name, required String location, String? phone}) =>
      Api.post('settings/office-create', {
        'name': name.trim(),
        'location': location.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phoneNumber': phone.trim(),
      });

  static Future<void> updateOffice({required String id, required String name, required String location, String? phone}) =>
      Api.put('settings/office-update', {
        'id': id,
        'name': name.trim(),
        'location': location.trim(),
        'phoneNumber': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      });

  /// `true` = imefichwa (ina historia), `false` = imefutwa kabisa.
  static Future<bool> deleteOffice(String id) async =>
      ((await Api.delete('settings/office/$id')) as Map?)?['archived'] == true;

  /// Inaunda aina za SMS ambazo bado hazipo, kisha inarudisha zote.
  static Future<List<SmsSetting>> smsSettings() async {
    final list = await Api.list(Api.get('settings/sms-set-search'), SmsSetting.fromJson);
    if (list.length >= SmsKind.values.length) return list;
    return Api.list(Api.get('settings/sms-set-create'), SmsSetting.fromJson);
  }

  static Future<SmsSetting> toggleSms(String id) =>
      Api.one(Api.put('settings/sms-set-update/$id'), SmsSetting.fromJson);
}

class ExpenseRepo {
  ExpenseRepo._();

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [status]: PENDING | APPROVED | REJECTED (null = zote).
  static Future<List<Expense>> search({
    DateTime? from,
    DateTime? to,
    String? officeId,
    String? status,
    String? categoryId,
    String? accountId,
    String? boxId,
  }) =>
      Api.list(
        Api.post('expenses/search', {
          if (from != null) 'startDate': _day(from),
          if (to != null) 'endDate': _day(to),
          if (officeId != null) 'office_id': officeId,
          if (status != null) 'status': status,
          if (categoryId != null) 'category_id': categoryId,
          if (accountId != null) 'institute_id': accountId,
          if (boxId != null) 'package_id': boxId,
        }),
        Expense.fromJson,
      );

  static Future<Expense> save({
    String? id,
    required String details,
    required double amount,
    required String officeId,
    String currency = 'TZS',
    String? categoryId,
    String? accountId,
    String? boxId,
    String payStatus = 'PAID',
    double? paidAmount,
    String? supplier,
  }) async {
    final body = {
      'details': details.trim(),
      'amount': amount,
      'office_id': officeId,
      'currency': currency,
      'category_id': categoryId,
      'institute_id': accountId,
      'package_id': boxId,
      'payStatus': payStatus,
      if (payStatus == 'PARTIAL') 'paidAmount': paidAmount,
      if (supplier != null && supplier.trim().isNotEmpty) 'supplier': supplier.trim(),
    };
    final res = id == null ? await Api.post('expenses', body) : await Api.put('expenses/update', {...body, 'id': id});
    return Expense.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<void> delete(String id) => Api.delete('expenses/$id');

  static Future<void> approve(String id) => Api.post('expenses/$id/approve');

  static Future<void> reject(String id, String reason) => Api.post('expenses/$id/reject', {'reason': reason.trim()});

  static Future<void> uploadReceipt(String id, Uint8List bytes, String name) =>
      Api.multipart('expenses/$id/receipt', fields: const {}, fileBytes: bytes, fileName: name);

  static Future<Uint8List> receipt(String id) => Api.getBytes('expenses/$id/receipt');

  /// Kulipa deni la matumizi (lote au sehemu).
  static Future<void> pay(String id, {required double amount, String? accountId, String? note}) =>
      Api.post('expenses/$id/pay', {'amount': amount, 'institute_id': accountId, 'note': note?.trim()});
}

/// Madai ya gharama: kazi iliyofanywa inayodai gharama zake zijazwe (na kuzuia kazi zisipojazwa).
class DemandRepo {
  DemandRepo._();

  /// {items, blocked, remind}
  static Future<({List<CostDemand> items, bool blocked, bool remind})> mine() async {
    final body = Map<String, dynamic>.from(await Api.get('demands/mine') as Map);
    return (
      items: J.list(body['items'], CostDemand.fromJson),
      blocked: J.boolean(body['blocked']),
      remind: J.boolean(body['remind']),
    );
  }

  static Future<List<CostDemand>> all({String? status}) =>
      Api.list(Api.get(status == null ? 'demands' : 'demands?status=$status'), CostDemand.fromJson);

  /// Gharama moja kwa mabox mengi. [mode]: EACH | EQUAL | WEIGHT | MANUAL. [preview] = onyesha mgawanyo tu.
  static Future<Map<String, dynamic>> fillMany({
    required List<String> demandIds,
    required String category,
    required String mode,
    String currency = 'TZS',
    double? amount,
    Map<String, double> amounts = const {},
    String payStatus = 'PAID',
    double? paidAmount,
    String? supplier,
    String? accountId,
    String? note,
    bool preview = false,
  }) async =>
      Map<String, dynamic>.from(await Api.post('demands/fill-many', {
        'demandIds': demandIds,
        'category': category,
        'mode': mode,
        'currency': currency,
        'amount': amount,
        'amounts': amounts,
        'payStatus': payStatus,
        'paidAmount': paidAmount,
        'supplier': supplier?.trim(),
        'institute_id': accountId,
        'note': note?.trim(),
        'preview': preview,
      }) as Map);

  /// [costs]: [{category, amount, currency, note, payStatus, paidAmount, supplier, institute_id}]
  static Future<CostDemand> fill(String id, List<Map<String, dynamic>> costs) async =>
      CostDemand.fromJson(Map<String, dynamic>.from(await Api.post('demands/$id/fill', {'costs': costs}) as Map));

  static Future<void> noCost(String id, String reason) => Api.post('demands/$id/no-cost', {'reason': reason.trim()});

  static Future<void> waive(String id, String reason) => Api.post('demands/$id/waive', {'reason': reason.trim()});

  static Future<List<DemandRule>> rules() => Api.list(Api.get('demands/rules'), DemandRule.fromJson);

  static Future<void> saveRule(DemandRule r) => Api.put('demands/rules/${r.trigger}', {
        'enabled': r.enabled,
        'categories': r.categories,
        'responsible': r.responsible,
        'role_id': r.roleId,
        'remindHour': r.remindHour,
        'graceDays': r.graceDays,
        'blockScope': r.blockScope,
      });
}

/// Mali za kudumu na uchakavu.
class AssetRepo {
  AssetRepo._();

  static Future<({List<FixedAssetItem> items, double cost, double accumulated, double bookValue})> all() async {
    final body = Map<String, dynamic>.from(await Api.get('assets') as Map);
    return (
      items: J.list(body['items'], FixedAssetItem.fromJson),
      cost: J.dbl(body['cost']),
      accumulated: J.dbl(body['accumulated']),
      bookValue: J.dbl(body['bookValue']),
    );
  }

  static Future<void> save({
    String? id,
    required String name,
    required String category,
    required double cost,
    String currency = 'TZS',
    required DateTime purchaseDate,
    required int lifeMonths,
    double salvage = 0,
    String? accountId,
    String? officeId,
    String? serial,
    String? note,
  }) {
    final body = {
      'name': name.trim(),
      'category': category,
      'cost': cost,
      'currency': currency,
      'purchaseDate': _day(purchaseDate),
      'lifeMonths': lifeMonths,
      'salvage': salvage,
      'institute_id': accountId,
      'office_id': officeId,
      'serial': serial?.trim(),
      'note': note?.trim(),
    };
    return id == null ? Api.post('assets', body) : Api.put('assets/$id', body);
  }

  static Future<void> dispose(String id, {required DateTime date, double amount = 0, String? accountId}) =>
      Api.post('assets/$id/dispose', {'date': _day(date), 'amount': amount, 'institute_id': accountId});

  static Future<void> delete(String id) => Api.delete('assets/$id');
}

/// Mishahara: wafanyakazi, viwango na mishahara ya kila mwezi.
class PayrollRepo {
  PayrollRepo._();

  static Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(await Api.get('payroll/settings') as Map);

  static Future<void> saveSettings(Map<String, dynamic> body) => Api.put('payroll/settings', body);

  static Future<List<StaffMember>> employees({bool all = false}) =>
      Api.list(Api.get(all ? 'payroll/employees?all=true' : 'payroll/employees'), StaffMember.fromJson);

  static Future<void> saveEmployee(Map<String, dynamic> body, {String? id}) =>
      id == null ? Api.post('payroll/employees', body) : Api.put('payroll/employees/$id', body);

  static Future<void> deleteEmployee(String id) => Api.delete('payroll/employees/$id');

  static Future<List<PayrollRunData>> runs() => Api.list(Api.get('payroll/runs'), PayrollRunData.fromJson);

  static Future<PayrollRunData> run(String id) => Api.one(Api.get('payroll/runs/$id'), PayrollRunData.fromJson);

  static Future<PayrollRunData> prepare(String month) => Api.one(Api.post('payroll/runs', {'month': month}), PayrollRunData.fromJson);

  static Future<PayrollRunData> editLine(String runId, String lineId, {double? basic, double allowance = 0, double deduction = 0}) =>
      Api.one(
        Api.put('payroll/runs/$runId/lines/$lineId', {'basic': basic, 'allowance': allowance, 'deduction': deduction}),
        PayrollRunData.fromJson,
      );

  static Future<PayrollRunData> post(String runId, {String? accountId}) =>
      Api.one(Api.post('payroll/runs/$runId/post', {'institute_id': accountId}), PayrollRunData.fromJson);

  static Future<void> deleteRun(String id) => Api.delete('payroll/runs/$id');

  static Future<Uint8List> sheet(String id, String fmt) => Api.getBytes('payroll/runs/$id/sheet.$fmt');
}

/// Uhasibu: akaunti za fedha, salio, mapato mengine, uhamisho, makundi na faida/hasara.
class AccountingRepo {
  AccountingRepo._();

  static String _q(Map<String, String?> params) {
    final parts = [
      for (final e in params.entries)
        if (e.value != null && e.value!.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent(e.value!)}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  static String _period(DateTime? from, DateTime? to, {String? office}) =>
      _q({'startDate': from == null ? null : _day(from), 'endDate': to == null ? null : _day(to), 'office': office});

  static Future<Map<String, dynamic>> summary({DateTime? from, DateTime? to, String? office}) async {
    final body = await Api.get('accounting/summary${_period(from, to, office: office)}');
    return Map<String, dynamic>.from(body as Map);
  }

  /// [fmt] = 'pdf' au 'xlsx'.
  static Future<Uint8List> summaryFile(String fmt, {DateTime? from, DateTime? to, String? office}) =>
      Api.getBytes('accounting/summary.$fmt${_period(from, to, office: office)}');

  /// {items, total, byKind}
  static Future<Map<String, dynamic>> accounts({String? office}) async {
    final body = await Api.get('accounting/accounts${_q({'office': office})}');
    return Map<String, dynamic>.from(body as Map);
  }

  /// Akaunti kwa fomu (bila salio) - kwa mwenye ruhusa ya matumizi.
  static Future<List<FinAccount>> options() => Api.list(Api.get('accounting/accounts/options'), FinAccount.fromJson);

  static Future<void> saveAccount({
    String? id,
    required String name,
    required String kind,
    String? accountNo,
    String currency = 'TZS',
    String? officeId,
    double openingBalance = 0,
    DateTime? openingDate,
  }) {
    final body = {
      'name': name.trim(),
      'kind': kind,
      'accountNo': accountNo?.trim(),
      'currencyType': currency,
      'office_id': officeId,
      'openingBalance': openingBalance,
      'openingDate': openingDate == null ? null : _day(openingDate),
    };
    return id == null ? Api.post('accounting/accounts', body) : Api.put('accounting/accounts/$id', body);
  }

  static Future<void> deleteAccount(String id) => Api.delete('accounting/accounts/$id');

  static Future<Map<String, dynamic>> statement(String id, {DateTime? from, DateTime? to}) async {
    final body = await Api.get('accounting/accounts/$id/statement${_period(from, to)}');
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Uint8List> statementExcel(String id, {DateTime? from, DateTime? to}) =>
      Api.getBytes('accounting/accounts/$id/statement.xlsx${_period(from, to)}');

  static Future<List<AccCategory>> categories({String? kind}) =>
      Api.list(Api.get('accounting/categories${_q({'kind': kind})}'), AccCategory.fromJson);

  static Future<void> saveCategory({String? id, required String name, required String kind, String? description}) {
    final body = {'name': name.trim(), 'kind': kind, 'description': description?.trim()};
    return id == null ? Api.post('accounting/categories', body) : Api.put('accounting/categories/$id', body);
  }

  static Future<void> deleteCategory(String id) => Api.delete('accounting/categories/$id');

  static Future<List<OtherIncome>> incomes({DateTime? from, DateTime? to, String? officeId}) => Api.list(
        Api.post('accounting/incomes/search', {
          if (from != null) 'startDate': _day(from),
          if (to != null) 'endDate': _day(to),
          if (officeId != null) 'office_id': officeId,
        }),
        OtherIncome.fromJson,
      );

  static Future<void> saveIncome({
    String? id,
    required String details,
    required double amount,
    String currency = 'TZS',
    String? categoryId,
    String? accountId,
    String? officeId,
  }) {
    final body = {
      'details': details.trim(),
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'institute_id': accountId,
      'office_id': officeId,
    };
    return id == null ? Api.post('accounting/incomes', body) : Api.put('accounting/incomes/$id', body);
  }

  static Future<void> deleteIncome(String id) => Api.delete('accounting/incomes/$id');

  static Future<List<AccTransfer>> transfers({DateTime? from, DateTime? to}) =>
      Api.list(Api.get('accounting/transfers${_period(from, to)}'), AccTransfer.fromJson);

  /// [amount] kwa sarafu ya akaunti inayotoa; [toAmount] kilichopokelewa (kama sarafu tofauti).
  static Future<void> transfer({required String fromId, required String toId, required double amount, double? toAmount, String? note}) =>
      Api.post('accounting/transfers',
          {'from_id': fromId, 'to_id': toId, 'amount': amount, if (toAmount != null) 'toAmount': toAmount, 'note': note?.trim()});

  /// Madeni yote tunayodaiwa (gharama za mabox + matumizi).
  static Future<({List<Payable> items, double total, List<Map<String, dynamic>> bySupplier})> payables() async {
    final body = Map<String, dynamic>.from(await Api.get('accounting/payables') as Map);
    final g = body['bySupplier'];
    return (
      items: J.list(body['items'], Payable.fromJson),
      total: J.dbl(body['total']),
      bySupplier: g is List ? [for (final x in g.whereType<Map>()) Map<String, dynamic>.from(x)] : <Map<String, dynamic>>[],
    );
  }

  static Future<Map<String, dynamic>> balanceSheet() async =>
      Map<String, dynamic>.from(await Api.get('accounting/balance-sheet') as Map);

  static Future<({List<EquityEntry> items, double capital, double drawings})> equity() async {
    final body = Map<String, dynamic>.from(await Api.get('accounting/equity') as Map);
    return (items: J.list(body['items'], EquityEntry.fromJson), capital: J.dbl(body['capital']), drawings: J.dbl(body['drawings']));
  }

  static Future<void> saveEquity({required String kind, required double amount, String currency = 'TZS', String? accountId, String? owner, String? details}) =>
      Api.post('accounting/equity', {
        'kind': kind,
        'amount': amount,
        'currency': currency,
        'institute_id': accountId,
        'owner': owner?.trim(),
        'details': details?.trim(),
      });

  static Future<void> deleteEquity(String id) => Api.delete('accounting/equity/$id');

  /// Miezi iliyofungwa: [{month, note, lockedBy, created_at}]
  static Future<List<Map<String, dynamic>>> locks() async {
    final body = await Api.get('accounting/locks');
    return body is List ? [for (final x in body.whereType<Map>()) Map<String, dynamic>.from(x)] : <Map<String, dynamic>>[];
  }

  static Future<void> lockMonth(String month, {String? note}) => Api.post('accounting/locks', {'month': month, 'note': note});

  static Future<void> unlockMonth(String month) => Api.delete('accounting/locks/$month');

  static Future<void> deleteTransfer(String id) => Api.delete('accounting/transfers/$id');
}

class SmsRepo {
  SmsRepo._();

  /// [sent] null = zote (historia: zinazosubiri na zilizotumwa).
  static Future<List<SmsMessage>> list({SmsKind? kind, bool? sent = false, String? delivery, int? days, int? limit}) =>
      Api.list(
        Api.post('sms', {
          if (kind != null) 'smsFor': kind.code,
          'isReceived': false,
          'isSMSSend': sent,
          if (delivery != null) 'deliveryStatus': delivery,
          if (days != null) 'days': days,
          if (limit != null) 'limit': limit,
        }),
        SmsMessage.fromJson,
      );

  static Future<void> send(String id, {String? text}) =>
      Api.post('sms/send', {'id': id, if (text != null && text.trim().isNotEmpty) 'text': text.trim()});

  static Future<void> delete(String id) => Api.delete('sms/$id');

  /// Kutuma tena ujumbe uliokwisha tumwa: nakala mpya (wa awali unabaki kwenye historia).
  static Future<void> resend(String id, {String? text, String? msisdn}) => Api.post('sms/resend', {
        'id': id,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (msisdn != null && msisdn.trim().isNotEmpty) 'msisdn': msisdn.trim(),
      });

  /// Salio la SMS: {balance, source (GATEWAY/ESTIMATE/null), estimated, used, usedThisMonth, low, lowAt, history}.
  static Future<Map<String, dynamic>> balance() async =>
      J.map(await Api.get('sms/balance')) ?? const <String, dynamic>{};

  /// Kurekodi SMS zilizonunuliwa (ADD) au salio halisi la sasa (SET).
  static Future<Map<String, dynamic>> recordBalance({required String kind, required int amount, String? note}) async =>
      J.map(await Api.post('sms/balance', {
        'kind': kind,
        'amount': amount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      })) ??
      const <String, dynamic>{};

  /// Hali ya kufika kwa ujumbe wa siku 30: {byChannel: {SMS: {DELIVERED: n, FAILED: n, ...}}}.
  static Future<Map<String, dynamic>> deliverySummary() async =>
      J.map(await Api.get('sms/delivery-summary')) ?? const <String, dynamic>{};

  /// Ujumbe wa ankara (kila bidhaa kwa mstari wake, jumla, kilicholipwa na deni) kabla ya kutuma.
  static Future<Map<String, dynamic>> invoicePreview(String invoiceId) async =>
      J.map(await Api.get('sms/invoice/$invoiceId/preview')) ?? const <String, dynamic>{};

  /// Kutuma SMS ya ankara; [text] tupu = ujumbe wa bidhaa za ankara. Inarudisha idadi ya ujumbe.
  static Future<int> sendInvoice(
    String invoiceId, {
    String? text,
    bool toCustomer = true,
    bool toReceiver = false,
    String channel = 'SMS',
  }) async {
    final body = await Api.post('sms/invoice', {
      'invoiceId': invoiceId,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'toCustomer': toCustomer,
      'toReceiver': toReceiver,
      'channel': channel,
    });
    return body is Map ? J.integer(body['messages']) : 0;
  }

  static Map<String, dynamic> _broadcast({
    required Audience audience,
    required String text,
    List<String> customerIds = const [],
    String? customerId,
    String? phone,
    String? name,
    String channel = 'SMS',
    bool sendNow = true,
  }) =>
      {
        'audience': audience.code,
        'text': text.trim(),
        'customerIds': customerIds,
        if (customerId != null) 'customerId': customerId,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'channel': channel,
        'sendNow': sendNow,
      };

  /// Walengwa wangapi na mfano wa ujumbe (kabla ya kutuma).
  static Future<BroadcastPreview> broadcastPreview({
    required Audience audience,
    required String text,
    List<String> customerIds = const [],
    String? customerId,
    String? phone,
    String? name,
  }) =>
      Api.one(
        Api.post('sms/broadcast/preview', _broadcast(
          audience: audience, text: text, customerIds: customerIds, customerId: customerId, phone: phone, name: name)),
        BroadcastPreview.fromJson,
      );

  /// Ujumbe kwa mteja mmoja, waliochaguliwa au wote. Inarudisha idadi ya walengwa.
  static Future<int> broadcast({
    required Audience audience,
    required String text,
    List<String> customerIds = const [],
    String? customerId,
    String? phone,
    String? name,
    String channel = 'SMS',
    bool sendNow = true,
  }) async {
    final body = await Api.post('sms/broadcast', _broadcast(
        audience: audience,
        text: text,
        customerIds: customerIds,
        customerId: customerId,
        phone: phone,
        name: name,
        channel: channel,
        sendNow: sendNow));
    return body is Map ? J.integer(body['recipients']) : 0;
  }
}

/// Mizigo iliyokaa stoo zaidi ya siku za bure.
class StorageRepo {
  StorageRepo._();

  static Future<OverdueSummary> overdue() => Api.one(Api.get('store/overdue'), OverdueSummary.fromJson);

  /// Kumkumbusha mteja. [invoiceIds] tupu = wote waliochelewa. Inarudisha idadi ya ankara.
  static Future<int> remind({List<String> invoiceIds = const [], String channel = 'SMS', String? text}) async {
    final body = await Api.post('store/overdue/remind', {
      'invoiceIds': invoiceIds,
      'channel': channel,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
    });
    return body is Map ? J.integer(body['invoices']) : 0;
  }
}

/// Aina za ripoti za PDF (zote zinatengenezwa na server kwa reportlab).
enum ReportKind { range, debt, product, income, expenditure, summary, customers, boxes, storage, handovers, statement }

class ReportRepo {
  ReportRepo._();

  static String _path(ReportKind kind) => switch (kind) {
        ReportKind.range => 'report/range',
        ReportKind.debt => 'report/debt',
        ReportKind.product => 'report/product',
        ReportKind.income => 'report/financial-income',
        ReportKind.expenditure => 'report/expenditure',
        _ => 'report/pdf/${kind.name}',
      };

  static Future<Uint8List> pdf(ReportKind kind,
      {DateTime? from, DateTime? to, String? status, String? officeId, String? customerId, String? carrier}) {
    return Api.postBytes(_path(kind), {
      if (from != null) 'startDate': ExpenseRepo._day(from),
      if (to != null) 'endDate': ExpenseRepo._day(to),
      if (status != null) 'status': status,
      if (officeId != null) 'office': officeId,
      if (customerId != null) 'customerId': customerId,
      if (carrier != null) 'carrier': carrier,
    });
  }

  /// Muhtasari wa biashara kwa kipindi (JSON kwa chati).
  static Future<Map<String, dynamic>> summary({DateTime? from, DateTime? to}) async {
    final body = await Api.get('report/summary${_rangeQuery(from, to)}');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  /// Wateja bora kwa kipindi.
  static Future<Map<String, dynamic>> topCustomers({DateTime? from, DateTime? to}) async {
    final body = await Api.get('report/top-customers${_rangeQuery(from, to)}');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}

class UserRepo {
  UserRepo._();

  static Future<List<AppUser>> all() => Api.list(Api.get('user/all'), AppUser.fromJson);

  /// Kumtoa mtumiaji kwenye vifaa vyote (mf. simu imepotea).
  static Future<void> logoutEverywhere(String userId) => Api.post('user/$userId/logout-all');

  static Future<void> create({
    required String firstName,
    required String lastName,
    required String phone,
    required String username,
    required String password,
    String? officeId,
    bool? allOffices,
    String? roleId,
  }) =>
      Api.post('user', {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phone.trim(),
        'username': username.trim(),
        'password': password,
        if (officeId != null) 'office_id': officeId,
        if (allOffices != null) 'allOffices': allOffices,
        if (roleId != null) 'role_id': roleId,
      });

  static Future<void> update({
    required String id,
    required String firstName,
    required String lastName,
    required String phone,
    String? officeId,
    bool? allOffices,
  }) =>
      Api.put('user/update', {
        'id': id,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phone.trim(),
        if (officeId != null) 'office_id': officeId,
        if (allOffices != null) 'allOffices': allOffices,
      });

  static Future<void> changePassword(String id, String password) =>
      Api.put('user/change-password', {'id': id, 'password': password});

  static Future<void> toggleBlock(String id) => Api.put('user/block', {'id': id});

  static Future<void> delete(String id) => Api.delete('user/$id');

  static Future<List<Permission>> permissions(String userId) =>
      Api.list(Api.get('permission/$userId'), Permission.fromJson);

  static Future<List<dynamic>> myPermissionsJson() async {
    final body = await Api.get('permission/me');
    return body is List ? body : const [];
  }

  static Future<Permission> savePermission(Permission p) =>
      Api.one(Api.put('permission/change', p.toJson()), Permission.fromJson);

  /// Kuwasha / kuzima uthibitisho wa hatua mbili (code ya SMS) kwa mtumiaji.
  static Future<void> setTwoFactor(String id, bool enabled) =>
      Api.put('user/two-factor', {'id': id, 'enabled': enabled});
}

class BackupRepo {
  BackupRepo._();

  static Future<BackupOverview> overview() => Api.one(Api.get('backup'), BackupOverview.fromJson);

  static Future<BackupItem> create() => Api.one(Api.post('backup'), BackupItem.fromJson);

  static Future<Uint8List> download(String name) => Api.getBytes('backup/$name/download');

  static Future<void> delete(String name) => Api.delete('backup/$name');
}

class AuditRepo {
  AuditRepo._();

  static Future<AuditResult> search({
    String? userId,
    String? module,
    String? action,
    bool? failed,
    String? client,
    String? query,
    String? startDate,
    String? endDate,
    int offset = 0,
    int limit = 50,
  }) =>
      Api.one(
        Api.post('audit/search', {
          if (client != null) 'client': client,
          if (userId != null) 'userId': userId,
          if (module != null) 'module': module,
          if (action != null) 'action': action,
          if (failed != null) 'failed': failed,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          'offset': offset,
          'limit': limit,
        }),
        AuditResult.fromJson,
      );

  static Future<List<String>> modules() async {
    final body = await Api.get('audit/modules');
    return body is List ? body.map((e) => e.toString()).toList() : <String>[];
  }
}


String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _rangeQuery(DateTime? from, DateTime? to) {
  final parts = [if (from != null) 'startDate=${_day(from)}', if (to != null) 'endDate=${_day(to)}'];
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

/// Gharama za kusafirisha mabox na faida.
class ShipmentRepo {
  ShipmentRepo._();

  static Future<List<BoxCost>> costs(String boxId) => Api.list(Api.get('shipment/$boxId/costs'), BoxCost.fromJson);

  static Future<BoxCost> addCost(
    String boxId, {
    required String category,
    required double amount,
    String currency = 'TZS',
    String? note,
    String payStatus = 'PAID',
    double? paidAmount,
    String? supplier,
    String? accountId,
  }) =>
      Api.one(
        Api.post('shipment/$boxId/costs', {
          'category': category,
          'amount': amount,
          'currency': currency,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'payStatus': payStatus,
          if (payStatus == 'PARTIAL') 'paidAmount': paidAmount,
          if (supplier != null && supplier.trim().isNotEmpty) 'supplier': supplier.trim(),
          'institute_id': accountId,
        }),
        BoxCost.fromJson,
      );

  /// Gharama zote za mabox kwa kipindi ([mine] = nilizojaza mimi): {items, total, paid, owed, boxes, byCategory}
  static Future<({List<BoxCost> items, double total, double paid, double owed, int boxes})> allCosts({
    DateTime? from,
    DateTime? to,
    String? payStatus,
    String? category,
    bool mine = false,
  }) async {
    final q = [
      if (from != null) 'startDate=${_day(from)}',
      if (to != null) 'endDate=${_day(to)}',
      if (payStatus != null) 'payStatus=$payStatus',
      if (category != null) 'category=$category',
      if (mine) 'mine=true',
    ];
    final body = Map<String, dynamic>.from(await Api.get('shipment/costs${q.isEmpty ? '' : '?${q.join('&')}'}') as Map);
    return (
      items: J.list(body['items'], BoxCost.fromJson),
      total: J.dbl(body['total']),
      paid: J.dbl(body['paid']),
      owed: J.dbl(body['owed']),
      boxes: J.integer(body['boxes']),
    );
  }

  /// Kulipa deni la gharama (lote au sehemu).
  static Future<BoxCost> payCost(String costId, {required double amount, String currency = 'TZS', String? accountId, String? note}) =>
      Api.one(
        Api.post('shipment/costs/$costId/pay', {
          'amount': amount,
          'currency': currency,
          'institute_id': accountId,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
        BoxCost.fromJson,
      );

  /// Madeni ya gharama tunayodaiwa: {items, total, bySupplier}
  static Future<({List<BoxCost> items, double total, List<Map<String, dynamic>> bySupplier})> payables({bool all = false}) async {
    final body = Map<String, dynamic>.from(await Api.get(all ? 'shipment/payables?all=true' : 'shipment/payables') as Map);
    final groups = body['bySupplier'];
    return (
      items: J.list(body['items'], BoxCost.fromJson),
      total: J.dbl(body['total']),
      bySupplier: groups is List ? [for (final g in groups.whereType<Map>()) Map<String, dynamic>.from(g)] : <Map<String, dynamic>>[],
    );
  }

  static Future<void> deleteCost(String costId) => Api.delete('shipment/costs/$costId');

  static Future<BoxProfit> profit(String boxId) => Api.one(Api.get('shipment/$boxId/profit'), BoxProfit.fromJson);

  static Future<ProfitReport> report({DateTime? from, DateTime? to}) =>
      Api.one(Api.get('shipment/profit-report${_rangeQuery(from, to)}'), ProfitReport.fromJson);
}

/// Ripoti za data: madeni kwa umri na Excel.
class AnalyticsRepo {
  AnalyticsRepo._();

  static Future<AgingReport> aging() => Api.one(Api.get('report/aging'), AgingReport.fromJson);

  /// Mapato ya kipindi: jumla, usafirishaji na stoo.
  static Future<IncomeBreakdown> income({DateTime? from, DateTime? to}) =>
      Api.one(Api.get('report/income${_rangeQuery(from, to)}'), IncomeBreakdown.fromJson);

  /// kind: invoices, payments, expenses, aging, profit, customers, storage
  static Future<Uint8List> excel(String kind, {DateTime? from, DateTime? to}) =>
      Api.getBytes('report/export/$kind${_rangeQuery(from, to)}');

  /// Kuendesha vikumbusho vya SMS sasa hivi.
  static Future<Map<String, int>> runReminders() async {
    final body = await Api.post('sms/reminders/run');
    if (body is! Map) return const {};
    return body.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
  }
}


/// Madai ya mzigo ulioharibika / kupotea.
class ClaimRepo {
  ClaimRepo._();

  static Future<List<CargoClaim>> search({String? status, String? invoiceId}) => Api.list(
        Api.post('claim/search', {
          if (status != null) 'status': status,
          if (invoiceId != null) 'invoiceId': invoiceId,
        }),
        CargoClaim.fromJson,
      );

  static Future<CargoClaim> create({
    required String invoiceId,
    String? productId,
    required String type,
    double? cartons,
    required String description,
    Uint8List? photo,
    String? photoName,
  }) =>
      Api.one(
        Api.multipart(
          'claim',
          fields: {
            'stringValue': jsonEncode({
              'invoiceId': invoiceId,
              if (productId != null) 'productId': productId,
              'type': type,
              if (cartons != null && cartons > 0) 'cartons': cartons,
              'description': description.trim(),
            }),
          },
          files: [if (photo != null) UploadFile('photo', photo, photoName ?? 'photo.jpg')],
        ),
        CargoClaim.fromJson,
      );

  static Future<CargoClaim> resolve(
    String id, {
    required String status,
    double compensation = 0,
    String settlement = 'NONE',
    String? instituteId,
    required String resolution,
  }) =>
      Api.one(
        Api.put('claim/$id/resolve', {
          'status': status,
          'compensation': compensation,
          'settlement': settlement,
          if (instituteId != null) 'instituteId': instituteId,
          'resolution': resolution.trim(),
        }),
        CargoClaim.fromJson,
      );

  static Future<Uint8List> photo(String id) => Api.getBytes('claim/$id/photo');

  static Future<Map<String, int>> counts() async {
    final body = await Api.get('claim/counts');
    if (body is! Map) return const {};
    return body.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
  }
}


class NotificationRepo {
  NotificationRepo._();

  static Future<NoticeList> list({bool unreadOnly = false, int limit = 30}) =>
      Api.one(Api.get('notification', query: {'unreadOnly': '$unreadOnly', 'limit': '$limit'}), NoticeList.fromJson);

  static Future<void> markRead({List<String> ids = const [], bool all = false}) =>
      Api.put('notification/read', {'ids': ids, 'all': all});
}

/// Dashibodi ya shughuli za mtumiaji (zake; admin: za yeyote).
class ActivityRepo {
  ActivityRepo._();

  static Future<Map<String, dynamic>> summary({String? userId, String? start, String? end}) async {
    final body = await Api.get('activity/summary', query: {
      if (userId != null) 'userId': userId,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}

/// Picha ya mzigo kwa simu kupitia QR ya code ya ofisi.
class PhotoRepo {
  PhotoRepo._();

  static String _c(String code) => Uri.encodeComponent(code.trim());

  /// {exists, productId, path, staged, stagedAt}
  static Future<Map<String, dynamic>> status(String code) async {
    final body = await Api.get('product/photo/${_c(code)}/status');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<Uint8List> staged(String code) => Api.getBytes('product/photo/${_c(code)}/staged');

  static Future<void> discard(String code) => Api.delete('product/photo/${_c(code)}/staged');

  /// {attached, staged, description, invoiceNumber}
  static Future<Map<String, dynamic>> upload(String code, Uint8List bytes, String name) async {
    final body = await Api.multipart('product/photo/${_c(code)}', fields: const {}, fileBytes: bytes, fileName: name);
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}

/// Taarifa za pop-up (wadaiwa, mizigo stoo muda mrefu, mabox yaliyo wazi, ...).
class PopupRepo {
  PopupRepo._();

  static Future<List<PopupGroup>> due() => Api.list(Api.get('popup/due'), PopupGroup.fromJson);

  static Future<List<AutoSmsRule>> autoSms() => Api.list(Api.get('sms/auto-rules'), AutoSmsRule.fromJson);

  static Future<List<AutoSmsRule>> saveAutoSms(AutoSmsRule r) =>
      Api.list(Api.put('sms/auto-rules', [r.toJson()]), AutoSmsRule.fromJson);

  static Future<List<PopupRule>> rules() => Api.list(Api.get('popup/rules'), PopupRule.fromJson);

  static Future<List<PopupRule>> saveRule(PopupRule r) => Api.list(
        Api.put('popup/rules', [
          {'kind': r.kind, 'enabled': r.enabled, 'afterDays': r.afterDays, 'everyMinutes': r.everyMinutes},
        ]),
        PopupRule.fromJson,
      );
}

class HealthRepo {
  HealthRepo._();

  static Future<Map<String, dynamic>> details() async {
    final body = await Api.get('health/details');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<void> testAlert() => Api.post('health/test-alert');
}

class ImportRepo {
  ImportRepo._();

  static Future<Uint8List> template(String kind) => Api.getBytes('import/template/$kind');

  static Future<ImportResult> run(String kind, Uint8List bytes, String fileName, {required bool dryRun}) => Api.one(
        Api.multipart(
          'import/$kind?dryRun=$dryRun',
          fields: const {},
          files: [UploadFile('file', bytes, fileName)],
        ),
        ImportResult.fromJson,
      );
}

class WhatsAppRepo {
  WhatsAppRepo._();

  static bool? _configured;

  /// Kama server imewekewa WhatsApp (inakumbukwa baada ya kuuliza mara moja).
  static Future<bool> configured() async {
    if (_configured != null) return _configured!;
    try {
      final body = await Api.get('whatsapp/status');
      _configured = body is Map && body['configured'] == true;
    } catch (_) {
      return false; // mf. hana ruhusa ya WHATSAPP: tusikumbuke, mtumiaji mwingine anaweza kuwa nayo
    }
    return _configured!;
  }

  /// Ujumbe (na picha, si lazima) kwa mteja wa ankara au kwa namba [phone].
  static Future<void> sendMessage({
    required String text,
    String? invoiceId,
    String? phone,
    Uint8List? image,
    String? imageName,
  }) =>
      Api.multipart(
        'whatsapp/message',
        fields: {
          'text': text.trim(),
          if (invoiceId != null) 'invoiceId': invoiceId,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
        files: [if (image != null) UploadFile('image', image, imageName ?? 'picha.jpg')],
      );

  /// Picha za mizigo ya ankara (moja kwa kila mzigo wenye picha). Inarudisha idadi iliyotumwa.
  static Future<int> sendProductPhotos(String invoiceId) async {
    final body = await Api.post('whatsapp/product-photos', {'invoiceId': invoiceId});
    return body is Map && body['sent'] is num ? (body['sent'] as num).toInt() : 0;
  }

  /// kind: INVOICE, RECEIPT, HANDOVER
  static Future<void> sendDocument(String invoiceId, {String kind = 'INVOICE', String? paymentId, String? phone}) =>
      Api.post('whatsapp/document', {
        'invoiceId': invoiceId,
        'kind': kind,
        if (paymentId != null) 'paymentId': paymentId,
        if (phone != null) 'phone': phone,
      });
}

/// Kufunga hesabu ya siku (cash-up).
class CashUpRepo {
  CashUpRepo._();

  static Future<CashExpected> expected(DateTime day) =>
      Api.one(Api.get('cashup/expected', query: {'day': ExpenseRepo._day(day)}), CashExpected.fromJson);

  static Future<CashUp> close(DateTime day, List<Map<String, dynamic>> lines, {String? note}) => Api.one(
        Api.post('cashup', {
          'day': ExpenseRepo._day(day),
          'lines': lines,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
        CashUp.fromJson,
      );

  static Future<List<CashUp>> history({DateTime? from, DateTime? to}) async {
    final body = await Api.get('cashup${_rangeQuery(from, to)}');
    return body is Map ? J.list(body['items'], CashUp.fromJson) : <CashUp>[];
  }

  static Future<Uint8List> pdf(String id) => Api.getBytes('cashup/$id/pdf');

  static Future<void> reopen(String id) => Api.delete('cashup/$id');
}


/// Makadirio ya bei (quotation).
class QuotationRepo {
  QuotationRepo._();

  static Future<({List<Quotation> items, int total, Map<String, int> counts})> search({
    String? query,
    String? status,
    String? customerId,
    int offset = 0,
    int limit = 50,
  }) async {
    final body = J.map(await Api.post('quotation/search', {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (status != null) 'status': status,
          if (customerId != null) 'customerId': customerId,
          'offset': offset,
          'limit': limit,
        })) ??
        const <String, dynamic>{};
    final counts = J.map(body['counts']) ?? const <String, dynamic>{};
    return (
      items: J.list(body['items'], Quotation.fromJson),
      total: J.integer(body['total']),
      counts: {for (final e in counts.entries) e.key: J.integer(e.value)},
    );
  }

  static Future<Quotation> get(String id) async => Quotation.fromJson(J.map(await Api.get('quotation/$id')) ?? {});

  /// Kuhesabu bei bila kuhifadhi: inarudisha bidhaa zenye unit/rate/amount na jumla.
  static Future<({List<QuotationItem> items, double total})> calculate(List<QuotationItem> items) async {
    final body = J.map(await Api.post('quotation/calculate', {'items': [for (final i in items) i.toJson()]})) ??
        const <String, dynamic>{};
    return (items: J.list(body['items'], QuotationItem.fromJson), total: J.dbl(body['total']));
  }

  static Future<Quotation> save({
    String? id,
    String? customerId,
    required String customerName,
    String? phoneNumber,
    int validDays = 14,
    String? note,
    required List<QuotationItem> items,
  }) async {
    final payload = {
      if (customerId != null) 'customerId': customerId,
      'customerName': customerName.trim(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) 'phoneNumber': phoneNumber,
      'validDays': validDays,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'items': [for (final i in items) i.toJson()],
    };
    final body = id == null ? await Api.post('quotation', payload) : await Api.put('quotation/$id', payload);
    return Quotation.fromJson(J.map(body) ?? {});
  }

  static Future<Quotation> setStatus(String id, String status) async =>
      Quotation.fromJson(J.map(await Api.put('quotation/$id/status', {'status': status})) ?? {});

  static Future<void> delete(String id) => Api.delete('quotation/$id');

  static Future<Uint8List> pdf(String id) => Api.getBytes('quotation/$id/pdf');

  static Future<String> message(String id) async => J.str((J.map(await Api.get('quotation/$id/message')) ?? {})['text']);

  static Future<int> sendSms(String id, {String channel = 'SMS', String? text}) async {
    final body = await Api.post('quotation/$id/sms', {
      'channel': channel,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
    });
    return body is Map ? J.integer(body['messages']) : 0;
  }

  /// Inarudisha id ya ankara mpya.
  static Future<String> convert(String id) async {
    final body = J.map(await Api.post('quotation/$id/convert', {})) ?? const <String, dynamic>{};
    return J.str(body['invoiceId']);
  }
}

/// Inbox ya WhatsApp: majibu na ujumbe kutoka kwa wateja.
class WhatsappInboxRepo {
  WhatsappInboxRepo._();

  static List<Map<String, dynamic>> _maps(dynamic body) =>
      body is List ? body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  static Future<List<Map<String, dynamic>>> conversations({String? q}) async =>
      _maps(await Api.get('whatsapp/inbox', query: {if (q != null && q.trim().isNotEmpty) 'q': q.trim()}));

  /// {messages, conversations} - ambazo hazijasomwa.
  static Future<Map<String, dynamic>> unread() async {
    final body = await Api.get('whatsapp/inbox/unread');
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> thread(String phone) async {
    final body = await Api.get('whatsapp/inbox/thread', query: {'phone': phone});
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> reply(String phone, String text) async {
    final body = await Api.post('whatsapp/inbox/reply', {'phone': phone, 'text': text});
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static Future<void> markRead(String phone) => Api.post('whatsapp/inbox/read', {'phone': phone});

  static Future<Uint8List> media(String messageId) => Api.getBytes('whatsapp/inbox/media/$messageId');
}

/// Malipo ya simu (AzamPay): akaunti ya kampuni, kulipisha ankara, na kulipia subscription.
class OnlinePayRepo {
  OnlinePayRepo._();

  static Map<String, dynamic> _map(dynamic body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static Future<Map<String, dynamic>> settings() async => _map(await Api.get('online-pay/settings'));

  static Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> data) async =>
      _map(await Api.put('online-pay/settings', data));

  static Future<Map<String, dynamic>> clearSettings() async => _map(await Api.delete('online-pay/settings'));

  /// Ombi la PIN kwenye simu ya mteja. [amount] null = deni lote; [phone] null = simu ya mteja wa ankara.
  static Future<Map<String, dynamic>> payInvoice(String debtId, {String? phone, String? provider, double? amount}) async =>
      _map(await Api.post('online-pay/invoice', {
        'debtId': debtId,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (provider != null) 'provider': provider,
        if (amount != null) 'amount': amount,
      }));

  static Future<Map<String, dynamic>> status(String id) async => _map(await Api.get('online-pay/$id'));

  static Future<List<Map<String, dynamic>>> list({String? purpose}) async {
    final body = await Api.get('online-pay', query: {if (purpose != null) 'purpose': purpose});
    return body is List ? body.whereType<Map>().map(Map<String, dynamic>.from).toList() : const [];
  }

  /// Subscription kwa simu: {enabled, providers}.
  static Future<Map<String, dynamic>> subscriptionInfo() async =>
      _map(await Api.get('company/subscription/pay-online'));

  static Future<Map<String, dynamic>> paySubscription(String planId, int periods, String phone, String provider,
          {String? coupon, String? startMode}) async =>
      _map(await Api.post('company/subscription/pay-online', {
        'plan_id': planId,
        'periods': periods,
        'phone': phone.trim(),
        'provider': provider,
        if (coupon != null && coupon.trim().isNotEmpty) 'couponCode': coupon.trim(),
        if (startMode != null) 'startMode': startMode,
      }));

  static Future<Map<String, dynamic>> subscriptionStatus(String id) async =>
      _map(await Api.get('company/subscription/pay-online/$id'));
}

/// Msaada (tiketi kwa mtoa huduma) na vifaa vya mtumiaji.
class SupportRepo {
  SupportRepo._();

  static List<Map<String, dynamic>> _list(dynamic body) =>
      body is List ? body.whereType<Map>().map(Map<String, dynamic>.from).toList() : const [];

  static Map<String, dynamic> _map(dynamic body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static Future<List<Map<String, dynamic>>> mine() async => _list(await Api.get('support'));

  static Future<int> unread() async => J.integer(_map(await Api.get('support/unread'))['unread']);

  static Future<Map<String, dynamic>> create(
          {required String subject, required String text, String category = 'TECH', bool high = false}) async =>
      _map(await Api.post('support',
          {'subject': subject, 'text': text, 'category': category, 'priority': high ? 'HIGH' : 'NORMAL'}));

  static Future<Map<String, dynamic>> ticket(String id) async => _map(await Api.get('support/$id'));

  static Future<Map<String, dynamic>> reply(String id, String text) async =>
      _map(await Api.post('support/$id/reply', {'text': text}));

  static Future<void> close(String id) => Api.put('support/$id/close');

  /// Vifaa ulivyoingia navyo karibuni: [{at, client, device, ip}].
  static Future<List<Map<String, dynamic>>> mySessions() async => _list(await Api.get('user/me/sessions'));

  /// Kutoka kwenye vifaa vingine: {access_token, refresh_token} mpya za kifaa hiki.
  static Future<Map<String, dynamic>> logoutOthers() async => _map(await Api.post('user/me/logout-others'));
}
