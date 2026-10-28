import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Enamel colours beyond Material's roles: the jade hero field, the tier
/// palette used for budgets and categories, and the Saved tier.
@immutable
class Enamel extends ThemeExtension<Enamel> {
  /// Jade field behind the Home hero and other "shell" regions.
  final Color field;
  final Color onField;
  final Color onFieldMuted;

  /// Track behind tier fill bars.
  final Color track;

  final Color cash;
  final Color card;
  final Color saved;
  final Color onSaved;
  final Color onSavedMuted;
  final Color over;

  /// Named enamel colours, used for categories.
  final Color tangerine;
  final Color leaf;
  final Color cobalt;
  final Color coral;
  final Color plum;
  final Color teal;
  final Color rose;
  final Color ochre;
  final Color slate;

  const Enamel({
    required this.field,
    required this.onField,
    required this.onFieldMuted,
    required this.track,
    required this.cash,
    required this.card,
    required this.saved,
    required this.onSaved,
    required this.onSavedMuted,
    required this.over,
    required this.tangerine,
    required this.leaf,
    required this.cobalt,
    required this.coral,
    required this.plum,
    required this.teal,
    required this.rose,
    required this.ochre,
    required this.slate,
  });

  List<Color> get categoryCycle =>
      [tangerine, leaf, cobalt, coral, plum, teal, rose, ochre, slate];

  static const light = Enamel(
    field: Color(0xFF1E6F66),
    onField: Color(0xFFFFFFFF),
    onFieldMuted: Color(0xFFCDE7E2),
    track: Color(0xFFE3EBE7),
    cash: Color(0xFFD9607F),
    card: Color(0xFF2D4A8A),
    saved: Color(0xFF1E6F66),
    onSaved: Color(0xFFFFFFFF),
    onSavedMuted: Color(0xFFCDE7E2),
    over: Color(0xFFB3261E),
    tangerine: Color(0xFFD9692A),
    leaf: Color(0xFF4F8A32),
    cobalt: Color(0xFF2D4A8A),
    coral: Color(0xFFD9607F),
    plum: Color(0xFF7D4A93),
    teal: Color(0xFF237F86),
    rose: Color(0xFFB8475A),
    ochre: Color(0xFFB78516),
    slate: Color(0xFF5B6B7A),
  );

  static const dark = Enamel(
    field: Color(0xFF134A44),
    onField: Color(0xFFE6F2EF),
    onFieldMuted: Color(0xFFA9CFC8),
    track: Color(0xFF26332F),
    cash: Color(0xFFF08FA8),
    card: Color(0xFF93AEEA),
    saved: Color(0xFF6CC3B6),
    onSaved: Color(0xFF00332D),
    onSavedMuted: Color(0xFF0E4A43),
    over: Color(0xFFFFB4AB),
    tangerine: Color(0xFFF0A070),
    leaf: Color(0xFF9CCB7C),
    cobalt: Color(0xFF93AEEA),
    coral: Color(0xFFF08FA8),
    plum: Color(0xFFC79BDA),
    teal: Color(0xFF7CCBD0),
    rose: Color(0xFFEE98A6),
    ochre: Color(0xFFE6C06A),
    slate: Color(0xFFA9B6C2),
  );

  @override
  Enamel copyWith() => this;

  @override
  Enamel lerp(ThemeExtension<Enamel>? other, double t) {
    if (other is! Enamel) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Enamel(
      field: l(field, other.field),
      onField: l(onField, other.onField),
      onFieldMuted: l(onFieldMuted, other.onFieldMuted),
      track: l(track, other.track),
      cash: l(cash, other.cash),
      card: l(card, other.card),
      saved: l(saved, other.saved),
      onSaved: l(onSaved, other.onSaved),
      onSavedMuted: l(onSavedMuted, other.onSavedMuted),
      over: l(over, other.over),
      tangerine: l(tangerine, other.tangerine),
      leaf: l(leaf, other.leaf),
      cobalt: l(cobalt, other.cobalt),
      coral: l(coral, other.coral),
      plum: l(plum, other.plum),
      teal: l(teal, other.teal),
      rose: l(rose, other.rose),
      ochre: l(ochre, other.ochre),
      slate: l(slate, other.slate),
    );
  }
}

