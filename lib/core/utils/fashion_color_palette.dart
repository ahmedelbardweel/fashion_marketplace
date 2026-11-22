import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

import '../theme/app_design.dart';

class FashionColorOption {
  const FashionColorOption({
    required this.nameAr,
    required this.nameEn,
    required this.color,
    this.aliases = const [],
  });

  final String nameAr;
  final String nameEn;
  final Color color;
  final List<String> aliases;

  String get displayName => AppLang.isEn ? nameEn : nameAr;
}

abstract final class FashionColorPalette {
  static const List<FashionColorOption> presets = [
    FashionColorOption(
      nameAr: 'أسود',
      nameEn: 'Black',
      color: Color(0xFF141414),
      aliases: ['اسود', 'فحمي غامق', 'black', 'jet'],
    ),
    FashionColorOption(
      nameAr: 'أبيض',
      nameEn: 'White',
      color: Color(0xFFFFFFFF),
      aliases: ['ابيض', 'white'],
    ),
    FashionColorOption(
      nameAr: 'أوف وايت',
      nameEn: 'Off-White',
      color: Color(0xFFF5F1E6),
      aliases: ['كريمي', 'عاجي', 'سكري', 'off white', 'cream', 'ivory'],
    ),
    FashionColorOption(
      nameAr: 'رمادي',
      nameEn: 'Gray',
      color: Color(0xFF94A3B8),
      aliases: ['رصاصي', 'رمادي فاتح', 'gray', 'grey'],
    ),
    FashionColorOption(
      nameAr: 'رمادي غامق',
      nameEn: 'Charcoal',
      color: Color(0xFF475569),
      aliases: ['فحمي', 'رمادي داكن', 'charcoal', 'dark gray'],
    ),
    FashionColorOption(
      nameAr: 'بيج',
      nameEn: 'Beige',
      color: Color(0xFFD8C3A5),
      aliases: ['رملي', 'beige', 'sand', 'taupe'],
    ),
    FashionColorOption(
      nameAr: 'جملي',
      nameEn: 'Camel',
      color: Color(0xFFC19A6B),
      aliases: ['كامل', 'هافان', 'عسلي', 'camel', 'tan'],
    ),
    FashionColorOption(
      nameAr: 'بني',
      nameEn: 'Brown',
      color: Color(0xFF6B4423),
      aliases: ['شوكولا', 'قهوة', 'بني غامق', 'brown', 'chocolate', 'coffee'],
    ),
    FashionColorOption(
      nameAr: 'كحلي',
      nameEn: 'Navy',
      color: Color(0xFF1E3A5F),
      aliases: ['ازرق داكن', 'أزرق غامق', 'نيفي', 'navy', 'dark blue'],
    ),
    FashionColorOption(
      nameAr: 'أزرق',
      nameEn: 'Blue',
      color: Color(0xFF2563EB),
      aliases: ['ازرق', 'ازرق ملكي', 'blue', 'royal blue'],
    ),
    FashionColorOption(
      nameAr: 'سماوي',
      nameEn: 'Sky Blue',
      color: Color(0xFF60A5FA),
      aliases: ['ازرق فاتح', 'بيبي بلو', 'sky', 'light blue', 'baby blue'],
    ),
    FashionColorOption(
      nameAr: 'جينز',
      nameEn: 'Denim',
      color: Color(0xFF4A6FA5),
      aliases: ['denim', 'jeans'],
    ),
    FashionColorOption(
      nameAr: 'تركوازي',
      nameEn: 'Turquoise',
      color: Color(0xFF14B8A6),
      aliases: ['تيفاني', 'فيروزي', 'بترولي', 'turquoise', 'teal', 'cyan'],
    ),
    FashionColorOption(
      nameAr: 'أخضر',
      nameEn: 'Green',
      color: Color(0xFF16A34A),
      aliases: ['اخضر', 'زمردي', 'green', 'emerald'],
    ),
    FashionColorOption(
      nameAr: 'زيتي',
      nameEn: 'Olive',
      color: Color(0xFF556B2F),
      aliases: ['كاكي', 'عسكري', 'olive', 'khaki', 'army'],
    ),
    FashionColorOption(
      nameAr: 'نعناعي',
      nameEn: 'Mint',
      color: Color(0xFF6EE7B7),
      aliases: ['اخضر فاتح', 'منت', 'فستقي', 'mint', 'sage'],
    ),
    FashionColorOption(
      nameAr: 'أحمر',
      nameEn: 'Red',
      color: Color(0xFFDC2626),
      aliases: ['احمر', 'قرمزي', 'red', 'crimson'],
    ),
    FashionColorOption(
      nameAr: 'عنابي',
      nameEn: 'Burgundy',
      color: Color(0xFF7F1D1D),
      aliases: ['خمري', 'نبيتي', 'مارون', 'burgundy', 'maroon', 'wine'],
    ),
    FashionColorOption(
      nameAr: 'وردي',
      nameEn: 'Pink',
      color: Color(0xFFF472B6),
      aliases: ['زهري', 'بينك', 'بيبي بينك', 'pink', 'rose'],
    ),
    FashionColorOption(
      nameAr: 'فوشي',
      nameEn: 'Fuchsia',
      color: Color(0xFFD946EF),
      aliases: ['ماجنتا', 'فوشيا', 'fuchsia', 'magenta'],
    ),
    FashionColorOption(
      nameAr: 'مرجاني',
      nameEn: 'Coral',
      color: Color(0xFFFB7185),
      aliases: ['سلموني', 'خوخي', 'مشمشي', 'coral', 'peach', 'salmon'],
    ),
    FashionColorOption(
      nameAr: 'بنفسجي',
      nameEn: 'Purple',
      color: Color(0xFF7C3AED),
      aliases: ['ارجواني', 'أرجواني', 'purple', 'violet'],
    ),
    FashionColorOption(
      nameAr: 'موف',
      nameEn: 'Lavender',
      color: Color(0xFFC084FC),
      aliases: ['ليلكي', 'لافندر', 'موف فاتح', 'lavender', 'lilac', 'mauve'],
    ),
    FashionColorOption(
      nameAr: 'أصفر',
      nameEn: 'Yellow',
      color: Color(0xFFEAB308),
      aliases: ['اصفر', 'ليموني', 'yellow', 'lemon'],
    ),
    FashionColorOption(
      nameAr: 'خردلي',
      nameEn: 'Mustard',
      color: Color(0xFFCA8A04),
      aliases: ['مستردة', 'كموني', 'mustard'],
    ),
    FashionColorOption(
      nameAr: 'برتقالي',
      nameEn: 'Orange',
      color: Color(0xFFF97316),
      aliases: ['اورنج', 'نحاسي', 'orange', 'terracotta'],
    ),
    FashionColorOption(
      nameAr: 'ذهبي',
      nameEn: 'Gold',
      color: Color(0xFFD4AF37),
      aliases: ['gold', 'golden'],
    ),
    FashionColorOption(
      nameAr: 'فضي',
      nameEn: 'Silver',
      color: Color(0xFFC0C5CE),
      aliases: ['ميتاليك', 'سلفر', 'silver', 'metallic'],
    ),
  ];

