import 'package:flutter/material.dart';

/// Centralised theme definitions — light and dark.
///
/// Color values mirror RN's source/styles/index.js exactly:
///   Light: background-color=#ffffff, font-color=#050505, border-color=#f0f0f0
///   Dark:  background-color=#18191a, font-color=#e4e6eb, border-color=#2d2f30
abstract class AppTheme {
  static const _primary = Color(0xFF1877F2); // RN: primary-color

  // ── Light theme ─────────────────────────────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
        seedColor: _primary, brightness: Brightness.light),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: const Color(0xFFFFFFFF), // RN: background-color light
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF050505), // RN: font-color light
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: const Color(0xFFFFFFFF),
    dividerColor: const Color(0xFFF0F0F0), // RN: border-color light
    listTileTheme: const ListTileThemeData(
      tileColor: Color(0xFFFFFFFF),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F0F0), // RN: search-background-color light
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? _primary
              : const Color(0xFFF4F3F4)),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF81B0FF)
              : const Color(0xFF767577)),
    ),
    extensions: const [CircuitChatColors.light],
  );

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
        seedColor: _primary, brightness: Brightness.dark),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: const Color(0xFF18191A), // RN: background-color dark
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF242526), // RN: tabbar-background-color dark
      foregroundColor: Color(0xFFE4E6EB), // RN: font-color dark
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: const Color(0xFF2F3031), // RN: background-alt-color dark
    dividerColor: const Color(0xFF2D2F30), // RN: border-color dark
    listTileTheme: const ListTileThemeData(
      tileColor: Color(0xFF2F3031),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF18191A), // RN: composer-input-background dark
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2F30))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? _primary
              : const Color(0xFFF4F3F4)),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF81B0FF)
              : const Color(0xFF767577)),
    ),
    extensions: const [CircuitChatColors.dark],
  );
}

// ── Custom semantic color extension ──────────────────────────────────────────
/// Access via: `Theme.of(context).extension<CircuitChatColors>()!`
/// All values match RN's styles/index.js variables.
@immutable
class CircuitChatColors extends ThemeExtension<CircuitChatColors> {
  const CircuitChatColors({
    required this.pageBackground,
    required this.surfaceBackground,
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.inputBackground,
    required this.bubbleMe,
    required this.bubbleMeText,
    required this.bubbleOther,
    required this.bubbleOtherText,
    required this.divider,
    required this.searchBackground,
    required this.tabBarBackground,
    required this.overlay,
  });

  final Color pageBackground;
  final Color surfaceBackground;  // slightly elevated surface (alt-background)
  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color inputBackground;
  final Color bubbleMe;
  final Color bubbleMeText;
  final Color bubbleOther;
  final Color bubbleOtherText;
  final Color divider;
  final Color searchBackground;
  final Color tabBarBackground;
  final Color overlay;

  // ── Light (mirrors RN light variables) ────────────────────────────────────
  static const light = CircuitChatColors(
    pageBackground:   Color(0xFFFFFFFF), // background-color
    surfaceBackground:Color(0xFFF7F7F7), // background-alt-color
    cardBackground:   Color(0xFFFFFFFF),
    primaryText:      Color(0xFF050505), // font-color
    secondaryText:    Color(0xFF8A8D91), // font-light-color
    border:           Color(0xFFF0F0F0), // border-color
    inputBackground:  Color(0xFFF0F0F0), // search-background-color
    bubbleMe:         Color(0xFF1877F2), // primary-color (sent)
    bubbleMeText:     Color(0xFFFFFFFF),
    bubbleOther:      Color(0xFFF1F1F1), // chat-bubble-color light
    bubbleOtherText:  Color(0xFF050505),
    divider:          Color(0xFFF0F0F0),
    searchBackground: Color(0xFFF0F0F0),
    tabBarBackground: Color(0xFFF9F9F9),
    overlay:          Color(0x99F4F4F4),
  );

