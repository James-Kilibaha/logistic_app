import 'json.dart';

/// Dai la gharama: kazi iliyofanywa (box limesafirishwa / limefika) inayohitaji gharama zake zijazwe.
class CostDemand {
  final String id;
  final String trigger; // BOX_CLOSED | BOX_ARRIVED
  final String triggerLabel;
  final String packageId;
  final String? boxId;
  final String? trackNumber;
  final List<String> categories;
  final List<String> missing; // ANY = gharama yoyote
  final String responsible;
  final String? doer;
  final String status; // OPEN | DONE | NONE | WAIVED
  final String? note;
  final String? closedBy;
  final DateTime? closedAt;
  final String? remindLocal;
  final String? blockLocal;
  final bool remind;
  final bool blocking;
  final bool isResponsible;
  final bool canFill;
  final bool canWaive;
  final DateTime? createdAt;

  const CostDemand({
    required this.id,
    required this.trigger,
    this.triggerLabel = '',
    required this.packageId,
    this.boxId,
    this.trackNumber,
    this.categories = const [],
    this.missing = const [],
    this.responsible = '',
    this.doer,
    this.status = 'OPEN',
    this.note,
    this.closedBy,
    this.closedAt,
    this.remindLocal,
    this.blockLocal,
    this.remind = false,
    this.blocking = false,
    this.isResponsible = false,
    this.canFill = false,
    this.canWaive = false,
    this.createdAt,
  });

  bool get isOpen => status == 'OPEN';

  static List<String> _strings(dynamic v) => v is List ? [for (final x in v) '$x'] : const [];

  factory CostDemand.fromJson(Map<String, dynamic> j) => CostDemand(
        id: J.str(j['id']),
        trigger: J.str(j['trigger']),
        triggerLabel: J.str(j['triggerLabel']),
        packageId: J.str(j['package_id']),
        boxId: J.strOrNull(j['boxId']),
        trackNumber: J.strOrNull(j['trackNumber']),
        categories: _strings(j['categories']),
        missing: _strings(j['missing']),
        responsible: J.str(j['responsible']),
        doer: J.strOrNull(j['doer']),
        status: J.str(j['status'], 'OPEN'),
        note: J.strOrNull(j['note']),
        closedBy: J.strOrNull(j['closedBy']),
        closedAt: J.date(j['closedAt']),
        remindLocal: J.strOrNull(j['remindLocal']),
        blockLocal: J.strOrNull(j['blockLocal']),
        remind: J.boolean(j['remind']),
        blocking: J.boolean(j['blocking']),
        isResponsible: J.boolean(j['isResponsible']),
        canFill: J.boolean(j['canFill']),
        canWaive: J.boolean(j['canWaive']),
        createdAt: J.date(j['created_at']),
      );
}

/// Sheria ya kudai gharama kwa kazi fulani.
class DemandRule {
  final String trigger;
  final String label;
  final bool enabled;
  final List<String> categories;
  final String responsible; // DOER | ROLE
  final String? roleId;
  final String? role;
  final int remindHour;
  final int graceDays;
  final String blockScope; // EVERYONE | RESPONSIBLE | NONE

  const DemandRule({
    required this.trigger,
    this.label = '',
    this.enabled = true,
    this.categories = const [],
    this.responsible = 'DOER',
    this.roleId,
    this.role,
    this.remindHour = 17,
    this.graceDays = 0,
    this.blockScope = 'EVERYONE',
  });

  factory DemandRule.fromJson(Map<String, dynamic> j) => DemandRule(
        trigger: J.str(j['trigger']),
        label: J.str(j['label']),
        enabled: J.boolean(j['enabled']),
        categories: CostDemand._strings(j['categories']),
        responsible: J.str(j['responsible'], 'DOER'),
        roleId: J.strOrNull(j['role_id']),
        role: J.strOrNull(j['role']),
        remindHour: J.integer(j['remindHour'], 17),
        graceDays: J.integer(j['graceDays']),
        blockScope: J.str(j['blockScope'], 'EVERYONE'),
      );
}
