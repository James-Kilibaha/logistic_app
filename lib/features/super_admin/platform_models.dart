import '../../data/models/company.dart';
import '../../data/models/json.dart';

/// Kampuni (mteja wako) kama inavyoonekana kwenye admin panel.
class PlatformCompany {
  final String id;
  final String name;
  final String slug;
  final String? legalName;
  final String? email;
  final String? phone;
  final String? address;
  final String? country;
  final String? tin;
  final String? domain;
  final String? primaryColor;
  final String? accentColor;
  final String? logoPath;

  /// ACTIVE | SUSPENDED
  final String status;
  final String? ownerName;
  final String? ownerPhone;
  final String? notes;
  final String? source;
  final String? signupPlanId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final SubscriptionState? subscription;

  /// Nafasi za ziada ulizoipa kampuni juu ya mpango wake.
  final int extraUsers;
  final int extraOffices;
  final int extraInvoicesPerMonth;

  const PlatformCompany({
    required this.id,
    required this.name,
    required this.slug,
    this.legalName,
    this.email,
    this.phone,
    this.address,
    this.country,
    this.tin,
    this.domain,
    this.primaryColor,
    this.accentColor,
    this.logoPath,
    required this.status,
    this.ownerName,
    this.ownerPhone,
    this.notes,
    this.source,
    this.signupPlanId,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.subscription,
    this.extraUsers = 0,
    this.extraOffices = 0,
    this.extraInvoicesPerMonth = 0,
  });

  bool get suspended => status == 'SUSPENDED';

  bool get isActive => status == 'ACTIVE';

  /// Imejisajili yenyewe na inasubiri uithibitishe (au uliikataa - unaweza kuithibitisha baadaye).
  bool get awaitingApproval => status == 'PENDING' || status == 'REJECTED';

  factory PlatformCompany.fromJson(Map<String, dynamic> j) => PlatformCompany(
        id: J.str(j['id']),
        name: J.str(j['name']),
        slug: J.str(j['slug']),
        legalName: J.strOrNull(j['legalName']),
        email: J.strOrNull(j['email']),
        phone: J.strOrNull(j['phone']),
        address: J.strOrNull(j['address']),
        country: J.strOrNull(j['country']),
        tin: J.strOrNull(j['tin']),
        domain: J.strOrNull(j['domain']),
        primaryColor: J.strOrNull(j['primaryColor']),
        accentColor: J.strOrNull(j['accentColor']),
        logoPath: J.strOrNull(j['logoPath']),
        status: J.str(j['status'], 'ACTIVE'),
        ownerName: J.strOrNull(j['ownerName']),
        ownerPhone: J.strOrNull(j['ownerPhone']),
        notes: J.strOrNull(j['notes']),
        source: J.strOrNull(j['source']),
        signupPlanId: J.strOrNull(j['signupPlanId']),
        approvedBy: J.strOrNull(j['approvedBy']),
        approvedAt: J.date(j['approvedAt']),
        createdAt: J.date(j['created_at']),
        subscription: J.map(j['subscription']) == null ? null : SubscriptionState.fromJson(J.map(j['subscription'])!),
        extraUsers: J.integer(j['extraUsers']),
        extraOffices: J.integer(j['extraOffices']),
        extraInvoicesPerMonth: J.integer(j['extraInvoicesPerMonth']),
      );

  /// Data ya kubadilisha kampuni (PUT /api/platform/companies).
  Map<String, dynamic> toUpdate() => {
        'id': id,
        'name': name,
        'slug': slug,
        'legalName': legalName,
        'email': email,
        'phone': phone,
        'address': address,
        'country': country,
        'tin': tin,
        'domain': domain,
        'primaryColor': primaryColor,
        'accentColor': accentColor,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'notes': notes,
      };
}

/// Mtumiaji wa kampuni (kwa kumrudishia nywila).
class TenantUser {
  final String id;
  final String username;
  final String name;
  final String? phone;
  final bool active;

  const TenantUser({required this.id, required this.username, required this.name, this.phone, this.active = true});