extension EnamelContext on BuildContext {
  Enamel get enamel => Theme.of(this).extension<Enamel>()!;
}

/// Money and other figures line up in columns.
const tabular = [FontFeature.tabularFigures()];

class AppTheme {
  static const _butter = Color(0xFFF2C14E);
  static const _onButter = Color(0xFF2A2005);

  static final ColorScheme _lightScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1E6F66),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBFE6DE),
    onPrimaryContainer: Color(0xFF00332D),
    secondary: Color(0xFF8A6A12),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFE7A8),
    onSecondaryContainer: _onButter,
    tertiary: Color(0xFF2D4A8A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD9E2FF),
    onTertiaryContainer: Color(0xFF0B1B45),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF3F7F4),
    onSurface: Color(0xFF16201E),
    onSurfaceVariant: Color(0xFF46534F),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFBFDFB),
    surfaceContainer: Color(0xFFEAF0EC),
    surfaceContainerHigh: Color(0xFFE3EBE7),
    surfaceContainerHighest: Color(0xFFDCE5E0),
    outline: Color(0xFF74817D),
    outlineVariant: Color(0xFFC4D0CB),
    inverseSurface: Color(0xFF2A3532),
    onInverseSurface: Color(0xFFEDF3F0),
    inversePrimary: Color(0xFF7FCFC2),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static final ColorScheme _darkScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7FCFC2),
    onPrimary: Color(0xFF00382F),
    primaryContainer: Color(0xFF145048),
    onPrimaryContainer: Color(0xFFBFE6DE),
    secondary: Color(0xFFE9C46A),
    onSecondary: Color(0xFF3C2F00),
    secondaryContainer: Color(0xFF574500),
    onSecondaryContainer: Color(0xFFFFE7A8),
    tertiary: Color(0xFFB0C6FF),
    onTertiary: Color(0xFF14295C),
    tertiaryContainer: Color(0xFF2D4A8A),
    onTertiaryContainer: Color(0xFFD9E2FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0F1715),
    onSurface: Color(0xFFE2EBE7),
    onSurfaceVariant: Color(0xFFB0BEB9),
    surfaceContainerLowest: Color(0xFF0A1110),
    surfaceContainerLow: Color(0xFF151F1C),
    surfaceContainer: Color(0xFF19241F),
    surfaceContainerHigh: Color(0xFF212D29),
    surfaceContainerHighest: Color(0xFF2B3834),
    outline: Color(0xFF8A9893),
    outlineVariant: Color(0xFF3D4A46),
    inverseSurface: Color(0xFFE2EBE7),
    onInverseSurface: Color(0xFF2A3532),
    inversePrimary: Color(0xFF1E6F66),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData get lightTheme => _build(_lightScheme, Enamel.light);
  static ThemeData get darkTheme => _build(_darkScheme, Enamel.dark);

  static ThemeData _build(ColorScheme scheme, Enamel enamel) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final isDark = scheme.brightness == Brightness.dark;
    // Start from Material's sized type scale. ThemeData.textTheme carries no
    // sizes until Theme.of merges them in, which component themes such as
    // AppBarTheme.titleTextStyle never get.
    final sized = Typography.englishLike2021.merge(
      isDark ? Typography.whiteMountainView : Typography.blackMountainView,
    );
    final text = GoogleFonts.figtreeTextTheme(sized).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final textTheme = text.copyWith(
      displayMedium: text.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        fontFeatures: tabular,
      ),
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        fontFeatures: tabular,
      ),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final fieldShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [enamel],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? scheme.secondary : _butter,
        foregroundColor: isDark ? scheme.onSecondary : _onButter,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: fieldShape,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: fieldShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size(0, 44),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.primaryContainer,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 10,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
