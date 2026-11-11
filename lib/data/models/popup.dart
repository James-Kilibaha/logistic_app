import 'json.dart';

/// Kitu kimoja ndani ya taarifa ya pop-up (mf. ankara yenye deni).
class PopupItem {
  final String title;
  final String subtitle;

  /// invoice:<id> / box:<id> / sms / store-overdue ... (kama taarifa za 🔔)
  final String? link;

  const PopupItem({required this.title, this.subtitle = '', this.link});

  factory PopupItem.fromJson(Map<String, dynamic> j) =>
      PopupItem(title: J.str(j['title']), subtitle: J.str(j['subtitle']), link: J.strOrNull(j['link']));
}

/// Aina moja ya taarifa iliyo na vitu sasa hivi (mf. wadaiwa 12).
class PopupGroup {
  final String kind;
  final int count;
  final int afterDays;
  final int everyMinutes;
  final double? total;
  final List<PopupItem> items;

  const PopupGroup({
    required this.kind,
    required this.count,
    required this.afterDays,
    required this.everyMinutes,
    this.total,
    this.items = const [],
  });

  factory PopupGroup.fromJson(Map<String, dynamic> j) => PopupGroup(
        kind: J.str(j['kind']),
        count: J.integer(j['count']),
        afterDays: J.integer(j['afterDays']),
        everyMinutes: J.integer(j['everyMinutes']),
        total: j['total'] == null ? null : J.dbl(j['total']),
        items: J.list(j['items'], PopupItem.fromJson),
      );
}

/// Sheria ya aina moja (admin): kuwasha, siku za kusubiri, na kujirudia kila dakika ngapi.
class PopupRule {
  final String kind;
  final String module;
  final bool enabled;
  final int afterDays;
  final int everyMinutes;

  const PopupRule({
    required this.kind,
    required this.module,
    required this.enabled,
    required this.afterDays,
    required this.everyMinutes,
  });

  factory PopupRule.fromJson(Map<String, dynamic> j) => PopupRule(
        kind: J.str(j['kind']),
        module: J.str(j['module']),
        enabled: J.boolean(j['enabled']),
        afterDays: J.integer(j['afterDays']),
        everyMinutes: J.integer(j['everyMinutes']),
      );
}

/// SMS za moja kwa moja (vikumbusho): DEBT / CREDIT / STORAGE_WARN / STORAGE_OVERDUE.
class AutoSmsRule {
  final String kind;
  final bool enabled;

  /// Ianze baada ya siku ngapi (STORAGE_WARN: siku ngapi kabla siku za bure hazijaisha).
  final int afterDays;

  /// Ijirudie kila siku ngapi (0 = mara moja tu).
  final int everyDays;

  /// Itumwe yenyewe (true) au isubiri "Tuma" (false).
  final bool autoSend;

  /// Saa ya siku ya kutuma (0-23).
  final int hour;
  final DateTime? lastRunOn;

  const AutoSmsRule({
    required this.kind,
    required this.enabled,
    required this.afterDays,
    required this.everyDays,
    required this.autoSend,
    required this.hour,
    this.lastRunOn,
  });

  AutoSmsRule copyWith({bool? enabled, int? afterDays, int? everyDays, bool? autoSend, int? hour}) => AutoSmsRule(
        kind: kind,
        enabled: enabled ?? this.enabled,
        afterDays: afterDays ?? this.afterDays,
        everyDays: everyDays ?? this.everyDays,
        autoSend: autoSend ?? this.autoSend,
        hour: hour ?? this.hour,
        lastRunOn: lastRunOn,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'enabled': enabled,
        'afterDays': afterDays,
        'everyDays': everyDays,
        'autoSend': autoSend,
        'hour': hour,
      };

  factory AutoSmsRule.fromJson(Map<String, dynamic> j) => AutoSmsRule(
        kind: J.str(j['kind']),
        enabled: J.boolean(j['enabled']),
        afterDays: J.integer(j['afterDays']),
        everyDays: J.integer(j['everyDays']),
        autoSend: J.boolean(j['autoSend']),
        hour: J.integer(j['hour']),
        lastRunOn: J.date(j['lastRunOn']),
      );
}
