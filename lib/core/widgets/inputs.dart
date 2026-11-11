import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Kichwa kidogo juu ya sehemu ya fomu.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required) TextSpan(text: ' *', style: TextStyle(color: p.danger)),
          ],
        ),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text.withValues(alpha: .85)),
      ),
    );
  }
}

/// Sehemu ya kuandika yenye kichwa juu (mtindo mmoja kwa fomu zote).
class AppField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool obscure;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool required;
  final int maxLines;
  final int? minLines;
  final TextCapitalization capitalization;

  const AppField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.obscure = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.required = false,
    this.maxLines = 1,
    this.minLines,
    this.capitalization = TextCapitalization.none,
  });

  /// Kiasi cha pesa (koma za maelfu zinaongezwa wakati wa kuandika).
  factory AppField.money({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
    bool required = true,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) =>
      AppField(
        key: key,
        controller: controller,
        label: label,
        hint: hint ?? '0',
        helper: helper,
        icon: icon ?? Icons.payments_outlined,
        required: required,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [ThousandsFormatter(allowDecimal: true)],
        onChanged: onChanged,
        validator: validator ?? (required ? Validators.positive : null),
      );

  /// Namba (uzito, idadi, vipimo).
  factory AppField.number({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
    String? suffixText,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) =>
      AppField(
        key: key,
        controller: controller,
        label: label,
        hint: hint ?? '0',
        helper: helper,
        icon: icon,
        required: required,
        suffix: suffixText == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(widthFactor: 1, child: Text(suffixText)),
              ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: onChanged,
        validator: required ? Validators.positive : null,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction ?? (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
          inputFormatters: inputFormatters,
          validator: validator ?? (required ? Validators.required : null),
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          obscureText: obscure,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLines: obscure ? 1 : maxLines,
          minLines: minLines,
          textCapitalization: capitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Orodha ya kuchagua (dropdown) yenye kichwa juu.
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final IconData? icon;
  final bool required;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.onChanged,
    this.hint,
    this.icon,
    this.required = true,
    this.validator,
  });

  String? _requiredValue(T? v) => v == null ? 'fieldRequired'.tr : null;

  @override
  Widget build(BuildContext context) {
    final T? selected = value != null && items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        DropdownButtonFormField<T>(
          key: ValueKey<Object?>(selected),
          initialValue: selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: context.palette.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item, child: Text(itemLabel(item), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
          validator: validator ?? (required ? _requiredValue : null),
          decoration: InputDecoration(
            hintText: hint ?? 'select'.tr,
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Uhakiki wa sehemu za fomu.
class Validators {
  Validators._();

  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'fieldRequired'.tr : null;

  /// Namba si lazima; ikiandikwa lazima iwe sahihi: Tanzania (+255...) au ya nchi nyingine (+code...).
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Phone.normalize(v) == null ? 'invalidPhoneFormat'.tr : null;
  }

  /// Namba inayohitajika (mf. kutuma ujumbe kwa namba).
  static String? phoneRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'fieldRequired'.tr;
    return phone(v);
  }

  static String? positive(String? v) {
    final n = Fmt.parse(v);
    if (n == null) return 'fieldRequired'.tr;
    if (n <= 0) return 'mustBePositive'.tr;
    return null;
  }

  static String? number(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Fmt.parse(v) == null ? 'invalidNumber'.tr : null;
  }

  static String? Function(String?) minLength(int n) =>
      (v) => (v == null || v.trim().length < n) ? 'minChars'.trParams({'n': '$n'}) : null;
}

/// Sehemu ya namba ya simu: si lazima (isipokuwa [required]); inakubali za Tanzania na za kimataifa (+code)
/// mtumiaji akitoka kwenye sehemu (0712 345 678 -> +255712345678).
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final bool required;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  const PhoneField({
    super.key,
    required this.controller,
    this.label,
    this.required = false,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
  });

  void _tidy() {
    final n = Phone.normalize(controller.text);
    if (n != null && n != controller.text) {
      controller.text = n;
      onChanged?.call(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      onFocusChange: (has) {
        if (!has) _tidy();
      },
      child: AppField(
        controller: controller,
        label: label ?? (required ? 'phone'.tr : 'phoneOptional'.tr),
        hint: Phone.example,
        helper: 'phoneFormatHelp'.tr,
        icon: Icons.phone_outlined,
        required: required,
        readOnly: readOnly,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-()]'))],
        validator: required ? Validators.phoneRequired : Validators.phone,
        onChanged: onChanged,
      ),
    );
  }
}

/// Mpangilio wa sehemu mbili (au zaidi) kwa mstari mmoja kwenye skrini pana,
/// na moja chini ya nyingine kwenye simu.
class FieldRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const FieldRow({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

/// Sehemu ya kutafuta (juu ya orodha).
class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  const SearchBox({super.key, required this.controller, required this.hint, required this.onChanged, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return trailing ?? const SizedBox.shrink();
            return IconButton(
              tooltip: 'clear'.tr,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            );
          },
        ),
      ),
    );
  }
}
