import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models/json.dart';
import '../../data/repositories.dart';

/// "Umesahau nywila?": hatua 1 = jina la mtumiaji (code inatumwa kwa SMS), hatua 2 = code + nywila mpya.
/// Inarudisha jina la mtumiaji nywila ikibadilishwa (ili skrini ya kuingia iweke jina).
///
/// [request] / [reset]: kwa super admin (`/api/platform/forgot`) - kawaida ni watumiaji wa kampuni.
Future<String?> showForgotPassword({
  String? username,
  Future<Map<String, dynamic>> Function(String username)? request,
  Future<void> Function(String token, String code, String password)? reset,
  String fieldLabelKey = 'usernameOrPhone',
}) async {
  final name = TextEditingController(text: username ?? '');
  String? token;
  String phoneHint = '';
  String? account;
  int ttl = 5;
  final step1 = await showFormSheet(
    help: 'forgotPassword',
    title: 'forgotPassword'.tr,
    subtitle: 'forgotPasswordSub'.tr,
    icon: Icons.lock_reset_rounded,
    submitLabel: 'sendCode'.tr,
    submitIcon: Icons.sms_outlined,
    builder: (context, setState) => AppField(
      controller: name,
      label: fieldLabelKey.tr,
      hint: 'usernameOrPhoneHint'.tr,
      icon: Icons.person_outline_rounded,
      required: true,
      autofocus: true,
    ),
    onSubmit: () async {
      final res = await (request ?? AuthRepo.forgot)(name.text);
      token = J.strOrNull(res['resetToken']);
      ttl = J.integer(res['ttlMinutes'], 5);
      final sentTo = res['sentTo'] is List ? (res['sentTo'] as List).map((e) => '$e').join(', ') : '';
      phoneHint = sentTo.isNotEmpty ? sentTo : J.str(res['phoneHint']);
      account = J.strOrNull(res['username']);
    },
  );
  if (!step1 || token == null) return null;

  final code = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  bool hidden = true;
  final step2 = await showFormSheet(
    help: 'forgotPassword',
    title: 'resetPassword'.tr,
    subtitle: (request == null ? 'resetPasswordSub' : 'resetPasswordSentTo').trParams({'phone': phoneHint, 'm': '$ttl'}),
    icon: Icons.password_rounded,
    submitLabel: 'savePassword'.tr,
    submitIcon: Icons.check_rounded,
    builder: (context, setState) => Column(
      children: [
        AppField(
          controller: code,
          label: 'otpCode'.tr,
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          required: true,
          autofocus: true,
        ),
        const SizedBox(height: 14),
        AppField(
          controller: pass,
          label: 'newPassword'.tr,
          icon: Icons.lock_outline_rounded,
          obscure: hidden,
          required: true,
          helper: 'passwordRule'.tr,
          suffix: IconButton(
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        AppField(
          controller: confirm,
          label: 'confirmPassword'.tr,
          icon: Icons.lock_outline_rounded,
          obscure: hidden,
          required: true,
          validator: (v) => v != pass.text ? 'passwordsDontMatch'.tr : null,
        ),
      ],
    ),
    onSubmit: () => (reset ?? AuthRepo.resetPassword)(token!, code.text, pass.text),
  );
  if (!step2) return null;
  Toast.success('passwordResetDone'.tr, title: 'resetPassword'.tr);
  return account ?? name.text.trim();
}
