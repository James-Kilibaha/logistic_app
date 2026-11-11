import 'invoice.dart';
import 'json.dart';

class Customer {
  final String id;
  final String name;
  final String phoneNumber;
  final int active;
  final DateTime? createdAt;
  final List<Invoice> invoices;

  /// Kikomo cha mkopo (TSh). `null` = kikomo cha kawaida cha mfumo; 0 = hakopeshwi.
  final double? creditLimit;

  const Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.active = 1,
    this.createdAt,
    this.invoices = const [],
    this.creditLimit,
  });

  bool get isActive => active == 1;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: J.str(j['id']),
        name: J.str(j['name']),
        phoneNumber: J.str(j['phoneNumber']),
        active: J.integer(j['active'], 1),
        createdAt: J.date(j['created_at']),
        invoices: J.list(j['invoice'], Invoice.fromJson),
        creditLimit: j['creditLimit'] == null ? null : J.dbl(j['creditLimit']),
      );
}
