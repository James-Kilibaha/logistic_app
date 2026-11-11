import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/lookups.dart';
import '../../data/models/settings.dart';
import '../../data/models/role.dart';
import '../../data/models/user.dart';
import '../auth/change_password_page.dart';
import '../../data/repositories.dart';
import 'permissions_page.dart';

class UserFlows {
  UserFlows._();

  static Future<void> permissions(AppUser user) async {
    await Get.to(() => PermissionsPage(user: user));
  }

  static Future<void> edit({AppUser? user}) async {
    List<Office> offices = const [];
    try {
      offices = await Lookups.to.loadOffices();
    } catch (_) {}

    final first = TextEditingController(text: user?.firstName ?? '');
    final last = TextEditingController(text: user?.lastName ?? '');
    final phone = TextEditingController(text: user?.phoneNumber ?? '');
    final username = TextEditingController(text: user?.username ?? '');
    final password = TextEditingController();
    Office? office;
    for (final o in offices) {
      if (o.id == user?.officeId) office = o;
    }
    office ??= offices.isEmpty ? null : offices.first;
    bool allOffices = user?.allOffices ?? true;
    List<Role> roles = const [];
    Role? role;
    if (user == null && AppController.to.can(AppModule.permission, AppAction.update)) {
      try {
        roles = await RoleRepo.all();
      } catch (_) {}
    }
    bool hidden = true;

    final ok = await showFormSheet(
      help: 'formUser',
      title: user == null ? 'newUser'.tr : 'editUser'.tr,
      subtitle: user == null ? 'newUserSub'.tr : '@${user.username}',
      icon: user == null ? Icons.person_add_alt_1_outlined : Icons.manage_accounts_outlined,
      submitLabel: user == null ? 'createUser'.tr : 'saveChanges'.tr,
      builder: (context, setState) => Column(
        children: [
          FieldRow(children: [
            AppField(controller: first, label: 'firstName'.tr, required: true, capitalization: TextCapitalization.words),
            AppField(controller: last, label: 'lastName'.tr, required: true, capitalization: TextCapitalization.words),
          ]),
          const SizedBox(height: 16),
          PhoneField(controller: phone),
          const SizedBox(height: 16),
          if (offices.isNotEmpty) ...[
            AppDropdown<Office>(
              label: 'office'.tr,
              value: office,
              items: offices,
              required: false,
              icon: Icons.store_mall_directory_outlined,
              itemLabel: (o) => o.label,
              onChanged: (v) => setState(() => office = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: allOffices,
              onChanged: (v) => setState(() => allOffices = v),
              title: Text('seesAllOffices'.tr),
              subtitle: Text(allOffices ? 'seesAllOfficesOn'.tr : 'seesAllOfficesOff'.tr),
            ),
            const SizedBox(height: 8),
          ],
          if (roles.isNotEmpty) ...[
            AppDropdown<Role>(
              label: 'role'.tr,
              value: role,
              items: roles,
              required: false,
              hint: 'chooseRole'.tr,
              icon: Icons.badge_outlined,
              itemLabel: (r) => r.name,
              onChanged: (v) => setState(() => role = v),
            ),
            const SizedBox(height: 16),
          ],
          if (user == null) ...[
            AppField(
              controller: username,
              label: 'username'.tr,
              icon: Icons.alternate_email_rounded,
              required: true,
              validator: Validators.minLength(3),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: password,
              label: 'password'.tr,
              icon: Icons.lock_outline_rounded,
              required: true,
              obscure: hidden,
              helper: 'tempPasswordHelp'.tr,
              validator: passwordPolicy,
              suffix: IconButton(
                icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => hidden = !hidden),
              ),
            ),
          ],
        ],
      ),
      onSubmit: () => user == null
          ? UserRepo.create(
              firstName: first.text,
              lastName: last.text,
              phone: Phone.forApi(phone.text),
              username: username.text,
              password: password.text,
              officeId: office?.id,
              allOffices: allOffices,
              roleId: role?.id,
            )
          : UserRepo.update(
              id: user.id,
              firstName: first.text,
              lastName: last.text,
              phone: Phone.forApi(phone.text),
              officeId: office?.id,
              allOffices: allOffices,
            ),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success('${first.text} ${last.text}', title: user == null ? 'userCreated'.tr : 'changesSaved'.tr);
    }
  }

