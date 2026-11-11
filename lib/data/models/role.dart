import 'json.dart';
import 'user.dart';

/// Ruhusa za moduli moja ndani ya role.
class RoleFlags {
  final String module;
  final bool select;
  final bool insert;
  final bool update;
  final bool delete;
  final bool block;

  const RoleFlags({
    required this.module,
    this.select = false,
    this.insert = false,
    this.update = false,
    this.delete = false,
    this.block = false,
  });

  bool allows(AppAction a) => switch (a) {
        AppAction.select => select,
        AppAction.insert => insert,
        AppAction.update => update,
        AppAction.delete => delete,
        AppAction.block => block,
      };

  RoleFlags withAction(AppAction a, bool v) => RoleFlags(
        module: module,
        select: a == AppAction.select ? v : select,
        insert: a == AppAction.insert ? v : insert,
        update: a == AppAction.update ? v : update,
        delete: a == AppAction.delete ? v : delete,
        block: a == AppAction.block ? v : block,
      );

  /// Washa/zima vitendo vyote vyenye maana kwa moduli hii (vingine vinabaki vimezimwa).
  RoleFlags all(bool v) {
    final acts = actionsFor(module);
    bool on(AppAction a) => v && (acts.contains(a) || a == AppAction.select);
    return RoleFlags(
        module: module,
        select: on(AppAction.select),
        insert: on(AppAction.insert),
        update: on(AppAction.update),
        delete: on(AppAction.delete),
        block: on(AppAction.block));
  }

  int get count => [for (final a in actionsFor(module)) allows(a)].where((e) => e).length;

  bool get full => count == actionsFor(module).length;

  factory RoleFlags.fromJson(Map<String, dynamic> j) => RoleFlags(
        module: J.str(j['module']),
        select: J.boolean(j['data_select']),
        insert: J.boolean(j['data_insert']),
        update: J.boolean(j['data_update']),
        delete: J.boolean(j['data_delete']),
        block: J.boolean(j['data_block']),
      );

  Map<String, dynamic> toJson() => {
        'module': module,
        'data_select': select,
        'data_insert': insert,
        'data_update': update,
        'data_delete': delete,
        'data_block': block,
      };
}

/// Jukumu (role): seti ya ruhusa inayopewa watumiaji wengi.
class Role {
  final String id;
  final String name;
  final String? description;
  final bool isSystem;
  final int users;
  final List<RoleFlags> permissions;

  const Role({
    required this.id,
    required this.name,
    this.description,
    this.isSystem = false,
    this.users = 0,
    this.permissions = const [],
  });

  factory Role.fromJson(Map<String, dynamic> j) => Role(
        id: J.str(j['id']),
        name: J.str(j['name']),
        description: J.strOrNull(j['description']),
        isSystem: J.boolean(j['isSystem']),
        users: J.integer(j['users']),
        permissions: J.list(j['permissions'], RoleFlags.fromJson),
      );
}
