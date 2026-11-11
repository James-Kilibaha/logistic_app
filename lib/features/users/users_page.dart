import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/user.dart';
import 'roles_page.dart';
import 'user_flows.dart';
import 'users_controller.dart';

class UsersPage extends GetView<UsersController> {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    return AppPage(
      help: 'users',
      title: 'navUsers'.tr,
      subtitle: 'hintUsers'.tr,
      actions: [
        if (can(AppModule.permission))
          TextButton.icon(
            onPressed: () async {
              await Get.to(() => const RolesPage());
              controller.load();
            },
            icon: const Icon(Icons.badge_outlined, size: 20),
            label: Text('roles'.tr),
          ),
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: can(AppModule.user, AppAction.insert)
          ? PageAction(icon: Icons.person_add_alt_1_rounded, label: 'newUser'.tr, onPressed: () => UserFlows.edit())
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchUserHint'.tr, onChanged: controller.onSearch),
          ),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(icon: Icons.manage_accounts_outlined, title: 'noUsers'.tr),
                builder: () => DataList<AppUser>(
                  items: list,
                  onRefresh: controller.refreshList,
                  onTap: can(AppModule.permission) ? UserFlows.permissions : null,
                  columns: [
                    ColumnSpec('user'.tr, flex: 4),
                    ColumnSpec('phone'.tr, flex: 3),
                    ColumnSpec('role'.tr, flex: 3),
                    ColumnSpec('office'.tr, flex: 3),
                    ColumnSpec('status'.tr, flex: 2),
                  ],
                  cells: (context, u) => [
                    Row(
                      children: [
                        Initials(u.initials, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: CellText(u.fullName, sub: '@${u.username}', bold: true)),
                      ],
                    ),
                    CellText(Fmt.phone(u.phoneNumber), sub: u.twoFactor ? 'twoFactorShort'.tr : null),
                    CellText(controller.roleName(u.roleId) ?? 'customPermissions'.tr),
                    CellText(u.office?.name ?? '—', sub: u.office?.location),
                    _UserStatus(user: u),
                  ],
                  actions: (context, u) => _UserMenu(user: u),
                  card: (context, u) => Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      children: [
                        Initials(u.initials, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              Text(
                                '@${u.username} · ${controller.roleName(u.roleId) ?? 'customPermissions'.tr} · ${u.office?.name ?? '—'}',
                                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                              ),
                              const SizedBox(height: 6),
                              _UserStatus(user: u),
                            ],
                          ),
                        ),
                        _UserMenu(user: u),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _UserStatus extends StatelessWidget {
  final AppUser user;

  const _UserStatus({required this.user});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = AppController.to.user.value?.id == user.id;
    return Wrap(
      spacing: 6,
      children: [
        user.isActive ? Pill('active'.tr, color: p.success, dense: true) : Pill('blocked'.tr, color: p.danger, dense: true),
        if (user.mustChangePassword) Pill('pendingPassword'.tr, color: p.warning, dense: true),
        if (me) Pill('you'.tr, color: p.primary, dense: true),
      ],
    );
  }
}

class _UserMenu extends StatelessWidget {
  final AppUser user;

  const _UserMenu({required this.user});

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    final p = context.palette;
    final me = AppController.to.user.value?.id == user.id;
    return PopupMenuButton<String>(
      tooltip: 'actions'.tr,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) {
        switch (v) {
          case 'perm':
            UserFlows.permissions(user);
          case 'edit':
            UserFlows.edit(user: user);
          case 'password':
            UserFlows.changePassword(user);
          case 'block':
            UserFlows.toggleBlock(user);
          case 'role':
            UserFlows.assignRole(user);
          case 'devices':
            UserFlows.logoutEverywhere(user);
          case '2fa':
            UserFlows.toggleTwoFactor(user);
          case 'delete':
            UserFlows.delete(user);
        }
      },
      itemBuilder: (context) => [
        if (can(AppModule.permission, AppAction.update)) PopupMenuItem(value: 'role', child: Text('assignRole'.tr)),
        if (can(AppModule.permission)) PopupMenuItem(value: 'perm', child: Text('permissions'.tr)),
        if (can(AppModule.user, AppAction.update)) ...[
          PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
          PopupMenuItem(value: 'password', child: Text('resetPassword'.tr)),
          PopupMenuItem(value: '2fa', child: Text(user.twoFactor ? 'twoFactorOff'.tr : 'twoFactorOn'.tr)),
          if (!me) PopupMenuItem(value: 'devices', child: Text('logoutEverywhere'.tr)),
        ],
        if (!me && can(AppModule.user, AppAction.block))
          PopupMenuItem(value: 'block', child: Text(user.isActive ? 'block'.tr : 'unblock'.tr)),
        if (!me && can(AppModule.user, AppAction.delete))
          PopupMenuItem(value: 'delete', child: Text('delete'.tr, style: TextStyle(color: p.danger))),
      ],
    );
  }
}