  static String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static Color? _tryParseHex(String raw) {
    final cleaned = raw.trim().replaceFirst('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return null;
  }

  /// Resolves a product color name (Arabic, English, or `#RRGGBB`) to its swatch [Color].
  static Color resolveColor(String raw) {
    final hex = _tryParseHex(raw);
    if (hex != null) return hex;

    final norm = _normalize(raw);
    if (norm.isEmpty) return AppColors.primary;

    // 1) Exact match on Arabic, English, or alias
    for (final preset in presets) {
      if (_normalize(preset.nameAr) == norm ||
          _normalize(preset.nameEn) == norm ||
          preset.aliases.any((a) => _normalize(a) == norm)) {
        return preset.color;
      }
    }

    // 2) Substring match (e.g. "أسود مطفي" -> أسود)
    for (final preset in presets) {
      final ar = _normalize(preset.nameAr);
      final en = _normalize(preset.nameEn);
      if (norm.contains(ar) ||
          norm.contains(en) ||
          preset.aliases.any((a) => norm.contains(_normalize(a)))) {
        return preset.color;
      }
    }

    // 3) Deterministic muted fallback swatch for completely custom labels
    final hash = norm.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0xFFFFFF);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.42, 0.48).toColor();
  }

  static bool isLightColor(Color color) => color.computeLuminance() > 0.62;
}

/// Pure circular color swatch for customer selection (color circle only, no text inside).
class ColorSwatchCircle extends StatelessWidget {
  const ColorSwatchCircle({
    super.key,
    required this.colorName,
    required this.selected,
    required this.onTap,
    this.size = 34,
    this.enabled = true,
  });

  final String colorName;
  final bool selected;
  final VoidCallback? onTap;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final swatch = FashionColorPalette.resolveColor(colorName);
    final isLight = FashionColorPalette.isLightColor(swatch);
    final checkColor = isLight ? const Color(0xFF141414) : Colors.white;

    final ringColor = AppColors.isDark
        ? Colors.white.withValues(alpha: 0.92)
        : AppColors.text;

    return Tooltip(
      message: colorName.tr,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? AppHaptics.action(onTap) : null,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: size + 6,
              height: size + 6,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ringColor : Colors.transparent,
                  width: 1.8,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLight
                        ? AppColors.borderStrong
                        : (AppColors.isDark
                              ? Colors.white.withValues(alpha: 0.24)
                              : Colors.black.withValues(alpha: 0.14)),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: size * 0.46,
                        color: checkColor,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact circular/pill size selector that stays small side-by-side (never stretches full width).
class SizeSwatchCircle extends StatelessWidget {
  const SizeSwatchCircle({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
    this.size = 40,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final display = label.tr;
    final isShort = display.length <= 3;
    final selectedBg = AppColors.isDark ? Colors.white : AppColors.text;
    final selectedFg = AppColors.isDark
        ? const Color(0xFF111111)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: enabled ? AppHaptics.action(onTap) : null,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: isShort ? size : null,
          height: size,
          constraints: BoxConstraints(minWidth: size),
          padding: EdgeInsets.symmetric(horizontal: isShort ? 0 : 14),
          decoration: BoxDecoration(
            color: !enabled
                ? ProductDetailsDesign.optionDisabledBackground
                : selected
                ? selectedBg
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: selected
                ? null
                : Border.all(
                    color: !enabled ? AppColors.divider : AppColors.border,
                    width: 1,
                  ),
          ),
          child: Center(
            widthFactor: 1.0,
            child: Text(
              display,
              maxLines: 1,
              style: TextStyle(
                fontSize: isShort ? 12.5 : 12,
                fontWeight: selected ? AppFont.bold : AppFont.semiBold,
                color: !enabled
                    ? ProductDetailsDesign.optionDisabledText
                    : selected
                    ? selectedFg
                    : AppColors.textSecondary,
                decoration: enabled ? null : TextDecoration.lineThrough,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
