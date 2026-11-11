import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/role.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import 'permissions_page.dart';

const List<AppAction> _actions = [AppAction.select, AppAction.insert, AppAction.update, AppAction.delete, AppAction.block];

/// Majukumu (roles): seti za ruhusa zinazopewa watumiaji.
class RolesPage extends StatefulWidget {
  const RolesPage({super.key});

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  List<Role> _roles = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  bool get _canEdit => AppController.to.can(AppModule.permission, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roles = await RoleRepo.all();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _status = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _open([Role? role]) async {
    final saved = await Get.to<bool>(() => RoleEditPage(role: role, canEdit: _canEdit));
    if (saved == true) _load();
  }

  Future<void> _delete(Role role) async {
    final ok = await confirmAction(
      title: 'deleteRole'.tr,
      message: role.name,
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    if (await runGuarded(() => RoleRepo.delete(role.id), success: 'deleted'.tr)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canAdd = AppController.to.can(AppModule.permission, AppAction.insert);
    return AppPage(
      help: 'roles',
      title: 'roles'.tr,
      subtitle: 'rolesSub'.tr,
      showBack: true,
      actions: [IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      mainAction: canAdd ? PageAction(icon: Icons.add_rounded, label: 'newRole'.tr, onPressed: () => _open()) : null,
      body: AsyncBody(
        status: _status,
        error: _error,
        isEmpty: _roles.isEmpty,
        onRetry: _load,
        empty: EmptyState(icon: Icons.badge_outlined, title: 'noRoles'.tr),
        builder: () => PageScroll(
          onRefresh: _load,
          children: [
            for (final r in _roles)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  onTap: () => _open(r),
                  leading: CircleAvatar(
                    backgroundColor: p.primarySoft,
                    child: Icon(r.isSystem ? Icons.verified_user_outlined : Icons.badge_outlined, color: p.primary),
                  ),
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (r.description != null) r.description!,
                    'roleUsersCount'.trParams({'n': '${r.users}'}),
                    'roleModulesCount'.trParams({'n': '${r.permissions.where((x) => x.select).length}'}),
                  ].join(' · ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.isSystem) Pill('systemRole'.tr, color: p.info, dense: true),
                      if (!r.isSystem && AppController.to.can(AppModule.permission, AppAction.delete))
                        IconButton(
                          tooltip: 'delete'.tr,
                          onPressed: () => _delete(r),
                          icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                        ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kuunda au kubadilisha role: jina, maelezo na jedwali la ruhusa (moduli x vitendo).
class RoleEditPage extends StatefulWidget {
  final Role? role;
  final bool canEdit;

  const RoleEditPage({super.key, this.role, required this.canEdit});

  @override
  State<RoleEditPage> createState() => _RoleEditPageState();
}

class _RoleEditPageState extends State<RoleEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.role?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.role?.description ?? '');
  late List<RoleFlags> _flags;
  bool _apply = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = {for (final f in widget.role?.permissions ?? const <RoleFlags>[]) f.module: f};
    _flags = [for (final m in AppModule.values) existing[m.code] ?? RoleFlags(module: m.code)]
      ..sort((a, b) => moduleOrder(a.module).compareTo(moduleOrder(b.module)));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _set(int i, RoleFlags f) => setState(() => _flags = [..._flags]..[i] = f);

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      Toast.warning('roleNameRequired'.tr);
      return;
    }
    setState(() => _busy = true);
    try {
      await RoleRepo.save(
        id: widget.role?.id,
        name: _name.text,
        description: _description.text,
        permissions: _flags,
        applyToUsers: _apply,
      );
      Toast.success(_name.text, title: 'saved'.tr);
      AppController.to.notifyChanged();
      Get.back(result: true);
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final edit = widget.canEdit;
    return AppPage(
      help: 'roles',
      title: widget.role == null ? 'newRole'.tr : widget.role!.name,
      subtitle: 'roleEditSub'.tr,
      showBack: true,
      mainAction: edit ? PageAction(icon: Icons.save_outlined, label: 'save'.tr, onPressed: () {
                if (!_busy) _save();
              }) : null,
      body: PageScroll(
        children: [
          SectionCard(
            child: Column(
              children: [
                AppField(controller: _name, label: 'roleName'.tr, required: true, enabled: edit, icon: Icons.badge_outlined),
                const SizedBox(height: 14),
                AppField(controller: _description, label: 'roleDescription'.tr, enabled: edit, icon: Icons.notes_rounded),
                if (widget.role != null && widget.role!.users > 0)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _apply,
                    onChanged: edit ? (v) => setState(() => _apply = v) : null,
                    title: Text('applyRoleToUsers'.trParams({'n': '${widget.role!.users}'})),
                    subtitle: Text('applyRoleToUsersSub'.tr),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'permissions'.tr,
            icon: Icons.verified_user_outlined,
            trailing: edit
                ? Wrap(spacing: 4, children: [
                    TextButton(
                      onPressed: () => setState(() => _flags = [for (final f in _flags) f.all(true)]),
                      child: Text('selectAll'.tr),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _flags = [for (final f in _flags) f.all(false)]),
                      child: Text('clearAll'.tr),
                    ),
                  ])
                : null,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columnSpacing: 18,
                horizontalMargin: 10,
                headingTextStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12),
                columns: [
                  DataColumn(label: Text('module'.tr)),
                  for (final a in _actions) DataColumn(label: Text(actionLabel(a))),
                ],
                rows: [
                  for (int i = 0; i < _flags.length; i++)
                    DataRow(cells: [
                      DataCell(
                        InkWell(
                          onTap: edit ? () => _set(i, _flags[i].all(!_flags[i].full)) : null,
                          child: ModuleTitle(_flags[i].module),
                        ),
                      ),
                      for (final a in _actions)
                        if (!actionsFor(_flags[i].module).contains(a))
                          const DataCell(Center(child: Text('—')))
                        else
                        DataCell(Checkbox(
                          value: _flags[i].allows(a),
                          onChanged: edit
                              ? (v) {
                                  var f = _flags[i].withAction(a, v ?? false);
                                  // kuona ni lazima kwa vitendo vingine
                                  if (a != AppAction.select && (v ?? false)) f = f.withAction(AppAction.select, true);
                                  if (a == AppAction.select && !(v ?? false)) f = f.all(false);
                                  _set(i, f);
                                }
                              : null,
                        )),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
