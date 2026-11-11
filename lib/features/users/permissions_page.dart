import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

String moduleLabel(String code) => 'mod_$code'.tr;

/// Maelezo mafupi ya moduli: inaruhusu nini hasa.
String moduleDescription(String code) {
  final key = 'modDesc_$code';
  final v = key.tr;
  return v == key ? '' : v;
}

/// Mpangilio wa kimantiki (kama ulivyo kwenye AppModule), si wa alfabeti.
int moduleOrder(String code) {
  final m = AppModule.fromCode(code);
  return m == null ? 999 : m.index;
}

/// Jina la moduli + maelezo yake chini (kwenye jedwali la ruhusa na la role).
class ModuleTitle extends StatelessWidget {
  final String code;
  final Widget? trailing;

  const ModuleTitle(this.code, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final desc = moduleDescription(code);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(moduleLabel(code), style: TextStyle(fontWeight: FontWeight.w700, color: p.text))),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (desc.isNotEmpty)
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

String actionLabel(AppAction a) => switch (a) {
      AppAction.select => 'actSelect'.tr,
      AppAction.insert => 'actInsert'.tr,
      AppAction.update => 'actUpdate'.tr,
      AppAction.delete => 'actDelete'.tr,
      AppAction.block => 'actBlock'.tr,
    };

/// Jedwali la ruhusa za mtumiaji: kila moduli na vitendo vyake vyenye maana tu.
class PermissionsPage extends StatefulWidget {
  final AppUser user;

  const PermissionsPage({super.key, required this.user});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  List<Permission> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  final Set<String> _saving = {};

  static const List<AppAction> _actions = [
    AppAction.select,
    AppAction.insert,
    AppAction.update,
    AppAction.delete,
    AppAction.block,
  ];

  bool get _canEdit => AppController.to.can(AppModule.permission, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await UserRepo.permissions(widget.user.id);
      list.sort((a, b) => moduleOrder(a.name).compareTo(moduleOrder(b.name)));
      if (!mounted) return;
      setState(() {
        _items = list;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _save(Permission updated) async {
    final index = _items.indexWhere((e) => e.id == updated.id);
    if (index < 0) return;
    final previous = _items[index];
    setState(() {
      _items = [..._items]..[index] = updated;
      _saving.add(updated.id);
    });
    try {
      await UserRepo.savePermission(updated);
      if (widget.user.id == AppController.to.user.value?.id) {
        await AppController.to.refreshPermissions();
      }
    } catch (e) {
      Toast.error(e);
      if (mounted) setState(() => _items = [..._items]..[index] = previous);
    } finally {
      if (mounted) setState(() => _saving.remove(updated.id));
    }
  }

  Future<void> _setAll(bool value) async {
    final ok = await confirmAction(
      title: value ? 'grantAll'.tr : 'revokeAll'.tr,
      message: (value ? 'grantAllMsg' : 'revokeAllMsg').trParams({'name': widget.user.fullName}),
      danger: !value,
      icon: value ? Icons.verified_user_outlined : Icons.remove_moderator_outlined,
    );
    if (!ok) return;
    for (final p in _items) {
      final acts = actionsFor(p.name);
      bool on(AppAction a) => value && (acts.contains(a) || a == AppAction.select);
      final next = p.copyWith(
          insert: on(AppAction.insert),
          update: on(AppAction.update),
          select: on(AppAction.select),
          delete: on(AppAction.delete),
          block: on(AppAction.block));
      await _save(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppPage(
      help: 'permissions',
      title: 'permissions'.tr,
      subtitle: '${widget.user.fullName} · @${widget.user.username}',
      showBack: true,
      actions: [
        if (_canEdit && _items.isNotEmpty)
          PopupMenuButton<bool>(
            tooltip: 'actions'.tr,
            onSelected: _setAll,
            itemBuilder: (context) => [
              PopupMenuItem(value: true, child: Text('grantAll'.tr)),
              PopupMenuItem(value: false, child: Text('revokeAll'.tr, style: TextStyle(color: p.danger))),
            ],
          ),
      ],
      body: _status == LoadStatus.loading
          ? const LoadingList()
          : _status == LoadStatus.error
              ? ErrorState(message: _error ?? '', onRetry: _load)
              : PageScroll(
                  children: [
                    if (!_canEdit)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.warning.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('readOnlyPermissions'.tr, style: TextStyle(color: p.warning)),
                      ),
                    Card(
                      child: LayoutBuilder(builder: (context, c) {
                        final bool wide = c.maxWidth >= 640;
                        return Column(
                          children: [
                            if (wide)
                              Container(
                                color: p.surfaceAlt,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text('module'.tr.toUpperCase(), style: _head(p)),
                                    ),
                                    for (final a in _actions)
                                      Expanded(
                                        flex: 2,
                                        child: Text(actionLabel(a).toUpperCase(), textAlign: TextAlign.center, style: _head(p)),
                                      ),
                                  ],
                                ),
                              ),
                            for (int i = 0; i < _items.length; i++) ...[
                              if (i > 0 || wide) Divider(height: 1, color: p.border),
                              wide ? _wideRow(context, _items[i]) : _narrowRow(context, _items[i]),
                            ],
                          ],
                        );
                      }),
                    ),
                  ],
                ),
    );
  }

  TextStyle _head(AppPalette p) =>
      TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .6);

  Widget _moduleTitle(BuildContext context, Permission perm) {
    final p = context.palette;
    return ModuleTitle(
      perm.name,
      trailing: _saving.contains(perm.id)
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
          : null,
    );
  }

  Widget _wideRow(BuildContext context, Permission perm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: _moduleTitle(context, perm)),
          for (final a in _actions)
            Expanded(
              flex: 2,
              child: Center(
                child: !actionsFor(perm.name).contains(a)
                    ? Text('—', style: TextStyle(color: context.palette.muted))
                    : Switch(
                  value: perm.allows(a),
                  onChanged: _canEdit ? (v) => _save(perm.withAction(a, v)) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _narrowRow(BuildContext context, Permission perm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleTitle(context, perm),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in actionsFor(perm.name))
                FilterChip(
                  label: Text(actionLabel(a)),
                  selected: perm.allows(a),
                  showCheckmark: true,
                  onSelected: _canEdit ? (v) => _save(perm.withAction(a, v)) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
