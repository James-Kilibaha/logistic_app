import 'json.dart';

/// Akaunti ya fedha (Cash / Benki / Simu) - ni "taasisi" ileile inayopokea malipo ya ankara.
class FinAccount {
  final String id;
  final String name;
  final String accountNo;
  final String currencyType;
  final String kind; // CASH | BANK | MOBILE
  final String? officeId;
  final String? office;
  final double openingBalance;
  final String? openingDate;
  final double? balance; // TSh (null = huna ruhusa ya kuona salio)
  final double? nativeBalance; // kwa sarafu ya akaunti

  const FinAccount({
    required this.id,
    required this.name,
    required this.accountNo,
    this.currencyType = 'TZS',
    this.kind = 'BANK',
    this.officeId,
    this.office,
    this.openingBalance = 0,
    this.openingDate,
    this.balance,
    this.nativeBalance,
  });

  bool get isLocal => const ['TZS', 'TSH'].contains(currencyType.toUpperCase());

  factory FinAccount.fromJson(Map<String, dynamic> j) => FinAccount(
        id: J.str(j['id']),
        name: J.str(j['name']),
        accountNo: J.str(j['accountNo']),
        currencyType: J.str(j['currencyType'], 'TZS'),
        kind: J.str(j['kind'], 'BANK'),
        officeId: J.strOrNull(j['office_id']),
        office: J.strOrNull(j['office']),
        openingBalance: J.dbl(j['openingBalance']),
        openingDate: J.strOrNull(j['openingDate']),
        balance: j['balance'] == null ? null : J.dbl(j['balance']),
        nativeBalance: j['nativeBalance'] == null ? null : J.dbl(j['nativeBalance']),
      );

  /// Jina (sarafu) · ofisi - ili ijulikane ni akaunti ya sarafu ipi.
  String get label => '$name (${currencyType.toUpperCase()})${office == null ? '' : ' · $office'}';
}

/// Kundi la matumizi (EXPENSE) au la mapato mengine (INCOME).
class AccCategory {
  final String id;
  final String name;
  final String kind;
  final String? description;
  final bool isBlocked;

  const AccCategory({required this.id, required this.name, this.kind = 'EXPENSE', this.description, this.isBlocked = false});

  factory AccCategory.fromJson(Map<String, dynamic> j) => AccCategory(
        id: J.str(j['id']),
        name: J.str(j['name']),
        kind: J.str(j['kind'], 'EXPENSE'),
        description: J.strOrNull(j['description']),
        isBlocked: J.boolean(j['isBlocked']),
      );
}

/// Mapato yasiyotoka kwenye ankara.
class OtherIncome {
  final String id;
  final String details;
  final double amount;
  final String currency;
  final double? amountOriginal;
  final String? categoryId;
  final String? category;
  final String? accountId;
  final String? account;
  final String? officeId;
  final String? office;
  final String? createdBy;
  final DateTime? createdAt;

  const OtherIncome({
    required this.id,
    required this.details,
    required this.amount,
    this.currency = 'TZS',
    this.amountOriginal,
    this.categoryId,
    this.category,
    this.accountId,
    this.account,
    this.officeId,
    this.office,
    this.createdBy,
    this.createdAt,
  });

  factory OtherIncome.fromJson(Map<String, dynamic> j) => OtherIncome(
        id: J.str(j['id']),
        details: J.str(j['details']),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        amountOriginal: j['amountOriginal'] == null ? null : J.dbl(j['amountOriginal']),
        categoryId: J.strOrNull(j['category_id']),
        category: J.strOrNull(j['category']),
        accountId: J.strOrNull(j['institute_id']),
        account: J.strOrNull(j['institute']),
        officeId: J.strOrNull(j['office_id']),
        office: J.strOrNull(j['office']),
        createdBy: J.strOrNull(j['createdBy']),
        createdAt: J.date(j['created_at']),
      );
}

/// Kuhamisha pesa kati ya akaunti.
class AccTransfer {
  final String id;
  final String fromId;
  final String from;
  final String toId;
  final String to;
  final double amount;
  final double? fromAmount;
  final double? toAmount;
  final String fromCurrency;
  final String toCurrency;
  final String? note;
  final String? createdBy;
  final DateTime? createdAt;

  const AccTransfer({
    required this.id,
    required this.fromId,
    required this.from,
    required this.toId,
    required this.to,
    required this.amount,
    this.fromAmount,
    this.toAmount,
    this.fromCurrency = 'TZS',
    this.toCurrency = 'TZS',
    this.note,
    this.createdBy,
    this.createdAt,
  });

  factory AccTransfer.fromJson(Map<String, dynamic> j) => AccTransfer(
        id: J.str(j['id']),
        fromId: J.str(j['from_id']),
        from: J.str(j['from']),
        toId: J.str(j['to_id']),
        to: J.str(j['to']),
        amount: J.dbl(j['amount']),
        fromAmount: j['fromAmount'] == null ? null : J.dbl(j['fromAmount']),
        toAmount: j['toAmount'] == null ? null : J.dbl(j['toAmount']),
        fromCurrency: J.str(j['fromCurrency'], 'TZS'),
        toCurrency: J.str(j['toCurrency'], 'TZS'),
        note: J.strOrNull(j['note']),
        createdBy: J.strOrNull(j['createdBy']),
        createdAt: J.date(j['created_at']),
      );
}

