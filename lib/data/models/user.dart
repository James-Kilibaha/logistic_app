import 'json.dart';
import 'settings.dart';

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String username;
  final int active;
  final String? officeId;

  /// `false` = anaona data ya ofisi yake tu.
  final bool allOffices;
  final String? roleId;

  /// Lazima aweke nywila yake mwenyewe kabla ya kutumia mfumo.
  final bool mustChangePassword;

  /// Uthibitisho wa hatua mbili (code ya SMS wakati wa kuingia).
  final bool twoFactor;
  final Office? office;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.username,
    this.active = 1,
    this.officeId,
    this.allOffices = true,
    this.roleId,
    this.mustChangePassword = false,
    this.twoFactor = false,
    this.office,
    this.createdAt,
  });

  /// Amefungiwa ofisi moja.
  bool get officeOnly => officeId != null && !allOffices;

  String get fullName => '$firstName $lastName'.trim();

  bool get isActive => active == 1;

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: J.str(j['id']),
        firstName: J.str(j['firstName']),
        lastName: J.str(j['lastName']),
        phoneNumber: J.str(j['phoneNumber']),
        username: J.str(j['username']),
        active: J.integer(j['active'], 1),
        officeId: J.strOrNull(j['office_id']),
        allOffices: J.boolean(j['allOffices'], true),
        roleId: J.strOrNull(j['role_id']),
        mustChangePassword: J.boolean(j['mustChangePassword']),
        twoFactor: J.boolean(j['twoFactor']),
        office: J.first(j['office'], Office.fromJson),
        createdAt: J.date(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'username': username,
        'active': active,
        'office_id': officeId,
        'allOffices': allOffices,
        'role_id': roleId,
        'mustChangePassword': mustChangePassword,
        'twoFactor': twoFactor,
      };
}

/// Moduli za mfumo (lazima zilingane na `Module` ya backend).
enum AppModule {
  user('USER'),
  customer('CUSTOMER'),
  invoice('INVOICE'),
  package('PACKAGE'),
  permission('PERMISSION'),
  product('PRODUCT'),
  receive('RECEIVE'),
  setting('SETTING'),
  store('STORE'),
  payment('PAYMENT'),
  expenses('EXPENSES'),
  sms('SMS'),
  report('REPORT'),
  dashboard('DASHBOARD'),
  handover('HANDOVER'),
  discount('DISCOUNT'),
  refund('REFUND'),
  credit('CREDIT'),
  claim('CLAIM'),
  cashup('CASHUP'),
  broadcast('BROADCAST'),
  whatsapp('WHATSAPP'),
  profit('PROFIT'),
  finance('FINANCE'),
  audit('AUDIT'),
  backup('BACKUP'),
  dataImport('IMPORT'),
  price('PRICE'),
  quote('QUOTE'),
  accounting('ACCOUNTING'),
  payroll('PAYROLL');

  final String code;

  const AppModule(this.code);

  static AppModule? fromCode(String code) {
    for (final m in AppModule.values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

enum AppAction { insert, update, select, delete, block }

/// Vitendo vyenye maana kwa kila moduli (vingine havitumiki kwenye mfumo, kwa hiyo havionyeshwi).
const Map<String, List<AppAction>> moduleActions = {
  'USER': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete, AppAction.block],
  'CUSTOMER': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete, AppAction.block],
  'INVOICE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete, AppAction.block],
  'PACKAGE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'PERMISSION': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'PRODUCT': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'RECEIVE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete, AppAction.block],
  'SETTING': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'STORE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'PAYMENT': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'EXPENSES': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'SMS': [AppAction.select, AppAction.insert, AppAction.delete],
  'REPORT': [AppAction.select],
  'DASHBOARD': [AppAction.select],
  'HANDOVER': [AppAction.select, AppAction.insert, AppAction.update],
  'DISCOUNT': [AppAction.insert],
  'REFUND': [AppAction.insert],
  'CREDIT': [AppAction.select, AppAction.update],
  'CLAIM': [AppAction.select, AppAction.insert, AppAction.update],
  'CASHUP': [AppAction.select, AppAction.insert, AppAction.delete],
  'BROADCAST': [AppAction.insert],
  'WHATSAPP': [AppAction.select, AppAction.insert],
  'PROFIT': [AppAction.select, AppAction.update, AppAction.delete],
  'FINANCE': [AppAction.select],
  'AUDIT': [AppAction.select],
  'BACKUP': [AppAction.select, AppAction.insert, AppAction.delete],
  'IMPORT': [AppAction.select, AppAction.insert],
  'PRICE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'QUOTE': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'ACCOUNTING': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
  'PAYROLL': [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete],
};

List<AppAction> actionsFor(String module) => moduleActions[module] ?? AppAction.values;

class Permission {
  final String id;
  final String name;
  final String userId;
  final bool insert;
  final bool update;
  final bool select;
  final bool delete;
  final bool block;

  const Permission({
    required this.id,
    required this.name,
    required this.userId,
    this.insert = false,
    this.update = false,
    this.select = false,
    this.delete = false,
    this.block = false,
  });

  AppModule? get module => AppModule.fromCode(name);

  bool allows(AppAction action) => switch (action) {
        AppAction.insert => insert,
        AppAction.update => update,
        AppAction.select => select,
        AppAction.delete => delete,
        AppAction.block => block,
      };

  bool get all => insert && update && select && delete && block;

  Permission copyWith({bool? insert, bool? update, bool? select, bool? delete, bool? block}) => Permission(
        id: id,
        name: name,
        userId: userId,
        insert: insert ?? this.insert,
        update: update ?? this.update,
        select: select ?? this.select,
        delete: delete ?? this.delete,
        block: block ?? this.block,
      );

  Permission withAction(AppAction action, bool value) => switch (action) {
        AppAction.insert => copyWith(insert: value),
        AppAction.update => copyWith(update: value),
        AppAction.select => copyWith(select: value),
        AppAction.delete => copyWith(delete: value),
        AppAction.block => copyWith(block: value),
      };

  factory Permission.fromJson(Map<String, dynamic> j) => Permission(
        id: J.str(j['id']),
        name: J.str(j['name']),
        userId: J.str(j['user_id']),
        insert: J.boolean(j['data_insert']),
        update: J.boolean(j['data_update']),
        select: J.boolean(j['data_select']),
        delete: J.boolean(j['data_delete']),
        block: J.boolean(j['data_block']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'user_id': userId,
        'data_insert': insert,
        'data_update': update,
        'data_select': select,
        'data_delete': delete,
        'data_block': block,
      };
}