  factory TenantUser.fromJson(Map<String, dynamic> j) => TenantUser(
        id: J.str(j['id']),
        username: J.str(j['username']),
        name: J.str(j['name']),
        phone: J.strOrNull(j['phone']),
        active: J.boolean(j['active'], true),
      );
}

/// Taarifa kamili za kampuni moja.
class CompanyDetail {
  final PlatformCompany company;
  final SubscriptionState subscription;
  final CompanyUsage usage;
  final List<SubscriptionPeriod> history;
  final List<SubscriptionPayment> payments;
  final List<TenantUser> users;
  final String? appUrl;
  final String? logoUrl;

  /// Hali ya WhatsApp ya kampuni: {enabled, ok, displayPhone, verifiedName, quality, error}
  final Map<String, dynamic> whatsapp;

  const CompanyDetail({
    required this.company,
    required this.subscription,
    required this.usage,
    required this.history,
    required this.payments,
    required this.users,
    this.appUrl,
    this.logoUrl,
    this.whatsapp = const {},
  });

  factory CompanyDetail.fromJson(Map<String, dynamic> j) => CompanyDetail(
        company: PlatformCompany.fromJson(J.map(j['company']) ?? const {}),
        subscription: SubscriptionState.fromJson(J.map(j['subscription']) ?? const {}),
        usage: CompanyUsage.fromJson(J.map(j['usage'])),
        history: J.list(j['history'], SubscriptionPeriod.fromJson),
        payments: J.list(j['payments'], SubscriptionPayment.fromJson),
        users: J.list(j['users'], TenantUser.fromJson),
        appUrl: J.strOrNull(J.map(j['branding'])?['appUrl']),
        logoUrl: J.strOrNull(J.map(j['branding'])?['logoUrl']),
        whatsapp: J.map(j['whatsapp']) ?? const {},
      );
}

/// Malipo yaliyotumwa na kampuni (orodha ya admin panel - ina company_id).
class PlatformPayment {
  final SubscriptionPayment payment;
  final String companyId;
  final String companyName;
  final String companySlug;
  final String planId;

  /// Mpango mdogo: NOW = kampuni imekubali siku zilizobaki zifutwe (QUEUE = inasubiri wa sasa uishe).
  final String? startMode;

  const PlatformPayment({
    this.startMode,
    required this.payment,
    required this.companyId,
    required this.companyName,
    required this.companySlug,
    required this.planId,
  });

  factory PlatformPayment.fromJson(Map<String, dynamic> j) => PlatformPayment(
        payment: SubscriptionPayment.fromJson(j),
        companyId: J.str(j['company_id']),
        companyName: J.str(j['companyName'], '-'),
        companySlug: J.str(j['companySlug']),
        planId: J.str(j['plan_id']),
        startMode: J.strOrNull(j['startMode']),
      );
}

/// Msimamizi wa mfumo (wewe na wasaidizi wako).
class PlatformAdminUser {
  final String id;
  final String username;
  final String fullName;
  final String? phone;
  final String? email;
  final bool active;
  final DateTime? lastLoginAt;

  /// Uthibitisho wa hatua mbili (app ya Authenticator) umewashwa.
  final bool totpEnabled;

  /// OWNER | FINANCE | SUPPORT | VIEWER
  final String role;

  const PlatformAdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.phone,
    this.email,
    this.active = true,
    this.lastLoginAt,
    this.totpEnabled = false,
    this.role = 'OWNER',
  });

  factory PlatformAdminUser.fromJson(Map<String, dynamic> j) => PlatformAdminUser(
        id: J.str(j['id']),
        username: J.str(j['username']),
        fullName: J.str(j['fullName']),
        phone: J.strOrNull(j['phone']),
        email: J.strOrNull(j['email']),
        active: J.boolean(j['active'], true),
        lastLoginAt: J.date(j['lastLoginAt']),
        totpEnabled: J.boolean(j['totpEnabled']),
        role: J.str(j['role'], 'OWNER'),
      );
}
