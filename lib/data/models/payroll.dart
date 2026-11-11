import 'json.dart';

/// Mfanyakazi (mishahara).
class StaffMember {
  final String id;
  final String name;
  final String? phone;
  final String? position;
  final String? officeId;
  final String? office;
  final double basic;
  final double allowance;
  final double deduction;
  final bool nssf;
  final bool paye;
  final String? tin;
  final String? nssfNo;
  final String? bank;
  final bool active;

  const StaffMember({
    required this.id,
    required this.name,
    this.phone,
    this.position,
    this.officeId,
    this.office,
    this.basic = 0,
    this.allowance = 0,
    this.deduction = 0,
    this.nssf = true,
    this.paye = true,
    this.tin,
    this.nssfNo,
    this.bank,
    this.active = true,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: J.str(j['id']),
        name: J.str(j['name']),
        phone: J.strOrNull(j['phone']),
        position: J.strOrNull(j['position']),
        officeId: J.strOrNull(j['office_id']),
        office: J.strOrNull(j['office']),
        basic: J.dbl(j['basic']),
        allowance: J.dbl(j['allowance']),
        deduction: J.dbl(j['deduction']),
        nssf: J.boolean(j['nssf']),
        paye: J.boolean(j['paye']),
        tin: J.strOrNull(j['tin']),
        nssfNo: J.strOrNull(j['nssfNo']),
        bank: J.strOrNull(j['bank']),
        active: J.boolean(j['active']),
      );
}

/// Mishahara ya mwezi mmoja: mistari (kila mfanyakazi) na jumla.
class PayrollRunData {
  final String id;
  final String month;
  final String status; // DRAFT | POSTED
  final Map<String, double> totals;
  final List<Map<String, dynamic>> lines;

  const PayrollRunData({required this.id, required this.month, this.status = 'DRAFT', this.totals = const {}, this.lines = const []});

  bool get posted => status == 'POSTED';

  double t(String k) => totals[k] ?? 0;

  factory PayrollRunData.fromJson(Map<String, dynamic> j) {
    final t = j['totals'];
    final l = j['lines'];
    return PayrollRunData(
      id: J.str(j['id']),
      month: J.str(j['month']),
      status: J.str(j['status'], 'DRAFT'),
      totals: t is Map ? {for (final e in t.entries) '${e.key}': J.dbl(e.value)} : const {},
      lines: l is List ? [for (final x in l.whereType<Map>()) Map<String, dynamic>.from(x)] : const [],
    );
  }
}
