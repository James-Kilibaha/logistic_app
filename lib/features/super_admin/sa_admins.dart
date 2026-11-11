import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import 'platform_api.dart';
import 'platform_models.dart';
import 'sa_common.dart';

/// Wasimamizi wa mfumo (wewe na wasaidizi wako).
class SaAdmins extends StatefulWidget {
  const SaAdmins({super.key});

  @override
  State<SaAdmins> createState() => _SaAdminsState();
}

class _SaAdminsState extends State<SaAdmins> {
  int _version = 0;

  Future<List<PlatformAdminUser>> _load() async {
    final body = await PlatformApi.get('admins');
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => PlatformAdminUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  void _reload() => setState(() => _version++);

  Future<void> _edit([PlatformAdminUser? current]) async {
    final username = TextEditingController(text: current?.username ?? '');
    final fullName = TextEditingController(text: current?.fullName ?? '');
    final phone = TextEditingController(text: current?.phone ?? '');
    final email = TextEditingController(text: current?.email ?? '');
    final password = TextEditingController();
    bool active = current?.active ?? true;
    String role = current?.role ?? 'SUPPORT';
    final isMe = current != null && current.username == (Session.platformAdmin?['username'] ?? '');

    final ok = await showFormSheet(
      title: current == null ? 'saNewAdmin'.tr : 'saEditAdmin'.tr,
      icon: Icons.shield_outlined,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: username, label: 'username'.tr, enabled: current == null, required: true,
              validator: Validators.minLength(3)),
          const SizedBox(height: 14),
          AppField(controller: fullName, label: 'saFullName'.tr, required: true, validator: Validators.minLength(2)),
          const SizedBox(height: 14),
          PhoneField(controller: phone),
          const SizedBox(height: 14),
          AppField(controller: email, label: 'email'.tr),
          const SizedBox(height: 14),
          AppField(
            controller: password,
            label: current == null ? 'password'.tr : 'saNewPasswordOptional'.tr,
            helper: 'passwordPolicy'.tr,
            required: current == null,
            validator: (v) {
              if (current != null && (v ?? '').isEmpty) return null;
              return Validators.minLength(8)(v);
            },
          ),
          const SizedBox(height: 14),
          AppDropdown<String>(
            label: 'saRole'.tr,
            value: role,
            items: const ['OWNER', 'FINANCE', 'SUPPORT', 'VIEWER'],
            itemLabel: (r) => 'saRole_$r'.tr,
            icon: Icons.badge_outlined,
            onChanged: isMe ? null : (v) => setState(() => role = v ?? role),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('saRoleHelp_$role'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
          ),
          if (current != null && !isMe)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('saActive'.tr),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
        ],
      ),
      onSubmit: () {
        String? opt(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();
        if (current == null) {
          return PlatformApi.post('admins', {
            'username': username.text.trim(),
            'password': password.text,
            'fullName': fullName.text.trim(),
            'phone': opt(phone),
            'email': opt(email),
            'role': role,
          });
        }
        return PlatformApi.put('admins', {
          'id': current.id,
          'fullName': fullName.text.trim(),
          'phone': opt(phone),
          'email': opt(email),
          'active': active,
          if (!isMe) 'role': role,
          if (password.text.isNotEmpty) 'password': password.text,
        });
      },
    );
    if (ok) {
      Toast.success(fullName.text, title: 'saved'.tr);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaLoader<List<PlatformAdminUser>>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, admins, reload) {
        final p = context.palette;
        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(
              title: 'saAdmins'.tr,
              subtitle: 'saAdminsSub'.tr,
              actions: [
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: Text('saNewAdmin'.tr),
                ),
              ],
            ),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < admins.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    ListTile(
                      leading: Icon(admins[i].active ? Icons.shield_rounded : Icons.shield_outlined,
                          color: admins[i].active ? p.primary : p.muted),
                      title: Text('${admins[i].fullName} (${admins[i].username})'),
                      subtitle: Text([
                        if (admins[i].phone != null) Fmt.phone(admins[i].phone),
                        if (admins[i].email != null) admins[i].email!,
                        '${'saLastLogin'.tr}: ${Fmt.dateTime(admins[i].lastLoginAt)}',
                      ].join(' · ')),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!admins[i].active) Pill('saInactive'.tr, color: p.muted, dense: true),
                          Pill('saRole_${admins[i].role}'.tr, color: admins[i].role == 'OWNER' ? p.primary : p.info,
                              dense: true),
                          Pill(admins[i].totpEnabled ? '2FA' : 'sa2faOff'.tr,
                              color: admins[i].totpEnabled ? p.success : p.warning,
                              icon: admins[i].totpEnabled ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
                              dense: true),
                          if (admins[i].totpEnabled && admins[i].id != (Session.platformAdmin?['id'] ?? '').toString())
                            IconButton(
                              tooltip: 'sa2faReset'.tr,
                              icon: const Icon(Icons.phonelink_erase_rounded),
                              onPressed: () async {
                                final ok = await confirmAction(
                                  title: 'sa2faReset'.tr,
                                  message: 'sa2faResetMsg'.trParams({'name': admins[i].fullName}),
                                  icon: Icons.phonelink_erase_rounded,
                                  danger: true,
                                );
                                if (ok && await runGuarded(() => PlatformApi.resetTwoFactor(admins[i].id),
                                    success: 'sa2faResetDone'.tr)) {
                                  await reload();
                                }
                              },
                            ),
                          IconButton(
                            tooltip: 'edit'.tr,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(admins[i]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
