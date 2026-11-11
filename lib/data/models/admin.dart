import 'json.dart';

/// Backup moja (faili la .zip kwenye server).
class BackupItem {
  final String name;
  final int size;
  final DateTime? createdAt;

  const BackupItem({required this.name, required this.size, this.createdAt});

  factory BackupItem.fromJson(Map<String, dynamic> j) => BackupItem(
        name: J.str(j['name']),
        size: J.integer(j['size']),
        createdAt: J.date(j['created_at']),
      );

  String get sizeLabel {
    if (size >= 1 << 30) return '${(size / (1 << 30)).toStringAsFixed(2)} GB';
    if (size >= 1 << 20) return '${(size / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }
}

class BackupOverview {
  final bool enabled;
  final int hour;
  final int keep;
  final bool mirror;
  final List<BackupItem> items;

  const BackupOverview({
    required this.enabled,
    required this.hour,
    required this.keep,
    required this.mirror,
    required this.items,
  });

  factory BackupOverview.fromJson(Map<String, dynamic> j) {
    final s = J.map(j['status']) ?? const <String, dynamic>{};
    return BackupOverview(
      enabled: J.boolean(s['enabled']),
      hour: J.integer(s['hour'], 2),
      keep: J.integer(s['keep'], 14),
      mirror: J.boolean(s['mirror']),
      items: J.list(j['items'], BackupItem.fromJson),
    );
  }

  BackupItem? get last => items.isEmpty ? null : items.first;
}

/// Kumbukumbu moja ya kitendo (audit log).
class AuditEntry {
  final String id;
  final DateTime? createdAt;
  final String? userId;
  final String? username;
  final String module;
  final String action;
  final String method;
  final String path;
  final String? entityId;
  final int statusCode;
  final String? ip;
  final String? summary;
  final String? detail;

  /// APP / WEB / API
  final String? client;

  /// mf. "Samsung SM-A515F · Android 13" au "Chrome 130 · Windows 10/11"
  final String? device;

  const AuditEntry({
    required this.id,
    this.createdAt,
    this.userId,
    this.username,
    required this.module,
    required this.action,
    required this.method,
    required this.path,
    this.entityId,
    required this.statusCode,
    this.ip,
    this.summary,
    this.detail,
    this.client,
    this.device,
  });

  bool get failed => statusCode >= 400;

  /// "App · Samsung SM-A515F · Android 13" / "Web · Chrome 130 · Windows 10/11"
  String? get deviceLabel {
    final kind = switch (client) { 'APP' => 'App', 'WEB' => 'Web', 'API' => 'API', _ => null };
    final parts = [if (kind != null) kind, if ((device ?? '').isNotEmpty) device!];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: J.str(j['id']),
        createdAt: J.date(j['created_at']),
        userId: J.strOrNull(j['user_id']),
        username: J.strOrNull(j['username']),
        module: J.str(j['module'], '-'),
        action: J.str(j['action'], '-'),
        method: J.str(j['method']),
        path: J.str(j['path']),
        entityId: J.strOrNull(j['entity_id']),
        statusCode: J.integer(j['status_code']),
        ip: J.strOrNull(j['ip']),
        summary: J.strOrNull(j['summary']),
        detail: J.strOrNull(j['detail']),
        client: J.strOrNull(j['client']),
        device: J.strOrNull(j['device']),
      );
}

class AuditResult {
  final int total;
  final List<AuditEntry> items;

  const AuditResult({required this.total, required this.items});

  factory AuditResult.fromJson(Map<String, dynamic> j) =>
      AuditResult(total: J.integer(j['total']), items: J.list(j['items'], AuditEntry.fromJson));
}