  // ── Dark (mirrors RN dark variables) ──────────────────────────────────────
  static const dark = CircuitChatColors(
    pageBackground:   Color(0xFF18191A), // background-color dark
    surfaceBackground:Color(0xFF2F3031), // background-alt-color dark
    cardBackground:   Color(0xFF2F3031),
    primaryText:      Color(0xFFE4E6EB), // font-color dark
    secondaryText:    Color(0xFFB0B3B8), // font-light-color dark
    border:           Color(0xFF2D2F30), // border-color dark
    inputBackground:  Color(0xFF18191A), // composer-input-background dark
    bubbleMe:         Color(0xFF1877F2), // same primary in dark
    bubbleMeText:     Color(0xFFFFFFFF),
    bubbleOther:      Color(0xFF242526), // chat-bubble-color dark
    bubbleOtherText:  Color(0xFFE4E6EB),
    divider:          Color(0xFF2D2F30),
    searchBackground: Color(0xFF3C3D3F), // background-alt-active-color dark
    tabBarBackground: Color(0xFF242526), // tabbar-background-color dark
    overlay:          Color(0x80000000),
  );

  @override
  CircuitChatColors copyWith({
    Color? pageBackground, Color? surfaceBackground, Color? cardBackground,
    Color? primaryText, Color? secondaryText, Color? border,
    Color? inputBackground, Color? bubbleMe, Color? bubbleMeText,
    Color? bubbleOther, Color? bubbleOtherText, Color? divider,
    Color? searchBackground, Color? tabBarBackground, Color? overlay,
  }) =>
      CircuitChatColors(
        pageBackground:   pageBackground   ?? this.pageBackground,
        surfaceBackground:surfaceBackground ?? this.surfaceBackground,
        cardBackground:   cardBackground   ?? this.cardBackground,
        primaryText:      primaryText      ?? this.primaryText,
        secondaryText:    secondaryText    ?? this.secondaryText,
        border:           border           ?? this.border,
        inputBackground:  inputBackground  ?? this.inputBackground,
        bubbleMe:         bubbleMe         ?? this.bubbleMe,
        bubbleMeText:     bubbleMeText     ?? this.bubbleMeText,
        bubbleOther:      bubbleOther      ?? this.bubbleOther,
        bubbleOtherText:  bubbleOtherText  ?? this.bubbleOtherText,
        divider:          divider          ?? this.divider,
        searchBackground: searchBackground ?? this.searchBackground,
        tabBarBackground: tabBarBackground ?? this.tabBarBackground,
        overlay:          overlay          ?? this.overlay,
      );

  @override
  CircuitChatColors lerp(CircuitChatColors? other, double t) {
    if (other == null) return this;
    return CircuitChatColors(
      pageBackground:   Color.lerp(pageBackground,   other.pageBackground,   t)!,
      surfaceBackground:Color.lerp(surfaceBackground,other.surfaceBackground,t)!,
      cardBackground:   Color.lerp(cardBackground,   other.cardBackground,   t)!,
      primaryText:      Color.lerp(primaryText,      other.primaryText,      t)!,
      secondaryText:    Color.lerp(secondaryText,     other.secondaryText,    t)!,
      border:           Color.lerp(border,           other.border,           t)!,
      inputBackground:  Color.lerp(inputBackground,  other.inputBackground,  t)!,
      bubbleMe:         Color.lerp(bubbleMe,         other.bubbleMe,         t)!,
      bubbleMeText:     Color.lerp(bubbleMeText,     other.bubbleMeText,     t)!,
      bubbleOther:      Color.lerp(bubbleOther,      other.bubbleOther,      t)!,
      bubbleOtherText:  Color.lerp(bubbleOtherText,  other.bubbleOtherText,  t)!,
      divider:          Color.lerp(divider,          other.divider,          t)!,
      searchBackground: Color.lerp(searchBackground, other.searchBackground, t)!,
      tabBarBackground: Color.lerp(tabBarBackground, other.tabBarBackground, t)!,
      overlay:          Color.lerp(overlay,          other.overlay,          t)!,
    );
  }
}

/// Convenience extension on [BuildContext] — avoids the verbose
/// `Theme.of(context).extension<CircuitChatColors>()!` in every widget.
extension ThemeContextX on BuildContext {
  CircuitChatColors get cc =>
      Theme.of(this).extension<CircuitChatColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