  static Future<void> changePassword(AppUser user) async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showFormSheet(
      help: 'formUser',
      title: 'resetPassword'.tr,
      subtitle: user.fullName,
      icon: Icons.password_rounded,
      builder: (context, setState) => Column(
        children: [
          AppField(
            controller: password,
            label: 'newPassword'.tr,
            icon: Icons.lock_outline_rounded,
            obscure: true,
            required: true,
            helper: 'tempPasswordHelp'.tr,
            validator: passwordPolicy,
          ),
          const SizedBox(height: 16),
          AppField(
            controller: confirm,
            label: 'confirmPassword'.tr,
            icon: Icons.lock_outline_rounded,
            obscure: true,
            required: true,
            validator: (v) => v != password.text ? 'passwordsDontMatch'.tr : null,
          ),
        ],
      ),
      onSubmit: () => UserRepo.changePassword(user.id, password.text),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success('tempPasswordSet'.trParams({'name': user.fullName}), title: 'passwordChanged'.tr);
    }
  }

  /// Kumpa mtumiaji role: ruhusa zake zinakuwa za role hiyo.
  static Future<void> assignRole(AppUser user) async {
    List<Role> roles;
    try {
      roles = await RoleRepo.all();
    } catch (e) {
      Toast.error(e);
      return;
    }
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null || !ctx.mounted) return;
    final picked = await showDialog<Object>(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: Text('${'assignRole'.tr} · ${user.fullName}'),
        children: [
          for (final r in roles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r.id == user.roleId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: r.description == null ? null : Text(r.description!),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'none'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded),
              title: Text('customPermissions'.tr),
              subtitle: Text('customPermissionsSub'.tr),
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final roleId = picked is Role ? picked.id : null;
    if (await runGuarded(() => RoleRepo.assign(user.id, roleId), success: 'changesSaved'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  static Future<void> logoutEverywhere(AppUser user) async {
    final ok = await confirmAction(
      title: 'logoutEverywhere'.tr,
      message: 'logoutUserEverywhereMsg'.trParams({'name': user.fullName}),
      confirmText: 'logoutEverywhere'.tr,
      icon: Icons.devices_other_rounded,
      danger: true,
    );
    if (!ok) return;
    await runGuarded(() => UserRepo.logoutEverywhere(user.id), success: 'loggedOutEverywhere'.tr);
  }

  /// Uthibitisho wa hatua mbili: code ya SMS inahitajika kila anapoingia.
  static Future<void> toggleTwoFactor(AppUser user) async {
    final enabling = !user.twoFactor;
    final ok = await confirmAction(
      title: enabling ? 'twoFactorOn'.tr : 'twoFactorOff'.tr,
      message: (enabling ? 'twoFactorOnMsg' : 'twoFactorOffMsg')
          .trParams({'name': user.fullName, 'phone': Fmt.phone(user.phoneNumber)}),
      confirmText: enabling ? 'enable'.tr : 'disable'.tr,
      icon: Icons.verified_user_outlined,
      danger: !enabling,
    );
    if (!ok) return;
    if (await runGuarded(() => UserRepo.setTwoFactor(user.id, enabling), success: 'changesSaved'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  static Future<void> toggleBlock(AppUser user) async {
    final blocking = user.isActive;
    final ok = await confirmAction(
      title: blocking ? 'blockUser'.tr : 'unblockUser'.tr,
      message: (blocking ? 'blockUserMsg' : 'unblockUserMsg').trParams({'name': user.fullName}),
      confirmText: blocking ? 'block'.tr : 'unblock'.tr,
      icon: blocking ? Icons.block_rounded : Icons.lock_open_rounded,
      danger: blocking,
    );
    if (!ok) return;
    if (await runGuarded(() => UserRepo.toggleBlock(user.id), success: 'changesSaved'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  static Future<void> delete(AppUser user) async {
    final ok = await confirmAction(
      title: 'deleteUser'.tr,
      message: 'deleteUserMsg'.trParams({'name': user.fullName}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    if (await runGuarded(() => UserRepo.delete(user.id), success: 'deleted'.tr)) {
      AppController.to.notifyChanged();
    }
  }
}