/// Deni tunalodaiwa: gharama ya box (BOX_COST) au matumizi (EXPENSE).
class Payable {
  final String id;
  final String source;
  final String title;
  final double amountTzs;
  final double paidTzs;
  final double owedTzs;
  final String? payStatus;
  final String? supplier;
  final DateTime? createdAt;

  const Payable({
    required this.id,
    required this.source,
    required this.title,
    this.amountTzs = 0,
    this.paidTzs = 0,
    this.owedTzs = 0,
    this.payStatus,
    this.supplier,
    this.createdAt,
  });

  factory Payable.fromJson(Map<String, dynamic> j) => Payable(
        id: J.str(j['id']),
        source: J.str(j['source'], 'BOX_COST'),
        title: J.str(j['title']),
        amountTzs: J.dbl(j['amountTzs']),
        paidTzs: J.dbl(j['paidTzs']),
        owedTzs: J.dbl(j['owedTzs']),
        payStatus: J.strOrNull(j['payStatus']),
        supplier: J.strOrNull(j['supplier']),
        createdAt: J.date(j['created_at']),
      );
}

/// Mtaji ulioingizwa (CAPITAL) au pesa alizochukua mmiliki (DRAWING).
class EquityEntry {
  final String id;
  final String kind;
  final String? owner;
  final String? details;
  final double amount;
  final String currency;
  final double? amountOriginal;
  final String? account;
  final DateTime? createdAt;

  const EquityEntry({
    required this.id,
    required this.kind,
    this.owner,
    this.details,
    required this.amount,
    this.currency = 'TZS',
    this.amountOriginal,
    this.account,
    this.createdAt,
  });

  bool get isCapital => kind == 'CAPITAL';

  factory EquityEntry.fromJson(Map<String, dynamic> j) => EquityEntry(
        id: J.str(j['id']),
        kind: J.str(j['kind'], 'CAPITAL'),
        owner: J.strOrNull(j['owner']),
        details: J.strOrNull(j['details']),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        amountOriginal: j['amountOriginal'] == null ? null : J.dbl(j['amountOriginal']),
        account: J.strOrNull(j['institute']),
        createdAt: J.date(j['created_at']),
      );
}

/// Mali ya kudumu.
class FixedAssetItem {
  final String id;
  final String name;
  final String category;
  final double cost;
  final String purchaseDate;
  final int lifeMonths;
  final double salvage;
  final double monthly;
  final double accumulated;
  final double bookValue;
  final String? accountId;
  final String? account;
  final String? officeId;
  final String? office;
  final String? serial;
  final String? note;
  final String? disposedOn;
  final double? disposalAmount;
  final String currency;
  final double? amountOriginal;

  const FixedAssetItem({
    required this.id,
    required this.name,
    this.category = 'OTHER',
    required this.cost,
    required this.purchaseDate,
    this.lifeMonths = 60,
    this.salvage = 0,
    this.monthly = 0,
    this.accumulated = 0,
    this.bookValue = 0,
    this.accountId,
    this.account,
    this.officeId,
    this.office,
    this.serial,
    this.note,
    this.disposedOn,
    this.disposalAmount,
    this.currency = 'TZS',
    this.amountOriginal,
  });

  bool get disposed => disposedOn != null;

  factory FixedAssetItem.fromJson(Map<String, dynamic> j) => FixedAssetItem(
        id: J.str(j['id']),
        name: J.str(j['name']),
        category: J.str(j['category'], 'OTHER'),
        cost: J.dbl(j['cost']),
        purchaseDate: J.str(j['purchaseDate']),
        lifeMonths: J.integer(j['lifeMonths'], 60),
        salvage: J.dbl(j['salvage']),
        monthly: J.dbl(j['monthly']),
        accumulated: J.dbl(j['accumulated']),
        bookValue: J.dbl(j['bookValue']),
        accountId: J.strOrNull(j['institute_id']),
        account: J.strOrNull(j['institute']),
        officeId: J.strOrNull(j['office_id']),
        office: J.strOrNull(j['office']),
        serial: J.strOrNull(j['serial']),
        note: J.strOrNull(j['note']),
        disposedOn: J.strOrNull(j['disposedOn']),
        disposalAmount: j['disposalAmount'] == null ? null : J.dbl(j['disposalAmount']),
        currency: J.str(j['currency'], 'TZS'),
        amountOriginal: j['amountOriginal'] == null ? null : J.dbl(j['amountOriginal']),
      );
}

/// Mstari mmoja wa mwenendo wa akaunti.
class StatementLine {
  final DateTime? at;
  final String type;
  final String ref;
  final String details;
  final double moneyIn;
  final double moneyOut;
  final double balance;

  const StatementLine({
    this.at,
    required this.type,
    this.ref = '',
    required this.details,
    this.moneyIn = 0,
    this.moneyOut = 0,
    this.balance = 0,
  });

  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
        at: J.date(j['at']),
        type: J.str(j['type']),
        ref: J.str(j['ref']),
        details: J.str(j['details']),
        moneyIn: J.dbl(j['moneyIn']),
        moneyOut: J.dbl(j['moneyOut']),
        balance: J.dbl(j['balance']),
      );
}
