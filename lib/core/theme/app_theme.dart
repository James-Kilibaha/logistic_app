import 'package:flutter/material.dart';

/// Rangi za kawaida za mfumo (kila kampuni inaweza kuweka rangi zake - tazama core/branding.dart).
///
/// Bluu ya "cobalt" ni rangi kuu (vitufe, menyu iliyochaguliwa, viungo) na
/// "amber" ni rangi ya pili (alama za mizigo, takwimu muhimu).
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF1F4FD8);
  static const Color brandOnDark = Color(0xFF8AA6FF);
  static const Color accent = Color(0xFFF59E0B);

  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0369A1);

  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color infoDark = Color(0xFF38BDF8);
}

/// Rangi za ziada ambazo `ColorScheme` haina (zinapatikana kwa `context.palette`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primarySoft;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  static const AppPalette light = AppPalette(
    background: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F9FC),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    primary: AppColors.brand,
    primarySoft: Color(0xFFE8EEFD),
    accent: AppColors.accent,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0B1120),
    surface: Color(0xFF111A2E),
    surfaceAlt: Color(0xFF17223A),
    border: Color(0xFF243049),
    text: Color(0xFFE6EAF2),
    muted: Color(0xFF94A3B8),
    primary: AppColors.brandOnDark,
    primarySoft: Color(0xFF1D2A4D),
    accent: Color(0xFFFBBF24),
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    info: AppColors.infoDark,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? muted,
    Color? primary,
    Color? primarySoft,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      border: mix(border, other.border),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      primary: mix(primary, other.primary),
      primarySoft: mix(primarySoft, other.primarySoft),
      accent: mix(accent, other.accent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
    );
  }
}

/// Upana wa skrini unaobadilisha mpangilio.
class Breakpoints {
  Breakpoints._();

  /// Chini ya hapa: simu (menyu chini, fomu kwenye bottom sheet).
  static const double medium = 720;

  /// Kuanzia hapa: kompyuta (sidebar kamili, meza pana).
  static const double wide = 1100;
}

/// Njia fupi za kufikia theme kutoka kwenye `BuildContext`.
///
/// Majina haya yamechaguliwa yasigongane na extensions za GetX
/// (`context.theme`, `context.width`, `context.isTablet` ...).
extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Kompyuta / skrini pana.
  bool get isWide => screenWidth >= Breakpoints.wide;

  /// Tablet au zaidi.
  bool get isMediumUp => screenWidth >= Breakpoints.medium;
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'HurmeGeometricSans4';

  /// [primary]/[accent] = rangi za kampuni (branding); `null` = rangi za kawaida.
  static ThemeData light({Color? primary, Color? accent}) {
    var p = AppPalette.light;
    if (primary != null) {
      p = p.copyWith(primary: primary, primarySoft: Color.lerp(Colors.white, primary, .10));
    }
    if (accent != null) p = p.copyWith(accent: accent);
    return _build(Brightness.light, p);
  }

  static ThemeData dark({Color? primary, Color? accent}) {
    var p = AppPalette.dark;
    if (primary != null) {
      final onDark = Color.lerp(primary, Colors.white, .38)!;
      p = p.copyWith(primary: onDark, primarySoft: Color.lerp(AppPalette.dark.surface, primary, .32));
    }
    if (accent != null) p = p.copyWith(accent: Color.lerp(accent, Colors.white, .15));
    return _build(Brightness.dark, p);
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final bool dark = brightness == Brightness.dark;
    final Color onPrimary = dark ? const Color(0xFF0B1120) : Colors.white;

    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness).copyWith(
      primary: p.primary,
      onPrimary: onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primary,
      secondary: p.accent,
      onSecondary: const Color(0xFF1F1300),
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surfaceAlt,
      surfaceContainer: p.surfaceAlt,
      surfaceContainerHigh: p.surfaceAlt,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
      outlineVariant: p.border,
      error: p.danger,
      onError: Colors.white,
    );

    final BorderRadius r10 = BorderRadius.circular(10);
    final BorderRadius r14 = BorderRadius.circular(14);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: color, width: width));

    final TextStyle buttonText = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 14.5,
      letterSpacing: .2,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
    );

    final TextTheme text = base.textTheme
        .apply(bodyColor: p.text, displayColor: p.text, fontFamily: fontFamily)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: p.text),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: p.text),
          titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          bodySmall: base.textTheme.bodySmall?.copyWith(color: p.muted),
        );

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.muted, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        shape: Border(bottom: BorderSide(color: p.border)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: r14, side: BorderSide(color: p.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? p.surfaceAlt : p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        disabledBorder: inputBorder(p.border.withValues(alpha: .5)),
        focusedBorder: inputBorder(p.primary, 1.6),
        errorBorder: inputBorder(p.danger),
        focusedErrorBorder: inputBorder(p.danger, 1.6),
        labelStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: .8)),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        helperStyle: TextStyle(color: p.muted, fontSize: 12),
        errorStyle: TextStyle(color: p.danger, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: r10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: r10)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primarySoft,
        disabledColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: fontFamily, color: p.text, fontWeight: FontWeight.w500, fontSize: 13),
        secondaryLabelStyle: TextStyle(fontFamily: fontFamily, color: p.primary, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        checkmarkColor: p.primary,
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14.5, color: p.text, height: 1.4),
        barrierColor: Colors.black.withValues(alpha: .45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySoft,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primary : p.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? p.primary : p.muted, size: 24);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        textColor: p.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: r10),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, color: p.muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.muted,
        indicatorColor: p.primary,
        dividerColor: p.border,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.border)),
        textStyle: TextStyle(fontFamily: fontFamily, color: p.text, fontSize: 14),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.border)),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE6EAF2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: dark ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 12.5,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimary : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: p.muted, width: 1.4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          selectedBackgroundColor: p.primarySoft,
          selectedForegroundColor: p.primary,
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(6),
        thumbColor: WidgetStatePropertyAll(p.muted.withValues(alpha: .35)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.primary,
        headerForegroundColor: onPrimary,
        rangeSelectionBackgroundColor: p.primarySoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
