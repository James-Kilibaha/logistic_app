import 'package:flutter/material.dart';

import 'json.dart';

Color? _color(dynamic v) {
  final s = J.strOrNull(v)?.replaceFirst('#', '');
  if (s == null || s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

String colorHex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Taarifa za mfumo wenyewe (mtoa huduma).
class PlatformInfo {
  final String name;
  final String? domain;
  final String? supportPhone;
  final String? supportEmail;
  final bool signup;

  const PlatformInfo({required this.name, this.domain, this.supportPhone, this.supportEmail, this.signup = false});

  factory PlatformInfo.fromJson(Map<String, dynamic>? j) => PlatformInfo(
        name: J.str(j?['name'], 'Logistic'),
        domain: J.strOrNull(j?['domain']),
        supportPhone: J.strOrNull(j?['supportPhone']),
        supportEmail: J.strOrNull(j?['supportEmail']),
        signup: J.boolean(j?['signup']),
      );
}

/// Jina, logo na rangi za kampuni (kutoka GET /api/public/branding).
class Branding {
  final bool resolved;
  final String slug;
  final String name;
  final String? phone;
  final String? email;
  final String? origin;
  final String? logoUrl;
  final Color? primary;
  final Color? accent;
  final String? appUrl;
  final bool tracking;
  final bool active;

  /// PENDING (imejisajili - inasubiri kuthibitishwa) | ACTIVE | SUSPENDED | REJECTED
  final String status;
  final PlatformInfo platform;
  final Map<String, dynamic> raw;

  const Branding({
    required this.resolved,
    required this.slug,
    required this.name,
    this.phone,
    this.email,
    this.origin,
    this.logoUrl,
    this.primary,
    this.accent,
    this.appUrl,
    this.tracking = true,
    this.active = true,
    this.status = 'ACTIVE',
    required this.platform,
    this.raw = const {},
  });

  factory Branding.fromJson(Map<String, dynamic> j) {
    final platform = PlatformInfo.fromJson(J.map(j['platform']));
    return Branding(
      resolved: J.boolean(j['resolved']),
      slug: J.str(j['slug']),
      name: J.str(j['name'], platform.name),
      phone: J.strOrNull(j['phone']),
      email: J.strOrNull(j['email']),
      origin: J.strOrNull(j['origin']),
      logoUrl: J.strOrNull(j['logoUrl']),
      primary: _color(j['primaryColor']),
      accent: _color(j['accentColor']),
      appUrl: J.strOrNull(j['appUrl']),
      tracking: J.boolean(j['tracking'], true),
      active: J.boolean(j['active'], true),
      status: J.str(j['status'], 'ACTIVE'),
      platform: platform,
      raw: j,
    );
  }

  /// Kabla kampuni haijajulikana (app ya simu bila code ya kampuni).
  static const Branding none = Branding(resolved: false, slug: '', name: 'Logistic', platform: PlatformInfo(name: 'Logistic'));

  String get displayName => resolved ? name : platform.name;
}

/// Mpango wa subscription.
class Plan {
  final String id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int months;
  final int? maxUsers;
  final int? maxOffices;
  final int? maxInvoicesPerMonth;
  final List<String>? modules;

  const Plan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.months,
    this.maxUsers,
    this.maxOffices,
    this.maxInvoicesPerMonth,
    this.modules,
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: J.str(j['id']),
        code: J.str(j['code']),
        name: J.str(j['name']),
        description: J.strOrNull(j['description']),
        price: J.dbl(j['price']),
        currency: J.str(j['currency'], 'TZS'),
        months: J.integer(j['months'], 1),
        maxUsers: j['maxUsers'] == null ? null : J.integer(j['maxUsers']),
        maxOffices: j['maxOffices'] == null ? null : J.integer(j['maxOffices']),
        maxInvoicesPerMonth: j['maxInvoicesPerMonth'] == null ? null : J.integer(j['maxInvoicesPerMonth']),
        modules: j['modules'] is List ? (j['modules'] as List).map((e) => e.toString()).toList() : null,
      );

  @override
  bool operator ==(Object other) => other is Plan && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Hali ya subscription ya kampuni.
class SubscriptionState {
  /// TRIAL | ACTIVE | GRACE | EXPIRED | NONE
  final String status;
  final bool readOnly;
  final DateTime? endsAt;
  final DateTime? graceEndsAt;
  final int? daysLeft;
  final Plan? plan;

  /// Moduli za ziada zilizo kwenye mpango (WHATSAPP, QUOTE ...).
  final List<String> modules;

  /// Mpango mdogo uliolipiwa unaosubiri wa sasa uishe (null = hakuna).
  final String? upcomingPlan;
  final DateTime? upcomingStartsAt;

  const SubscriptionState({
    this.upcomingPlan,
    this.upcomingStartsAt,
    required this.status,
    required this.readOnly,
    this.endsAt,
    this.graceEndsAt,
    this.daysLeft,
    this.plan,
    this.modules = const [],
  });

  factory SubscriptionState.fromJson(Map<String, dynamic> j) => SubscriptionState(
        status: J.str(j['status'], 'NONE'),
        readOnly: J.boolean(j['readOnly']),
        endsAt: J.date(j['endsAt']),
        graceEndsAt: J.date(j['graceEndsAt']),
        daysLeft: j['daysLeft'] == null ? null : J.integer(j['daysLeft']),
        plan: J.map(j['plan']) == null ? null : Plan.fromJson(J.map(j['plan'])!),
        modules: j['modules'] is List ? (j['modules'] as List).map((e) => e.toString()).toList() : const [],
        upcomingPlan: J.strOrNull(J.map(j['upcoming'])?['planName']),
        upcomingStartsAt: J.date(J.map(j['upcoming'])?['startsAt']),
      );

  bool get isTrial => status == 'TRIAL';

  /// Banner ionyeshwe: majaribio/subscription inakaribia kuisha, neema, au imeisha.
  bool get needsAttention =>
      readOnly || status == 'GRACE' || ((status == 'TRIAL' || status == 'ACTIVE') && (daysLeft ?? 99) <= 7);
}

/// Matumizi ya kampuni dhidi ya mipaka ya mpango.
class CompanyUsage {
  final int users;
  final int offices;
  final int invoicesThisMonth;

  const CompanyUsage({this.users = 0, this.offices = 0, this.invoicesThisMonth = 0});

  factory CompanyUsage.fromJson(Map<String, dynamic>? j) => CompanyUsage(
        users: J.integer(j?['users']),
        offices: J.integer(j?['offices']),
        invoicesThisMonth: J.integer(j?['invoicesThisMonth']),
      );
}

/// Malipo ya subscription (kampuni -> mtoa huduma).
class SubscriptionPayment {
  final String id;
  final String planName;
  final int periods;
  final double amount;
  final String currency;
  final String? method;
  final String? reference;

  /// PENDING | CONFIRMED | REJECTED
  final String status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const SubscriptionPayment({
    required this.id,
    required this.planName,
    required this.periods,
    required this.amount,
    required this.currency,
    this.method,
    this.reference,
    required this.status,
    this.note,
    this.createdAt,
    this.reviewedAt,
  });

  factory SubscriptionPayment.fromJson(Map<String, dynamic> j) => SubscriptionPayment(
        id: J.str(j['id']),
        planName: J.str(J.map(j['plan'])?['name'], '-'),
        periods: J.integer(j['periods'], 1),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        method: J.strOrNull(j['method']),
        reference: J.strOrNull(j['reference']),
        status: J.str(j['status']),
        note: J.strOrNull(j['note']),
        createdAt: J.date(j['created_at']),
        reviewedAt: J.date(j['reviewedAt']),
      );
}

/// Kipindi kimoja cha subscription.
class SubscriptionPeriod {
  final String id;
  final String planName;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? note;

  const SubscriptionPeriod({
    required this.id,
    required this.planName,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.note,
  });

  factory SubscriptionPeriod.fromJson(Map<String, dynamic> j) => SubscriptionPeriod(
        id: J.str(j['id']),
        planName: J.str(J.map(j['plan'])?['name'], '-'),
        status: J.str(j['status']),
        startsAt: J.date(j['startsAt']),
        endsAt: J.date(j['endsAt']),
        note: J.strOrNull(j['note']),
      );
}

/// Ukurasa wa subscription: hali, matumizi, historia, malipo na mipango.
class SubscriptionOverview {
  final SubscriptionState state;
  final CompanyUsage usage;
  final List<SubscriptionPeriod> history;
  final List<SubscriptionPayment> payments;
  final List<Plan> plans;
  final String? payTo;
  final String? supportPhone;
  final String? supportEmail;

  const SubscriptionOverview({
    required this.state,
    required this.usage,
    required this.history,
    required this.payments,
    required this.plans,
    this.payTo,
    this.supportPhone,
    this.supportEmail,
  });

  factory SubscriptionOverview.fromJson(Map<String, dynamic> j) => SubscriptionOverview(
        state: SubscriptionState.fromJson(J.map(j['state']) ?? const {}),
        usage: CompanyUsage.fromJson(J.map(j['usage'])),
        history: J.list(j['history'], SubscriptionPeriod.fromJson),
        payments: J.list(j['payments'], SubscriptionPayment.fromJson),
        plans: J.list(j['plans'], Plan.fromJson),
        payTo: J.strOrNull(j['payTo']),
        supportPhone: J.strOrNull(J.map(j['support'])?['phone']),
        supportEmail: J.strOrNull(J.map(j['support'])?['email']),
      );
}

/// Ukurasa wa "Kampuni yetu": wasifu + mipangilio ya biashara.
class CompanyProfile {
  final String id;
  final String name;
  final String slug;
  final String? legalName;
  final String? phone;
  final String? email;
  final String? address;
  final String? country;
  final String? tin;
  final String? domain;
  final Color? primary;
  final Color? accent;
  final Branding branding;

  /// Thamani zilizowekwa na kampuni (null = inatumia ya kawaida).
  final Map<String, dynamic> settings;

  /// Thamani za kawaida za mfumo.
  final Map<String, dynamic> defaults;
  final bool ownSms;
  final bool platformSms;
  final SubscriptionState subscription;
  final CompanyUsage usage;

  const CompanyProfile({
    required this.id,
    required this.name,
    required this.slug,
    this.legalName,
    this.phone,
    this.email,
    this.address,
    this.country,
    this.tin,
    this.domain,
    this.primary,
    this.accent,
    required this.branding,
    required this.settings,
    required this.defaults,
    required this.ownSms,
    required this.platformSms,
    required this.subscription,
    required this.usage,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> j) {
    final c = J.map(j['company']) ?? const {};
    final s = J.map(j['settings']) ?? const {};
    return CompanyProfile(
      id: J.str(c['id']),
      name: J.str(c['name']),
      slug: J.str(c['slug']),
      legalName: J.strOrNull(c['legalName']),
      phone: J.strOrNull(c['phone']),
      email: J.strOrNull(c['email']),
      address: J.strOrNull(c['address']),
      country: J.strOrNull(c['country']),
      tin: J.strOrNull(c['tin']),
      domain: J.strOrNull(c['domain']),
      primary: _color(c['primaryColor']),
      accent: _color(c['accentColor']),
      branding: Branding.fromJson(J.map(j['branding']) ?? const {}),
      settings: J.map(s['values']) ?? const {},
      defaults: J.map(s['defaults']) ?? const {},
      ownSms: J.boolean(s['ownSms']),
      platformSms: J.boolean(s['platformSms']),
      subscription: SubscriptionState.fromJson(J.map(j['subscription']) ?? const {}),
      usage: CompanyUsage.fromJson(J.map(j['usage'])),
    );
  }
}
