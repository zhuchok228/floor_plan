// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unused_element, library_private_types_in_public_api, prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'
    show
        rootBundle,
        AssetManifest,
        StandardMessageCodec,
        LogicalKeyboardKey,
        HardwareKeyboard,
        KeyDownEvent,
        ByteData;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'platform_adapter.dart';

ui.Image? _resolveTextureImage(String? texId, Map<String, ui.Image> images) {
  if (texId == null || images.isEmpty) return null;
  if (images.containsKey(texId)) return images[texId];
  
  // Try finding by filename or base name match
  final base = texId.split('/').last.replaceAll('.jpg', '').replaceAll('.png', '').toLowerCase();
  for (final entry in images.entries) {
    final entryBase = entry.key.split('/').last.replaceAll('.jpg', '').replaceAll('.png', '').toLowerCase();
    if (entryBase == base || entry.key.toLowerCase().contains(base)) {
      return entry.value;
    }
  }
  return null;
}


void main() {
  runApp(const FloorPlanApp());
}

final ValueNotifier<bool> isDarkThemeNotifier = ValueNotifier<bool>(true);

class FloorPlanApp extends StatelessWidget {
  const FloorPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkThemeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'План квартиры PRO 2D/3D',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: 'Segoe UI',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D99FF),
              brightness: Brightness.light,
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            dialogBackgroundColor: Colors.white,
            cardColor: Colors.white,
            dividerColor: const Color(0xFFCBD5E1),
            textTheme: Typography.material2021().black.apply(
              fontFamily: 'Segoe UI',
              bodyColor: const Color(0xFF0F172A),
              displayColor: const Color(0xFF0F172A),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              labelStyle: const TextStyle(color: Color(0xFF475569)),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              suffixStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.5),
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Segoe UI',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D99FF),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            dialogBackgroundColor: const Color(0xFF1E293B),
            cardColor: const Color(0xFF1E293B),
            dividerColor: const Color(0xFF334155),
            textTheme: Typography.material2021().white.apply(
              fontFamily: 'Segoe UI',
              bodyColor: const Color(0xFFF1F5F9),
              displayColor: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E293B),
              titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFFE2E8F0)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              suffixStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.5),
              ),
            ),
            useMaterial3: true,
          ),
          home: const FloorPlanEditor(),
        );
      },
    );
  }
}

enum EditorTool {
  overview,
  drawWall,
  wallDimensions,
  drawRoomBox,
  drawDimension,
  addDoor,
  addWindow,
  addObject,
}

enum OpeningType { door, window }

enum WallViewMode3D {
  cutawaySims,
  fullWalls,
  lowWalls,
}

const Map<String, String> kTextureItemDisplayNamesRu = {
  'laminate_quickstep_oak_natural': 'Ламинат Quick-Step Дуб натуральный (фаска 4V)',
  'laminate_quickstep_oak_natural.jpg': 'Ламинат Quick-Step Дуб натуральный (фаска 4V)',
  'laminate_quickstep_oak_bleached': 'Ламинат Quick-Step Дуб нордик белёный',
  'laminate_quickstep_oak_bleached.jpg': 'Ламинат Quick-Step Дуб нордик белёный',
  'laminate_tarkett_cinema_vintage': 'Ламинат Tarkett Cinema Дуб винтаж с фаской',
  'laminate_tarkett_cinema_vintage.jpg': 'Ламинат Tarkett Cinema Дуб винтаж с фаской',
  'laminate_kronotex_grey_loft': 'Ламинат Kronotex Дуб дымчато-серый лофт',
  'laminate_kronotex_grey_loft.jpg': 'Ламинат Kronotex Дуб дымчато-серый лофт',
  'laminate_egger_dark_walnut': 'Ламинат Egger Дуб тёмный коньячный 33 класс',
  'laminate_egger_dark_walnut.jpg': 'Ламинат Egger Дуб тёмный коньячный 33 класс',
  'laminate_wood_honey_classic': 'Ламинат Дуб медовый классический рустик',
  'laminate_wood_honey_classic.jpg': 'Ламинат Дуб медовый классический рустик',

  'parquet_chevron_french_oak': 'Паркет Французская ёлочка (Chevron) светлый дуб',
  'parquet_chevron_french_oak.jpg': 'Паркет Французская ёлочка (Chevron) светлый дуб',
  'parquet_herringbone_hungarian_oak': 'Паркет Венгерская ёлочка (Herringbone) дуб селект',
  'parquet_herringbone_hungarian_oak.jpg': 'Паркет Венгерская ёлочка (Herringbone) дуб селект',
  'parquet_barlinek_walnut_select': 'Инженерная доска Barlinek Американский орех',
  'parquet_barlinek_walnut_select.jpg': 'Инженерная доска Barlinek Американский орех',
  'parquet_coswick_ash_nordic': 'Паркетная доска Coswick Ясень скандинавский',
  'parquet_coswick_ash_nordic.jpg': 'Паркетная доска Coswick Ясень скандинавский',
  'parquet_modular_versailles': 'Паркет модульный версальский дуб коньячный',
  'parquet_modular_versailles.jpg': 'Паркет модульный версальский дуб коньячный',
  'parquet_oak_rustic_wide': 'Массивная доска Дуб рустик брашированный',
  'parquet_oak_rustic_wide.jpg': 'Массивная доска Дуб рустик брашированный',

  'linoleum_tarkett_idyllia_oak': 'Линолеум Tarkett Идиллия Нова Дуб классик',
  'linoleum_tarkett_idyllia_oak.jpg': 'Линолеум Tarkett Идиллия Нова Дуб классик',
  'linoleum_tarkett_granite_speckle': 'Линолеум коммерческий Tarkett Мраморная крошка',
  'linoleum_tarkett_granite_speckle.jpg': 'Линолеум коммерческий Tarkett Мраморная крошка',
  'spc_fine_floor_calacatta_marble': 'Кварцвинил SPC Fine Floor Белый мрамор калакатта',
  'spc_fine_floor_calacatta_marble.jpg': 'Кварцвинил SPC Fine Floor Белый мрамор калакатта',
  'spc_alpine_floor_concrete_loft': 'Кварцвинил SPC Alpine Floor Серый сланец лофт',
  'spc_alpine_floor_concrete_loft.jpg': 'Кварцвинил SPC Alpine Floor Серый сланец лофт',
  'spc_herringbone_sand_quartz': 'Кварцвинил SPC замковый Тёплый песчаник',
  'spc_herringbone_sand_quartz.jpg': 'Кварцвинил SPC замковый Тёплый песчаник',

  'wallpaper_rasch_linen_beige': 'Обои Rasch Флизелин фактурный лён (бежевый)',
  'wallpaper_rasch_linen_beige.jpg': 'Обои Rasch Флизелин фактурный лён (бежевый)',
  'wallpaper_erismann_plaster_warm': 'Обои Erismann Тёплая штукатурка под покраску',
  'wallpaper_erismann_plaster_warm.jpg': 'Обои Erismann Тёплая штукатурка под покраску',
  'wallpaper_marburg_scandi_geometry': 'Обои Marburg Скандинавская геометрия',
  'wallpaper_marburg_scandi_geometry.jpg': 'Обои Marburg Скандинавская геометрия',
  'wallpaper_stenova_artdeco_gold': 'Обои Victoria Stenova Арт-Деко с золотом',
  'wallpaper_stenova_artdeco_gold.jpg': 'Обои Victoria Stenova Арт-Деко с золотом',
  'wallpaper_palitra_loft_concrete': 'Обои Палитра Лофт серое фактурное полотно',
  'wallpaper_palitra_loft_concrete.jpg': 'Обои Палитра Лофт серое фактурное полотно',

  'tile_subway_white_bevel': 'Плитка настенная Кабанчик белый глянцевый (Метро)',
  'tile_subway_white_bevel.jpg': 'Плитка настенная Кабанчик белый глянцевый (Метро)',
  'tile_kerama_marazzi_calacatta_gold': 'Керамогранит Kerama Marazzi Calacatta Gold',
  'tile_kerama_marazzi_calacatta_gold.jpg': 'Керамогранит Kerama Marazzi Calacatta Gold',
  'tile_kerama_marazzi_marquina_nero': 'Керамогранит Kerama Marazzi Marquina Nero',
  'tile_kerama_marazzi_marquina_nero.jpg': 'Керамогранит Kerama Marazzi Marquina Nero',
  'tile_italon_loft_grey_cement': 'Керамогранит Italon Микроцемент серый мат',
  'tile_italon_loft_grey_cement.jpg': 'Керамогранит Italon Микроцемент серый мат',
  'tile_hexagon_mosaic_marble': 'Мозаика шестигранная гексагон белый мрамор',
  'tile_hexagon_mosaic_marble.jpg': 'Мозаика шестигранная гексагон белый мрамор',
  'tile_patchwork_vintage_portugal': 'Плитка португальский винтажный пэчворк',
  'tile_patchwork_vintage_portugal.jpg': 'Плитка португальский винтажный пэчворк',

  'paint_tikkurila_white_scandi': 'Краска Tikkurila Белый сканди матовый (F497)',
  'paint_tikkurila_white_scandi.jpg': 'Краска Tikkurila Белый сканди матовый (F497)',
  'paint_dulux_warm_cashmere': 'Краска Dulux Тёплый кашемир (бежевая)',
  'paint_dulux_warm_cashmere.jpg': 'Краска Dulux Тёплый кашемир (бежевая)',
  'paint_tikkurila_sage_green': 'Краска Tikkurila Мягкий шалфей (M442 пастель)',
  'paint_tikkurila_sage_green.jpg': 'Краска Tikkurila Мягкий шалфей (M442 пастель)',
  'paint_dulux_graphite_loft': 'Краска Dulux Графит лофт глубокий мат',
  'paint_dulux_graphite_loft.jpg': 'Краска Dulux Графит лофт глубокий мат',
  'plaster_venetian_pearl_silk': 'Венецианская штукатурка Мокрый шёлк жемчужный',
  'plaster_venetian_pearl_silk.jpg': 'Венецианская штукатурка Мокрый шёлк жемчужный',
  'plaster_microcement_warm_grey': 'Декоративный микроцемент тёплый серый',
  'plaster_microcement_warm_grey.jpg': 'Декоративный микроцемент тёплый серый',
  'stone_decorative_block': 'Декоративный камень',
  'stone_decorative_block.jpg': 'Декоративный камень',
  'stone_masonry_wild': 'Каменная кладка (дикий камень)',
  'stone_masonry_wild.jpg': 'Каменная кладка (дикий камень)',
  'brick_loft_white': 'Кирпич белый лофт',
  'brick_loft_white.jpg': 'Кирпич белый лофт',
  'brick_red_facing': 'Кирпич красный облицовочный',
  'brick_red_facing.jpg': 'Кирпич красный облицовочный',
  'carpet_pile_beige': 'Ковер ворсовый бежевый',
  'carpet_pile_beige.jpg': 'Ковер ворсовый бежевый',
  'concrete_granite_seamless': 'Гранитная текстура бесшовная',
  'concrete_granite_seamless.jpg': 'Гранитная текстура бесшовная',
  'concrete_wall_loft': 'Бетон стеновой лофт',
  'concrete_wall_loft.jpg': 'Бетон стеновой лофт',
  'concrete_polished_floor': 'Бетон шлифованный (пол)',
  'concrete_polished_floor.jpg': 'Бетон шлифованный (пол)',
  'plaster_white_textured': 'Штукатурка белая фактурная',
  'plaster_white_textured.jpg': 'Штукатурка белая фактурная',
  'grass_green_lawn': 'Газон зеленый (трава)',
  'grass_green_lawn.jpg': 'Газон зеленый (трава)',
  'leather_white_sofa': 'Кожа белая диванная',
  'leather_white_sofa.jpg': 'Кожа белая диванная',
  'leather_natural_brown': 'Кожа натуральная коричневая',
  'leather_natural_brown.jpg': 'Кожа натуральная коричневая',
  'leather_eco_premium': 'Экокожа премиум',
  'leather_eco_premium.jpg': 'Экокожа премиум',
  'marble_white_carrara': 'Мрамор белый Каррара',
  'marble_white_carrara.jpg': 'Мрамор белый Каррара',
  'marble_mosaic_art': 'Мраморная мозаика',
  'marble_mosaic_art.jpg': 'Мраморная мозаика',
  'marble_tile_glossy': 'Мраморная плитка глянец',
  'marble_tile_glossy.jpg': 'Мраморная плитка глянец',
  'metal_corrugated_steel': 'Металл рифленый (сталь)',
  'metal_corrugated_steel.jpg': 'Металл рифленый (сталь)',
  'metal_aged_bronze': 'Металл состаренный (бронза)',
  'metal_aged_bronze.jpg': 'Металл состаренный (бронза)',
  'tile_ceramic_classic': 'Керамическая плитка классик',
  'tile_ceramic_classic.jpg': 'Керамическая плитка классик',
  'tile_porcelain_granite': 'Плитка керамогранит напольная',
  'tile_porcelain_granite.jpg': 'Плитка керамогранит напольная',
  'tile_gray_large_format': 'Плитка серая крупноформатная',
  'tile_gray_large_format.jpg': 'Плитка серая крупноформатная',
  'tile_terrazzo_design': 'Плитка терраццо дизайнерская',
  'tile_terrazzo_design.jpg': 'Плитка терраццо дизайнерская',
  'wallpaper_jacquard': 'Обои текстильные жаккард',
  'wallpaper_jacquard.jpg': 'Обои текстильные жаккард',
  'textile_denim': 'Текстиль фактурный',
  'textile_denim.jpg': 'Текстиль фактурный',
  'wood_oak_countertop': 'Дерево массив дуба',
  'wood_oak_countertop.jpg': 'Дерево массив дуба',
  'wood_dark_walnut_parquet': 'Темный орех паркет',
  'wood_dark_walnut_parquet.jpg': 'Темный орех паркет',
  'wood_decking_terrace': 'Террасная доска палубная',
  'wood_decking_terrace.jpg': 'Террасная доска палубная',
  'wood_plywood_light': 'Фанера светлая интерьерная',
  'wood_plywood_light.jpg': 'Фанера светлая интерьерная',
};

const Map<String, String> kTextureCategoryNamesRu = {
  'laminate': 'Ламинат',
  'parquet': 'Паркет',
  'linoleum': 'Линолеум и SPC',
  'wallpaper': 'Обои',
  'tile': 'Плитка и керамогранит',
  'paint': 'Краска и штукатурка',
  'wood': 'Массив дерева',
  'marble': 'Мрамор',
  'concrete': 'Бетон',
  'brick_stone': 'Кирпич и камень',
  'carpets': 'Ковры',
  'leather': 'Кожа',
  'metal': 'Металл',
  'landscape': 'Ландшафт',
};

const Map<String, String> kModelCategoryNamesRu = {
  'living_room': 'Мягкая мебель',
  'bedroom': 'Спальня',
  'tables_chairs': 'Столы и стулья',
  'storage': 'Шкафы и хранение',
  'kitchen': 'Кухня и техника',
  'plumbing': 'Сантехника',
  'decor': 'Декор и свет',
  'electrical': 'Электрика и отопление',
};

const Map<String, (double, double, double)> kDefaultModelDimensions = {
  'living_room': (2.10, 0.95, 0.85),
  'bedroom': (1.80, 2.05, 0.90),
  'tables_chairs': (1.40, 0.85, 0.75),
  'storage': (1.20, 0.50, 2.00),
  'kitchen': (2.40, 0.60, 0.85),
  'plumbing': (1.70, 0.75, 0.60),
  'decor': (0.60, 0.60, 1.20),
  'electrical': (0.80, 0.15, 0.55),
};

class CatalogTexture {
  final String id;
  final String category;
  final String name;
  final String assetPath;
  final ui.Image image;

  CatalogTexture({
    required this.id,
    required this.category,
    required this.name,
    required this.assetPath,
    required this.image,
  });
}

class Parsed3DMesh {
  final List<_Vec3> vertices;
  final List<(int, int, int)> faces;

  Parsed3DMesh({required this.vertices, required this.faces});
}

class Catalog3DModel {
  final String id;
  final String folderKey;
  final String categoryRu;
  final String name;
  final String modelAssetPath;
  final String extension;
  final double defaultWidthM;
  final double defaultDepthM;
  final double defaultHeightM;
  final String? previewImagePath;
  final Parsed3DMesh? parsedMesh;

  Catalog3DModel({
    required this.id,
    required this.folderKey,
    required this.categoryRu,
    required this.name,
    required this.modelAssetPath,
    required this.extension,
    required this.defaultWidthM,
    required this.defaultDepthM,
    required this.defaultHeightM,
    this.previewImagePath,
    this.parsedMesh,
  });
}

enum UnitFormat {
  meters,
  millimeters,
}

class WallLayer {
  final String id;
  String name;
  double thicknessMm;
  bool enabled;
  Color color;
  String? materialCode;

  WallLayer({
    required this.id,
    required this.name,
    required this.thicknessMm,
    this.enabled = true,
    this.color = const Color(0xFFE2E8F0),
    this.materialCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'thMm': thicknessMm,
        'en': enabled,
        'color': color.toARGB32(),
        'mat': materialCode,
      };

  factory WallLayer.fromJson(Map<String, dynamic> json) => WallLayer(
        id: json['id'] as String? ?? 'layer',
        name: json['name'] as String? ?? 'Слой',
        thicknessMm: (json['thMm'] as num?)?.toDouble() ?? 10.0,
        enabled: json['en'] as bool? ?? true,
        color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFFE2E8F0),
        materialCode: json['mat'] as String?,
      );
}

// =========================================================================
// УМНАЯ РАСКЛАДКА ПЛИТКИ: МОДЕЛИ, ПАТТЕРНЫ, РАСЧЕТ МАТЕРИАЛОВ И ПОДРЕЗОК
// =========================================================================

enum TileMaterialType {
  porcelainRectified, // Керамогранит ректифицированный
  porcelainClassic,   // Керамогранит классический
  ceramicWall,        // Настенная керамическая плитка (кафель)
  ceramicFloor,       // Напольная керамическая плитка
  mosaic,             // Мозаика
}

enum TilePattern {
  straight, // Шов в шов (сетка)
  brickHalf, // Вразбежку 1/2 (кирпич)
  brickThird, // Вразбежку 1/3 (для крупного формата)
  diagonal, // Диагональная 45°
  herringbone, // «Ёлочка» (английская)
  checkerboard, // Шахматная / модульная
}

enum TileOriginAlignment {
  center, // Симметрично от центра
  topLeft, // От левого верхнего угла
  topRight, // От правого верхнего угла
  bottomLeft, // От левого нижнего угла
  bottomRight, // От правого нижнего угла
  custom, // Ручное смещение
}

enum TileCutType {
  full, // Целая плитка
  large, // Крупная подрезка (> 50%)
  small, // Мелкая подрезка (5-50%)
  critical, // Критический узкий обрезок (< 50 мм)
}

class TileLayoutConfig {
  double tileWidthMm;
  double tileHeightMm;
  double jointWidthMm;
  Color jointColor;
  TileMaterialType tileMaterial;
  TilePattern pattern;
  TileOriginAlignment originAlignment;
  double offsetXCm;
  double offsetYCm;
  double rotationDeg;
  bool showCutColors;
  bool showTileNumbers;
  bool showBasePointMarker;
  bool showStudioGrid;
  double glueThicknessMm;
  double pricePerSqM;
  int tilesPerBox;
  double reservePercent;
  String? tileTextureId;

  TileLayoutConfig({
    this.tileWidthMm = 600.0,
    this.tileHeightMm = 600.0,
    this.jointWidthMm = 2.0,
    this.jointColor = const Color(0xFF94A3B8),
    this.tileMaterial = TileMaterialType.porcelainRectified,
    this.pattern = TilePattern.straight,
    this.originAlignment = TileOriginAlignment.center,
    this.offsetXCm = 0.0,
    this.offsetYCm = 0.0,
    this.rotationDeg = 0.0,
    this.showCutColors = true,
    this.showTileNumbers = false,
    this.showBasePointMarker = true,
    this.showStudioGrid = false,
    this.glueThicknessMm = 4.0,
    this.pricePerSqM = 2200.0,
    this.tilesPerBox = 4,
    this.reservePercent = 10.0,
    this.tileTextureId,
  });

  TileLayoutConfig clone() {
    return TileLayoutConfig(
      tileWidthMm: tileWidthMm,
      tileHeightMm: tileHeightMm,
      jointWidthMm: jointWidthMm,
      jointColor: jointColor,
      tileMaterial: tileMaterial,
      pattern: pattern,
      originAlignment: originAlignment,
      offsetXCm: offsetXCm,
      offsetYCm: offsetYCm,
      rotationDeg: rotationDeg,
      showCutColors: showCutColors,
      showTileNumbers: showTileNumbers,
      showBasePointMarker: showBasePointMarker,
      showStudioGrid: showStudioGrid,
      glueThicknessMm: glueThicknessMm,
      pricePerSqM: pricePerSqM,
      tilesPerBox: tilesPerBox,
      reservePercent: reservePercent,
      tileTextureId: tileTextureId,
    );
  }

  Map<String, dynamic> toJson() => {
        'wMm': tileWidthMm,
        'hMm': tileHeightMm,
        'jMm': jointWidthMm,
        'jCol': jointColor.toARGB32(),
        'mat': tileMaterial.name,
        'pat': pattern.name,
        'align': originAlignment.name,
        'ox': offsetXCm,
        'oy': offsetYCm,
        'rot': rotationDeg,
        'cuts': showCutColors,
        'num': showTileNumbers,
        'basePt': showBasePointMarker,
        'sGrid': showStudioGrid,
        'glueMm': glueThicknessMm,
        'price': pricePerSqM,
        'box': tilesPerBox,
        'res': reservePercent,
        'tex': tileTextureId,
      };

  factory TileLayoutConfig.fromJson(Map<String, dynamic> m) => TileLayoutConfig(
        tileWidthMm: (m['wMm'] as num?)?.toDouble() ?? 600.0,
        tileHeightMm: (m['hMm'] as num?)?.toDouble() ?? 600.0,
        jointWidthMm: (m['jMm'] as num?)?.toDouble() ?? 2.0,
        jointColor: m['jCol'] != null ? Color(m['jCol'] as int) : const Color(0xFF94A3B8),
        tileMaterial: TileMaterialType.values.firstWhere(
          (mt) => mt.name == m['mat'],
          orElse: () => TileMaterialType.porcelainRectified,
        ),
        pattern: TilePattern.values.firstWhere(
          (p) => p.name == m['pat'],
          orElse: () => TilePattern.straight,
        ),
        originAlignment: TileOriginAlignment.values.firstWhere(
          (a) => a.name == m['align'],
          orElse: () => TileOriginAlignment.center,
        ),
        offsetXCm: (m['ox'] as num?)?.toDouble() ?? 0.0,
        offsetYCm: (m['oy'] as num?)?.toDouble() ?? 0.0,
        rotationDeg: (m['rot'] as num?)?.toDouble() ?? 0.0,
        showCutColors: m['cuts'] as bool? ?? true,
        showTileNumbers: m['num'] as bool? ?? false,
        showBasePointMarker: m['basePt'] as bool? ?? true,
        showStudioGrid: m['sGrid'] as bool? ?? false,
        glueThicknessMm: (m['glueMm'] as num?)?.toDouble() ?? 4.0,
        pricePerSqM: (m['price'] as num?)?.toDouble() ?? 2200.0,
        tilesPerBox: (m['box'] as num?)?.toInt() ?? 4,
        reservePercent: (m['res'] as num?)?.toDouble() ?? 10.0,
        tileTextureId: m['tex'] as String?,
      );
}

class PlacedTilePiece {
  final int id;
  final int col;
  final int row;
  final Rect bounds;
  final Path shape;
  final TileCutType cutType;
  final double areaSqM;
  final double clippedWidthCm;
  final double clippedHeightCm;

  PlacedTilePiece({
    required this.id,
    required this.col,
    required this.row,
    required this.bounds,
    required this.shape,
    required this.cutType,
    required this.areaSqM,
    required this.clippedWidthCm,
    required this.clippedHeightCm,
  });
}

class TileCalculationReport {
  final double roomAreaSqM;
  final double singleTileAreaSqM;
  final int totalVisiblePieces;
  final int fullTiles;
  final int largeCuts;
  final int smallCuts;
  final int criticalCuts;
  final int totalPurchasedTiles;
  final int totalBoxes;
  final double grossAreaSqM;
  final double adhesiveKg;
  final double glueThicknessMm;
  final double groutKg;
  final double totalCostRub;
  final int svpClipsCount;
  final int svpClipsPacks;
  final int svpWedgesCount;
  final int crossSpacersCount;
  final int crossSpacersPacks;
  final List<PlacedTilePiece> pieces;

  TileCalculationReport({
    required this.roomAreaSqM,
    required this.singleTileAreaSqM,
    required this.totalVisiblePieces,
    required this.fullTiles,
    required this.largeCuts,
    required this.smallCuts,
    required this.criticalCuts,
    required this.totalPurchasedTiles,
    required this.totalBoxes,
    required this.grossAreaSqM,
    required this.adhesiveKg,
    required this.glueThicknessMm,
    required this.groutKg,
    required this.totalCostRub,
    this.svpClipsCount = 0,
    this.svpClipsPacks = 0,
    this.svpWedgesCount = 0,
    this.crossSpacersCount = 0,
    this.crossSpacersPacks = 0,
    required this.pieces,
  });
}

class TileLayoutCalculator {
  static TileCalculationReport calculate(List<Offset> polygon, TileLayoutConfig config) {
    if (polygon.length < 3) {
      final sArea = (config.tileWidthMm / 1000.0) * (config.tileHeightMm / 1000.0);
      return TileCalculationReport(
        roomAreaSqM: 0.0,
        singleTileAreaSqM: sArea > 0.001 ? sArea : 0.36,
        totalVisiblePieces: 0,
        fullTiles: 0,
        largeCuts: 0,
        smallCuts: 0,
        criticalCuts: 0,
        totalPurchasedTiles: 0,
        totalBoxes: 0,
        grossAreaSqM: 0.0,
        adhesiveKg: 0.0,
        glueThicknessMm: config.glueThicknessMm,
        groutKg: 0.0,
        totalCostRub: 0.0,
        svpClipsCount: 0,
        svpClipsPacks: 0,
        svpWedgesCount: 0,
        crossSpacersCount: 0,
        crossSpacersPacks: 0,
        pieces: [],
      );
    }

    double minX = polygon.first.dx, maxX = polygon.first.dx;
    double minY = polygon.first.dy, maxY = polygon.first.dy;
    for (final p in polygon) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    final polyW = maxX - minX;
    final polyH = maxY - minY;

    double areaPx = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      areaPx += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    final roomAreaSqM = (areaPx.abs() / 2.0) / 10000.0;

    final tileWCm = config.tileWidthMm / 10.0;
    final tileHCm = config.tileHeightMm / 10.0;
    final jointCm = config.jointWidthMm / 10.0;
    final stepX = math.max(1.0, tileWCm + jointCm);
    final stepY = math.max(1.0, tileHCm + jointCm);

    double startX = minX;
    double startY = minY;

    switch (config.originAlignment) {
      case TileOriginAlignment.center:
        final remX = (polyW % stepX);
        final remY = (polyH % stepY);
        startX = minX - (stepX - remX) / 2.0 + config.offsetXCm;
        startY = minY - (stepY - remY) / 2.0 + config.offsetYCm;
        break;
      case TileOriginAlignment.topLeft:
        startX = minX + config.offsetXCm;
        startY = minY + config.offsetYCm;
        break;
      case TileOriginAlignment.topRight:
        startX = maxX - (polyW % stepX) + config.offsetXCm;
        startY = minY + config.offsetYCm;
        break;
      case TileOriginAlignment.bottomLeft:
        startX = minX + config.offsetXCm;
        startY = maxY - (polyH % stepY) + config.offsetYCm;
        break;
      case TileOriginAlignment.bottomRight:
        startX = maxX - (polyW % stepX) + config.offsetXCm;
        startY = maxY - (polyH % stepY) + config.offsetYCm;
        break;
      case TileOriginAlignment.custom:
        startX = minX + config.offsetXCm;
        startY = minY + config.offsetYCm;
        break;
    }

    while (startX > minX - stepX) {
      startX -= stepX;
    }
    while (startY > minY - stepY) {
      startY -= stepY;
    }

    final cols = math.min(100, ((maxX - startX) / stepX).ceil() + 2);
    final rows = math.min(100, ((maxY - startY) / stepY).ceil() + 2);

    final pieces = <PlacedTilePiece>[];
    int pieceId = 1;
    int fullCount = 0;
    int largeCount = 0;
    int smallCount = 0;
    int critCount = 0;

    bool pointInPoly(Offset pt) {
      bool inside = false;
      for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        final xi = polygon[i].dx, yi = polygon[i].dy;
        final xj = polygon[j].dx, yj = polygon[j].dy;
        final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
            (pt.dx < (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 0.0001 : (yj - yi)) + xi);
        if (intersect) inside = !inside;
      }
      return inside;
    }

    for (int r = 0; r < rows; r++) {
      double rowShift = 0.0;
      if (config.pattern == TilePattern.brickHalf) {
        rowShift = (r % 2 == 1) ? (stepX * 0.5) : 0.0;
      } else if (config.pattern == TilePattern.brickThird) {
        rowShift = (r % 3) * (stepX / 3.0);
      } else if (config.pattern == TilePattern.diagonal) {
        rowShift = (r % 2 == 1) ? (stepX * 0.5) : 0.0;
      } else if (config.pattern == TilePattern.herringbone) {
        rowShift = (r % 2 == 1) ? (stepX * 0.25) : 0.0;
      } else if (config.pattern == TilePattern.checkerboard) {
        rowShift = ((r ~/ 2) % 2 == 1) ? (stepX * 0.5) : 0.0;
      }

      for (int c = 0; c < cols; c++) {
        final tx = startX + c * stepX + rowShift;
        final ty = startY + r * stepY;
        final tRect = Rect.fromLTWH(tx, ty, tileWCm, tileHCm);

        if (tRect.right < minX || tRect.left > maxX || tRect.bottom < minY || tRect.top > maxY) {
          continue;
        }

        final in1 = pointInPoly(tRect.topLeft);
        final in2 = pointInPoly(tRect.topRight);
        final in3 = pointInPoly(tRect.bottomRight);
        final in4 = pointInPoly(tRect.bottomLeft);
        final inCenter = pointInPoly(tRect.center);

        final insideCorners = (in1 ? 1 : 0) + (in2 ? 1 : 0) + (in3 ? 1 : 0) + (in4 ? 1 : 0);

        if (insideCorners == 0 && !inCenter) {
          bool hasPolyVertex = false;
          for (final p in polygon) {
            if (tRect.contains(p)) {
              hasPolyVertex = true;
              break;
            }
          }
          if (!hasPolyVertex) continue;
        }

        TileCutType cutType;
        final clippedLeft = math.max(tRect.left, minX);
        final clippedRight = math.min(tRect.right, maxX);
        final clippedTop = math.max(tRect.top, minY);
        final clippedBottom = math.min(tRect.bottom, maxY);

        final visWidthCm = math.max(0.0, clippedRight - clippedLeft);
        final visHeightCm = math.max(0.0, clippedBottom - clippedTop);

        if (insideCorners == 4) {
          cutType = TileCutType.full;
          fullCount++;
        } else {
          int insideSamples = 0;
          for (double sy = 0.2; sy <= 0.8; sy += 0.3) {
            for (double sx = 0.2; sx <= 0.8; sx += 0.3) {
              if (pointInPoly(Offset(tRect.left + tRect.width * sx, tRect.top + tRect.height * sy))) {
                insideSamples++;
              }
            }
          }

          if ((visWidthCm < 5.0 && visWidthCm > 0.05) || (visHeightCm < 5.0 && visHeightCm > 0.05) || insideSamples <= 1) {
            cutType = TileCutType.critical;
            critCount++;
          } else if (insideSamples >= 5) {
            cutType = TileCutType.large;
            largeCount++;
          } else {
            cutType = TileCutType.small;
            smallCount++;
          }
        }

        final singleTileArea = (config.tileWidthMm / 1000.0) * (config.tileHeightMm / 1000.0);
        final piecePath = Path()..addRect(tRect);

        pieces.add(
          PlacedTilePiece(
            id: pieceId++,
            col: c,
            row: r,
            bounds: tRect,
            shape: piecePath,
            cutType: cutType,
            areaSqM: singleTileArea,
            clippedWidthCm: visWidthCm,
            clippedHeightCm: visHeightCm,
          ),
        );
      }
    }

    final singleTileAreaSqM = (config.tileWidthMm / 1000.0) * (config.tileHeightMm / 1000.0);
    final totalCuts = largeCount + smallCount + critCount;

    final rawTilesNeeded = fullCount + (totalCuts * 0.70).ceil();
    final withReserve = math.max(rawTilesNeeded, (roomAreaSqM / singleTileAreaSqM * (1.0 + config.reservePercent / 100.0)).ceil());
    final totalPurchasedTiles = math.max(1, withReserve);
    final totalBoxes = (totalPurchasedTiles / math.max(1, config.tilesPerBox)).ceil();
    final grossAreaSqM = totalPurchasedTiles * singleTileAreaSqM;
    final totalCostRub = grossAreaSqM * config.pricePerSqM;

    final adhesiveKg = roomAreaSqM * config.glueThicknessMm * 1.35;

    final wM = config.tileWidthMm / 1000.0;
    final hM = config.tileHeightMm / 1000.0;
    final jMm = config.jointWidthMm;
    final groutKg = roomAreaSqM > 0.01 && wM > 0 && hM > 0
        ? ((wM + hM) / (wM * hM)) * (jMm * 0.001) * 0.008 * 1600.0 * roomAreaSqM
        : 0.0;

    // Расчет СВП (системы выравнивания) и дистанционных крестиков по нормативам Estima / СП
    final isLargeFormat = (config.tileWidthMm >= 300.0 && config.tileHeightMm >= 300.0) ||
        (math.max(config.tileWidthMm, config.tileHeightMm) >= 400.0);
    int svpClips = 0;
    int svpClipsPacks = 0;
    int svpWedges = 0;
    int crossSpacers = 0;
    int crossSpacersPacks = 0;

    if (isLargeFormat && roomAreaSqM > 0.01 && wM > 0 && hM > 0) {
      final clipsPerSqM = ((1.0 / wM) + (1.0 / hM)) * 2.0;
      svpClips = (roomAreaSqM * clipsPerSqM * 1.15).ceil();
      svpClipsPacks = math.max(1, (svpClips / 250.0).ceil());
      svpWedges = math.min(svpClips, math.max(50, (svpClips * 0.35).ceil()));
      crossSpacers = (roomAreaSqM * 12).ceil();
      crossSpacersPacks = math.max(1, (crossSpacers / 300.0).ceil());
    } else if (roomAreaSqM > 0.01) {
      crossSpacers = (totalPurchasedTiles * 4 * 1.1).ceil();
      crossSpacersPacks = math.max(1, (crossSpacers / 300.0).ceil());
      svpClips = 0;
      svpClipsPacks = 0;
      svpWedges = 0;
    }

    return TileCalculationReport(
      roomAreaSqM: roomAreaSqM,
      singleTileAreaSqM: singleTileAreaSqM,
      totalVisiblePieces: pieces.length,
      fullTiles: fullCount,
      largeCuts: largeCount,
      smallCuts: smallCount,
      criticalCuts: critCount,
      totalPurchasedTiles: totalPurchasedTiles,
      totalBoxes: totalBoxes,
      grossAreaSqM: grossAreaSqM,
      adhesiveKg: adhesiveKg,
      glueThicknessMm: config.glueThicknessMm,
      groutKg: groutKg,
      totalCostRub: totalCostRub,
      svpClipsCount: svpClips,
      svpClipsPacks: svpClipsPacks,
      svpWedgesCount: svpWedges,
      crossSpacersCount: crossSpacers,
      crossSpacersPacks: crossSpacersPacks,
      pieces: pieces,
    );
  }

  static double getEstimaRecommendedJointMm({
    required bool isFloor,
    required TileMaterialType material,
    required double widthMm,
    required double heightMm,
  }) {
    final maxDim = math.max(widthMm, heightMm);
    if (material == TileMaterialType.mosaic || maxDim < 150) {
      return isFloor ? 2.0 : 1.5;
    }
    if (material == TileMaterialType.porcelainRectified) {
      // Estima: ректификат минимум 1-1.5 мм (для пола 1.5-2.0 мм для демпфирования вибраций и клея)
      return isFloor ? 2.0 : 1.5;
    }
    if (isFloor) {
      // Estima: напольные покрытия подвержены вибрациям и подвижкам эластичного клея
      if (maxDim <= 250) return 2.5;
      if (maxDim <= 600) return 3.0;
      return 3.5;
    } else {
      // Estima: настенные покрытия 1-4 мм
      if (maxDim <= 250) return 2.0;
      if (maxDim <= 600) return 2.5;
      return 3.0;
    }
  }
}

enum ElectricalType {
  socket,
  switchItem,
  light,
}

class ElectricalItem {
  final String id;
  String name;
  ElectricalType type;
  String subType;
  Offset position;
  double heightFromFloorMm;
  double rotationDeg;
  String groupLabel;
  bool showLabel;

  ElectricalItem({
    required this.id,
    required this.name,
    required this.type,
    required this.subType,
    required this.position,
    this.heightFromFloorMm = 300.0,
    this.rotationDeg = 0.0,
    this.groupLabel = '',
    this.showLabel = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'subType': subType,
        'px': position.dx,
        'py': position.dy,
        'hMm': heightFromFloorMm,
        'rot': rotationDeg,
        'group': groupLabel,
        'showLbl': showLabel,
      };

  factory ElectricalItem.fromJson(Map<String, dynamic> json) => ElectricalItem(
        id: json['id'] as String? ?? 'elec_${DateTime.now().microsecondsSinceEpoch}',
        name: json['name'] as String? ?? 'Элемент электрики',
        type: ElectricalType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ElectricalType.socket,
        ),
        subType: json['subType'] as String? ?? 'socket_single',
        position: Offset(
          (json['px'] as num?)?.toDouble() ?? 0.0,
          (json['py'] as num?)?.toDouble() ?? 0.0,
        ),
        heightFromFloorMm: (json['hMm'] as num?)?.toDouble() ?? 300.0,
        rotationDeg: (json['rot'] as num?)?.toDouble() ?? 0.0,
        groupLabel: json['group'] as String? ?? '',
        showLabel: json['showLbl'] as bool? ?? true,
      );
}

// =========================================================================
// ЭЛЕКТРИКА: ПРИВЯЗКА К ВНУТРЕННЕЙ ЧАСТИ СТЕНЫ И РАСЧЕТ БЛИЖАЙШИХ СТЕН
// =========================================================================

({Offset pos, double angleDeg, Wall? wall, double distFromWallStartCm}) _snapElectricalToWall(
  Offset mouseWorld,
  ElectricalType type,
  List<Wall> walls, {
  bool snapToGrid = false,
  double gridStepCm = 5.0,
  double snapDistanceCm = 80.0,
}) {
  if (type == ElectricalType.light) {
    Offset p = mouseWorld;
    if (snapToGrid) {
      p = Offset((p.dx / gridStepCm).round() * gridStepCm, (p.dy / gridStepCm).round() * gridStepCm);
    }
    return (pos: p, angleDeg: 0.0, wall: null, distFromWallStartCm: 0.0);
  }

  Wall? bestWall;
  double bestDist = snapDistanceCm;
  Offset bestPos = mouseWorld;
  double bestAngle = 0.0;
  double bestDistFromStart = 0.0;

  for (final w in walls) {
    final wallVec = w.end - w.start;
    final wallLen = wallVec.distance;
    if (wallLen < 0.1) continue;

    final u = wallVec / wallLen;
    final norm = Offset(-u.dy, u.dx);

    final toMouse = mouseWorld - w.start;
    final t = (toMouse.dx * u.dx + toMouse.dy * u.dy).clamp(0.0, wallLen);
    final proj = w.start + u * t;

    final d = (mouseWorld - proj).distance;
    if (d < bestDist) {
      bestDist = d;
      bestWall = w;

      final diff = mouseWorld - proj;
      final side = (diff.dx * norm.dx + diff.dy * norm.dy) >= 0 ? 1.0 : -1.0;
      final halfThick = w.thicknessCm / 2.0;
      const defaultR = 8.5;
      bestPos = proj + norm * (side * (halfThick + defaultR));

      double ang = math.atan2(u.dy, u.dx) * 180 / math.pi;
      if (side < 0) {
        ang = (ang + 180) % 360;
      }
      bestAngle = ang;
      bestDistFromStart = t;
    }
  }

  return (
    pos: bestPos,
    angleDeg: bestAngle,
    wall: bestWall,
    distFromWallStartCm: bestDistFromStart,
  );
}

class ElectricalWallBinding {
  final Wall wall;
  final Offset proj;
  final double distCm;
  final bool fromStart;
  final Offset badgeCenter;
  final double wallLenCm;
  final Offset roomDir;
  final double side;

  const ElectricalWallBinding({
    required this.wall,
    required this.proj,
    required this.distCm,
    required this.fromStart,
    required this.badgeCenter,
    required this.wallLenCm,
    required this.roomDir,
    required this.side,
  });
}

ElectricalWallBinding? _getElectricalWallBinding(
  ElectricalItem item,
  List<Wall> walls,
  double canvasScale,
) {
  if (item.type == ElectricalType.light) return null;
  Wall? nearestW;
  double minD = 999999.0;
  Offset? nearestProj;
  for (final w in walls) {
    final p = _projectPointOnSegment(item.position, w.start, w.end);
    final d = (item.position - p).distance;
    if (d < minD) {
      minD = d;
      nearestW = w;
      nearestProj = p;
    }
  }
  if (nearestW == null || nearestProj == null) return null;
  final wallVec = nearestW.end - nearestW.start;
  final wallLen = wallVec.distance;
  if (wallLen < 0.1) return null;
  final u = wallVec / wallLen;
  final norm = Offset(-u.dy, u.dx);
  final toPos = item.position - nearestProj;
  final side = (toPos.dx * norm.dx + toPos.dy * norm.dy) >= 0 ? 1.0 : -1.0;
  final roomDir = norm * side;
  final halfThick = nearestW.thicknessCm / 2.0;

  final dStart = (nearestProj - nearestW.start).distance;
  final dEnd = (nearestProj - nearestW.end).distance;
  final bool fromStart = dStart <= dEnd;
  final cornerCenter = fromStart ? nearestW.start : nearestW.end;
  final distCm = fromStart ? dStart : dEnd;

  final double r = 8.5 / canvasScale.clamp(0.6, 2.0);
  final cornerFace = cornerCenter + roomDir * halfThick;
  final socketFace = nearestProj + roomDir * halfThick;
  final dimOffset = roomDir * (r + 18.0 / canvasScale);
  final dimP1 = cornerFace + dimOffset;
  final dimP2 = socketFace + dimOffset;
  final midPt = Offset((dimP1.dx + dimP2.dx) / 2, (dimP1.dy + dimP2.dy) / 2);

  return ElectricalWallBinding(
    wall: nearestW,
    proj: nearestProj,
    distCm: distCm,
    fromStart: fromStart,
    badgeCenter: midPt,
    wallLenCm: wallLen,
    roomDir: roomDir,
    side: side,
  );
}

List<({Wall wall, Offset proj, double distCm})> _findNearestWallsForLightOnWalls(Offset lightPos, List<Wall> walls) {
  final list = <({Wall wall, Offset proj, double distCm})>[];
  for (final w in walls) {
    final p = _projectPointOnSegment(lightPos, w.start, w.end);
    final d = (lightPos - p).distance;
    final distToFace = (d - w.thicknessCm / 2.0).clamp(0.0, 999999.0);
    list.add((wall: w, proj: p, distCm: distToFace));
  }
  list.sort((a, b) => a.distCm.compareTo(b.distCm));
  if (list.length <= 1) return list;

  final first = list.first;
  final firstDir = (first.wall.end - first.wall.start);
  final firstLen = firstDir.distance;
  final u1 = firstLen > 0.001 ? firstDir / firstLen : const Offset(1, 0);

  ({Wall wall, Offset proj, double distCm})? second;
  for (int i = 1; i < list.length; i++) {
    final wDir = list[i].wall.end - list[i].wall.start;
    final wLen = wDir.distance;
    if (wLen > 0.001) {
      final u2 = wDir / wLen;
      final dot = (u1.dx * u2.dx + u1.dy * u2.dy).abs();
      if (dot < 0.8) {
        second = list[i];
        break;
      }
    }
  }
  second ??= list[1];

  return [first, second];
}

class Wall {
  Offset start;
  Offset end;
  double thicknessCm;
  String? textureSideA;
  String? textureSideB;
  List<WallLayer> layersSideA;
  List<WallLayer> layersSideB;
  TileLayoutConfig? tileConfig;
  double? customClearLengthM;

  Wall(
    this.start,
    this.end, {
    this.thicknessCm = 15.0,
    this.textureSideA,
    this.textureSideB,
    List<WallLayer>? layersSideA,
    List<WallLayer>? layersSideB,
    this.customClearLengthM,
  })  : layersSideA = layersSideA ?? [],
        layersSideB = layersSideB ?? [];

  double get lengthInMeters => (end - start).distance / 100.0;

  double get layersThicknessSideACm =>
      layersSideA.where((l) => l.enabled).fold(0.0, (s, l) => s + l.thicknessMm) / 10.0;
  double get layersThicknessSideBCm =>
      layersSideB.where((l) => l.enabled).fold(0.0, (s, l) => s + l.thicknessMm) / 10.0;
  double get totalLayersThicknessCm => layersThicknessSideACm + layersThicknessSideBCm;
  double get totalEffectiveThicknessCm => thicknessCm + totalLayersThicknessCm;

  void ensureStandardLayers() {
    if (layersSideA.isEmpty) {
      layersSideA = [
        WallLayer(id: 'plaster', name: 'Штукатурка', thicknessMm: 15.0, enabled: true, color: const Color(0xFFCBD5E1), materialCode: 'plaster'),
        WallLayer(id: 'tile_adhesive', name: 'Плиточный клей', thicknessMm: 5.0, enabled: false, color: const Color(0xFF94A3B8), materialCode: 'glue'),
        WallLayer(id: 'tile', name: 'Плитка / Керамогранит', thicknessMm: 9.0, enabled: false, color: const Color(0xFFF1F5F9), materialCode: 'tile'),
        WallLayer(id: 'putty', name: 'Шпатлёвка и краска', thicknessMm: 2.0, enabled: false, color: const Color(0xFFF8FAFC), materialCode: 'paint'),
        WallLayer(id: 'drywall', name: 'Гипсокартон (ГКЛ)', thicknessMm: 12.5, enabled: false, color: const Color(0xFFE2E8F0), materialCode: 'drywall'),
      ];
    }
    if (layersSideB.isEmpty) {
      layersSideB = [
        WallLayer(id: 'plaster', name: 'Штукатурка', thicknessMm: 15.0, enabled: true, color: const Color(0xFFCBD5E1), materialCode: 'plaster'),
        WallLayer(id: 'tile_adhesive', name: 'Плиточный клей', thicknessMm: 5.0, enabled: false, color: const Color(0xFF94A3B8), materialCode: 'glue'),
        WallLayer(id: 'tile', name: 'Плитка / Керамогранит', thicknessMm: 9.0, enabled: false, color: const Color(0xFFF1F5F9), materialCode: 'tile'),
        WallLayer(id: 'putty', name: 'Шпатлёвка и краска', thicknessMm: 2.0, enabled: false, color: const Color(0xFFF8FAFC), materialCode: 'paint'),
        WallLayer(id: 'drywall', name: 'Гипсокартон (ГКЛ)', thicknessMm: 12.5, enabled: false, color: const Color(0xFFE2E8F0), materialCode: 'drywall'),
      ];
    }
  }

  Map<String, dynamic> toJson() => {
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'th': thicknessCm,
        'texA': textureSideA,
        'texB': textureSideB,
        'layersA': layersSideA.map((l) => l.toJson()).toList(),
        'layersB': layersSideB.map((l) => l.toJson()).toList(),
        'tileConfig': tileConfig?.toJson(),
        'customClearM': customClearLengthM,
      };

  factory Wall.fromJson(Map<String, dynamic> m) {
    final legacyTex = m['tex'] as String?;
    final w = Wall(
      Offset((m['sx'] as num).toDouble(), (m['sy'] as num).toDouble()),
      Offset((m['ex'] as num).toDouble(), (m['ey'] as num).toDouble()),
      thicknessCm: (m['th'] as num?)?.toDouble() ?? 15.0,
      textureSideA: (m['texA'] as String?) ?? legacyTex,
      textureSideB: (m['texB'] as String?) ?? legacyTex,
      customClearLengthM: (m['customClearM'] as num?)?.toDouble(),
    );
    if (m['layersA'] is List) {
      w.layersSideA = (m['layersA'] as List).map((e) => WallLayer.fromJson(e)).toList();
    }
    if (m['layersB'] is List) {
      w.layersSideB = (m['layersB'] as List).map((e) => WallLayer.fromJson(e)).toList();
    }
    if (m['tileConfig'] != null) {
      w.tileConfig = TileLayoutConfig.fromJson(Map<String, dynamic>.from(m['tileConfig'] as Map));
    }
    return w;
  }
}

class RoomZone {
  final String id;
  String name;
  List<Offset> polygon;
  Color color;
  String? textureId;
  bool isManuallyAdjusted;
  bool isOpenContour;
  TileLayoutConfig? tileConfig;
  TileLayoutConfig? wallTileConfig;

  RoomZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.color,
    this.textureId,
    this.isManuallyAdjusted = false,
    this.isOpenContour = false,
    this.tileConfig,
    this.wallTileConfig,
  });

  double get areaSqM {
    if (polygon.length < 3) return 0.0;
    double areaPx = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      areaPx += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return (areaPx.abs() / 2.0) / 10000.0;
  }

  double get perimeterM {
    if (polygon.length < 2) return 0.0;
    double p = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      p += (polygon[(i + 1) % polygon.length] - polygon[i]).distance;
    }
    return p / 100.0;
  }

  Offset get visualCenter {
    if (polygon.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    double signedArea = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p0 = polygon[i];
      final p1 = polygon[(i + 1) % polygon.length];
      final a = p0.dx * p1.dy - p1.dx * p0.dy;
      signedArea += a;
      cx += (p0.dx + p1.dx) * a;
      cy += (p0.dy + p1.dy) * a;
    }
    if (signedArea.abs() < 1e-5) {
      double sx = 0, sy = 0;
      for (final p in polygon) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / polygon.length, sy / polygon.length);
    }
    signedArea *= 0.5;
    cx /= (6.0 * signedArea);
    cy /= (6.0 * signedArea);
    return Offset(cx, cy);
  }

  bool containsPoint(Offset point) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / ((yj - yi) == 0 ? 0.0001 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'poly': polygon.map((p) => [p.dx, p.dy]).toList(),
        'color': color.toARGB32(),
        'tex': textureId,
        'man': isManuallyAdjusted,
        'open': isOpenContour,
        'tileConfig': tileConfig?.toJson(),
        'wTile': wallTileConfig?.toJson(),
      };

  factory RoomZone.fromJson(Map<String, dynamic> m) => RoomZone(
        id: m['id'] as String,
        name: m['name'] as String,
        polygon: (m['poly'] as List)
            .map((pt) => Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()))
            .toList(),
        color: Color(m['color'] as int),
        textureId: m['tex'] as String?,
        isManuallyAdjusted: m['man'] as bool? ?? false,
        isOpenContour: m['open'] as bool? ?? false,
        tileConfig: m['tileConfig'] != null
            ? TileLayoutConfig.fromJson(Map<String, dynamic>.from(m['tileConfig'] as Map))
            : null,
        wallTileConfig: m['wTile'] != null
            ? TileLayoutConfig.fromJson(Map<String, dynamic>.from(m['wTile'] as Map))
            : null,
      );
}

class WallOpening {
  OpeningType type;
  String subtypeName;
  Offset position;
  double rotation;
  double widthMeters;
  double heightMeters;
  double sillHeightMeters;
  double depthCm;
  bool flipHorizontal;
  bool flipVertical;
  String? textureId;

  WallOpening({
    required this.type,
    required this.subtypeName,
    required this.position,
    this.rotation = 0.0,
    required this.widthMeters,
    double? heightMeters,
    double? sillHeightMeters,
    this.depthCm = 15.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.textureId,
  })  : heightMeters = heightMeters ?? (type == OpeningType.window ? 1.40 : 2.10),
        sillHeightMeters = sillHeightMeters ?? (type == OpeningType.window ? 0.85 : 0.0);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'sub': subtypeName,
        'px': position.dx,
        'py': position.dy,
        'rot': rotation,
        'w': widthMeters,
        'h': heightMeters,
        'sill': sillHeightMeters,
        'd': depthCm,
        'fh': flipHorizontal,
        'fv': flipVertical,
        'tex': textureId,
      };

  factory WallOpening.fromJson(Map<String, dynamic> m) {
    final t = m['type'] == 'window' ? OpeningType.window : OpeningType.door;
    return WallOpening(
      type: t,
      subtypeName: m['sub'] as String? ?? 'Проем',
      position: Offset((m['px'] as num).toDouble(), (m['py'] as num).toDouble()),
      rotation: (m['rot'] as num?)?.toDouble() ?? 0.0,
      widthMeters: (m['w'] as num?)?.toDouble() ?? 0.9,
      heightMeters: (m['h'] as num?)?.toDouble() ?? (t == OpeningType.window ? 1.40 : 2.10),
      sillHeightMeters: (m['sill'] as num?)?.toDouble() ?? (t == OpeningType.window ? 0.85 : 0.0),
      depthCm: (m['d'] as num?)?.toDouble() ?? 15.0,
      flipHorizontal: m['fh'] as bool? ?? false,
      flipVertical: m['fv'] as bool? ?? false,
      textureId: m['tex'] as String?,
    );
  }
}

class InteriorObject {
  String category;
  String name;
  Offset position;
  double widthMeters;
  double depthMeters;
  double heightMeters;
  double rotationDeg;
  String? textureId;
  String? model3dPath;
  String? previewImagePath;

  InteriorObject({
    required this.category,
    required this.name,
    required this.position,
    required this.widthMeters,
    required this.depthMeters,
    this.heightMeters = 0.85,
    this.rotationDeg = 0.0,
    this.textureId,
    this.model3dPath,
    this.previewImagePath,
  });

  Map<String, dynamic> toJson() => {
        'cat': category,
        'name': name,
        'px': position.dx,
        'py': position.dy,
        'w': widthMeters,
        'd': depthMeters,
        'h': heightMeters,
        'rot': rotationDeg,
        'tex': textureId,
        'mdl': model3dPath,
        'prv': previewImagePath,
      };

  factory InteriorObject.fromJson(Map<String, dynamic> m) => InteriorObject(
        category: m['cat'] as String? ?? 'Мебель',
        name: m['name'] as String? ?? 'Объект',
        position: Offset((m['px'] as num).toDouble(), (m['py'] as num).toDouble()),
        widthMeters: (m['w'] as num?)?.toDouble() ?? 1.0,
        depthMeters: (m['d'] as num?)?.toDouble() ?? 1.0,
        heightMeters: (m['h'] as num?)?.toDouble() ?? 0.85,
        rotationDeg: (m['rot'] as num?)?.toDouble() ?? 0.0,
        textureId: m['tex'] as String?,
        model3dPath: m['mdl'] as String?,
        previewImagePath: m['prv'] as String?,
      );
}

class CustomDimensionLine {
  Offset start;
  Offset end;
  double offsetPx;

  CustomDimensionLine(this.start, this.end, {this.offsetPx = 25.0});

  double get lengthInMeters => (end - start).distance / 100.0;

  Map<String, dynamic> toJson() => {
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'off': offsetPx,
      };

  factory CustomDimensionLine.fromJson(Map<String, dynamic> m) => CustomDimensionLine(
        Offset((m['sx'] as num).toDouble(), (m['sy'] as num).toDouble()),
        Offset((m['ex'] as num).toDouble(), (m['ey'] as num).toDouble()),
        offsetPx: (m['off'] as num?)?.toDouble() ?? 25.0,
      );
}

class CadSnapSettings {
  bool snapToGrid = true;
  double gridStepCm = 5.0;
  bool snapToEndpoints = true;
  bool snapToWallLines = true;
  bool snapToWallFaces = true;
  bool snapToMidpoints = true;
  bool snapAlignmentLines = true;
  bool snapOrtho90 = true;
}

class SnapGuideLine {
  final Offset from;
  final Offset to;
  final String label;
  SnapGuideLine(this.from, this.to, {this.label = ''});
}

class FurnitureWallDistances {
  Wall? leftWall;
  double? leftDistM;
  Offset? leftWallPt;

  Wall? rightWall;
  double? rightDistM;
  Offset? rightWallPt;

  Wall? topWall;
  double? topDistM;
  Offset? topWallPt;

  Wall? bottomWall;
  double? bottomDistM;
  Offset? bottomWallPt;
}

Offset _projectPointOnSegment(Offset p, Offset v, Offset w) {
  final l2 = (w - v).distanceSquared;
  if (l2 == 0) return v;
  double t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
  t = t.clamp(0.0, 1.0);
  return Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
}

(double, double) calcWallDeductions(Wall wall, List<Wall> allWalls, [List<RoomZone>? allZones]) {
  final double axialLenPx = (wall.end - wall.start).distance;
  if (axialLenPx < 1.0) return (0.0, 0.0);
  final dir = (wall.end - wall.start) / axialLenPx;
  final norm = Offset(-dir.dy, dir.dx);

  double startDeduction = 0.0;
  double endDeduction = 0.0;
  final double searchRadius = math.max(38.0, wall.totalEffectiveThicknessCm * 2.5);

  for (final other in allWalls) {
    if (identical(other, wall)) continue;
    final otherVec = other.end - other.start;
    final otherLen = otherVec.distance;
    if (otherLen < 1.0) continue;
    final otherDir = otherVec / otherLen;

    final double dot = (dir.dx * otherDir.dx + dir.dy * otherDir.dy).abs();
    if (dot > 0.95) continue; // Collinear / parallel walls

    final otherNorm = Offset(-otherDir.dy, otherDir.dx);
    final double halfOtherT = other.totalEffectiveThicknessCm / 2.0;

    final List<Offset> corners = [
      other.start + otherNorm * halfOtherT,
      other.start - otherNorm * halfOtherT,
      other.end + otherNorm * halfOtherT,
      other.end - otherNorm * halfOtherT,
    ];

    // Start joint inspection
    double dToStart = double.infinity;
    for (final c in corners) {
      dToStart = math.min(dToStart, (c - wall.start).distance);
    }
    final projStart = _projectPointOnSegment(wall.start, other.start, other.end);
    dToStart = math.min(dToStart, (wall.start - projStart).distance);

    if (dToStart <= searchRadius) {
      for (final c in corners) {
        final t = (c - wall.start).dx * dir.dx + (c - wall.start).dy * dir.dy;
        final perp = ((c - wall.start).dx * norm.dx + (c - wall.start).dy * norm.dy).abs();
        if (perp <= wall.totalEffectiveThicknessCm * 1.5 + 5.0 && t >= 0.0 && t <= axialLenPx * 0.55) {
          startDeduction = math.max(startDeduction, t);
        }
      }
      final denom = dir.dx * otherNorm.dx + dir.dy * otherNorm.dy;
      if (denom.abs() > 0.08) {
        for (final sign in [-1.0, 1.0]) {
          final planePt = other.start + otherNorm * (halfOtherT * sign);
          final tInter = ((planePt - wall.start).dx * otherNorm.dx + (planePt - wall.start).dy * otherNorm.dy) / denom;
          final interPt = wall.start + dir * tInter;
          final distToSeg = (interPt - _projectPointOnSegment(interPt, other.start, other.end)).distance;
          if (distToSeg <= halfOtherT + 6.0 && tInter >= 0.0 && tInter <= axialLenPx * 0.55) {
            startDeduction = math.max(startDeduction, tInter);
          }
        }
      }
    }

    // End joint inspection
    double dToEnd = double.infinity;
    for (final c in corners) {
      dToEnd = math.min(dToEnd, (c - wall.end).distance);
    }
    final projEnd = _projectPointOnSegment(wall.end, other.start, other.end);
    dToEnd = math.min(dToEnd, (wall.end - projEnd).distance);

    if (dToEnd <= searchRadius) {
      for (final c in corners) {
        final t = (wall.end - c).dx * dir.dx + (wall.end - c).dy * dir.dy;
        final perp = ((wall.end - c).dx * norm.dx + (wall.end - c).dy * norm.dy).abs();
        if (perp <= wall.totalEffectiveThicknessCm * 1.5 + 5.0 && t >= 0.0 && t <= axialLenPx * 0.55) {
          endDeduction = math.max(endDeduction, t);
        }
      }
      final denom = dir.dx * otherNorm.dx + dir.dy * otherNorm.dy;
      if (denom.abs() > 0.08) {
        for (final sign in [-1.0, 1.0]) {
          final planePt = other.start + otherNorm * (halfOtherT * sign);
          final tInter = ((wall.end - planePt).dx * otherNorm.dx + (wall.end - planePt).dy * otherNorm.dy) / denom;
          final interPt = wall.end - dir * tInter;
          final distToSeg = (interPt - _projectPointOnSegment(interPt, other.start, other.end)).distance;
          if (distToSeg <= halfOtherT + 6.0 && tInter >= 0.0 && tInter <= axialLenPx * 0.55) {
            endDeduction = math.max(endDeduction, tInter);
          }
        }
      }
    }
  }

  return (startDeduction, endDeduction);
}

class WallFaceDimension {
  final Wall wall;
  final Offset innerStart;
  final Offset innerEnd;
  final Offset witnessStartExt;
  final Offset witnessEndExt;
  final Offset badgePos;
  final Offset roomNormal;
  final double lengthM;
  final int lengthMm;
  final String formattedText;

  WallFaceDimension({
    required this.wall,
    required this.innerStart,
    required this.innerEnd,
    required this.witnessStartExt,
    required this.witnessEndExt,
    required this.badgePos,
    required this.roomNormal,
    required this.lengthM,
    required this.lengthMm,
    required this.formattedText,
  });
}

WallFaceDimension computeWallFaceDimension(Wall wall, List<Wall> allWalls, [List<RoomZone>? allZones]) {
  final double axialLenPx = (wall.end - wall.start).distance;
  if (axialLenPx < 1.0) {
    return WallFaceDimension(
      wall: wall,
      innerStart: wall.start,
      innerEnd: wall.end,
      witnessStartExt: wall.start,
      witnessEndExt: wall.end,
      badgePos: wall.start,
      roomNormal: const Offset(0, 1),
      lengthM: 0.0,
      lengthMm: 0,
      formattedText: '0 мм',
    );
  }

  final dir = (wall.end - wall.start) / axialLenPx;
  final norm = Offset(-dir.dy, dir.dx);
  final halfT = wall.totalEffectiveThicknessCm / 2.0;

  Offset roomNorm = norm;
  final mid = Offset((wall.start.dx + wall.end.dx) / 2, (wall.start.dy + wall.end.dy) / 2);
  final probeA = mid + norm * (halfT + 8.0);
  final probeB = mid - norm * (halfT + 8.0);

  bool sideAInZone = false;
  bool sideBInZone = false;
  if (allZones != null && allZones.isNotEmpty) {
    for (final z in allZones) {
      if (z.polygon.length >= 3) {
        if (z.containsPoint(probeA)) sideAInZone = true;
        if (z.containsPoint(probeB)) sideBInZone = true;
      }
    }
  }

  if (sideBInZone && !sideAInZone) {
    roomNorm = -norm;
  } else if (!sideAInZone && !sideBInZone) {
    double sideAScore = 0;
    double sideBScore = 0;
    for (final other in allWalls) {
      if (identical(other, wall)) continue;
      if ((other.start - wall.start).distance < 15.0 || (other.end - wall.start).distance < 15.0 ||
          (other.start - wall.end).distance < 15.0 || (other.end - wall.end).distance < 15.0) {
        final otherMid = Offset((other.start.dx + other.end.dx) / 2, (other.start.dy + other.end.dy) / 2);
        final toOther = otherMid - mid;
        if (toOther.dx * norm.dx + toOther.dy * norm.dy > 0) {
          sideAScore += 1;
        } else {
          sideBScore += 1;
        }
      }
    }
    if (sideBScore > sideAScore) {
      roomNorm = -norm;
    }
  }

  final faceBaseStart = wall.start + roomNorm * halfT;
  final faceBaseEnd = wall.end + roomNorm * halfT;

  Offset cStart = faceBaseStart;
  Offset cEnd = faceBaseEnd;

  Wall? adjStart;
  Wall? adjEnd;
  for (final other in allWalls) {
    if (identical(other, wall)) continue;
    if ((other.start - wall.start).distance < 15.0 || (other.end - wall.start).distance < 15.0) {
      adjStart = other;
    }
    if ((other.start - wall.end).distance < 15.0 || (other.end - wall.end).distance < 15.0) {
      adjEnd = other;
    }
  }

  if (adjStart != null) {
    final otherDir = (adjStart.end - adjStart.start);
    final otherLen = otherDir.distance;
    if (otherLen > 1.0) {
      final otherNorm = Offset(-otherDir.dy / otherLen, otherDir.dx / otherLen);
      final otherHalfT = adjStart.totalEffectiveThicknessCm / 2.0;
      for (final sign in [-1.0, 1.0]) {
        final otherFacePt = adjStart.start + otherNorm * (otherHalfT * sign);
        final inter = _intersectInfiniteLines(faceBaseStart, dir, otherFacePt, otherDir / otherLen);
        if (inter != null && (inter - wall.start).distance < math.max(60.0, wall.totalEffectiveThicknessCm * 2.5)) {
          cStart = inter;
          break;
        }
      }
    }
  }

  if (adjEnd != null) {
    final otherDir = (adjEnd.end - adjEnd.start);
    final otherLen = otherDir.distance;
    if (otherLen > 1.0) {
      final otherNorm = Offset(-otherDir.dy / otherLen, otherDir.dx / otherLen);
      final otherHalfT = adjEnd.totalEffectiveThicknessCm / 2.0;
      for (final sign in [-1.0, 1.0]) {
        final otherFacePt = adjEnd.start + otherNorm * (otherHalfT * sign);
        final inter = _intersectInfiniteLines(faceBaseEnd, dir, otherFacePt, otherDir / otherLen);
        if (inter != null && (inter - wall.end).distance < math.max(60.0, wall.totalEffectiveThicknessCm * 2.5)) {
          cEnd = inter;
          break;
        }
      }
    }
  }

  double lenPx = (cEnd - cStart).dx * dir.dx + (cEnd - cStart).dy * dir.dy;
  if (lenPx < 5.0) lenPx = axialLenPx;

  double finalLenM = lenPx / 100.0;
  if (wall.customClearLengthM != null && wall.customClearLengthM! > 0) {
    finalLenM = wall.customClearLengthM!;
  }
  final int lenMm = (finalLenM * 1000.0).round();

  final double extDist = 24.0;
  final witStart = cStart + roomNorm * extDist;
  final witEnd = cEnd + roomNorm * extDist;
  final badgePos = Offset((witStart.dx + witEnd.dx) / 2, (witStart.dy + witEnd.dy) / 2);

  return WallFaceDimension(
    wall: wall,
    innerStart: cStart,
    innerEnd: cEnd,
    witnessStartExt: witStart,
    witnessEndExt: witEnd,
    badgePos: badgePos,
    roomNormal: roomNorm,
    lengthM: finalLenM,
    lengthMm: lenMm,
    formattedText: '$lenMm мм',
  );
}

double calcWallInternalLength(Wall wall, List<Wall> allWalls, [List<RoomZone>? allZones]) {
  if (wall.customClearLengthM != null && wall.customClearLengthM! > 0) {
    return wall.customClearLengthM!;
  }
  final double axialLenPx = (wall.end - wall.start).distance;
  if (axialLenPx < 1.0) return 0.0;
  final faceDim = computeWallFaceDimension(wall, allWalls, allZones);
  if (faceDim.lengthM > 0.05) {
    return faceDim.lengthM;
  }
  final (startDeduction, endDeduction) = calcWallDeductions(wall, allWalls, allZones);
  return math.max(0.0, (axialLenPx - startDeduction - endDeduction) / 100.0);
}

Offset? _intersectInfiniteLines(Offset p1, Offset d1, Offset p2, Offset d2) {
  final denom = d1.dx * d2.dy - d1.dy * d2.dx;
  if (denom.abs() < 1e-4) return null;
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  final t = (dx * d2.dy - dy * d2.dx) / denom;
  return Offset(p1.dx + d1.dx * t, p1.dy + d1.dy * t);
}

FurnitureWallDistances _computeFurnitureWallDistances(InteriorObject obj, List<Wall> walls) {
  final res = FurnitureWallDistances();
  final double halfW = (obj.widthMeters * 100.0) / 2.0;
  final double halfD = (obj.depthMeters * 100.0) / 2.0;
  final pos = obj.position;

  for (final w in walls) {
    final proj = _projectPointOnSegment(pos, w.start, w.end);
    final dx = proj.dx - pos.dx;
    final dy = proj.dy - pos.dy;

    if ((w.start.dx - w.end.dx).abs() < (w.start.dy - w.end.dy).abs()) {
      final minY = math.min(w.start.dy, w.end.dy) - 40;
      final maxY = math.max(w.start.dy, w.end.dy) + 40;
      if (pos.dy >= minY && pos.dy <= maxY) {
        final wallFaceOffset = w.thicknessCm / 2.0;
        if (dx < 0) {
          final clearPx = (-dx) - halfW - wallFaceOffset;
          if (clearPx >= 0 && (res.leftDistM == null || clearPx / 100.0 < res.leftDistM!)) {
            res.leftDistM = clearPx / 100.0;
            res.leftWall = w;
            res.leftWallPt = Offset(proj.dx + wallFaceOffset, pos.dy);
          }
        } else {
          final clearPx = dx - halfW - wallFaceOffset;
          if (clearPx >= 0 && (res.rightDistM == null || clearPx / 100.0 < res.rightDistM!)) {
            res.rightDistM = clearPx / 100.0;
            res.rightWall = w;
            res.rightWallPt = Offset(proj.dx - wallFaceOffset, pos.dy);
          }
        }
      }
    } else {
      final minX = math.min(w.start.dx, w.end.dx) - 40;
      final maxX = math.max(w.start.dx, w.end.dx) + 40;
      if (pos.dx >= minX && pos.dx <= maxX) {
        final wallFaceOffset = w.thicknessCm / 2.0;
        if (dy < 0) {
          final clearPx = (-dy) - halfD - wallFaceOffset;
          if (clearPx >= 0 && (res.topDistM == null || clearPx / 100.0 < res.topDistM!)) {
            res.topDistM = clearPx / 100.0;
            res.topWall = w;
            res.topWallPt = Offset(pos.dx, proj.dy + wallFaceOffset);
          }
        } else {
          final clearPx = dy - halfD - wallFaceOffset;
          if (clearPx >= 0 && (res.bottomDistM == null || clearPx / 100.0 < res.bottomDistM!)) {
            res.bottomDistM = clearPx / 100.0;
            res.bottomWall = w;
            res.bottomWallPt = Offset(pos.dx, proj.dy - wallFaceOffset);
          }
        }
      }
    }
  }
  return res;
}

enum ActiveDockFlyout {
  none,
  construction,
  templates,
  textures,
  furniture,
  electrical,
  snapping,
}

class FloorPlanEditor extends StatefulWidget {
  const FloorPlanEditor({super.key});

  @override
  State<FloorPlanEditor> createState() => _FloorPlanEditorState();
}

class _FloorPlanEditorState extends State<FloorPlanEditor> with SingleTickerProviderStateMixin {
  static const String _kAutoSaveKey = 'floor_plan_pro_autosave_v5';

  bool isLoading = true;
  List<CatalogTexture> myTextureCatalog = [];
  List<Catalog3DModel> my3DModelCatalog = [];
  final Map<String, ui.Image> _loadedImages = {};
  final Map<String, Parsed3DMesh> _loaded3DMeshes = {};
  List<String> _debugManifestAssets = [];

  final List<Wall> walls = [];
  final List<RoomZone> zones = [];
  final List<WallOpening> openings = [];
  final List<InteriorObject> objects = [];
  final List<CustomDimensionLine> customDimensions = [];

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  final CadSnapSettings snapConfig = CadSnapSettings();
  final List<SnapGuideLine> activeGreenGuides = [];

  RoomZone? editingBoundaryZone;
  int? draggedZoneVertexIndex;

  InteriorObject? selectedObject;
  final Set<InteriorObject> selectedObjects = {};
  final Set<Wall> selectedWalls = {};
  final Set<WallOpening> selectedOpenings = {};
  final Set<CustomDimensionLine> selectedDimensions = {};
  final Set<ElectricalItem> selectedElectricalItems = {};
  CustomDimensionLine? selectedDimension;
  Rect? selectionMarquee;
  Offset? _selectionMarqueeStart;
  bool isMarqueeLeftToRight = true;
  Wall? selectedWall;
  int? selectedWallSide;
  WallOpening? selectedOpening;

  EditorTool selectedTool = EditorTool.drawWall;
  double currentThicknessCm = 15.0;

  bool _hoveringWallToolBtn = false;
  bool _hoveringThicknessPopup = false;
  Timer? _hideThicknessTimer;

  Offset canvasOffset = const Offset(80, 120);
  double canvasScale = 0.85;
  int activePointers = 0;
  bool _isMiddleMousePanning = false;
  Offset? _lastMiddleMousePos;
  double _baseScale = 1.0;
  Offset _baseFocalPoint = Offset.zero;
  Offset _baseCanvasOffset = Offset.zero;

  bool is3DMode = false;
  bool isDarkTheme = true;
  bool showGrid = true;
  WallViewMode3D wallViewMode3D = WallViewMode3D.cutawaySims;
  double wallHeightMeters = 2.70;
  double cameraYaw = -0.65;
  double cameraPitch = 0.72;
  double cameraZoom3D = 0.95;
  Offset cameraPan3D = Offset.zero;
  late final AnimationController _wallRiseController;
  Offset? _last3DPointerPos;
  final List<_WallHitPolygon3D> _last3DWallHitPolygons = [];

  Timer? _autoPanTimer;
  Offset? _lastPointerScreenPos;
  Size _viewportSize = Size.zero;

  Offset? currentStart;
  Offset? currentEnd;
  Offset? snappedPointHighlight;

  Offset? draggedCornerOriginal;
  WallOpening? draggedOpening;
  InteriorObject? draggedObject;

  final List<ElectricalItem> electricalItems = [];
  ElectricalItem? selectedElectricalItem;
  ElectricalItem? draggedElectricalItem;
  ({ElectricalType type, String subType, String name, double defaultHeightMm})? pendingElectricalPreset;

  UnitFormat currentUnit = UnitFormat.millimeters;
  bool showFilterFlyout = false;
  bool showWallThicknessSlider = false;
  bool _hasMovedDraggedItem = false;

  // Режим произвольной планировки
  bool isCustomSketchMode = false;
  int customSketchStep = 1; // 1 = набросок эскиза, 2 = задание жестких размеров
  int _sketchStartWallCount = 0;
  final Map<int, double> sketchWallTargetLengthsMm = {};
  bool showSettingsFlyout = false;
  bool showFurnitureLayer = true;
  bool showElectricalLayer = true;
  bool showDimensionsLayer = true;
  bool showZonesLayer = true;
  bool showElectricalLabels = true;
  bool showSocketDimensions = true;
  bool showLightDimensions = true;
  Offset? currentElectricalPreviewPos;

  String formatLength(double meters, {bool includeUnit = true, int? decimals}) {
    if (currentUnit == UnitFormat.millimeters) {
      final mm = (meters * 1000.0).round();
      return includeUnit ? '$mm мм' : '$mm';
    } else {
      final d = decimals ?? 2;
      final s = meters.toStringAsFixed(d);
      return includeUnit ? '$s м' : s;
    }
  }

  String formatCm(double cm, {bool includeUnit = true}) {
    if (currentUnit == UnitFormat.millimeters) {
      final mm = (cm * 10.0).round();
      return includeUnit ? '$mm мм' : '$mm';
    } else {
      final m = cm / 100.0;
      return includeUnit ? '${m.toStringAsFixed(2)} м' : m.toStringAsFixed(2);
    }
  }

  String formatMm(double mm, {bool includeUnit = true}) {
    if (currentUnit == UnitFormat.millimeters) {
      return includeUnit ? '${mm.round()} мм' : '${mm.round()}';
    } else {
      final m = mm / 1000.0;
      return includeUnit ? '${m.toStringAsFixed(2)} м' : m.toStringAsFixed(2);
    }
  }

  double parseInputToMeters(String text) {
    final clean = text.replaceAll(' ', '').replaceAll(',', '.').replaceAll('м', '').replaceAll('мм', '');
    final val = double.tryParse(clean) ?? 0.0;
    if (currentUnit == UnitFormat.millimeters) {
      return val / 1000.0;
    }
    return val;
  }

  static const List<Color> kZonePalette = [
    Color(0xFFD9B99B),
    Color(0xFF93C5FD),
    Color(0xFF86EFAC),
    Color(0xFFFDE047),
    Color(0xFFF9A8D4),
    Color(0xFFC4B5FD),
    Color(0xFF67E8F9),
    Color(0xFFFDBA74),
  ];

  static const List<(String, String, double, double, double)> kBuiltInPresets = [
    ('Мягкая мебель', 'Диван прямой', 2.20, 0.95, 0.85),
    ('Мягкая мебель', 'Диван угловой', 2.60, 1.60, 0.85),
    ('Мягкая мебель', 'Кресло', 0.85, 0.85, 0.80),
    ('Спальня', 'Кровать двуспальная', 1.80, 2.05, 0.90),
    ('Спальня', 'Кровать односпальная', 0.95, 2.05, 0.85),
    ('Спальня', 'Тумба прикроватная', 0.50, 0.45, 0.55),
    ('Столы и стулья', 'Стол обеденный', 1.50, 0.85, 0.75),
    ('Столы и стулья', 'Стол рабочий', 1.20, 0.65, 0.75),
    ('Шкафы и хранение', 'Стеллаж открытый', 1.20, 0.45, 2.00),
    ('Шкафы и хранение', 'Шкаф-купе', 2.00, 0.60, 2.40),
    ('Шкафы и хранение', 'Комод', 1.00, 0.50, 0.85),
    ('Кухня и техника', 'Кухонный гарнитур', 2.40, 0.60, 0.85),
    ('Кухня и техника', 'Холодильник', 0.60, 0.65, 1.95),
    ('Кухня и техника', 'Плита / Духовка', 0.60, 0.60, 0.85),
    ('Сантехника', 'Ванна акриловая', 1.70, 0.75, 0.60),
    ('Сантехника', 'Душевая кабина', 0.90, 0.90, 2.10),
    ('Сантехника', 'Унитаз-инсталляция', 0.40, 0.65, 0.80),
    ('Сантехника', 'Раковина с тумбой', 0.70, 0.50, 0.85),
    ('Сантехника', 'Стиральная машина', 0.60, 0.60, 0.85),
    ('Электрика и отопление', 'Радиатор отопления', 1.00, 0.12, 0.55),
    ('Электрика и отопление', 'Электрощиток', 0.40, 0.15, 0.50),
  ];

  @override
  void initState() {
    super.initState();
    _wallRiseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() {
        setState(() {});
      });
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _initializeProjectAndAssets();
  }

  @override
  void dispose() {
    _wallRiseController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _autoPanTimer?.cancel();
    _hideThicknessTimer?.cancel();
    super.dispose();
  }

  void _toggle3DMode() {
    if (!is3DMode) {
      setState(() {
        is3DMode = true;
        editingBoundaryZone = null;
      });
      _wallRiseController.forward(from: 0.0);
    } else {
      _wallRiseController.reverse().then((_) {
        if (mounted) {
          setState(() => is3DMode = false);
        }
      });
    }
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      final widget = primaryFocus.context!.widget;
      if (widget is EditableText) return false;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (isCtrl && key == LogicalKeyboardKey.keyZ) {
      if (isShift) {
        _redo();
      } else {
        _undo();
      }
      return true;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyY) {
      _redo();
      return true;
    }

    if (isCtrl && key == LogicalKeyboardKey.keyD && selectedObject != null) {
      _recordSnapshotForUndo();
      setState(() {
        final copy = InteriorObject(
          category: selectedObject!.category,
          name: selectedObject!.name,
          position: selectedObject!.position + const Offset(30, 30),
          widthMeters: selectedObject!.widthMeters,
          depthMeters: selectedObject!.depthMeters,
          heightMeters: selectedObject!.heightMeters,
          rotationDeg: selectedObject!.rotationDeg,
          textureId: selectedObject!.textureId,
          model3dPath: selectedObject!.model3dPath,
          previewImagePath: selectedObject!.previewImagePath,
        );
        objects.add(copy);
        selectedObject = copy;
        _autoSaveCurrentProject();
      });
      return true;
    }

    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (selectedObjects.isNotEmpty ||
          selectedWalls.isNotEmpty ||
          selectedOpenings.isNotEmpty ||
          selectedDimensions.isNotEmpty ||
          selectedElectricalItems.isNotEmpty) {
        _recordSnapshotForUndo();
        setState(() {
          objects.removeWhere((o) => selectedObjects.contains(o));
          walls.removeWhere((w) => selectedWalls.contains(w));
          openings.removeWhere((o) => selectedOpenings.contains(o));
          customDimensions.removeWhere((d) => selectedDimensions.contains(d));
          electricalItems.removeWhere((e) => selectedElectricalItems.contains(e));
          selectedObjects.clear();
          selectedWalls.clear();
          selectedOpenings.clear();
          selectedDimensions.clear();
          selectedElectricalItems.clear();
          selectedObject = null;
          selectedWall = null;
          selectedOpening = null;
          selectedDimension = null;
          selectedElectricalItem = null;
          _rebuildAutoZonesFromWalls();
          _autoSaveCurrentProject();
        });
        return true;
      }
      if (selectedDimension != null) {
        _recordSnapshotForUndo();
        setState(() {
          customDimensions.remove(selectedDimension);
          selectedDimensions.remove(selectedDimension);
          selectedDimension = null;
          _autoSaveCurrentProject();
        });
        return true;
      } else if (selectedObject != null) {
        _recordSnapshotForUndo();
        setState(() {
          objects.remove(selectedObject);
          selectedObject = null;
          _autoSaveCurrentProject();
        });
        return true;
      } else if (selectedOpening != null) {
        _recordSnapshotForUndo();
        setState(() {
          openings.remove(selectedOpening);
          selectedOpening = null;
          _autoSaveCurrentProject();
        });
        return true;
      } else if (selectedWall != null) {
        _recordSnapshotForUndo();
        setState(() {
          walls.remove(selectedWall);
          selectedWall = null;
          _rebuildAutoZonesFromWalls();
        });
        return true;
      } else if (selectedElectricalItem != null) {
        _recordSnapshotForUndo();
        setState(() {
          electricalItems.remove(selectedElectricalItem);
          selectedElectricalItem = null;
          _autoSaveCurrentProject();
        });
        return true;
      }
    }

    if (key == LogicalKeyboardKey.keyR && selectedObject != null) {
      _recordSnapshotForUndo();
      setState(() {
        final stepDeg = isShift ? 15.0 : 45.0;
        selectedObject!.rotationDeg = (selectedObject!.rotationDeg + stepDeg) % 360.0;
        _autoSaveCurrentProject();
      });
      return true;
    }

    if (selectedObject != null) {
      final double moveStep = isShift ? 1.0 : snapConfig.gridStepCm;
      Offset delta = Offset.zero;
      if (key == LogicalKeyboardKey.arrowLeft) delta = Offset(-moveStep, 0);
      if (key == LogicalKeyboardKey.arrowRight) delta = Offset(moveStep, 0);
      if (key == LogicalKeyboardKey.arrowUp) delta = Offset(0, -moveStep);
      if (key == LogicalKeyboardKey.arrowDown) delta = Offset(0, moveStep);

      if (delta != Offset.zero) {
        _recordSnapshotForUndo();
        setState(() {
          selectedObject!.position += delta;
          _autoSaveCurrentProject();
        });
        return true;
      }
    }

    if (key == LogicalKeyboardKey.space) {
      _toggle3DMode();
      return true;
    }

    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        pendingElectricalPreset = null;
        currentElectricalPreviewPos = null;
        activeDockFlyout = ActiveDockFlyout.none;
        showEstimateFlyout = false;
        selectedObject = null;
        selectedWall = null;
        selectedWallSide = null;
        selectedOpening = null;
        editingBoundaryZone = null;
        currentStart = null;
        currentEnd = null;
        selectedTool = EditorTool.overview;
      });
      return true;
    }

    if (!isCtrl) {
      if (key == LogicalKeyboardKey.digit1) setState(() => selectedTool = EditorTool.overview);
      if (key == LogicalKeyboardKey.digit2) setState(() => selectedTool = EditorTool.drawWall);
      if (key == LogicalKeyboardKey.digit3) setState(() => selectedTool = EditorTool.drawRoomBox);
      if (key == LogicalKeyboardKey.digit4) setState(() => selectedTool = EditorTool.drawDimension);
      if (key == LogicalKeyboardKey.digit5) setState(() => selectedTool = EditorTool.addDoor);
      if (key == LogicalKeyboardKey.digit6) setState(() => selectedTool = EditorTool.addWindow);
    }

    return false;
  }

  void _showKeyboardShortcutsModal() {
    const shortcuts = [
      ('Колесико мыши (зажать)', 'Перемещение (панорама) камеры в любом месте (не двигает мебель)'),
      ('Колесико мыши (крутить)', 'Приближение / отдаление чертежа и 3D-сцены'),
      ('Delete / Backspace', 'Удалить выбранную мебель, окно, дверь или стену'),
      ('R (или Shift + R)', 'Повернуть выбранную мебель на 45° (или на 15°)'),
      ('Стрелки ⬅️⬆️➡️⬇️', 'Точно сдвинуть выбранную мебель на шаг сетки (с Shift — по 1 см)'),
      ('Ctrl + D', 'Дублировать выбранный предмет мебели'),
      ('Ctrl + Z / Ctrl + Y', 'Отменить действие / Вернуть действие'),
      ('Пробел (Space)', 'Быстрое переключение между 2D чертежом и 3D видом'),
      ('Клик по стороне стены в 3D', 'Открыть визуальный каталог текстур именно для этой стороны стены'),
      ('1 / 2 / 3 / 4 / 5 / 6', 'Быстрый выбор инструментов: Обзор, Стена, Коробка, Размер, Дверь, Окно'),
      ('Esc', 'Снять выделение / Отменить текущее рисование'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_alt_outlined, color: Color(0xFF0D99FF)),
            SizedBox(width: 10),
            Text('Горячие клавиши и управление', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: math.min(560.0, MediaQuery.of(context).size.width - 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: shortcuts
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 195,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueGrey.shade200),
                              ),
                              child: Text(
                                s.$1,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(s.$2, style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
        ],
      ),
    );
  }

  String _encodeCurrentStateToJson() {
    return jsonEncode({
      'version': 5,
      'wallHeight': wallHeightMeters,
      'walls': walls.map((w) => w.toJson()).toList(),
      'zones': zones.map((z) => z.toJson()).toList(),
      'openings': openings.map((o) => o.toJson()).toList(),
      'objects': objects.map((o) => o.toJson()).toList(),
      'dimensions': customDimensions.map((d) => d.toJson()).toList(),
      'unit': currentUnit.name,
      'showFurniture': showFurnitureLayer,
      'showElectrical': showElectricalLayer,
      'showDimensions': showDimensionsLayer,
      'showZones': showZonesLayer,
      'electrical': electricalItems.map((e) => e.toJson()).toList(),
    });
  }

  void _restoreStateFromJson(String jsonStr, {bool saveToLocalStorage = true}) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      wallHeightMeters = (data['wallHeight'] as num?)?.toDouble() ?? 2.70;
      walls
        ..clear()
        ..addAll(((data['walls'] as List?) ?? []).map((e) => Wall.fromJson(e)));
      zones
        ..clear()
        ..addAll(((data['zones'] as List?) ?? []).map((e) => RoomZone.fromJson(e)));
      openings
        ..clear()
        ..addAll(((data['openings'] as List?) ?? []).map((e) => WallOpening.fromJson(e)));
      objects
        ..clear()
        ..addAll(((data['objects'] as List?) ?? []).map((e) => InteriorObject.fromJson(e)));
      customDimensions
        ..clear()
        ..addAll(((data['dimensions'] as List?) ?? []).map((e) => CustomDimensionLine.fromJson(e)));
      if (data['unit'] is String) {
        currentUnit = UnitFormat.values.firstWhere(
          (u) => u.name == data['unit'],
          orElse: () => UnitFormat.meters,
        );
      }
      if (data['showFurniture'] is bool) showFurnitureLayer = data['showFurniture'] as bool;
      if (data['showElectrical'] is bool) showElectricalLayer = data['showElectrical'] as bool;
      if (data['showDimensions'] is bool) showDimensionsLayer = data['showDimensions'] as bool;
      if (data['showZones'] is bool) showZonesLayer = data['showZones'] as bool;
      electricalItems
        ..clear()
        ..addAll(((data['electrical'] as List?) ?? []).map((e) => ElectricalItem.fromJson(e)));
      editingBoundaryZone = null;
      selectedObject = null;
      selectedWall = null;
      selectedWallSide = null;
      selectedOpening = null;
      selectedElectricalItem = null;
      draggedElectricalItem = null;

      _rebuildAutoZonesFromWalls();
      if (saveToLocalStorage) {
        PlatformAdapter.saveLocalStorage(_kAutoSaveKey, jsonStr);
      }
    } catch (e) {
      debugPrint('Ошибка чтения JSON проекта: $e');
    }
  }

  void _recordSnapshotForUndo() {
    final snap = _encodeCurrentStateToJson();
    if (_undoStack.isEmpty || _undoStack.last != snap) {
      _undoStack.add(snap);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
    }
  }

  void _autoSaveCurrentProject() {
    try {
      PlatformAdapter.saveLocalStorage(_kAutoSaveKey, _encodeCurrentStateToJson());
    } catch (_) {}
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_encodeCurrentStateToJson());
    final prev = _undoStack.removeLast();
    setState(() {
      _restoreStateFromJson(prev);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_encodeCurrentStateToJson());
    final next = _redoStack.removeLast();
    setState(() {
      _restoreStateFromJson(next);
    });
  }

  void _exportProjectJsonFile() {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonDecode(_encodeCurrentStateToJson()));
    final bytes = utf8.encode(jsonStr);
    PlatformAdapter.downloadFile('floor_plan_${DateTime.now().millisecondsSinceEpoch}.json', bytes, 'application/json');
  }

  void _importProjectJsonFile() {
    PlatformAdapter.pickAndReadJson((content) {
      _recordSnapshotForUndo();
      setState(() {
        _restoreStateFromJson(content);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проект успешно загружен!')),
        );
      }
    });
  }

  void _exportPlanAsVectorPdf() {
    double minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
    for (final w in walls) {
      minX = math.min(minX, math.min(w.start.dx, w.end.dx));
      minY = math.min(minY, math.min(w.start.dy, w.end.dy));
      maxX = math.max(maxX, math.max(w.start.dx, w.end.dx));
      maxY = math.max(maxY, math.max(w.start.dy, w.end.dy));
    }
    if (minX > maxX) {
      minX = 0;
      minY = 0;
      maxX = 800;
      maxY = 600;
    }
    final pad = 120.0;
    final vbX = minX - pad;
    final vbY = minY - pad;
    final vbW = (maxX - minX) + pad * 2;
    final vbH = (maxY - minY) + pad * 2;

    final StringBuffer svg = StringBuffer();
    svg.writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$vbX $vbY $vbW $vbH" width="100%" height="540px" style="background:#ffffff; border:1px solid #cbd5e1; border-radius:8px;">');

    for (double x = (vbX ~/ 100) * 100.0; x <= vbX + vbW; x += 100) {
      svg.writeln('<line x1="$x" y1="$vbY" x2="$x" y2="${vbY + vbH}" stroke="#e2e8f0" stroke-width="1"/>');
    }
    for (double y = (vbY ~/ 100) * 100.0; y <= vbY + vbH; y += 100) {
      svg.writeln('<line x1="$vbX" y1="$y" x2="${vbX + vbW}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>');
    }

    for (final z in zones) {
      if (z.polygon.length < 3) continue;
      final pts = z.polygon.map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}').join(' ');
      final hex = '#${(z.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      svg.writeln('<polygon points="$pts" fill="$hex" fill-opacity="0.28" stroke="$hex" stroke-width="2"/>');
    }

    for (final o in objects) {
      final wPx = o.widthMeters * 100.0;
      final dPx = o.depthMeters * 100.0;
      svg.writeln(
          '<g transform="translate(${o.position.dx},${o.position.dy}) rotate(${o.rotationDeg})">'
          '<rect x="${-wPx / 2}" y="${-dPx / 2}" width="$wPx" height="$dPx" rx="5" fill="#cbd5e1" stroke="#1e293b" stroke-width="2"/>'
          '<text x="0" y="-2" font-family="Arial" font-size="11" font-weight="bold" text-anchor="middle" fill="#0f172a">${o.name}</text>'
          '<text x="0" y="12" font-family="Arial" font-size="9" text-anchor="middle" fill="#334155">${o.widthMeters.toStringAsFixed(2)}x${o.depthMeters.toStringAsFixed(2)} м</text>'
          '</g>');
    }

    for (final w in walls) {
      svg.writeln(
          '<line x1="${w.start.dx}" y1="${w.start.dy}" x2="${w.end.dx}" y2="${w.end.dy}" stroke="#1e293b" stroke-width="${w.thicknessCm}" stroke-linecap="round"/>');
      final mid = Offset((w.start.dx + w.end.dx) / 2, (w.start.dy + w.end.dy) / 2);
      svg.writeln(
          '<rect x="${mid.dx - 26}" y="${mid.dy - 9}" width="52" height="18" rx="4" fill="#ffffff" stroke="#94a3b8" stroke-width="1"/>'
          '<text x="${mid.dx}" y="${mid.dy + 4}" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle" fill="#0f172a">${w.lengthInMeters.toStringAsFixed(2)} м</text>');
    }

    for (final op in openings) {
      final wPx = op.widthMeters * 100.0;
      final hPx = op.depthCm + 4;
      final deg = op.rotation * 180 / math.pi;
      final stroke = op.type == OpeningType.door ? '#92400e' : '#0284c7';
      svg.writeln(
          '<g transform="translate(${op.position.dx},${op.position.dy}) rotate($deg)">'
          '<rect x="${-wPx / 2}" y="${-hPx / 2}" width="$wPx" height="$hPx" fill="#ffffff" stroke="$stroke" stroke-width="2.5"/>'
          '</g>');
    }

    for (final z in zones) {
      final c = z.visualCenter;
      svg.writeln(
          '<rect x="${c.dx - 48}" y="${c.dy - 18}" width="96" height="36" rx="6" fill="#ffffff" fill-opacity="0.92" stroke="#cbd5e1"/>'
          '<text x="${c.dx}" y="${c.dy - 2}" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle" fill="#0f172a">${z.name}</text>'
          '<text x="${c.dx}" y="${c.dy + 13}" font-family="Arial" font-size="11" font-weight="bold" text-anchor="middle" fill="#b45309">${z.areaSqM.toStringAsFixed(2)} м²</text>');
    }

    svg.writeln('</svg>');

    final rowsHtml = zones
        .map((z) =>
            '<tr><td style="padding:6px 10px; border:1px solid #cbd5e1;">${z.name}</td>'
            '<td style="padding:6px 10px; border:1px solid #cbd5e1; font-weight:bold;">${z.areaSqM.toStringAsFixed(2)} м²</td>'
            '<td style="padding:6px 10px; border:1px solid #cbd5e1;">${z.perimeterM.toStringAsFixed(2)} м</td></tr>')
        .join();

    final htmlDoc = '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8"/>
  <title>Чертеж планировки PRO (Векторный PDF)</title>
  <style>
    @page { size: A4 landscape; margin: 12mm; }
    body { font-family: Arial, sans-serif; color: #0f172a; margin: 0; padding: 16px; }
    h1 { font-size: 20px; margin: 0 0 6px 0; }
    .meta { font-size: 13px; color: #475569; margin-bottom: 12px; }
    table { border-collapse: collapse; width: 100%; margin-top: 14px; font-size: 12px; }
    th { background: #f1f5f9; text-align: left; padding: 6px 10px; border: 1px solid #cbd5e1; }
    @media print { .no-print { display: none; } }
  </style>
</head>
<body>
  <div class="no-print" style="margin-bottom:12px; padding:10px; background:#eff6ff; border:1px solid #93c5fd; border-radius:8px; display:flex; justify-content:space-between; align-items:center;">
    <span>💡 В открывшемся окне печати выберите <b>«Сохранить как PDF» (Save as PDF)</b> — чертеж сохранится в 100% векторном качестве!</span>
    <button onclick="window.print()" style="padding:8px 16px; background:#2563eb; color:#fff; border:none; border-radius:6px; font-weight:bold; cursor:pointer;">Сохранить PDF / Печать</button>
  </div>
  <h1>Архитектурный план и экспликация помещений</h1>
  <div class="meta">
    Общая площадь: <b>${totalZonesAreaSqM.toStringAsFixed(2)} м²</b> &nbsp;|&nbsp;
    Периметр стен: <b>${totalPerimeter.toStringAsFixed(2)} м</b> &nbsp;|&nbsp;
    Высота потолков: <b>${wallHeightMeters.toStringAsFixed(2)} м</b> &nbsp;|&nbsp;
    Предметов мебели и оборудования: <b>${objects.length}</b>
  </div>
  $svg
  <table>
    <thead>
      <tr><th>Помещение / Зона</th><th>Площадь (м²)</th><th>Периметр (м)</th></tr>
    </thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>
  <script>setTimeout(() => window.print(), 350);</script>
</body>
</html>
''';

    PlatformAdapter.openOrDownloadHtml('Plan_Kvartiry_PRO.html', htmlDoc);
  }

  Future<void> _initializeProjectAndAssets() async {
    await _loadFolderAssets();
    final saved = PlatformAdapter.loadLocalStorage(_kAutoSaveKey);
    if (saved != null && saved.isNotEmpty) {
      _restoreStateFromJson(saved, saveToLocalStorage: false);
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _openWallTileLayoutStudio(Wall wall) {
    final double clearLenM = _getWallInternalLength(wall);
    final double effectiveLenM = (clearLenM > 0.05 ? clearLenM : wall.lengthInMeters);
    final double wallLenCm = effectiveLenM * 100.0;
    final double wallHgtCm = wallHeightMeters * 100.0;
    final poly = [
      const Offset(0, 0),
      Offset(wallLenCm, 0),
      Offset(wallLenCm, wallHgtCm),
      Offset(0, wallHgtCm),
    ];

    // Find any room containing this wall to have context
    RoomZone? parentZone;
    for (final z in zones) {
      if (z.polygon.any((p) => (p - wall.start).distance < 10.0 || (p - wall.end).distance < 10.0)) {
        parentZone = z;
        break;
      }
    }
    final dummyZone = RoomZone(
      id: 'wall_${wall.hashCode}',
      name: 'Стена (чистый просвет: ${effectiveLenM.toStringAsFixed(2)} м)',
      polygon: poly,
      color: const Color(0xFF0D9488),
      tileConfig: wall.tileConfig,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TileLayoutStudioDialog(
        initialZone: dummyZone,
        allZones: zones.isNotEmpty ? zones : [dummyZone],
        isDarkTheme: isDarkTheme,
        wallHeightMeters: wallHeightMeters,
        allWalls: walls,
        allOpenings: openings,
        targetWall: wall,
        onSave: (z, cfg, isWall, {bool applyToAllWalls = false}) {
          _recordSnapshotForUndo();
          setState(() {
            if (applyToAllWalls && parentZone != null) {
              parentZone.wallTileConfig = cfg.clone();
              for (final w in walls) {
                if (parentZone.polygon.any((p) => (p - w.start).distance < 10.0 || (p - w.end).distance < 10.0)) {
                  w.tileConfig = cfg.clone();
                }
              }
            } else {
              wall.tileConfig = cfg.clone();
              if (parentZone != null && parentZone.wallTileConfig == null) {
                parentZone.wallTileConfig = cfg.clone();
              }
            }
            _autoSaveCurrentProject();
          });
        },
        onReset: (z, isWall) {
          _recordSnapshotForUndo();
          setState(() {
            wall.tileConfig = null;
            _autoSaveCurrentProject();
          });
        },
        onExportPdf: (z, cfg, isWall) {
          _exportTileLayoutPdf(z, cfg, isWallLayout: true, targetWall: wall);
        },
      ),
    );
  }

  void _openTileLayoutStudio([RoomZone? targetZone]) {
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для раскладки плитки сначала создайте хотя бы одну замкнутую комнату или добавьте зону.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final zone = targetZone ?? (zones.isNotEmpty ? zones.first : null);
    if (zone == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TileLayoutStudioDialog(
        initialZone: zone,
        allZones: zones,
        isDarkTheme: isDarkTheme,
        wallHeightMeters: wallHeightMeters,
        allWalls: walls,
        allOpenings: openings,
        onSave: (z, cfg, isWall, {bool applyToAllWalls = false}) {
          _recordSnapshotForUndo();
          setState(() {
            if (isWall) {
              z.wallTileConfig = cfg.clone();
              if (applyToAllWalls) {
                for (final w in walls) {
                  if (z.polygon.any((p) => (p - w.start).distance < 10.0 || (p - w.end).distance < 10.0)) {
                    w.tileConfig = cfg.clone();
                  }
                }
              }
            } else {
              z.tileConfig = cfg.clone();
            }
            _autoSaveCurrentProject();
          });
        },
        onReset: (z, isWall) {
          _recordSnapshotForUndo();
          setState(() {
            if (isWall) {
              z.wallTileConfig = null;
            } else {
              z.tileConfig = null;
            }
            _autoSaveCurrentProject();
          });
        },
        onExportPdf: (z, cfg, isWall) {
          _exportTileLayoutPdf(z, cfg, isWallLayout: isWall);
        },
      ),
    );
  }

  void _exportTileLayoutPdf(RoomZone zone, TileLayoutConfig config, {bool isWallLayout = false, Wall? targetWall}) {
    if (zone.polygon.length < 3) return;
    final report = TileLayoutCalculator.calculate(zone.polygon, config);

    double minX = zone.polygon.first.dx, maxX = zone.polygon.first.dx;
    double minY = zone.polygon.first.dy, maxY = zone.polygon.first.dy;
    for (final p in zone.polygon) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final pad = 60.0;
    final vbX = minX - pad;
    final vbY = minY - pad;
    final vbW = (maxX - minX) + pad * 2;
    final vbH = (maxY - minY) + pad * 2;

    final StringBuffer svg = StringBuffer();
    svg.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="$vbX $vbY $vbW $vbH" width="100%" height="480px" style="background:#f8fafc; border:1px solid #cbd5e1; border-radius:8px;">');

    for (double x = (vbX ~/ 100) * 100.0; x <= vbX + vbW; x += 100) {
      svg.writeln('<line x1="$x" y1="$vbY" x2="$x" y2="${vbY + vbH}" stroke="#e2e8f0" stroke-width="1"/>');
    }
    for (double y = (vbY ~/ 100) * 100.0; y <= vbY + vbH; y += 100) {
      svg.writeln('<line x1="$vbX" y1="$y" x2="${vbX + vbW}" y2="$y" stroke="#e2e8f0" stroke-width="1"/>');
    }

    final polyPts = zone.polygon.map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}').join(' ');
    svg.writeln('<defs>');
    svg.writeln('<clipPath id="tileZoneClip"><polygon points="$polyPts"/></clipPath>');
    svg.writeln('</defs>');

    svg.writeln('<g clip-path="url(#tileZoneClip)">');
    for (final piece in report.pieces) {
      String fillColor = '#f8fafc';
      String strokeColor = '#94a3b8';
      if (config.showCutColors) {
        switch (piece.cutType) {
          case TileCutType.full:
            fillColor = '#dcfce7';
            strokeColor = '#16a34a';
            break;
          case TileCutType.large:
            fillColor = '#fef3c7';
            strokeColor = '#d97706';
            break;
          case TileCutType.small:
            fillColor = '#dbeafe';
            strokeColor = '#2563eb';
            break;
          case TileCutType.critical:
            fillColor = '#fee2e2';
            strokeColor = '#dc2626';
            break;
        }
      }
      final r = piece.bounds;
      svg.writeln('<rect x="${r.left.toStringAsFixed(1)}" y="${r.top.toStringAsFixed(1)}" width="${r.width.toStringAsFixed(1)}" height="${r.height.toStringAsFixed(1)}" fill="$fillColor" stroke="$strokeColor" stroke-width="1.2"/>');

      if (config.showTileNumbers) {
        final cx = r.center.dx.toStringAsFixed(1);
        final cy = (r.center.dy + 3).toStringAsFixed(1);
        svg.writeln('<text x="$cx" y="$cy" font-family="Arial" font-size="8" font-weight="bold" text-anchor="middle" fill="#1e293b">${piece.id}</text>');
      }
    }
    svg.writeln('</g>');

    svg.writeln('<polygon points="$polyPts" fill="none" stroke="#0f172a" stroke-width="3.5" stroke-linejoin="round"/>');

    final anchorX = minX + config.offsetXCm;
    final anchorY = minY + config.offsetYCm;
    svg.writeln('<circle cx="$anchorX" cy="$anchorY" r="7" fill="#0284c7" stroke="#ffffff" stroke-width="2"/>');
    svg.writeln('<text x="$anchorX" y="${anchorY - 10}" font-family="Arial" font-size="9" font-weight="bold" text-anchor="middle" fill="#0284c7">Базовая точка (0,0)</text>');

    svg.writeln('</svg>');

    final patternName = config.pattern == TilePattern.straight
        ? 'Прямая (шов в шов)'
        : config.pattern == TilePattern.brickHalf
            ? 'Вразбежку 1/2'
            : config.pattern == TilePattern.brickThird
                ? 'Вразбежку 1/3'
                : 'Диагональная 45°';

    final htmlDoc = '''<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8"/>
  <title>Технологическая карта раскладки плитки — ${zone.name}</title>
  <style>
    @page { size: A4 landscape; margin: 10mm; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; color: #0f172a; margin: 0; padding: 16px; background:#fff; }
    h1 { font-size: 19px; margin: 0 0 4px 0; color: #0f172a; }
    .badge { display:inline-block; padding:3px 8px; border-radius:4px; font-size:11px; font-weight:bold; }
    .b-full { background:#dcfce7; color:#166534; }
    .b-large { background:#fef3c7; color:#92400e; }
    .b-small { background:#dbeafe; color:#1e40af; }
    .b-crit { background:#fee2e2; color:#991b1b; }
    .meta-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 12px 0; }
    .meta-card { background:#f8fafc; border:1px solid #e2e8f0; border-radius:6px; padding:8px 12px; }
    .meta-title { font-size:11px; color:#64748b; margin-bottom:2px; text-transform:uppercase; letter-spacing:0.5px; }
    .meta-val { font-size:14px; font-weight:bold; color:#0f172a; }
    table { border-collapse: collapse; width: 100%; margin-top: 12px; font-size: 12px; }
    th { background: #f1f5f9; text-align: left; padding: 7px 10px; border: 1px solid #cbd5e1; font-weight: 600; }
    td { padding: 6px 10px; border: 1px solid #cbd5e1; }
    .notes { margin-top:14px; padding:10px 14px; background:#f0fdf4; border:1px solid #bbf7d0; border-radius:6px; font-size:11.5px; line-height:1.45; }
    @media print { .no-print { display: none; } }
  </style>
</head>
<body>
  <div class="no-print" style="margin-bottom:12px; padding:10px 16px; background:#eff6ff; border:1px solid #93c5fd; border-radius:8px; display:flex; justify-content:space-between; align-items:center;">
    <span>💡 <b>Чертеж готов к печати:</b> выберите «Сохранить как PDF» (Save as PDF) для получения качественного векторного листа с раскладкой.</span>
    <button onclick="window.print()" style="padding:8px 16px; background:#0284c7; color:#fff; border:none; border-radius:6px; font-weight:bold; cursor:pointer;">Сохранить PDF / Печать</button>
  </div>

  <h1>📐 Технологический план раскладки плитки: ${zone.name}</h1>
  <div style="font-size:12px; color:#475569; margin-bottom:8px;">
    Размер плитки: <b>${config.tileWidthMm.round()}×${config.tileHeightMm.round()} мм</b> &nbsp;|&nbsp;
    Шов: <b>${config.jointWidthMm} мм</b> &nbsp;|&nbsp;
    Схема: <b>$patternName</b> &nbsp;|&nbsp;
    Площадь: <b>${report.roomAreaSqM.toStringAsFixed(2)} м²</b>
  </div>

  $svg

  <div class="meta-grid">
    <div class="meta-card">
      <div class="meta-title">Заказ плитки (+${config.reservePercent.round()}% запас)</div>
      <div class="meta-val">${report.totalPurchasedTiles} шт (${report.totalBoxes} кор. / ${report.grossAreaSqM.toStringAsFixed(2)} м²)</div>
    </div>
    <div class="meta-card">
      <div class="meta-title">Плиточный клей (расход ~4.5 кг/м²)</div>
      <div class="meta-val">${report.adhesiveKg.toStringAsFixed(1)} кг (~${(report.adhesiveKg / 25).ceil()} меш. по 25 кг)</div>
    </div>
    <div class="meta-card">
      <div class="meta-title">Затирка для швов (${config.jointWidthMm} мм)</div>
      <div class="meta-val">${report.groutKg.toStringAsFixed(2)} кг</div>
    </div>
    <div class="meta-card">
      <div class="meta-title">Ориентировочная стоимость</div>
      <div class="meta-val">${report.totalCostRub.toStringAsFixed(0)} ₽ (${config.pricePerSqM.round()} ₽/м²)</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Категория плитки на чертеже</th>
        <th>Цвет</th>
        <th>Количество на плане</th>
        <th>Доля от общего числа</th>
        <th>Примечание мастера</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>Целая плитка (100%)</b></td>
        <td><span class="badge b-full">Зеленый</span></td>
        <td><b>${report.fullTiles} шт</b></td>
        <td>${(report.totalVisiblePieces > 0 ? report.fullTiles / report.totalVisiblePieces * 100 : 0).toStringAsFixed(1)}%</td>
        <td>Укладывается без подрезки</td>
      </tr>
      <tr>
        <td><b>Крупная подрезка (> 50%)</b></td>
        <td><span class="badge b-large">Желтый</span></td>
        <td><b>${report.largeCuts} шт</b></td>
        <td>${(report.totalVisiblePieces > 0 ? report.largeCuts / report.totalVisiblePieces * 100 : 0).toStringAsFixed(1)}%</td>
        <td>Остатки могут использоваться на противоположных сторонах</td>
      </tr>
      <tr>
        <td><b>Мелкая подрезка (< 50%)</b></td>
        <td><span class="badge b-small">Синий</span></td>
        <td><b>${report.smallCuts} шт</b></td>
        <td>${(report.totalVisiblePieces > 0 ? report.smallCuts / report.totalVisiblePieces * 100 : 0).toStringAsFixed(1)}%</td>
        <td>Стандартная подрезка у стен</td>
      </tr>
      <tr>
        <td><b>Узкие полоски (< 50 мм)</b></td>
        <td><span class="badge b-crit">Красный</span></td>
        <td><b>${report.criticalCuts} шт</b></td>
        <td>${(report.totalVisiblePieces > 0 ? report.criticalCuts / report.totalVisiblePieces * 100 : 0).toStringAsFixed(1)}%</td>
        <td>${report.criticalCuts == 0 ? 'Идеально — узких подрезок нет!' : 'Внимание: высокая вероятность скола, рекомендуется центровка'}</td>
      </tr>
    </tbody>
  </table>

  <div class="notes">
    <b>Инструкция для плиточника:</b><br/>
    1. Начинать укладку строго от обозначенной <b>Базовой точки</b>.<br/>
    2. Межплиточный шов выдерживать крестиками или СВП толщиной <b>${config.jointWidthMm} мм</b>.<br/>
    3. Подрезку вдоль стен осуществлять мокрорезом или плиткорезом с алмазным диском.
  </div>

  <script>setTimeout(() => window.print(), 350);</script>
</body>
</html>''';

    PlatformAdapter.openOrDownloadHtml('Raskladka_${zone.name.replaceAll(RegExp(r'[^a-zA-Z0-9а-яА-Я_]'), '_')}.html', htmlDoc);
  }

  Parsed3DMesh? _parseObjMeshFromString(String objText) {
    final List<(double, double, double)> rawCoords = [];
    final List<(int, int, int)> rawFaces = [];

    for (final line in const LineSplitter().convert(objText)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('v ')) {
        final parts = trimmed.substring(2).trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final x = double.tryParse(parts[0].replaceAll(',', '.')) ?? 0.0;
          final y = double.tryParse(parts[1].replaceAll(',', '.')) ?? 0.0;
          final z = double.tryParse(parts[2].replaceAll(',', '.')) ?? 0.0;
          rawCoords.add((x, y, z));
        }
      } else if (trimmed.startsWith('f ')) {
        final parts = trimmed.substring(2).trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final List<int> idxList = [];
          for (final p in parts) {
            if (p.isEmpty) continue;
            final vStr = p.split('/').first;
            final vi = int.tryParse(vStr);
            if (vi != null) {
              final resolved = vi > 0 ? vi - 1 : rawCoords.length + vi;
              if (resolved >= 0 && resolved < rawCoords.length) {
                idxList.add(resolved);
              }
            }
          }
          for (int i = 1; i < idxList.length - 1; i++) {
            rawFaces.add((idxList[0], idxList[i], idxList[i + 1]));
          }
        }
      }
    }

    if (rawCoords.isEmpty || rawFaces.isEmpty) return null;

    double minX = 1e9, minY = 1e9, minZ = 1e9;
    double maxX = -1e9, maxY = -1e9, maxZ = -1e9;
    for (final c in rawCoords) {
      if (c.$1 < minX) minX = c.$1;
      if (c.$2 < minY) minY = c.$2;
      if (c.$3 < minZ) minZ = c.$3;
      if (c.$1 > maxX) maxX = c.$1;
      if (c.$2 > maxY) maxY = c.$2;
      if (c.$3 > maxZ) maxZ = c.$3;
    }

    final spanY = maxY - minY;
    final spanZ = maxZ - minZ;
    final bool zIsUp = spanZ > spanY * 1.35;
    final List<_Vec3> converted = rawCoords
        .map((c) => zIsUp ? _Vec3(c.$1, c.$2, c.$3) : _Vec3(c.$1, c.$3, c.$2))
        .toList();

    return _weldAndNormalizeMesh(converted, rawFaces);
  }

  Parsed3DMesh? _parseGlbMeshFromBytes(Uint8List bytes) {
    try {
      if (bytes.length < 20) return null;
      final bd = ByteData.sublistView(bytes);
      final magic = bd.getUint32(0, Endian.little);
      if (magic != 0x46546C67) return null;

      final jsonChunkLen = bd.getUint32(12, Endian.little);
      final jsonChunkType = bd.getUint32(16, Endian.little);
      if (jsonChunkType != 0x4E4F534A) return null;

      final jsonStr = utf8.decode(bytes.sublist(20, 20 + jsonChunkLen));
      final Map<String, dynamic> gltf = jsonDecode(jsonStr);

      final int binChunkStart = 20 + jsonChunkLen;
      if (bytes.length < binChunkStart + 8) return null;
      final int binDataStart = binChunkStart + 8;

      final List accessors = (gltf['accessors'] as List?) ?? [];
      final List bufferViews = (gltf['bufferViews'] as List?) ?? [];
      final List meshes = (gltf['meshes'] as List?) ?? [];
      if (meshes.isEmpty) return null;

      final List<_Vec3> rawVerts = [];
      final List<(int, int, int)> rawFaces = [];

      for (final mesh in meshes) {
        final List primitives = (mesh['primitives'] as List?) ?? [];
        for (final prim in primitives) {
          final attrs = prim['attributes'] as Map<String, dynamic>?;
          if (attrs == null || !attrs.containsKey('POSITION')) continue;

          final int posAccIdx = attrs['POSITION'] as int;
          final posAcc = accessors[posAccIdx] as Map<String, dynamic>;
          final int posBvIdx = posAcc['bufferView'] as int;
          final posBv = bufferViews[posBvIdx] as Map<String, dynamic>;

          final int count = posAcc['count'] as int;
          final int byteOffset = ((posBv['byteOffset'] as int?) ?? 0) + ((posAcc['byteOffset'] as int?) ?? 0);
          final int byteStride = (posBv['byteStride'] as int?) ?? 12;

          final int baseVertexOffset = rawVerts.length;
          for (int i = 0; i < count; i++) {
            final int off = binDataStart + byteOffset + i * byteStride;
            if (off + 12 > bytes.length) break;
            final x = bd.getFloat32(off, Endian.little);
            final y = bd.getFloat32(off + 4, Endian.little);
            final z = bd.getFloat32(off + 8, Endian.little);
            rawVerts.add(_Vec3(x, z, y));
          }

          if (prim.containsKey('indices')) {
            final int indAccIdx = prim['indices'] as int;
            final indAcc = accessors[indAccIdx] as Map<String, dynamic>;
            final int indBvIdx = indAcc['bufferView'] as int;
            final indBv = bufferViews[indBvIdx] as Map<String, dynamic>;
            final int indCount = indAcc['count'] as int;
            final int compType = indAcc['componentType'] as int;
            final int indOffset = ((indBv['byteOffset'] as int?) ?? 0) + ((indAcc['byteOffset'] as int?) ?? 0);

            int readIndex(int k) {
              if (compType == 5123) {
                return bd.getUint16(binDataStart + indOffset + k * 2, Endian.little);
              } else if (compType == 5125) {
                return bd.getUint32(binDataStart + indOffset + k * 4, Endian.little);
              } else {
                return bd.getUint8(binDataStart + indOffset + k);
              }
            }

            for (int k = 0; k + 2 < indCount; k += 3) {
              rawFaces.add((
                baseVertexOffset + readIndex(k),
                baseVertexOffset + readIndex(k + 1),
                baseVertexOffset + readIndex(k + 2),
              ));
            }
          }
        }
      }

      return _weldAndNormalizeMesh(rawVerts, rawFaces);
    } catch (_) {
      return null;
    }
  }

  Parsed3DMesh? _weldAndNormalizeMesh(List<_Vec3> rawVerts, List<(int, int, int)> rawFaces) {
    if (rawVerts.isEmpty || rawFaces.isEmpty) return null;
    double minX = 1e9, minY = 1e9, minZ = 1e9;
    double maxX = -1e9, maxY = -1e9, maxZ = -1e9;

    for (final v in rawVerts) {
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
      if (v.z > maxZ) maxZ = v.z;
    }

    final spanX = math.max(1e-5, maxX - minX);
    final spanY = math.max(1e-5, maxY - minY);
    final spanZ = math.max(1e-5, maxZ - minZ);
    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;

    final normVerts = rawVerts
        .map((v) => _Vec3(
              (v.x - cx) / spanX,
              (v.y - cy) / spanY,
              (v.z - minZ) / spanZ,
            ))
        .toList();

    if (rawFaces.length <= 3500) {
      return Parsed3DMesh(vertices: normVerts, faces: rawFaces);
    }

    const int gridRes = 28;
    final Map<int, int> cellToNewVert = {};
    final List<_Vec3> weldedVerts = [];
    final List<int> oldToNew = List.filled(normVerts.length, 0);

    for (int i = 0; i < normVerts.length; i++) {
      final v = normVerts[i];
      final gx = ((v.x + 0.5) * gridRes).round().clamp(0, gridRes);
      final gy = ((v.y + 0.5) * gridRes).round().clamp(0, gridRes);
      final gz = (v.z * gridRes).round().clamp(0, gridRes);
      final key = (gx << 12) | (gy << 6) | gz;

      int? newIdx = cellToNewVert[key];
      if (newIdx == null) {
        newIdx = weldedVerts.length;
        cellToNewVert[key] = newIdx;
        weldedVerts.add(v);
      }
      oldToNew[i] = newIdx;
    }

    final Set<(int, int, int)> uniqueTris = {};
    final List<(int, int, int)> weldedFaces = [];

    for (final f in rawFaces) {
      final i0 = oldToNew[f.$1];
      final i1 = oldToNew[f.$2];
      final i2 = oldToNew[f.$3];
      if (i0 != i1 && i1 != i2 && i2 != i0) {
        final sorted = [i0, i1, i2]..sort();
        final triKey = (sorted[0], sorted[1], sorted[2]);
        if (uniqueTris.add(triKey)) {
          weldedFaces.add((i0, i1, i2));
        }
      }
    }

    return Parsed3DMesh(
      vertices: weldedVerts,
      faces: weldedFaces.isEmpty ? rawFaces.take(3500).toList() : weldedFaces,
    );
  }

  Future<void> _loadFolderAssets() async {
    List<CatalogTexture> loadedTextures = [];
    List<Catalog3DModel> loadedModels = [];
    Set<String> allAssetPaths = {};

    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      allAssetPaths.addAll(manifest.listAssets());
    } catch (_) {}

    if (allAssetPaths.isEmpty) {
      try {
        final String binJsonStr = await rootBundle.loadString('AssetManifest.bin.json');
        final dynamic decodedJson = jsonDecode(binJsonStr);
        if (decodedJson is String) {
          final bytes = base64Decode(decodedJson);
          final dynamic map = const StandardMessageCodec().decodeMessage(bytes.buffer.asByteData());
          if (map is Map) {
            allAssetPaths.addAll(map.keys.map((k) => k.toString()));
          }
        }
      } catch (_) {}
    }

    _debugManifestAssets = allAssetPaths.toList();

    for (final String rawPath in allAssetPaths) {
      final String lower = rawPath.toLowerCase();
      final bool isImage = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');

      if (!isImage) continue;

      if (lower.contains('assets/textures/')) {
        final List<String> parts = rawPath.split('/');
        String folderKey = 'other';
        final int texIdx = parts.indexWhere((p) => p.toLowerCase() == 'textures');
        if (texIdx != -1 && texIdx + 1 < parts.length - 1) {
          folderKey = parts[texIdx + 1];
        }

        final String categoryRu = kTextureCategoryNamesRu[folderKey] ?? folderKey;
        final String fileName = parts.last;
        final int dotIndex = fileName.lastIndexOf('.');
        final String rawBaseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
        final String name = kTextureItemDisplayNamesRu[fileName] ??
            kTextureItemDisplayNamesRu[rawBaseName] ??
            rawBaseName;

        try {
          final data = await rootBundle.load(rawPath);
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          final frame = await codec.getNextFrame();

          _loadedImages[rawPath] = frame.image;
          loadedTextures.add(CatalogTexture(
            id: rawPath,
            category: categoryRu,
            name: name,
            assetPath: rawPath,
            image: frame.image,
          ));
        } catch (e) {
          debugPrint('Пропуск текстуры $rawPath: $e');
        }
      } else if (lower.contains('assets/models/')) {
        try {
          final data = await rootBundle.load(rawPath);
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          final frame = await codec.getNextFrame();
          _loadedImages[rawPath] = frame.image;
        } catch (_) {}
      }
    }

    final RegExp sizePattern = RegExp(r'_(\d+)x(\d+)(?:x(\d+))?', caseSensitive: false);

    for (final String rawPath in allAssetPaths) {
      final String lower = rawPath.toLowerCase();
      if (!lower.contains('assets/models/')) continue;

      final bool is3DModel = lower.endsWith('.glb') ||
          lower.endsWith('.gltf') ||
          lower.endsWith('.obj') ||
          lower.endsWith('.fbx') ||
          lower.endsWith('.stl') ||
          lower.endsWith('.max') ||
          lower.endsWith('.3ds');

      final bool isStandaloneFurnitureImage = (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.webp')) &&
          !allAssetPaths.any((other) {
            final baseNoExt = rawPath.substring(0, rawPath.lastIndexOf('.'));
            return other != rawPath &&
                other.startsWith(baseNoExt) &&
                (other.endsWith('.glb') || other.endsWith('.gltf') || other.endsWith('.obj') || other.endsWith('.fbx'));
          });

      if (!is3DModel && !isStandaloneFurnitureImage) continue;

      final List<String> parts = rawPath.split('/');
      String folderKey = 'living_room';
      final int mdlIdx = parts.indexWhere((p) => p.toLowerCase() == 'models');
      if (mdlIdx != -1 && mdlIdx + 1 < parts.length - 1) {
        folderKey = parts[mdlIdx + 1];
      }

      final String categoryRu = kModelCategoryNamesRu[folderKey] ?? folderKey;
      final String fileName = parts.last;
      final int dotIndex = fileName.lastIndexOf('.');
      final String ext = dotIndex != -1 ? fileName.substring(dotIndex + 1).toUpperCase() : '3D';
      String baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;

      final defaults = kDefaultModelDimensions[folderKey] ?? (1.20, 0.80, 0.85);
      double widthM = defaults.$1;
      double depthM = defaults.$2;
      double heightM = defaults.$3;

      final match = sizePattern.firstMatch(baseName);
      if (match != null) {
        final wCm = double.tryParse(match.group(1) ?? '');
        final dCm = double.tryParse(match.group(2) ?? '');
        final hCm = double.tryParse(match.group(3) ?? '');
        if (wCm != null && wCm > 10) widthM = wCm / 100.0;
        if (dCm != null && dCm > 10) depthM = dCm / 100.0;
        if (hCm != null && hCm > 10) heightM = hCm / 100.0;
        baseName = baseName.replaceAll(match.group(0)!, '');
      }

      final String cleanName = baseName.replaceAll('_', ' ').trim();

      String? previewImg;
      if (isStandaloneFurnitureImage) {
        previewImg = rawPath;
      } else {
        final prefix = rawPath.substring(0, dotIndex);
        for (final candidateExt in ['.png', '.jpg', '.jpeg', '.webp']) {
          if (_loadedImages.containsKey('$prefix$candidateExt')) {
            previewImg = '$prefix$candidateExt';
            break;
          }
        }
      }

      Parsed3DMesh? parsedMesh;
      if (lower.endsWith('.obj')) {
        try {
          final data = await rootBundle.load(rawPath);
          final objStr = utf8.decode(data.buffer.asUint8List(), allowMalformed: true);
          parsedMesh = _parseObjMeshFromString(objStr);
        } catch (_) {}
      } else if (lower.endsWith('.glb')) {
        try {
          final data = await rootBundle.load(rawPath);
          parsedMesh = _parseGlbMeshFromBytes(data.buffer.asUint8List());
        } catch (_) {}
      }

      if (parsedMesh != null) {
        _loaded3DMeshes[rawPath] = parsedMesh;
      }

      loadedModels.add(Catalog3DModel(
        id: rawPath,
        folderKey: folderKey,
        categoryRu: categoryRu,
        name: cleanName.isEmpty ? fileName : cleanName,
        modelAssetPath: rawPath,
        extension: ext,
        defaultWidthM: widthM,
        defaultDepthM: depthM,
        defaultHeightM: heightM,
        previewImagePath: previewImg,
        parsedMesh: parsedMesh,
      ));
    }

    if (mounted) {
      setState(() {
        myTextureCatalog = loadedTextures;
        my3DModelCatalog = loadedModels;
      });
    }
  }

  void _startOrUpdateAutoPan(Offset screenPos) {
    _lastPointerScreenPos = screenPos;
    _autoPanTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_lastPointerScreenPos == null || _viewportSize == Size.zero) return;

      final pos = _lastPointerScreenPos!;
      const double edgeMargin = 65.0;
      const double maxSpeed = 14.0;

      double dx = 0.0;
      double dy = 0.0;

      if (pos.dx < edgeMargin) {
        dx = maxSpeed * ((edgeMargin - pos.dx) / edgeMargin).clamp(0.15, 1.0);
      } else if (pos.dx > _viewportSize.width - edgeMargin) {
        dx = -maxSpeed * ((pos.dx - (_viewportSize.width - edgeMargin)) / edgeMargin).clamp(0.15, 1.0);
      }

      if (pos.dy < edgeMargin + 60) {
        dy = maxSpeed * (((edgeMargin + 60) - pos.dy) / edgeMargin).clamp(0.15, 1.0);
      } else if (pos.dy > _viewportSize.height - edgeMargin - 70) {
        dy = -maxSpeed * ((pos.dy - (_viewportSize.height - edgeMargin - 70)) / edgeMargin).clamp(0.15, 1.0);
      }

      if (dx != 0.0 || dy != 0.0) {
        setState(() {
          canvasOffset += Offset(dx, dy);
          final worldPos = _screenToWorld(pos);

          if (editingBoundaryZone != null && draggedZoneVertexIndex != null) {
            editingBoundaryZone!.polygon[draggedZoneVertexIndex!] = _snapPoint(worldPos);
          } else if ((selectedTool == EditorTool.drawWall || selectedTool == EditorTool.drawDimension) &&
              currentStart != null) {
            currentEnd = _snapPoint(
              worldPos,
              referenceStart: currentStart,
              preferWallFaces: selectedTool == EditorTool.drawDimension,
            );
          } else if (selectedTool == EditorTool.drawRoomBox && currentStart != null) {
            currentEnd = _snapPoint(worldPos, allowOrtho: false);
          } else if (selectedTool == EditorTool.overview && draggedCornerOriginal != null) {
            final nc = _snapPoint(worldPos, ignorePoint: draggedCornerOriginal);
            _moveConnectedCorner(draggedCornerOriginal!, nc);
            draggedCornerOriginal = nc;
          }
        });
      }
    });
  }

  void _stopAutoPan() {
    _autoPanTimer?.cancel();
    _autoPanTimer = null;
    _lastPointerScreenPos = null;
  }

  void _rebuildAutoZonesFromWalls() {
    List<(Offset, Offset)> segments = [];
    List<Offset> allEndpoints = [];
    for (final w in walls) {
      allEndpoints.add(w.start);
      allEndpoints.add(w.end);
    }

    for (final w in walls) {
      List<double> splits = [0.0, 1.0];
      final ab = w.end - w.start;
      final lenSq = ab.distanceSquared;
      if (lenSq < 1.0) continue;

      for (final pt in allEndpoints) {
        final t = ((pt.dx - w.start.dx) * ab.dx + (pt.dy - w.start.dy) * ab.dy) / lenSq;
        if (t > 0.01 && t < 0.99) {
          final proj = Offset(w.start.dx + t * ab.dx, w.start.dy + t * ab.dy);
          if ((pt - proj).distance <= 14.0) {
            splits.add(t);
          }
        }
      }

      splits.sort();
      for (int i = 0; i < splits.length - 1; i++) {
        if ((splits[i + 1] - splits[i]) > 0.01) {
          final p1 = Offset(w.start.dx + splits[i] * ab.dx, w.start.dy + splits[i] * ab.dy);
          final p2 = Offset(w.start.dx + splits[i + 1] * ab.dx, w.start.dy + splits[i + 1] * ab.dy);
          segments.add((p1, p2));
        }
      }
    }

    List<Offset> nodes = [];
    int getNodeIndex(Offset pt) {
      for (int i = 0; i < nodes.length; i++) {
        if ((nodes[i] - pt).distance <= 14.0) return i;
      }
      nodes.add(pt);
      return nodes.length - 1;
    }

    Map<int, Set<int>> fullAdj = {};
    for (final seg in segments) {
      final u = getNodeIndex(seg.$1);
      final v = getNodeIndex(seg.$2);
      if (u != v) {
        fullAdj.putIfAbsent(u, () => {}).add(v);
        fullAdj.putIfAbsent(v, () => {}).add(u);
      }
    }

    Map<int, Set<int>> coreAdj = {
      for (final e in fullAdj.entries) e.key: Set<int>.from(e.value),
    };

    bool removedDangling = true;
    while (removedDangling) {
      removedDangling = false;
      final keys = coreAdj.keys.toList();
      for (final k in keys) {
        final neighbors = coreAdj[k];
        if (neighbors != null && neighbors.length <= 1) {
          for (final nb in neighbors) {
            coreAdj[nb]?.remove(k);
          }
          coreAdj.remove(k);
          removedDangling = true;
        }
      }
    }

    Map<int, List<int>> sortedAdj = {};
    for (final entry in coreAdj.entries) {
      final u = entry.key;
      final list = entry.value.toList();
      list.sort((a, b) {
        final angA = math.atan2(nodes[a].dy - nodes[u].dy, nodes[a].dx - nodes[u].dx);
        final angB = math.atan2(nodes[b].dy - nodes[u].dy, nodes[b].dx - nodes[u].dx);
        return angA.compareTo(angB);
      });
      sortedAdj[u] = list;
    }

    Set<(int, int)> visitedHalfEdges = {};
    List<(List<Offset>, bool)> detectedPolygons = [];

    for (final u in sortedAdj.keys) {
      for (final v in sortedAdj[u]!) {
        if (visitedHalfEdges.contains((u, v))) continue;

        List<int> face = [];
        int curr = u;
        int next = v;
        bool valid = true;

        while (true) {
          visitedHalfEdges.add((curr, next));
          face.add(curr);

          final neighbors = sortedAdj[next];
          if (neighbors == null || neighbors.isEmpty) {
            valid = false;
            break;
          }
          final idx = neighbors.indexOf(curr);
          if (idx == -1) {
            valid = false;
            break;
          }
          final nextNode = neighbors[(idx - 1 + neighbors.length) % neighbors.length];
          curr = next;
          next = nextNode;

          if (curr == u && next == v) break;
          if (face.length > 60) {
            valid = false;
            break;
          }
        }

        if (valid && face.length >= 3) {
          double signedArea = 0;
          for (int i = 0; i < face.length; i++) {
            final p1 = nodes[face[i]];
            final p2 = nodes[face[(i + 1) % face.length]];
            signedArea += (p1.dx * p2.dy - p2.dx * p1.dy);
          }
          if (signedArea > 2000.0) {
            detectedPolygons.add((face.map((id) => nodes[id]).toList(), false));
          }
        }
      }
    }

    Set<(int, int)> coreEdges = {};
    for (final u in coreAdj.keys) {
      for (final v in coreAdj[u]!) {
        coreEdges.add((math.min(u, v), math.max(u, v)));
      }
    }

    Map<int, Set<int>> danglingAdj = {};
    for (final u in fullAdj.keys) {
      for (final v in fullAdj[u]!) {
        final edgeKey = (math.min(u, v), math.max(u, v));
        if (!coreEdges.contains(edgeKey)) {
          danglingAdj.putIfAbsent(u, () => {}).add(v);
          danglingAdj.putIfAbsent(v, () => {}).add(u);
        }
      }
    }

    Set<int> visitedDangling = {};
    for (final startNode in danglingAdj.keys) {
      if (visitedDangling.contains(startNode)) continue;

      List<int> compNodes = [];
      List<int> queue = [startNode];
      visitedDangling.add(startNode);

      while (queue.isNotEmpty) {
        final curr = queue.removeAt(0);
        compNodes.add(curr);
        for (final nb in danglingAdj[curr] ?? <int>{}) {
          if (!visitedDangling.contains(nb)) {
            visitedDangling.add(nb);
            queue.add(nb);
          }
        }
      }

      if (compNodes.length >= 3) {
        int endA = compNodes.firstWhere((n) => (danglingAdj[n]?.length ?? 0) == 1, orElse: () => compNodes.first);
        List<int> chain = [endA];
        Set<int> usedInChain = {endA};

        while (true) {
          final last = chain.last;
          final nextCandidates = (danglingAdj[last] ?? <int>{}).where((n) => !usedInChain.contains(n)).toList();
          if (nextCandidates.isEmpty) break;
          chain.add(nextCandidates.first);
          usedInChain.add(nextCandidates.first);
        }

        if (chain.length >= 3) {
          List<Offset> openPoly = chain.map((id) => nodes[id]).toList();
          final firstPt = openPoly.first;
          final lastPt = openPoly.last;

          if ((firstPt.dx - lastPt.dx).abs() > 25.0 && (firstPt.dy - lastPt.dy).abs() > 25.0) {
            final corner1 = Offset(firstPt.dx, lastPt.dy);
            final corner2 = Offset(lastPt.dx, firstPt.dy);
            final d1 = openPoly.skip(1).take(openPoly.length - 2).fold(999999.0, (m, p) => math.min(m, (p - corner1).distance));
            final d2 = openPoly.skip(1).take(openPoly.length - 2).fold(999999.0, (m, p) => math.min(m, (p - corner2).distance));
            openPoly.add(d1 >= d2 ? corner1 : corner2);
          }

          double areaPx = 0;
          for (int i = 0; i < openPoly.length; i++) {
            final p1 = openPoly[i];
            final p2 = openPoly[(i + 1) % openPoly.length];
            areaPx += (p1.dx * p2.dy) - (p2.dx * p1.dy);
          }
          if (areaPx.abs() / 2.0 > 2000.0) {
            detectedPolygons.add((openPoly, true));
          }
        }
      }
    }

    final manualZones = zones.where((z) => z.isManuallyAdjusted).toList();
    final oldAutoZones = zones.where((z) => !z.isManuallyAdjusted).toList();
    List<RoomZone> updatedZones = List.from(manualZones);

    for (final item in detectedPolygons) {
      final poly = item.$1;
      final isOpen = item.$2;

      final tempZone = RoomZone(
        id: 'auto_${updatedZones.length + 1}',
        name: isOpen ? 'Зона ${updatedZones.length + 1}' : 'Комната ${updatedZones.length + 1}',
        polygon: poly,
        color: kZonePalette[updatedZones.length % kZonePalette.length],
        isOpenContour: isOpen,
      );
      final center = tempZone.visualCenter;

      if (manualZones.any((mz) => mz.containsPoint(center))) {
        continue;
      }

      RoomZone? matchedOld;
      for (final old in oldAutoZones) {
        if ((old.visualCenter - center).distance < 75.0 || old.containsPoint(center)) {
          matchedOld = old;
          break;
        }
      }

      if (matchedOld != null) {
        matchedOld.polygon = poly;
        matchedOld.isOpenContour = isOpen;
        updatedZones.add(matchedOld);
        oldAutoZones.remove(matchedOld);
      } else {
        updatedZones.add(tempZone);
      }
    }

    zones
      ..clear()
      ..addAll(updatedZones);
    _autoSaveCurrentProject();
  }

  Offset _screenToWorld(Offset screenPos) => (screenPos - canvasOffset) / canvasScale;

  Offset? _intersectInfiniteLines(Offset p1, Offset d1, Offset p2, Offset d2) {
    final denom = d1.dx * d2.dy - d1.dy * d2.dx;
    if (denom.abs() < 1e-4) return null;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final t = (dx * d2.dy - dy * d2.dx) / denom;
    return Offset(p1.dx + d1.dx * t, p1.dy + d1.dy * t);
  }

  Offset _snapPoint(
    Offset rawWorldPoint, {
    Offset? referenceStart,
    Offset? ignorePoint,
    bool allowOrtho = true,
    bool preferWallFaces = false,
  }) {
    final double snapRadius = 26.0 / canvasScale;
    final double alignRadius = 15.0 / canvasScale;

    snappedPointHighlight = null;
    activeGreenGuides.clear();

    double x = rawWorldPoint.dx;
    double y = rawWorldPoint.dy;

    // =========================================================================
    // 1. ПРИВЯЗКА К ГРАНЯМ И ВНУТРЕННИМ/ВНЕШНИМ УГЛАМ СТЕН (Рулетка и чистовые размеры)
    // =========================================================================
    if ((snapConfig.snapToWallFaces || preferWallFaces) && selectedTool != EditorTool.drawWall) {
      final List<({Offset pt, String label})> faceCorners = [];
      final List<({Offset start, Offset end, Wall wall, String label})> faceSegments = [];

      for (int i = 0; i < walls.length; i++) {
        final w = walls[i];
        final wVec = w.end - w.start;
        final wLen = wVec.distance;
        if (wLen < 1.0) continue;
        final dir = wVec / wLen;
        final norm = Offset(-dir.dy, dir.dx);
        final halfA = w.thicknessCm / 2.0 + w.layersThicknessSideACm;
        final halfB = w.thicknessCm / 2.0 + w.layersThicknessSideBCm;

        final faStart = w.start + norm * halfA;
        final faEnd = w.end + norm * halfA;
        final fbStart = w.start - norm * halfB;
        final fbEnd = w.end - norm * halfB;

        faceSegments.add((start: faStart, end: faEnd, wall: w, label: 'Грань стены'));
        faceSegments.add((start: fbStart, end: fbEnd, wall: w, label: 'Грань стены'));

        // Концевые точки незамкнутых граней
        faceCorners.add((pt: faStart, label: 'Край стены'));
        faceCorners.add((pt: faEnd, label: 'Край стены'));
        faceCorners.add((pt: fbStart, label: 'Край стены'));
        faceCorners.add((pt: fbEnd, label: 'Край стены'));

        // Расчёт точных точек пересечения граней смежных стен на стыках (внутренние и внешние углы)
        for (int j = i + 1; j < walls.length; j++) {
          final w2 = walls[j];
          final w2Vec = w2.end - w2.start;
          final w2Len = w2Vec.distance;
          if (w2Len < 1.0) continue;
          final dir2 = w2Vec / w2Len;
          final norm2 = Offset(-dir2.dy, dir2.dx);
          final half2A = w2.thicknessCm / 2.0 + w2.layersThicknessSideACm;
          final half2B = w2.thicknessCm / 2.0 + w2.layersThicknessSideBCm;

          final w2FaStart = w2.start + norm2 * half2A;
          final w2FbStart = w2.start - norm2 * half2B;

          // Проверяем близость стыка
          for (final c1 in [w.start, w.end]) {
            for (final c2 in [w2.start, w2.end]) {
              if ((c1 - c2).distance <= math.max(30.0, w.totalEffectiveThicknessCm + w2.totalEffectiveThicknessCm)) {
                final junction = Offset((c1.dx + c2.dx) / 2, (c1.dy + c2.dy) / 2);
                final maxDist = (w.totalEffectiveThicknessCm + w2.totalEffectiveThicknessCm) * 1.5;

                for (final f1 in [(faStart, dir), (fbStart, dir)]) {
                  for (final f2 in [(w2FaStart, dir2), (w2FbStart, dir2)]) {
                    final inter = _intersectInfiniteLines(f1.$1, f1.$2, f2.$1, f2.$2);
                    if (inter != null && (inter - junction).distance <= maxDist) {
                      faceCorners.add((pt: inter, label: 'Угол стены'));
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Откосы проемов (двери, окна) вдоль граней
      for (final op in openings) {
        Wall? host;
        for (final w in walls) {
          if ((_projectPointOnSegment(op.position, w.start, w.end) - op.position).distance <= w.thicknessCm) {
            host = w;
            break;
          }
        }
        if (host != null) {
          final hVec = host.end - host.start;
          final hLen = hVec.distance;
          if (hLen > 1.0) {
            final hDir = hVec / hLen;
            final hNorm = Offset(-hDir.dy, hDir.dx);
            final halfA = host.thicknessCm / 2.0 + host.layersThicknessSideACm;
            final halfB = host.thicknessCm / 2.0 + host.layersThicknessSideBCm;
            final halfW = (op.widthMeters * 100.0) / 2.0;

            final j1A = (op.position - hDir * halfW) + hNorm * halfA;
            final j2A = (op.position + hDir * halfW) + hNorm * halfA;
            final j1B = (op.position - hDir * halfW) - hNorm * halfB;
            final j2B = (op.position + hDir * halfW) - hNorm * halfB;

            faceCorners.add((pt: j1A, label: 'Откос проема'));
            faceCorners.add((pt: j2A, label: 'Откос проема'));
            faceCorners.add((pt: j1B, label: 'Откос проема'));
            faceCorners.add((pt: j2B, label: 'Откос проема'));
          }
        }
      }

      // Электрика (розетки, выключатели, светильники)
      if (showElectricalLayer) {
        for (final item in electricalItems) {
          faceCorners.add((pt: item.position, label: item.name));
        }
      }

      // 1.1.1 Сначала ищем ближайший угол/откос/точку грани
      ({Offset pt, String label})? bestCorner;
      double minCornerDist = snapRadius;
      for (final fc in faceCorners) {
        if (ignorePoint != null && (fc.pt - ignorePoint).distance < 2.0) continue;
        final d = (fc.pt - rawWorldPoint).distance;
        if (d < minCornerDist) {
          minCornerDist = d;
          bestCorner = fc;
        }
      }
      if (bestCorner != null) {
        snappedPointHighlight = bestCorner.pt;
        activeGreenGuides.add(SnapGuideLine(bestCorner.pt, bestCorner.pt, label: bestCorner.label));
        return bestCorner.pt;
      }

      // 1.1.2 Ортогональная перпендикулярная проекция от referenceStart к грани стены
      if (allowOrtho && snapConfig.snapOrtho90 && referenceStart != null) {
        for (final seg in faceSegments) {
          final segVec = seg.end - seg.start;
          final segLen = segVec.distance;
          if (segLen < 1.0) continue;
          final segDir = segVec / segLen;
          final t = (referenceStart.dx - seg.start.dx) * segDir.dx + (referenceStart.dy - seg.start.dy) * segDir.dy;
          if (t >= -10.0 && t <= segLen + 10.0) {
            final orthoPt = Offset(seg.start.dx + t * segDir.dx, seg.start.dy + t * segDir.dy);
            if ((rawWorldPoint - orthoPt).distance < snapRadius * 1.25) {
              snappedPointHighlight = orthoPt;
              activeGreenGuides.add(SnapGuideLine(referenceStart, orthoPt, label: '90° к грани'));
              return orthoPt;
            }
          }
        }
      }

      // 1.1.3 Проекция курсора на продольную линию грани стены
      Offset? bestFaceProj;
      String bestFaceLabel = 'Грань стены';
      Offset? bestFaceStart, bestFaceEnd;
      double minFaceDist = snapRadius * 0.95;

      for (final seg in faceSegments) {
        final proj = _projectPointOnSegment(rawWorldPoint, seg.start, seg.end);
        final d = (rawWorldPoint - proj).distance;
        if (d < minFaceDist) {
          minFaceDist = d;
          bestFaceProj = proj;
          bestFaceLabel = seg.label;
          bestFaceStart = seg.start;
          bestFaceEnd = seg.end;
        }
      }

      if (bestFaceProj != null) {
        snappedPointHighlight = bestFaceProj;
        activeGreenGuides.add(SnapGuideLine(bestFaceStart!, bestFaceEnd!, label: bestFaceLabel));
        return bestFaceProj;
      }

      // Если режим инструмента "Рулетка / Размер" - строго НЕ привязываемся к осевым линиям стен!
      if (preferWallFaces) {
        if (snapConfig.snapToGrid) {
          final step = snapConfig.gridStepCm;
          x = (x / step).round() * step;
          y = (y / step).round() * step;
          final result = Offset(x, y);
          snappedPointHighlight = result;
          return result;
        }
        return rawWorldPoint;
      }
    }

    // =========================================================================
    // 2. СТАНДАРТНЫЕ ПРИВЯЗКИ CAD (Осевые вершины, середины, направляющие, сетка)
    // =========================================================================
    if (snapConfig.snapToEndpoints) {
      Offset? bestCorner;
      double minDist = snapRadius;
      for (final wall in walls) {
        for (final corner in [wall.start, wall.end]) {
          if (ignorePoint != null && (corner - ignorePoint).distance < 2.0) continue;
          final d = (corner - rawWorldPoint).distance;
          if (d < minDist) {
            minDist = d;
            bestCorner = corner;
          }
        }
      }
      if (bestCorner != null) {
        snappedPointHighlight = bestCorner;
        return bestCorner;
      }
    }

    if (snapConfig.snapToMidpoints) {
      for (final wall in walls) {
        if (ignorePoint != null && ((wall.start - ignorePoint).distance < 2.0 || (wall.end - ignorePoint).distance < 2.0)) {
          continue;
        }
        final mid = Offset((wall.start.dx + wall.end.dx) / 2, (wall.start.dy + wall.end.dy) / 2);
        if ((mid - rawWorldPoint).distance < snapRadius * 0.85) {
          snappedPointHighlight = mid;
          activeGreenGuides.add(SnapGuideLine(wall.start, wall.end, label: 'Середина'));
          return mid;
        }
      }
    }

    bool snappedX = false;
    bool snappedY = false;

    if (allowOrtho && snapConfig.snapOrtho90 && referenceStart != null) {
      if ((x - referenceStart.dx).abs() < alignRadius) {
        x = referenceStart.dx;
        snappedX = true;
        activeGreenGuides.add(SnapGuideLine(referenceStart, Offset(x, y), label: '90°'));
      }
      if ((y - referenceStart.dy).abs() < alignRadius) {
        y = referenceStart.dy;
        snappedY = true;
        activeGreenGuides.add(SnapGuideLine(referenceStart, Offset(x, y), label: '0°'));
      }
    }

    if (snapConfig.snapAlignmentLines) {
      for (final wall in walls) {
        for (final corner in [wall.start, wall.end]) {
          if (ignorePoint != null && (corner - ignorePoint).distance < 2.0) continue;
          if (!snappedX && (x - corner.dx).abs() < alignRadius) {
            x = corner.dx;
            snappedX = true;
            activeGreenGuides.add(SnapGuideLine(corner, Offset(x, y)));
          }
          if (!snappedY && (y - corner.dy).abs() < alignRadius) {
            y = corner.dy;
            snappedY = true;
            activeGreenGuides.add(SnapGuideLine(corner, Offset(x, y)));
          }
        }
      }
    }

    if (snapConfig.snapToWallLines) {
      Wall? hitWall;
      Offset? hitProj;
      double bestWallDist = snapRadius * 0.85;

      for (final wall in walls) {
        if (ignorePoint != null && ((wall.start - ignorePoint).distance < 2.0 || (wall.end - ignorePoint).distance < 2.0)) {
          continue;
        }
        final proj = _projectPointOnSegment(Offset(x, y), wall.start, wall.end);
        final d = (Offset(x, y) - proj).distance;
        if (d < bestWallDist) {
          bestWallDist = d;
          hitWall = wall;
          hitProj = proj;
        }
      }

      if (hitWall != null && hitProj != null) {
        snappedPointHighlight = hitProj;
        activeGreenGuides.add(SnapGuideLine(hitWall.start, hitWall.end));
        return hitProj;
      }
    }

    if (snapConfig.snapToGrid) {
      final step = snapConfig.gridStepCm;
      x = snappedX ? x : (x / step).round() * step;
      y = snappedY ? y : (y / step).round() * step;
    }

    final result = Offset(x, y);
    if (snappedX || snappedY) {
      snappedPointHighlight = result;
    }
    return result;
  }

  bool _segmentIntersectsRect(Offset p1, Offset p2, Rect rect) {
    if (rect.contains(p1) || rect.contains(p2)) return true;
    final rL = rect.left;
    final rR = rect.right;
    final rT = rect.top;
    final rB = rect.bottom;

    final minX = math.min(p1.dx, p2.dx);
    final maxX = math.max(p1.dx, p2.dx);
    final minY = math.min(p1.dy, p2.dy);
    final maxY = math.max(p1.dy, p2.dy);
    if (maxX < rL || minX > rR || maxY < rT || minY > rB) return false;

    final tl = Offset(rL, rT);
    final tr = Offset(rR, rT);
    final bl = Offset(rL, rB);
    final br = Offset(rR, rB);

    return _segmentsIntersect(p1, p2, tl, tr) ||
        _segmentsIntersect(p1, p2, tr, br) ||
        _segmentsIntersect(p1, p2, br, bl) ||
        _segmentsIntersect(p1, p2, bl, tl);
  }

  bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset p, Offset q) => p.dx * q.dy - p.dy * q.dx;
    final r = b - a;
    final s = d - c;
    final rxs = cross(r, s);
    final qp = c - a;
    final qpxr = cross(qp, r);

    if (rxs.abs() < 1e-6) {
      if (qpxr.abs() < 1e-6) {
        final rSq = r.dx * r.dx + r.dy * r.dy;
        if (rSq == 0) return false;
        final t0 = ((c.dx - a.dx) * r.dx + (c.dy - a.dy) * r.dy) / rSq;
        final t1 = t0 + ((s.dx * r.dx + s.dy * r.dy) / rSq);
        return math.min(t0, t1) <= 1.0 && math.max(t0, t1) >= 0.0;
      }
      return false;
    }

    final t = cross(qp, s) / rxs;
    final u = qpxr / rxs;
    return t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0;
  }

  void _snapOpeningToNearestWall(WallOpening opening, Offset rawWorldPos) {
    final double snapDistance = 35.0 / canvasScale;
    Wall? bestWall;
    Offset? bestProjection;
    double minDist = snapDistance;

    for (final wall in walls) {
      final proj = _projectPointOnSegment(rawWorldPos, wall.start, wall.end);
      final dist = (rawWorldPos - proj).distance;
      if (dist < minDist) {
        minDist = dist;
        bestWall = wall;
        bestProjection = proj;
      }
    }

    if (bestWall != null && bestProjection != null) {
      opening.position = bestProjection;
      final dir = bestWall.end - bestWall.start;
      opening.rotation = math.atan2(dir.dy, dir.dx);
      opening.depthCm = bestWall.thicknessCm;
    } else if (snapConfig.snapToGrid) {
      final step = snapConfig.gridStepCm;
      opening.position = Offset(
        (rawWorldPos.dx / step).round() * step,
        (rawWorldPos.dy / step).round() * step,
      );
    } else {
      opening.position = rawWorldPos;
    }
  }

  void _moveConnectedCorner(Offset oldCorner, Offset newCorner) {
    final double moveSnapThresh = math.max(28.0 / canvasScale, 18.0);
    for (final wall in walls) {
      if ((wall.start - oldCorner).distance <= moveSnapThresh) wall.start = newCorner;
      if ((wall.end - oldCorner).distance <= moveSnapThresh) wall.end = newCorner;
    }
    _rebuildAutoZonesFromWalls();
  }

  double get totalPerimeter => walls.fold(0.0, (sum, w) => sum + w.lengthInMeters);
  double get totalZonesAreaSqM => zones.fold(0.0, (sum, z) => sum + z.areaSqM);

  // Пресеты для быстрого добавления из раздела Строительство
  ({double width, double height, double sill, String name})? pendingWindowPreset;
  ({double width, double height, String name})? pendingDoorPreset;
  bool isCustomDoorSelected = false;
    ActiveDockFlyout activeDockFlyout = ActiveDockFlyout.none;
  String activeTextureFlyoutCategory = 'Все';
  String activeFurnitureFlyoutCategory = 'Все';
  bool showEstimateFlyout = false;
  Offset? pendingFurnitureWorldPos;

  double get totalWallsAreaSqM => walls.fold(0.0, (sum, w) => sum + w.lengthInMeters * wallHeightMeters);


  bool _pointInPolygon(Offset pt, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 0.0001 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  void _onTapCanvas(Offset screenTapPos) {
    if (is3DMode) {
      for (int i = _last3DWallHitPolygons.length - 1; i >= 0; i--) {
        final hit = _last3DWallHitPolygons[i];
        if (_pointInPolygon(screenTapPos, hit.screenQuad)) {
          final wallIdx = walls.indexOf(hit.wall);
          if (wallIdx != -1) {
            setState(() {
              selectedWall = hit.wall;
              selectedWallSide = hit.sideSign;
              selectedObject = null;
              selectedOpening = null;
            });
            _showEditWallDialog(wallIdx, targetSideSign: hit.sideSign);
            return;
          }
        }
      }
      setState(() {
        selectedWall = null;
        selectedWallSide = null;
      });
      return;
    }

    final worldPos = _screenToWorld(screenTapPos);

    if (editingBoundaryZone != null) {
      final poly = editingBoundaryZone!.polygon;
      for (int i = 0; i < poly.length; i++) {
        final p1 = poly[i];
        final p2 = poly[(i + 1) % poly.length];
        final proj = _projectPointOnSegment(worldPos, p1, p2);
        if ((worldPos - proj).distance < 20.0 / canvasScale) {
          _recordSnapshotForUndo();
          setState(() {
            poly.insert(i + 1, proj);
            editingBoundaryZone!.isManuallyAdjusted = true;
            _autoSaveCurrentProject();
          });
          return;
        }
      }
      return;
    }

    if (pendingElectricalPreset != null) {
      _recordSnapshotForUndo();
      final p = pendingElectricalPreset!;
      final snapRes = _snapElectricalToWall(worldPos, p.type, walls, snapToGrid: snapConfig.snapToGrid, gridStepCm: snapConfig.gridStepCm);
      final newItem = ElectricalItem(
        id: 'elec_${DateTime.now().microsecondsSinceEpoch}',
        name: p.name,
        type: p.type,
        subType: p.subType,
        position: snapRes.pos,
        rotationDeg: snapRes.angleDeg,
        heightFromFloorMm: p.defaultHeightMm,
        groupLabel: '',
        showLabel: true,
      );
      setState(() {
        electricalItems.add(newItem);
        selectedElectricalItem = newItem;
        selectedElectricalItems.clear();
        selectedElectricalItems.add(newItem);
        selectedObject = null;
        selectedWall = null;
        selectedOpening = null;
        pendingElectricalPreset = null;
        currentElectricalPreviewPos = null;
        selectedTool = EditorTool.overview;
        _autoSaveCurrentProject();
      });
      return;
    }

    if (showElectricalLayer) {
      // 1. Клик по размерному бейджу розетки или выключателя (быстрое редактирование расстояния от угла стены)
      if (showSocketDimensions) {
        for (int i = electricalItems.length - 1; i >= 0; i--) {
          final item = electricalItems[i];
          final binding = _getElectricalWallBinding(item, walls, canvasScale);
          if (binding != null) {
            if ((worldPos - binding.badgeCenter).distance < 24.0 / canvasScale) {
              setState(() {
                selectedElectricalItem = item;
                selectedElectricalItems.clear();
                selectedElectricalItems.add(item);
                selectedObject = null;
                selectedWall = null;
                selectedOpening = null;
                selectedDimension = null;
              });
              _showQuickEditElectricalDistanceDialog(item);
              return;
            }
          }
        }
      }

      // 2. Клик по размерному бейджу светильника до стены
      if (showLightDimensions) {
        for (int i = electricalItems.length - 1; i >= 0; i--) {
          final item = electricalItems[i];
          if (item.type == ElectricalType.light) {
            final nearestWalls = _findNearestWallsForLightOnWalls(item.position, walls);
            for (final wInfo in nearestWalls) {
              final midPt = Offset((item.position.dx + wInfo.proj.dx) / 2, (item.position.dy + wInfo.proj.dy) / 2);
              if ((worldPos - midPt).distance < 22.0 / canvasScale) {
                setState(() {
                  selectedElectricalItem = item;
                  selectedElectricalItems.clear();
                  selectedElectricalItems.add(item);
                  selectedObject = null;
                  selectedWall = null;
                  selectedOpening = null;
                  selectedDimension = null;
                });
                _showQuickEditLightDistanceDialog(item, wInfo);
                return;
              }
            }
          }
        }
      }

      // 3. Клик по самому элементу электрики (открывает окно полной настройки)
      for (int i = electricalItems.length - 1; i >= 0; i--) {
        if ((electricalItems[i].position - worldPos).distance < 24.0 / canvasScale) {
          setState(() {
            selectedElectricalItem = electricalItems[i];
            selectedElectricalItems.clear();
            selectedElectricalItems.add(electricalItems[i]);
            selectedObject = null;
            selectedWall = null;
            selectedOpening = null;
            selectedDimension = null;
          });
          _showElectricalItemConfigDialog(electricalItems[i]);
          return;
        }
      }
    }

    if (selectedTool == EditorTool.addDoor) {
      if (isCustomDoorSelected && pendingDoorPreset == null) {
        _showCreateDoorDialog(worldPos);
        return;
      }
      _recordSnapshotForUndo();
      final preset = pendingDoorPreset ?? (width: 0.80, height: 2.10, name: 'Межкомнатная дверь');
      final newDoor = WallOpening(
        type: OpeningType.door,
        subtypeName: preset.name,
        position: worldPos,
        widthMeters: preset.width,
        heightMeters: preset.height,
        sillHeightMeters: 0.0,
      );
      setState(() {
        _snapOpeningToNearestWall(newDoor, worldPos);
        openings.add(newDoor);
        selectedOpening = newDoor;
        selectedTool = EditorTool.overview;
        _autoSaveCurrentProject();
      });
      return;
    }

    if (selectedTool == EditorTool.addWindow) {
      if (pendingWindowPreset == null) {
        _showCreateWindowDialog(worldPos);
        return;
      }
      _recordSnapshotForUndo();
      final p = pendingWindowPreset!;
      final newWin = WallOpening(
        type: OpeningType.window,
        subtypeName: p.name,
        position: worldPos,
        widthMeters: p.width,
        heightMeters: p.height,
        sillHeightMeters: p.sill,
      );
      setState(() {
        _snapOpeningToNearestWall(newWin, worldPos);
        openings.add(newWin);
        selectedOpening = newWin;
        selectedTool = EditorTool.overview;
        _autoSaveCurrentProject();
      });
      return;
    }

    if (selectedTool == EditorTool.addObject) {
      setState(() {
        pendingFurnitureWorldPos = worldPos;
        activeDockFlyout = ActiveDockFlyout.furniture;
      });
      return;
    }

    for (int i = customDimensions.length - 1; i >= 0; i--) {
      final dim = customDimensions[i];
      final proj = _projectPointOnSegment(worldPos, dim.start, dim.end);
      if ((worldPos - proj).distance < 22.0 / canvasScale) {
        setState(() {
          selectedDimension = dim;
          selectedDimensions.clear();
          selectedDimensions.add(dim);
          selectedObject = null;
          selectedWall = null;
          selectedOpening = null;
          selectedElectricalItem = null;
        });
        return;
      }
    }

    for (int i = openings.length - 1; i >= 0; i--) {
      if ((openings[i].position - worldPos).distance < math.max(openings[i].widthMeters * 50, 25 / canvasScale)) {
        setState(() {
          selectedOpening = openings[i];
          selectedObject = null;
          selectedWall = null;
        });
        _showEditOpeningDialog(i);
        return;
      }
    }

    for (int i = objects.length - 1; i >= 0; i--) {
      if ((objects[i].position - worldPos).distance < math.max(objects[i].widthMeters, objects[i].depthMeters) * 50) {
        setState(() {
          selectedObject = objects[i];
          selectedOpening = null;
          selectedWall = null;
        });
        _showEditInteriorObjectDialog(i);
        return;
      }
    }

    // 1. Клик по размерному бейджу стены (быстрое редактирование длины со сдвигом)
    for (int i = 0; i < walls.length; i++) {
      final w = walls[i];
      final double axialLenPx = (w.end - w.start).distance;
      if (axialLenPx >= 1.0) {
        final dir = (w.end - w.start) / axialLenPx;
        final (startDed, endDed) = calcWallDeductions(w, walls);
        final innerStart = w.start + dir * startDed;
        final innerEnd = w.end - dir * endDed;
        final badgeMid = Offset((innerStart.dx + innerEnd.dx) / 2, (innerStart.dy + innerEnd.dy) / 2);

        if ((worldPos - badgeMid).distance < 28.0 / canvasScale) {
          setState(() {
            selectedWall = w;
            selectedWallSide = 1;
            selectedObject = null;
            selectedOpening = null;
          });
          _showQuickWallDimensionDialog(i);
          return;
        }
      }
    }

    // 2. Клик по телу стены (выделение плоскости стены)
    for (int i = 0; i < walls.length; i++) {
      final proj = _projectPointOnSegment(worldPos, walls[i].start, walls[i].end);
      if ((worldPos - proj).distance < 18.0 / canvasScale) {
        setState(() {
          selectedWall = walls[i];
          selectedWallSide = 1;
          selectedObject = null;
          selectedOpening = null;
        });
        return;
      }
    }

    if (showZonesLayer) {
      for (int i = zones.length - 1; i >= 0; i--) {
        if (zones[i].containsPoint(worldPos) || (zones[i].visualCenter - worldPos).distance < 45 / canvasScale) {
          _showEditRoomZoneDialog(i);
          return;
        }
      }
    }

    setState(() {
      selectedObject = null;
      selectedWall = null;
      selectedOpening = null;
      selectedElectricalItem = null;
      selectedDimension = null;
      selectedDimensions.clear();
      selectedObjects.clear();
      selectedWalls.clear();
      selectedOpenings.clear();
      editingBoundaryZone = null;
    });
  }

  Widget _buildVisualTextureSelectorGrid({
    required String? currentTextureId,
    required ValueChanged<String?> onSelect,
  }) {
    String selectedCat = 'Все';
    final categories = ['Все', ...myTextureCatalog.map((t) => t.category).toSet()];

    return StatefulBuilder(
      builder: (ctx, setGridState) {
        final filtered = selectedCat == 'Все'
            ? myTextureCatalog
            : myTextureCatalog.where((t) => t.category == selectedCat).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 38,
              width: math.min(480.0, MediaQuery.of(ctx).size.width - 48),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categories.contains(selectedCat) ? selectedCat : 'Все',
                  isExpanded: true,
                  dropdownColor: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF0D99FF)),
                  items: categories.map((cat) {
                    final count = cat == 'Все'
                        ? myTextureCatalog.length
                        : myTextureCatalog.where((t) => t.category == cat).length;
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(
                            cat == 'Все' ? Icons.category_rounded : Icons.folder_open_rounded,
                            size: 16,
                            color: const Color(0xFF0D99FF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: cat == selectedCat ? FontWeight.bold : FontWeight.w500,
                                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isDarkTheme ? Colors.white : Colors.black).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDarkTheme ? Colors.white70 : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newCat) {
                    if (newCat != null) setGridState(() => selectedCat = newCat);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              width: math.min(480.0, MediaQuery.of(ctx).size.width - 48),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 145,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: filtered.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == 0) {
                    final isNone = currentTextureId == null;
                    return InkWell(
                      onTap: () => onSelect(null),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNone ? const Color(0xFF0D99FF) : Colors.grey.shade300,
                            width: isNone ? 2.5 : 1.0,
                          ),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text(
                              'Без текстуры\n(Базовый цвет)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final tex = filtered[idx - 1];
                  final isSel = currentTextureId == tex.id;
                  return InkWell(
                    onTap: () => onSelect(tex.id),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? const Color(0xFF0D99FF) : Colors.grey.shade300,
                          width: isSel ? 3.0 : 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              child: CustomPaint(
                                painter: _SingleTexturePreviewPainter(image: _loadedImages[tex.id]!),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            color: isSel ? const Color(0xFFDBEAFE) : Colors.white,
                            child: Text(
                              '${tex.category}: ${tex.name}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  
  void _showCreateDoorDialog(Offset worldPos) {
    final wCtrl = TextEditingController(text: '0.90');
    final hCtrl = TextEditingController(text: '2.10');
    final nameCtrl = TextEditingController(text: 'Входная дверь');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.door_front_door_outlined, color: Color(0xFF0D99FF)),
            SizedBox(width: 8),
            Text('Параметры новой двери (Свой размер)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Тип / Название двери', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: wCtrl,
              decoration: const InputDecoration(labelText: 'Ширина двери (м)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hCtrl,
              decoration: const InputDecoration(labelText: 'Высота двери (м)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0.90;
              final h = double.tryParse(hCtrl.text.replaceAll(',', '.')) ?? 2.10;
              final name = nameCtrl.text.trim().isEmpty ? 'Дверь' : nameCtrl.text.trim();
              _recordSnapshotForUndo();
              final newDoor = WallOpening(
                type: OpeningType.door,
                subtypeName: name,
                position: worldPos,
                widthMeters: w,
                heightMeters: h,
                sillHeightMeters: 0.0,
              );
              setState(() {
                _snapOpeningToNearestWall(newDoor, worldPos);
                openings.add(newDoor);
                selectedOpening = newDoor;
                selectedTool = EditorTool.overview;
                _autoSaveCurrentProject();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Вставить'),
          ),
        ],
      ),
    );
  }

  
  void _showConstructionModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDarkTheme ? const Color(0xFF38383E) : const Color(0xFFE2E8F0)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.foundation_rounded, color: Color(0xFF0D99FF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Раздел: Строительство',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Выберите окна, двери, черчение комнаты коробкой или готовые шаблоны',
                    style: TextStyle(fontSize: 11.5, color: isDarkTheme ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: isDarkTheme ? Colors.white60 : Colors.black54),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(580.0, MediaQuery.of(context).size.width - 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ПОДРАЗДЕЛ: ОКНА
                _buildConstructionSectionHeader(Icons.window_outlined, 'Окна (выберите тип для вставки в стену):', const Color(0xFF38BDF8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildConstructionChoiceChip(
                      label: '⚙️ Свой размер',
                      subtitle: 'Произвольные Ш × В',
                      isSelected: selectedTool == EditorTool.addWindow && pendingWindowPreset == null,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = null;
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Одностворчатое',
                      subtitle: '0.80 × 1.40 м',
                      isSelected: false,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = (width: 0.80, height: 1.40, sill: 0.85, name: 'Одностворчатое окно');
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Двустворчатое стандарт',
                      subtitle: '1.40 × 1.40 м',
                      isSelected: false,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = (width: 1.40, height: 1.40, sill: 0.85, name: 'Двустворчатое окно');
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Трёхстворчатое широкое',
                      subtitle: '2.00 × 1.40 м',
                      isSelected: false,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = (width: 2.00, height: 1.40, sill: 0.85, name: 'Трёхстворчатое окно');
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Панорамное (в пол)',
                      subtitle: '2.40 × 2.20 м (h=0)',
                      isSelected: false,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = (width: 2.40, height: 2.20, sill: 0.0, name: 'Панорамное окно');
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Форточка / фрамуга',
                      subtitle: '0.60 × 0.80 м',
                      isSelected: false,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        setState(() {
                          pendingWindowPreset = (width: 0.60, height: 0.80, sill: 1.40, name: 'Фрамужное окно');
                          selectedTool = EditorTool.addWindow;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. ПОДРАЗДЕЛ: ДВЕРИ
                _buildConstructionSectionHeader(Icons.door_front_door_outlined, 'Двери (выберите тип для вставки в стену):', const Color(0xFF10B981)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildConstructionChoiceChip(
                      label: '⚙️ Свой размер',
                      subtitle: 'Произвольные Ш × В',
                      isSelected: selectedTool == EditorTool.addDoor && isCustomDoorSelected,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = true;
                          pendingDoorPreset = null;
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Межкомнатная стандарт',
                      subtitle: '0.80 × 2.10 м',
                      isSelected: false,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = false;
                          pendingDoorPreset = (width: 0.80, height: 2.10, name: 'Межкомнатная дверь');
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Узкая / санузел',
                      subtitle: '0.70 × 2.00 м',
                      isSelected: false,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = false;
                          pendingDoorPreset = (width: 0.70, height: 2.00, name: 'Дверь санузла');
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Входная усиленная',
                      subtitle: '0.95 × 2.10 м',
                      isSelected: false,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = false;
                          pendingDoorPreset = (width: 0.95, height: 2.10, name: 'Входная дверь');
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Двустворчатая распашная',
                      subtitle: '1.40 × 2.10 м',
                      isSelected: false,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = false;
                          pendingDoorPreset = (width: 1.40, height: 2.10, name: 'Двустворчатая дверь');
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildConstructionChoiceChip(
                      label: 'Раздвижная (купе)',
                      subtitle: '1.20 × 2.15 м',
                      isSelected: false,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        setState(() {
                          isCustomDoorSelected = false;
                          pendingDoorPreset = (width: 1.20, height: 2.15, name: 'Раздвижная дверь');
                          selectedTool = EditorTool.addDoor;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. ПОДРАЗДЕЛ: КОРОБКА И ШАБЛОНЫ
                _buildConstructionSectionHeader(Icons.dashboard_customize_rounded, 'Инструменты и готовые проекты:', const Color(0xFFF59E0B)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => selectedTool = EditorTool.drawRoomBox);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D99FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0D99FF).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.crop_square_rounded, color: Color(0xFF0D99FF), size: 24),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Коробка комнаты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Черчение комнаты замкнутым прямоугольником со стенами', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showTemplatesModal();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.dashboard_outlined, color: Color(0xFF059669), size: 24),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Шаблоны планировок', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('7 типовых планировок с превью чертежей', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConstructionSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDarkTheme ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  
  Widget _buildWindowIcon(int sashes) {
    return Container(
      width: 24,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.18),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: List.generate(sashes, (i) => Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: i < sashes - 1 ? const Border(right: BorderSide(color: Color(0xFF0284C7), width: 1.1)) : null,
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildConstructionChoiceChip({
    required String label,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    Widget? iconWidget,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : (isDarkTheme ? const Color(0xFF28282D) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null) ...[
              iconWidget,
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDarkTheme ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateWindowDialog(Offset worldPos) {
    final wCtrl = TextEditingController(text: '1.20');
    final hCtrl = TextEditingController(text: '1.40');
    final sillCtrl = TextEditingController(text: '0.85');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.window_outlined, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Параметры нового окна'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              decoration: const InputDecoration(labelText: 'Ширина окна (м)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sillCtrl,
              decoration: const InputDecoration(
                labelText: 'Высота от пола (подоконник, м)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hCtrl,
              decoration: const InputDecoration(
                labelText: 'Высота самого окна (м)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 1.20;
              final h = double.tryParse(hCtrl.text.replaceAll(',', '.')) ?? 1.40;
              final sill = double.tryParse(sillCtrl.text.replaceAll(',', '.')) ?? 0.85;
              _recordSnapshotForUndo();
              final newWin = WallOpening(
                type: OpeningType.window,
                subtypeName: 'Окно',
                position: worldPos,
                widthMeters: w,
                heightMeters: h,
                sillHeightMeters: sill,
              );
              setState(() {
                _snapOpeningToNearestWall(newWin, worldPos);
                openings.add(newWin);
                selectedOpening = newWin;
                selectedTool = EditorTool.overview;
                _autoSaveCurrentProject();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Поставить окно'),
          ),
        ],
      ),
    );
  }

  void _showEditDimensionDialog(int index) {
    final dim = customDimensions[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Размерная линия: ${dim.lengthInMeters.toStringAsFixed(2)} м'),
        content: const Text('Вы можете удалить эту выносную размерную линию с чертежа.'),
        actions: [
          TextButton(
            onPressed: () {
              _recordSnapshotForUndo();
              setState(() {
                customDimensions.removeAt(index);
                _autoSaveCurrentProject();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Удалить линию', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showMaterialsSpecificationModal() {
    final Map<String, double> floorByMaterial = {};
    double totalSkirtingM = 0.0;

    for (final z in zones) {
      String matName = 'Без текстуры (${z.name})';
      if (z.textureId != null) {
        final found = myTextureCatalog.where((t) => t.id == z.textureId).firstOrNull;
        matName = found != null ? '${found.category}: ${found.name}' : z.textureId!.split('/').last;
      }
      floorByMaterial[matName] = (floorByMaterial[matName] ?? 0.0) + z.areaSqM;
      totalSkirtingM += z.perimeterM;
    }

    final double doorsWidthM = openings
        .where((o) => o.type == OpeningType.door)
        .fold(0.0, (s, d) => s + d.widthMeters);
    final double netSkirtingM = math.max(0.0, totalSkirtingM - doorsWidthM);
    final double grossWallAreaSqM = totalPerimeter * wallHeightMeters;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Color(0xFF0D99FF), size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Спецификация материалов и смета площадей',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _exportPlanAsVectorPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Экспорт в векторный PDF'),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: [
                  const Text('1. Напольные покрытия (с запасом +10% на подрезку):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (floorByMaterial.isEmpty)
                    const Text('Нарисуйте замкнутые комнаты, чтобы рассчитать полы.')
                  else
                    ...floorByMaterial.entries.map((e) {
                      final cleanArea = e.value;
                      final withReserve = cleanArea * 1.10;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.grid_on_rounded, color: Color(0xFF059669)),
                          title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Чистая площадь: ${cleanArea.toStringAsFixed(2)} м²'),
                          trailing: Text(
                            'К покупке (+10%): ${withReserve.toStringAsFixed(2)} м²',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D99FF), fontSize: 14),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  const Text('2. Плинтусы и стены:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.straighten, color: Colors.deepOrange),
                      title: const Text('Напольный плинтус (за вычетом дверей)'),
                      subtitle: Text('Вычтено дверных проемов: ${doorsWidthM.toStringAsFixed(2)} м'),
                      trailing: Text(
                        '${(netSkirtingM * 1.05).toStringAsFixed(1)} пог. м (с запасом 5%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.format_paint_outlined, color: Colors.indigo),
                      title: Text('Площадь стен (при высоте ${wallHeightMeters.toStringAsFixed(2)} м)'),
                      subtitle: Text('Периметр всех стен: ${totalPerimeter.toStringAsFixed(2)} м'),
                      trailing: Text(
                        '${grossWallAreaSqM.toStringAsFixed(1)} м²',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('3. Ведомость 3D-моделей и мебели (${objects.length} шт.):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...objects.map((o) => ListTile(
                        dense: true,
                        leading: Icon(o.model3dPath != null ? Icons.view_in_ar : Icons.weekend_outlined,
                            color: const Color(0xFF0D99FF)),
                        title: Text('${o.category}: ${o.name}'),
                        subtitle: Text(o.model3dPath != null ? '3D файл: ${o.model3dPath}' : 'Процедурная 3D-мебель'),
                        trailing: Text(
                            '${o.widthMeters.toStringAsFixed(2)} × ${o.depthMeters.toStringAsFixed(2)} × ${o.heightMeters.toStringAsFixed(2)} м'),
                      )),
                  const SizedBox(height: 20),
                  const Text('4. Калькулятор бюджета ремонта (под ключ):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (ctx) {
                      final area = totalZonesAreaSqM;
                      final econom = (area * 8500).round();
                      final comfort = (area * 16000).round();
                      final business = (area * 32000).round();

                      String fmt(int val) {
                        return val.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]} ',
                        ) + ' ₽';
                      }

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Расчет на общую площадь помещений: ${area.toStringAsFixed(2)} м²',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBudgetTierCard(
                                    title: 'Эконом',
                                    rate: '8 500 ₽/м²',
                                    total: fmt(econom),
                                    desc: 'Ламинат 32 класс, обои под покраску, натяжной потолок, базовая сантехника',
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildBudgetTierCard(
                                    title: 'Комфорт (Хит)',
                                    rate: '16 000 ₽/м²',
                                    total: fmt(comfort),
                                    desc: 'Кварцвинил, плитка, покраска стен, скрытый плинтус, инсталляции',
                                    color: const Color(0xFF0D99FF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildBudgetTierCard(
                                    title: 'Бизнес / Люкс',
                                    rate: '32 000 ₽/м²',
                                    total: fmt(business),
                                    desc: 'Инженерная доска, крупноформатный керамогранит, теневой профиль, премиум',
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFurnitureCatalogModal(Offset worldPos) {
    String selectedCat = 'Все';
    final Set<String> allCats = {
      'Все',
      ...kModelCategoryNamesRu.values,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final userModels = selectedCat == 'Все'
              ? my3DModelCatalog
              : my3DModelCatalog.where((m) => m.categoryRu == selectedCat).toList();

          final builtIn = selectedCat == 'Все'
              ? kBuiltInPresets
              : kBuiltInPresets.where((p) => p.$1 == selectedCat).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.80,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_in_ar_rounded, color: Color(0xFF0D99FF), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Каталог мебели и 3D-моделей (в папках: ${my3DModelCatalog.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Поддерживается прямой рендер цельной геометрии .OBJ и .GLB + процедурная 3D-мебель',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Пересканировать папки assets/models/',
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await _loadFolderAssets();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allCats
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: c == selectedCat,
                                onSelected: (_) => setModalState(() => selectedCat = c),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (userModels.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'ВАШИ 3D-МОДЕЛИ ИЗ ПАПОК ASSETS/MODELS/:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: userModels.length,
                          itemBuilder: (ctx, i) {
                            final m = userModels[i];
                            return InkWell(
                              onTap: () {
                                _recordSnapshotForUndo();
                                final newObj = InteriorObject(
                                  category: m.categoryRu,
                                  name: m.name,
                                  position: worldPos,
                                  widthMeters: m.defaultWidthM,
                                  depthMeters: m.defaultDepthM,
                                  heightMeters: m.defaultHeightM,
                                  model3dPath: m.modelAssetPath,
                                  previewImagePath: m.previewImagePath,
                                );
                                setState(() {
                                  objects.add(newObj);
                                  selectedObject = newObj;
                                  selectedTool = EditorTool.overview;
                                  _autoSaveCurrentProject();
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            m.parsedMesh != null
                                                ? '3D MESH (${m.parsedMesh!.faces.length} тр.)'
                                                : '3D • ${m.extension}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.view_in_ar, color: Color(0xFF059669), size: 20),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      m.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${m.categoryRu} • ${m.defaultWidthM.toStringAsFixed(2)}×${m.defaultDepthM.toStringAsFixed(2)} м',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'БАЗОВЫЕ 3D-ШАБЛОНЫ МЕБЕЛИ И САНТЕХНИКИ:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D99FF)),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: builtIn.length,
                        itemBuilder: (ctx, i) {
                          final item = builtIn[i];
                          return InkWell(
                            onTap: () {
                              _recordSnapshotForUndo();
                              final newObj = InteriorObject(
                                category: item.$1,
                                name: item.$2,
                                position: worldPos,
                                widthMeters: item.$3,
                                depthMeters: item.$4,
                                heightMeters: item.$5,
                                textureId: myTextureCatalog.isNotEmpty ? myTextureCatalog.first.id : null,
                              );
                              setState(() {
                                objects.add(newObj);
                                selectedObject = newObj;
                                selectedTool = EditorTool.overview;
                                _autoSaveCurrentProject();
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.$2,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${item.$1} (${item.$3.toStringAsFixed(2)}×${item.$4.toStringAsFixed(2)}×${item.$5.toStringAsFixed(2)} м)',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditRoomZoneDialog(int index) {
    final zone = zones[index];
    final nameCtrl = TextEditingController(text: zone.name);
    Color tempColor = zone.color;
    String? tempTex = zone.textureId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.meeting_room_outlined, color: Color(0xFF0D99FF)),
              const SizedBox(width: 8),
              Expanded(child: Text('Зона: ${zone.areaSqM.toStringAsFixed(2)} м²')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Название помещения / зоны',
                    hintText: 'Например: Кухня, Прихожая',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Цвет зоны:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: kZonePalette.map((c) {
                    final isSelected = tempColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => tempColor = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.black12,
                            width: isSelected ? 3.0 : 1.0,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.black87) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Выберите текстуру пола (с превью):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildVisualTextureSelectorGrid(
                  currentTextureId: tempTex,
                  onSelect: (val) => setDialogState(() => tempTex = val),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                      foregroundColor: const Color(0xFF059669),
                    ),
                    icon: const Icon(Icons.highlight_alt_rounded),
                    label: const Text('Скорректировать границы зоны', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      _recordSnapshotForUndo();
                      setState(() {
                        zone.name = nameCtrl.text.trim().isEmpty ? zone.name : nameCtrl.text.trim();
                        zone.color = tempColor;
                        zone.textureId = tempTex;
                        zone.isManuallyAdjusted = true;
                        editingBoundaryZone = zone;
                        selectedTool = EditorTool.overview;
                        _autoSaveCurrentProject();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.grid_view_rounded, color: Color(0xFF0D9488)),
                    label: Text(
                      zone.tileConfig != null
                          ? 'Раскладка плитки: настроена (${zone.tileConfig!.tileWidthMm.round()}×${zone.tileConfig!.tileHeightMm.round()})'
                          : 'Умная раскладка плитки и калькулятор',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _openTileLayoutStudio(zone);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (zone.isManuallyAdjusted)
              TextButton(
                onPressed: () {
                  _recordSnapshotForUndo();
                  setState(() {
                    zones.removeAt(index);
                    _rebuildAutoZonesFromWalls();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Сбросить по стенам', style: TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  zone.name = nameCtrl.text.trim().isEmpty ? 'Помещение' : nameCtrl.text.trim();
                  zone.color = tempColor;
                  zone.textureId = tempTex;
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOpeningDialog(int index) {
    final op = openings[index];

    Wall? hostWall;
    for (final w in walls) {
      if ((_projectPointOnSegment(op.position, w.start, w.end) - op.position).distance < 5.0) {
        hostWall = w;
        break;
      }
    }

    final wCtrl = TextEditingController(text: op.widthMeters.toStringAsFixed(2));
    final hCtrl = TextEditingController(text: op.heightMeters.toStringAsFixed(2));
    final sillCtrl = TextEditingController(text: op.sillHeightMeters.toStringAsFixed(2));
    double tempRot = (op.rotation * 180 / math.pi) % 360;
    String? tempTex = op.textureId;

    final offsetStartCtrl = TextEditingController();
    final offsetEndCtrl = TextEditingController();
    double currentCenterM = 0;

    if (hostWall != null) {
      currentCenterM = (op.position - hostWall.start).distance / 100.0;
      double oStart = currentCenterM - op.widthMeters / 2;
      double oEnd = hostWall.lengthInMeters - currentCenterM - op.widthMeters / 2;
      offsetStartCtrl.text = math.max(0.0, oStart).toStringAsFixed(2);
      offsetEndCtrl.text = math.max(0.0, oEnd).toStringAsFixed(2);
    }

    bool startEdited = false;
    bool endEdited = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(op.type == OpeningType.door ? 'Настройка двери' : 'Настройка окна'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wCtrl,
                        decoration: const InputDecoration(labelText: 'Ширина (м)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hCtrl,
                        decoration: InputDecoration(
                          labelText: op.type == OpeningType.window ? 'Высота окна (м)' : 'Высота двери (м)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sillCtrl,
                  decoration: InputDecoration(
                    labelText: op.type == OpeningType.window
                        ? 'Высота от пола (подоконник, м)'
                        : 'Высота порога от пола (м)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (hostWall != null) ...[
                  const SizedBox(height: 12),
                  const Text('Точные отступы от углов стены:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: offsetStartCtrl,
                          decoration: const InputDecoration(labelText: 'От 1-го угла (м)', border: OutlineInputBorder()),
                          onChanged: (v) {
                            startEdited = true;
                            endEdited = false;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: offsetEndCtrl,
                          decoration: const InputDecoration(labelText: 'От 2-го угла (м)', border: OutlineInputBorder()),
                          onChanged: (v) {
                            endEdited = true;
                            startEdited = false;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Slider(
                    value: tempRot < 0 ? tempRot + 360 : tempRot,
                    min: 0,
                    max: 360,
                    divisions: 72,
                    onChanged: (v) => setDialogState(() => tempRot = v)),
                if (op.type == OpeningType.door)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Петли слева/справа'),
                        selected: op.flipHorizontal,
                        onSelected: (v) => setDialogState(() => op.flipHorizontal = v),
                      ),
                      FilterChip(
                        label: const Text('Внутрь/наружу'),
                        selected: op.flipVertical,
                        onSelected: (v) => setDialogState(() => op.flipVertical = v),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  openings.removeAt(index);
                  selectedOpening = null;
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Удалить (Del)', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                final nw = double.tryParse(wCtrl.text.replaceAll(',', '.'));
                final nh = double.tryParse(hCtrl.text.replaceAll(',', '.'));
                final nsill = double.tryParse(sillCtrl.text.replaceAll(',', '.'));

                // Обновляем параметры по ССЫЛКЕ, а не удаляем объект
                setState(() {
                  if (nw != null && nw > 0.2) op.widthMeters = nw;
                  if (nh != null && nh > 0.2) op.heightMeters = nh;
                  if (nsill != null && nsill >= 0.0) op.sillHeightMeters = nsill;
                  op.rotation = tempRot * math.pi / 180.0;
                  op.textureId = tempTex;

                  if (hostWall != null) {
                    double finalCenterM = currentCenterM;
                    if (startEdited) {
                      double startV = double.tryParse(offsetStartCtrl.text.replaceAll(',', '.')) ??
                          (currentCenterM - op.widthMeters / 2);
                      finalCenterM = startV + op.widthMeters / 2;
                    } else if (endEdited) {
                      double endV = double.tryParse(offsetEndCtrl.text.replaceAll(',', '.')) ??
                          (hostWall.lengthInMeters - currentCenterM - op.widthMeters / 2);
                      finalCenterM = hostWall.lengthInMeters - endV - op.widthMeters / 2;
                    }
                    final wallVec = hostWall.end - hostWall.start;
                    if (wallVec.distance > 0) {
                      final dir = wallVec / wallVec.distance;
                      op.position = hostWall.start + dir * (finalCenterM * 100.0);
                    }
                  }
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  double _getWallInternalLength(Wall wall) => calcWallInternalLength(wall, walls);

  double _legacyGetWallInternalLength(Wall wall) {
    final double axialLenPx = (wall.end - wall.start).distance;
    if (axialLenPx < 1.0) return 0.0;
    final dir = (wall.end - wall.start) / axialLenPx;

    double startDeduction = 0.0;
    double endDeduction = 0.0;

    for (final other in walls) {
      if (identical(other, wall)) continue;
      final otherLen = (other.end - other.start).distance;
      if (otherLen < 1.0) continue;
      final otherDir = (other.end - other.start) / otherLen;
      final dot = (dir.dx * otherDir.dx + dir.dy * otherDir.dy).abs();
      if (dot >= 0.88) continue; // параллельные стены пропускаем

      final double otherHalfT = other.totalEffectiveThicknessCm / 2.0;

      // Примыкание начала текущей стены к other (угол или T-стык)
      final projStart = _projectPointOnSegment(wall.start, other.start, other.end);
      if ((wall.start - projStart).distance <= math.max(25.0, otherHalfT + 8.0)) {
        startDeduction = math.max(startDeduction, otherHalfT.clamp(0.0, axialLenPx / 2.0));
      }

      // Примыкание конца текущей стены к other (угол или T-стык)
      final projEnd = _projectPointOnSegment(wall.end, other.start, other.end);
      if ((wall.end - projEnd).distance <= math.max(25.0, otherHalfT + 8.0)) {
        endDeduction = math.max(endDeduction, otherHalfT.clamp(0.0, axialLenPx / 2.0));
      }
    }


    final double internalLenPx = (axialLenPx - startDeduction - endDeduction).clamp(0.0, double.infinity);
    return internalLenPx / 100.0;
  }

  void _parametricResizeWall(Wall wall, double deltaLenPx, int mode) {
    if (deltaLenPx.abs() < 0.1) return;
    _recordSnapshotForUndo();

    final wallVec = wall.end - wall.start;
    final wallLen = wallVec.distance;
    if (wallLen < 1.0) return;
    final dir = wallVec / wallLen;

    void shiftEndpointAndConnected({
      required Offset targetEnd,
      required bool isStartPoint,
      required Offset shiftVec,
    }) {
      final oldPt = isStartPoint ? wall.start : wall.end;
      final newPt = oldPt + shiftVec;

      final double snapThresh = math.max(65.0, wall.totalEffectiveThicknessCm * 3.0);
      final List<Wall> connected = walls.where((w) {
        if (identical(w, wall)) return false;
        final dStart = (w.start - oldPt).distance;
        final dEnd = (w.end - oldPt).distance;
        if (dStart <= snapThresh || dEnd <= snapThresh) return true;
        final proj = _projectPointOnSegment(oldPt, w.start, w.end);
        if ((oldPt - proj).distance <= snapThresh) return true;
        // Also check if w touches the wall near oldPt
        final projW = _projectPointOnSegment(w.start, wall.start, wall.end);
        if ((w.start - projW).distance <= snapThresh && (projW - oldPt).distance <= snapThresh * 1.5) return true;
        final projWEnd = _projectPointOnSegment(w.end, wall.start, wall.end);
        return ((w.end - projWEnd).distance <= snapThresh && (projWEnd - oldPt).distance <= snapThresh * 1.5);
      }).toList();

      for (final adj in connected) {
        final adjVec = adj.end - adj.start;
        final adjLen = adjVec.distance;
        if (adjLen < 1.0) continue;
        final adjDir = adjVec / adjLen;
        final double dot = (dir.dx * adjDir.dx + dir.dy * adjDir.dy).abs();

        final bool adjStartMatches = (adj.start - oldPt).distance <= (adj.end - oldPt).distance;
        final Offset otherAdjEnd = adjStartMatches ? adj.end : adj.start;

        if (dot < 0.35) {
          // Перпендикулярная стена: смещаем целиком параллельно
          adj.start += shiftVec;
          adj.end += shiftVec;

          for (final op in openings) {
            final proj = _projectPointOnSegment(op.position, adj.start - shiftVec, adj.end - shiftVec);
            if ((op.position - proj).distance < 12.0) {
              op.position += shiftVec;
            }
          }
          for (final el in electricalItems) {
            final proj = _projectPointOnSegment(el.position, adj.start - shiftVec, adj.end - shiftVec);
            if ((el.position - proj).distance < 12.0) {
              el.position += shiftVec;
            }
          }

          for (final nextWall in walls) {
            if (identical(nextWall, adj) || identical(nextWall, wall)) continue;
            if ((nextWall.start - otherAdjEnd).distance <= snapThresh) {
              final nextVec = nextWall.end - nextWall.start;
              final nextLen = nextVec.distance;
              if (nextLen > 1.0) {
                final nextDot = (dir.dx * (nextVec.dx / nextLen) + dir.dy * (nextVec.dy / nextLen)).abs();
                if (nextDot > 0.65) {
                  nextWall.start += shiftVec;
                }
              }
            } else if ((nextWall.end - otherAdjEnd).distance <= snapThresh) {
              final nextVec = nextWall.end - nextWall.start;
              final nextLen = nextVec.distance;
              if (nextLen > 1.0) {
                final nextDot = (dir.dx * (nextVec.dx / nextLen) + dir.dy * (nextVec.dy / nextLen)).abs();
                if (nextDot > 0.65) {
                  nextWall.end += shiftVec;
                }
              }
            }
          }
        } else {
          if (adjStartMatches) {
            adj.start = newPt;
          } else {
            adj.end = newPt;
          }
        }
      }

      if (isStartPoint) {
        wall.start = newPt;
      } else {
        wall.end = newPt;
      }
    }

    if (mode == 1) {
      shiftEndpointAndConnected(targetEnd: wall.end, isStartPoint: false, shiftVec: dir * deltaLenPx);
    } else if (mode == -1) {
      shiftEndpointAndConnected(targetEnd: wall.start, isStartPoint: true, shiftVec: -dir * deltaLenPx);
    } else {
      final halfDelta = deltaLenPx / 2.0;
      shiftEndpointAndConnected(targetEnd: wall.start, isStartPoint: true, shiftVec: -dir * halfDelta);
      shiftEndpointAndConnected(targetEnd: wall.end, isStartPoint: false, shiftVec: dir * halfDelta);
    }

    _rebuildAutoZonesFromWalls();
    _autoSaveCurrentProject();
  }

  void _showQuickWallDimensionDialog(int wallIndex) {
    final wall = walls[wallIndex];
    final double curInternalM = calcWallInternalLength(wall, walls);
    final curMm = (curInternalM * 1000.0).round();
    final ctrl = TextEditingController(text: curMm.toString());
    int selectedDirMode = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155), width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.straighten_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Размер стены в свету',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Текущий размер: $curMm мм',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(380.0, MediaQuery.of(context).size.width - 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Новая длина (мм):',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      suffixText: 'мм',
                      suffixStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF475569)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Направление расширения / сдвига:',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selectedDirMode == -1 ? const Color(0xFF0284C7).withValues(alpha: 0.25) : Colors.transparent,
                            side: BorderSide(
                              color: selectedDirMode == -1 ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                              width: selectedDirMode == -1 ? 1.8 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setDlgState(() => selectedDirMode = -1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                          label: const Text('Влево', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selectedDirMode == 0 ? const Color(0xFF0284C7).withValues(alpha: 0.25) : Colors.transparent,
                            side: BorderSide(
                              color: selectedDirMode == 0 ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                              width: selectedDirMode == 0 ? 1.8 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setDlgState(() => selectedDirMode = 0),
                          icon: const Icon(Icons.compare_arrows_rounded, size: 16, color: Colors.white),
                          label: const Text('Симметр.', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selectedDirMode == 1 ? const Color(0xFF0284C7).withValues(alpha: 0.25) : Colors.transparent,
                            side: BorderSide(
                              color: selectedDirMode == 1 ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                              width: selectedDirMode == 1 ? 1.8 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setDlgState(() => selectedDirMode = 1),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          label: const Text('Вправо', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showEditWallDialog(wallIndex);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 15, color: Color(0xFF94A3B8)),
                          SizedBox(width: 6),
                          Text('Настроить слои стены (пирог, материалы)...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D99FF),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final newMm = double.tryParse(ctrl.text.replaceAll(',', '.'));
                  if (newMm != null && newMm > 50.0) {
                    final double targetM = newMm / 1000.0;
                    final double deltaM = targetM - curInternalM;
                    final double deltaPx = deltaM * 100.0;
                    setState(() {
                      _parametricResizeWall(wall, deltaPx, selectedDirMode);
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditWallDialog(int wallIndex, {int targetSideSign = 1}) {
    final wall = walls[wallIndex];
    wall.ensureStandardLayers();
    final double curInternalLen = _getWallInternalLength(wall);
    final wCtrl = TextEditingController(
      text: currentUnit == UnitFormat.millimeters
          ? (curInternalLen * 1000.0).round().toString()
          : curInternalLen.toStringAsFixed(2),
    );
    double tempThick = wall.thicknessCm;
    int activeSide = targetSideSign;
    String? tempTexA = wall.textureSideA;
    String? tempTexB = wall.textureSideB;

    List<WallLayer> tempLayersA = wall.layersSideA.map((l) => WallLayer.fromJson(l.toJson())).toList();
    List<WallLayer> tempLayersB = wall.layersSideB.map((l) => WallLayer.fromJson(l.toJson())).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentSideTex = activeSide >= 0 ? tempTexA : tempTexB;
          final activeLayers = activeSide >= 0 ? tempLayersA : tempLayersB;
          final totalLayersMm = activeLayers.where((l) => l.enabled).fold(0.0, (s, l) => s + l.thicknessMm);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.layers_rounded, color: Color(0xFF0D99FF)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Параметры и отделка стены', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold))),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: Text(wall.tileConfig != null ? 'Плитка (${wall.tileConfig!.tileWidthMm.round()}×${wall.tileConfig!.tileHeightMm.round()})' : 'Раскладка плитки', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _openWallTileLayoutStudio(wall);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(540.0, MediaQuery.of(context).size.width - 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wCtrl,
                            decoration: InputDecoration(
                              labelText: 'Внутренний размер в свету (${currentUnit == UnitFormat.millimeters ? "мм" : "м"})',
                              helperText: 'Осевой размер стены: ${formatLength(wall.lengthInMeters)}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Основа стены: ${formatCm(tempThick)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            SizedBox(
                              width: 160,
                              child: Slider(
                                value: tempThick,
                                min: 5,
                                max: 50,
                                divisions: 45,
                                onChanged: (v) => setDialogState(() => tempThick = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Сторона стены:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('Сторона (А) Внутренняя'),
                          selected: activeSide >= 0,
                          onSelected: (_) => setDialogState(() => activeSide = 1),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Сторона (Б) Обратная'),
                          selected: activeSide < 0,
                          onSelected: (_) => setDialogState(() => activeSide = -1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // СЛОИ ОТДЕЛКИ (ПИРОГ СТЕНЫ)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0D99FF).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.view_agenda_outlined, color: Color(0xFF0D99FF), size: 16),
                                  SizedBox(width: 6),
                                  Text('Слои отделки (пирог стены):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              Text('+${totalLayersMm.round()} мм', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Готовые наборы отделки:', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('Под плитку (штукатурка + клей + плитка)', style: TextStyle(fontSize: 10)),
                                onPressed: () {
                                  setDialogState(() {
                                    for (final l in activeLayers) {
                                      l.enabled = (l.id == 'plaster' || l.id == 'tile_adhesive' || l.id == 'tile');
                                    }
                                  });
                                },
                              ),
                              ActionChip(
                                label: const Text('Под покраску (штукатурка + шпатлевка)', style: TextStyle(fontSize: 10)),
                                onPressed: () {
                                  setDialogState(() {
                                    for (final l in activeLayers) {
                                      l.enabled = (l.id == 'plaster' || l.id == 'putty');
                                    }
                                  });
                                },
                              ),
                              ActionChip(
                                label: const Text('С ГКЛ (штукатурка + гипсокартон)', style: TextStyle(fontSize: 10)),
                                onPressed: () {
                                  setDialogState(() {
                                    for (final l in activeLayers) {
                                      l.enabled = (l.id == 'plaster' || l.id == 'drywall');
                                    }
                                  });
                                },
                              ),
                              ActionChip(
                                label: const Text('Без отделки', style: TextStyle(fontSize: 10)),
                                onPressed: () {
                                  setDialogState(() {
                                    for (final l in activeLayers) {
                                      l.enabled = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(color: isDarkTheme ? Colors.white12 : Colors.black12, height: 1),
                          const SizedBox(height: 6),

                          // Список слоев
                          ...activeLayers.map((layer) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: layer.enabled,
                                    onChanged: (v) => setDialogState(() => layer.enabled = v ?? false),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Expanded(
                                    child: Text(
                                      layer.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: layer.enabled ? FontWeight.bold : FontWeight.normal,
                                        color: layer.enabled ? null : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Text('${layer.thicknessMm.round()} мм', style: TextStyle(fontSize: 11, color: layer.enabled ? const Color(0xFF38BDF8) : Colors.grey)),
                                  SizedBox(
                                    width: 110,
                                    child: Slider(
                                      value: layer.thicknessMm.clamp(1.0, 30.0),
                                      min: 1.0,
                                      max: 30.0,
                                      divisions: 29,
                                      onChanged: layer.enabled
                                          ? (v) => setDialogState(() => layer.thicknessMm = v.roundToDouble())
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text('Текстура лицевого слоя (нажмите на превью):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    _buildVisualTextureSelectorGrid(
                      currentTextureId: currentSideTex,
                      onSelect: (val) {
                        setDialogState(() {
                          if (activeSide >= 0) {
                            tempTexA = val;
                          } else {
                            tempTexB = val;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _recordSnapshotForUndo();
                  setState(() {
                    walls.removeAt(wallIndex);
                    selectedWall = null;
                    _rebuildAutoZonesFromWalls();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Удалить стену (Del)', style: TextStyle(color: Colors.red)),
              ),
              FilledButton(
                onPressed: () {
                  _recordSnapshotForUndo();
                  final nw = parseInputToMeters(wCtrl.text);
                  setState(() {
                    wall.thicknessCm = tempThick;
                    wall.textureSideA = tempTexA;
                    wall.textureSideB = tempTexB;
                    wall.layersSideA = tempLayersA;
                    wall.layersSideB = tempLayersB;
                    if (nw > 0) {
                      final double deltaInternalM = nw - curInternalLen;
                      final double deltaPx = deltaInternalM * 100.0;
                      if (deltaPx.abs() > 0.1) {
                        _parametricResizeWall(wall, deltaPx, 1);
                      }
                    }
                    _rebuildAutoZonesFromWalls();
                    _autoSaveCurrentProject();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Применить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditInteriorObjectDialog(int index) {
    final obj = objects[index];
    final nameCtrl = TextEditingController(text: obj.name);
    final wCtrl = TextEditingController(text: obj.widthMeters.toStringAsFixed(2));
    final dCtrl = TextEditingController(text: obj.depthMeters.toStringAsFixed(2));
    final hCtrl = TextEditingController(text: obj.heightMeters.toStringAsFixed(2));
    double tempRot = obj.rotationDeg;
    String? tempTex = obj.textureId;
    String? tempModel = obj.model3dPath;

    final wallDists = _computeFurnitureWallDistances(obj, walls);
    final leftDistCtrl = TextEditingController(text: wallDists.leftDistM?.toStringAsFixed(2) ?? '');
    final rightDistCtrl = TextEditingController(text: wallDists.rightDistM?.toStringAsFixed(2) ?? '');
    final topDistCtrl = TextEditingController(text: wallDists.topDistM?.toStringAsFixed(2) ?? '');
    final bottomDistCtrl = TextEditingController(text: wallDists.bottomDistM?.toStringAsFixed(2) ?? '');

    String? editedWallSide;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Параметры мебели и отступы от стен'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: wCtrl,
                            decoration: const InputDecoration(labelText: 'Ширина (м)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: dCtrl,
                            decoration: const InputDecoration(labelText: 'Глубина (м)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: hCtrl,
                            decoration: const InputDecoration(labelText: 'Высота (м)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Точное расстояние до ближайших стен (м):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF059669))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: leftDistCtrl,
                        enabled: wallDists.leftWallPt != null,
                        decoration: InputDecoration(
                          labelText: wallDists.leftWallPt != null ? 'От стены слева (м)' : 'Слева нет стены',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => editedWallSide = 'left',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: rightDistCtrl,
                        enabled: wallDists.rightWallPt != null,
                        decoration: InputDecoration(
                          labelText: wallDists.rightWallPt != null ? 'От стены справа (м)' : 'Справа нет стены',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => editedWallSide = 'right',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: topDistCtrl,
                        enabled: wallDists.topWallPt != null,
                        decoration: InputDecoration(
                          labelText: wallDists.topWallPt != null ? 'От стены сверху (м)' : 'Сверху нет стены',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => editedWallSide = 'top',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: bottomDistCtrl,
                        enabled: wallDists.bottomWallPt != null,
                        decoration: InputDecoration(
                          labelText: wallDists.bottomWallPt != null ? 'От стены снизу (м)' : 'Снизу нет стены',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => editedWallSide = 'bottom',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Поворот: ${tempRot.round()}° (или клавиша R)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Slider(value: tempRot, min: 0, max: 360, divisions: 72, onChanged: (v) => setDialogState(() => tempRot = v)),
                DropdownButtonFormField<String?>(
                  initialValue: tempModel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: 'Привязанная 3D-модель (assets/models/)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Процедурная 3D-мебель по категории', style: TextStyle(fontSize: 12))),
                    ...my3DModelCatalog.map((m) => DropdownMenuItem(
                          value: m.modelAssetPath,
                          child: Text('${m.categoryRu}: ${m.name} (.${m.extension})', style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => tempModel = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: tempTex,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Текстура материала'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Базовый цвет', style: TextStyle(fontSize: 12))),
                    ...myTextureCatalog.map((t) =>
                        DropdownMenuItem(value: t.id, child: Text('${t.category} - ${t.name}', style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (v) => setDialogState(() => tempTex = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  objects.removeAt(index);
                  selectedObject = null;
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Удалить (Del)', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  // Обновляем по ССЫЛКЕ, чтобы не ломать индекс
                  obj.name = nameCtrl.text.trim().isEmpty ? obj.name : nameCtrl.text.trim();
                  obj.widthMeters = double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? obj.widthMeters;
                  obj.depthMeters = double.tryParse(dCtrl.text.replaceAll(',', '.')) ?? obj.depthMeters;
                  obj.heightMeters = double.tryParse(hCtrl.text.replaceAll(',', '.')) ?? obj.heightMeters;
                  obj.rotationDeg = tempRot;
                  obj.model3dPath = tempModel;
                  obj.textureId = tempTex;

                  final newLeft = double.tryParse(leftDistCtrl.text.replaceAll(',', '.'));
                  final newRight = double.tryParse(rightDistCtrl.text.replaceAll(',', '.'));
                  final newTop = double.tryParse(topDistCtrl.text.replaceAll(',', '.'));
                  final newBottom = double.tryParse(bottomDistCtrl.text.replaceAll(',', '.'));

                  double newX = obj.position.dx;
                  double newY = obj.position.dy;

                  if (editedWallSide == 'left' && newLeft != null && wallDists.leftWallPt != null) {
                    newX = wallDists.leftWallPt!.dx + (newLeft + obj.widthMeters / 2.0) * 100.0;
                  } else if (editedWallSide == 'right' && newRight != null && wallDists.rightWallPt != null) {
                    newX = wallDists.rightWallPt!.dx - (newRight + obj.widthMeters / 2.0) * 100.0;
                  } else if (newLeft != null &&
                      wallDists.leftWallPt != null &&
                      (newLeft - (wallDists.leftDistM ?? 0)).abs() > 0.005) {
                    newX = wallDists.leftWallPt!.dx + (newLeft + obj.widthMeters / 2.0) * 100.0;
                  } else if (newRight != null &&
                      wallDists.rightWallPt != null &&
                      (newRight - (wallDists.rightDistM ?? 0)).abs() > 0.005) {
                    newX = wallDists.rightWallPt!.dx - (newRight + obj.widthMeters / 2.0) * 100.0;
                  }

                  if (editedWallSide == 'top' && newTop != null && wallDists.topWallPt != null) {
                    newY = wallDists.topWallPt!.dy + (newTop + obj.depthMeters / 2.0) * 100.0;
                  } else if (editedWallSide == 'bottom' && newBottom != null && wallDists.bottomWallPt != null) {
                    newY = wallDists.bottomWallPt!.dy - (newBottom + obj.depthMeters / 2.0) * 100.0;
                  } else if (newTop != null &&
                      wallDists.topWallPt != null &&
                      (newTop - (wallDists.topDistM ?? 0)).abs() > 0.005) {
                    newY = wallDists.topWallPt!.dy + (newTop + obj.depthMeters / 2.0) * 100.0;
                  } else if (newBottom != null &&
                      wallDists.bottomWallPt != null &&
                      (newBottom - (wallDists.bottomDistM ?? 0)).abs() > 0.005) {
                    newY = wallDists.bottomWallPt!.dy - (newBottom + obj.depthMeters / 2.0) * 100.0;
                  }

                  obj.position = Offset(newX, newY);
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTextureCatalogModal() {
    String selectedCategory = 'Все';
    final categories = ['Все', ...myTextureCatalog.map((t) => t.category).toSet()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = selectedCategory == 'Все'
              ? myTextureCatalog
              : myTextureCatalog.where((t) => t.category == selectedCategory).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('База материалов и текстур', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF0D99FF).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  selectedObject != null
                                      ? 'Цель: «${selectedObject!.name}»'
                                      : selectedWall != null
                                          ? 'Цель: выбранная стена'
                                          : editingBoundaryZone != null
                                              ? 'Цель: зона «${editingBoundaryZone!.name}»'
                                              : 'Цель: пол комнат (${zones.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D99FF)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedObject != null
                                ? 'Кликните по материалу, чтобы применить его к выбранному предмету мебели'
                                : selectedWall != null
                                    ? 'Кликните по материалу, чтобы облицевать выбранную стену'
                                    : 'Кликните по материалу, чтобы постелить его на пол комнат',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Пересканировать папки',
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await _loadFolderAssets();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (myTextureCatalog.isEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'В папках пока нет картинок (.jpg / .png / .webp)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Положите файлы с английскими именами (например, beton_1.jpg) в папку assets/textures/concrete/ и перезапустите проект (F5).',
                              style: TextStyle(fontSize: 13),
                            ),
                            const Divider(height: 20),
                            SelectableText(
                              _debugManifestAssets.isEmpty
                                  ? 'Список пуст.'
                                  : _debugManifestAssets.map((e) => '• $e').join('\n'),
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: c == selectedCategory,
                                  onSelected: (_) => setModalState(() => selectedCategory = c),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 210,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final tex = filtered[idx];
                        return InkWell(
                          onTap: () {
                            _recordSnapshotForUndo();
                            setState(() {
                              if (selectedObject != null) {
                                selectedObject!.textureId = tex.id;
                              } else if (selectedWall != null) {
                                selectedWall!.textureSideA = tex.id;
                                selectedWall!.textureSideB = tex.id;
                              } else if (editingBoundaryZone != null) {
                                editingBoundaryZone!.textureId = tex.id;
                              } else if (selectedOpening != null) {
                                selectedOpening!.textureId = tex.id;
                              } else {
                                for (final z in zones) {
                                  z.textureId = tex.id;
                                }
                              }
                              _autoSaveCurrentProject();
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    child: CustomPaint(
                                      painter: _SingleTexturePreviewPainter(image: _loadedImages[tex.id]!),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '${tex.category}: ${tex.name}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }


  // =========================================================================
  // РЕЖИМ ПРОИЗВОЛЬНОЙ ПЛАНИРОВКИ И БЫСТРОЕ РЕДАКТИРОВАНИЕ РАЗМЕРОВ В СВЕТУ
  // =========================================================================
  void _startCustomSketchMode() {
    setState(() {
      isCustomSketchMode = true;
      customSketchStep = 1;
      selectedTool = EditorTool.drawWall;
      _sketchStartWallCount = walls.length;
      sketchWallTargetLengthsMm.clear();
      activeDockFlyout = ActiveDockFlyout.none;
    });
  }

  void _proceedToCustomSketchStep2() {
    setState(() {
      customSketchStep = 2;
      selectedTool = EditorTool.wallDimensions;
      for (int i = _sketchStartWallCount; i < walls.length; i++) {
        final dim = computeWallFaceDimension(walls[i], walls, zones);
        sketchWallTargetLengthsMm[i] = dim.lengthMm.toDouble();
      }
    });
  }

  void _cancelCustomSketchMode() {
    setState(() {
      if (customSketchStep == 1 && walls.length > _sketchStartWallCount) {
        walls.removeRange(_sketchStartWallCount, walls.length);
      }
      isCustomSketchMode = false;
      customSketchStep = 1;
      selectedTool = EditorTool.overview;
      sketchWallTargetLengthsMm.clear();
      _rebuildAutoZonesFromWalls();
    });
  }

  void _finalizeCustomSketchLayout() {
    _recordSnapshotForUndo();
    final sketchWalls = walls.sublist(_sketchStartWallCount);
    if (sketchWalls.length >= 3) {
      Offset currentPt = sketchWalls.first.start;
      for (int i = 0; i < sketchWalls.length; i++) {
        final w = sketchWalls[i];
        final wallIdx = _sketchStartWallCount + i;
        final double targetMm = sketchWallTargetLengthsMm[wallIdx] ?? (w.lengthInMeters * 1000.0);
        final double targetPx = targetMm / 10.0;

        final dir = (w.end - w.start);
        final len = dir.distance;
        final u = len > 0.01 ? dir / len : const Offset(1, 0);

        Offset orthoU = u;
        if (u.dx.abs() > u.dy.abs()) {
          orthoU = Offset(u.dx > 0 ? 1.0 : -1.0, 0.0);
        } else {
          orthoU = Offset(0.0, u.dy > 0 ? 1.0 : -1.0);
        }

        w.start = currentPt;
        w.end = currentPt + orthoU * targetPx;
        w.customClearLengthM = targetMm / 1000.0;
        currentPt = w.end;
      }
      sketchWalls.last.end = sketchWalls.first.start;
    }

    setState(() {
      isCustomSketchMode = false;
      customSketchStep = 1;
      selectedTool = EditorTool.overview;
      sketchWallTargetLengthsMm.clear();
      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Планировка успешно построена по заданным жестким размерам!'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showQuickClearDimensionDialog(int wallIndex, WallFaceDimension dim) {
    final wall = walls[wallIndex];
    final curMm = dim.lengthMm;
    final ctrl = TextEditingController(text: curMm > 0 ? curMm.toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D99FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.straighten_rounded, color: Color(0xFF38BDF8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Чистовой размер стены', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('В свету от угла до угла: $curMm мм', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Введите точный размер (мм):', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                suffixText: 'мм',
                suffixStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (val != null && val >= 50.0) {
                Navigator.pop(context);
                _recordSnapshotForUndo();
                final double newM = val / 1000.0;
                final double oldM = dim.lengthM;
                final double deltaM = newM - oldM;
                wall.customClearLengthM = newM;

                if (sketchWallTargetLengthsMm.containsKey(wallIndex)) {
                  sketchWallTargetLengthsMm[wallIndex] = val;
                }

                final axialLenPx = (wall.end - wall.start).distance;
                if (axialLenPx > 1.0) {
                  final dir = (wall.end - wall.start) / axialLenPx;
                  final shift = dir * (deltaM * 100.0);
                  final oldEnd = wall.end;
                  final newEnd = oldEnd + shift;
                  wall.end = newEnd;
                  for (final other in walls) {
                    if (identical(other, wall)) continue;
                    if ((other.start - oldEnd).distance < 10.0) {
                      other.start = newEnd;
                    } else if ((other.end - oldEnd).distance < 10.0) {
                      other.end = newEnd;
                    }
                  }
                }

                setState(() {
                  _rebuildAutoZonesFromWalls();
                  _autoSaveCurrentProject();
                });
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Применить ✓', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSketchOverlayBanner() {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 54, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.architecture_rounded, color: Color(0xFFA78BFA), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customSketchStep == 1
                              ? 'Произвольная планировка: Шаг 1 из 2'
                              : 'Шаг 2: Задайте точные размеры стен',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          customSketchStep == 1
                              ? 'Нарисуйте эскиз контура помещения от руки'
                              : 'Нажимайте на размеры стен на плане для ввода значений',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _cancelCustomSketchMode,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _cancelCustomSketchMode,
                    child: const Text('Отмена', style: TextStyle(fontSize: 11)),
                  ),
                  const Spacer(),
                  if (customSketchStep == 1)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      onPressed: (walls.length - _sketchStartWallCount >= 3)
                          ? _proceedToCustomSketchStep2
                          : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Задать размеры ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D99FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      onPressed: _finalizeCustomSketchLayout,
                      icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                      label: const Text('Построить чертёж 🚀', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCadSnapsMenu([BuildContext? btnContext]) {
    setState(() {
      activeDockFlyout = (activeDockFlyout == ActiveDockFlyout.snapping)
          ? ActiveDockFlyout.none
          : ActiveDockFlyout.snapping;
    });
  }

  void _finishDrawingShape() {
    if (currentStart == null || currentEnd == null) return;

    if (selectedTool == EditorTool.drawWall) {
      if ((currentEnd! - currentStart!).distance >= 5.0) {
        _recordSnapshotForUndo();
        final newEnd = currentEnd!;
        walls.add(Wall(currentStart!, newEnd, thicknessCm: currentThicknessCm));
        _rebuildAutoZonesFromWalls();
        _autoSaveCurrentProject();

        bool closedLoop = walls.any((w) => (w.start - newEnd).distance < 8.0 && !identical(w, walls.last));
        if (closedLoop) {
          currentStart = null;
          currentEnd = null;
          selectedTool = EditorTool.overview;
        } else {
          currentStart = newEnd;
          currentEnd = newEnd;
        }
        return;
      }
    } else if (selectedTool == EditorTool.drawDimension) {
      if ((currentEnd! - currentStart!).distance >= 5.0) {
        _recordSnapshotForUndo();
        customDimensions.add(CustomDimensionLine(currentStart!, currentEnd!));
        _autoSaveCurrentProject();
      }
    } else if (selectedTool == EditorTool.drawRoomBox) {
      final rect = Rect.fromPoints(currentStart!, currentEnd!);
      if (rect.width >= 20 && rect.height >= 20) {
        _recordSnapshotForUndo();
        final T = currentThicknessCm;
        final H = T / 2.0;

        // rect задаёт ЧИСТЫЙ ВНУТРЕННИЙ РАЗМЕР комнаты (в свету)!
        // Стены строятся снаружи rect, чтобы внутреннее пространство было ровно rect:
        final left = rect.left - H;
        final right = rect.right + H;
        final top = rect.top - H;
        final bottom = rect.bottom + H;

        final tl = Offset(left, top);
        final tr = Offset(right, top);
        final br = Offset(right, bottom);
        final bl = Offset(left, bottom);

        walls.add(Wall(tl, tr, thicknessCm: T));
        walls.add(Wall(tr, br, thicknessCm: T));
        walls.add(Wall(br, bl, thicknessCm: T));
        walls.add(Wall(bl, tl, thicknessCm: T));
        _rebuildAutoZonesFromWalls();
      }
    }
  }

  void _scheduleHideThicknessPopup() {
    _hideThicknessTimer?.cancel();
    _hideThicknessTimer = Timer(const Duration(milliseconds: 280), () {
      if (!_hoveringWallToolBtn && !_hoveringThicknessPopup && mounted) {
        setState(() {});
      }
    });
  }

  void _fitPlanToScreen() {
    if (walls.isEmpty && objects.isEmpty && zones.isEmpty) {
      setState(() {
        canvasOffset = const Offset(120, 140);
        canvasScale = 0.85;
      });
      return;
    }

    double minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
    for (final w in walls) {
      minX = math.min(minX, math.min(w.start.dx, w.end.dx));
      minY = math.min(minY, math.min(w.start.dy, w.end.dy));
      maxX = math.max(maxX, math.max(w.start.dx, w.end.dx));
      maxY = math.max(maxY, math.max(w.start.dy, w.end.dy));
    }
    for (final o in objects) {
      final hw = (o.widthMeters * 100) / 2;
      final hd = (o.depthMeters * 100) / 2;
      minX = math.min(minX, o.position.dx - hw);
      minY = math.min(minY, o.position.dy - hd);
      maxX = math.max(maxX, o.position.dx + hw);
      maxY = math.max(maxY, o.position.dy + hd);
    }

    final spanW = math.max(80.0, maxX - minX);
    final spanH = math.max(80.0, maxY - minY);
    final viewW = _viewportSize.width > 0 ? _viewportSize.width : 1200.0;
    final viewH = _viewportSize.height > 0 ? _viewportSize.height : 800.0;

    final targetScale = math.min((viewW - 320) / spanW, (viewH - 260) / spanH).clamp(0.25, 2.5);
    final centerWorld = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    setState(() {
      canvasScale = targetScale;
      canvasOffset = Offset(viewW / 2, viewH / 2) - centerWorld * canvasScale;
    });
  }

  void _loadTemplateStudio() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      final p1 = const Offset(100, 100);
      final p2 = const Offset(820, 100);
      final p3 = const Offset(820, 580);
      final p4 = const Offset(100, 580);

      walls.add(Wall(p1, p2, thicknessCm: 25));
      walls.add(Wall(p2, p3, thicknessCm: 25));
      walls.add(Wall(p3, p4, thicknessCm: 25));
      walls.add(Wall(p4, p1, thicknessCm: 25));

      final bathCorner = const Offset(340, 320);
      walls.add(Wall(const Offset(340, 100), bathCorner, thicknessCm: 15));
      walls.add(Wall(bathCorner, const Offset(100, 320), thicknessCm: 15));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь санузла',
        position: const Offset(340, 210),
        rotation: math.pi / 2,
        widthMeters: 0.8,
      ));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Входная дверь',
        position: const Offset(100, 450),
        rotation: math.pi / 2,
        widthMeters: 0.95,
      ));

      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно панорамное',
        position: const Offset(820, 340),
        rotation: math.pi / 2,
        widthMeters: 2.2,
      ));

      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Ванна акриловая',
        position: const Offset(190, 160),
        widthMeters: 1.7,
        depthMeters: 0.75,
      ));
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Унитаз-инсталляция',
        position: const Offset(300, 155),
        rotationDeg: 90,
        widthMeters: 0.4,
        depthMeters: 0.65,
      ));
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Раковина с тумбой',
        position: const Offset(300, 270),
        rotationDeg: 90,
        widthMeters: 0.7,
        depthMeters: 0.5,
      ));

      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Кухонный гарнитур',
        position: const Offset(490, 145),
        widthMeters: 2.4,
        depthMeters: 0.6,
      ));
      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Холодильник',
        position: const Offset(660, 145),
        widthMeters: 0.65,
        depthMeters: 0.65,
      ));
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Стол обеденный',
        position: const Offset(550, 280),
        widthMeters: 1.4,
        depthMeters: 0.85,
      ));

      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Диван прямой',
        position: const Offset(570, 500),
        rotationDeg: 180,
        widthMeters: 2.2,
        depthMeters: 0.95,
      ));
      objects.add(InteriorObject(
        category: 'storage',
        name: 'Шкаф-купе',
        position: const Offset(230, 520),
        rotationDeg: 180,
        widthMeters: 2.0,
        depthMeters: 0.6,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _loadTemplate2Room() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      // Наружный контур 10.5 × 6.5 м (68 м²)
      final p1 = const Offset(80, 80);
      final p2 = const Offset(1130, 80);
      final p3 = const Offset(1130, 730);
      final p4 = const Offset(80, 730);

      walls.add(Wall(p1, p2, thicknessCm: 25));
      walls.add(Wall(p2, p3, thicknessCm: 25));
      walls.add(Wall(p3, p4, thicknessCm: 25));
      walls.add(Wall(p4, p1, thicknessCm: 25));

      // Внутренние перегородки
      // Разделитель мастер-спальни и кухни-гостиной
      walls.add(Wall(const Offset(520, 80), const Offset(520, 420), thicknessCm: 15));
      walls.add(Wall(const Offset(80, 420), const Offset(520, 420), thicknessCm: 15));

      // Детская / кабинет в правом верхнем углу
      walls.add(Wall(const Offset(520, 80), const Offset(1130, 80), thicknessCm: 25));
      walls.add(Wall(const Offset(800, 80), const Offset(800, 360), thicknessCm: 15));
      walls.add(Wall(const Offset(520, 360), const Offset(800, 360), thicknessCm: 15));

      // Санузел в левом нижнем углу
      walls.add(Wall(const Offset(80, 560), const Offset(340, 560), thicknessCm: 15));
      walls.add(Wall(const Offset(340, 560), const Offset(340, 730), thicknessCm: 15));

      // Двери
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Входная дверь',
        position: const Offset(80, 480),
        rotation: math.pi / 2,
        widthMeters: 0.95,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь спальни',
        position: const Offset(380, 420),
        rotation: 0,
        widthMeters: 0.85,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь кабинета',
        position: const Offset(620, 360),
        rotation: 0,
        widthMeters: 0.85,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь санузла',
        position: const Offset(210, 560),
        rotation: 0,
        widthMeters: 0.8,
      ));

      // Окна
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно спальни',
        position: const Offset(280, 80),
        rotation: 0,
        widthMeters: 1.8,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно кабинета',
        position: const Offset(950, 80),
        rotation: 0,
        widthMeters: 1.6,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Панорамное окно гостиной',
        position: const Offset(1130, 550),
        rotation: math.pi / 2,
        widthMeters: 2.4,
      ));

      // Мебель - Мастер-спальня
      objects.add(InteriorObject(
        category: 'bedroom',
        name: 'Кровать двуспальная',
        position: const Offset(280, 220),
        rotationDeg: 90,
        widthMeters: 1.8,
        depthMeters: 2.1,
      ));
      objects.add(InteriorObject(
        category: 'storage',
        name: 'Шкаф-купе',
        position: const Offset(460, 220),
        rotationDeg: 90,
        widthMeters: 2.2,
        depthMeters: 0.65,
      ));

      // Мебель - Кабинет / Детская
      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Диван компактный',
        position: const Offset(660, 200),
        rotationDeg: 90,
        widthMeters: 1.8,
        depthMeters: 0.85,
      ));
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Рабочий стол',
        position: const Offset(950, 150),
        rotationDeg: 0,
        widthMeters: 1.5,
        depthMeters: 0.75,
      ));

      // Мебель - Кухня-гостиная
      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Кухонный гарнитур угловой',
        position: const Offset(600, 670),
        rotationDeg: 180,
        widthMeters: 3.2,
        depthMeters: 0.6,
      ));
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Обеденный стол со стульями',
        position: const Offset(700, 520),
        widthMeters: 1.5,
        depthMeters: 0.9,
      ));
      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Угловой диван',
        position: const Offset(980, 520),
        rotationDeg: 270,
        widthMeters: 2.6,
        depthMeters: 1.8,
      ));
      objects.add(InteriorObject(
        category: 'appliances',
        name: 'ТВ и тумба',
        position: const Offset(820, 420),
        rotationDeg: 0,
        widthMeters: 1.6,
        depthMeters: 0.45,
      ));

      // Мебель - Санузел
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Ванна акриловая',
        position: const Offset(170, 680),
        rotationDeg: 180,
        widthMeters: 1.7,
        depthMeters: 0.75,
      ));
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Унитаз-инсталляция',
        position: const Offset(300, 630),
        rotationDeg: 270,
        widthMeters: 0.42,
        depthMeters: 0.65,
      ));
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Раковина с тумбой',
        position: const Offset(140, 590),
        rotationDeg: 90,
        widthMeters: 0.8,
        depthMeters: 0.5,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _loadTemplateKitchenLiving() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      // Кухня-гостиная с островом 7.5 × 4.2 м (31.5 м²)
      final p1 = const Offset(100, 100);
      final p2 = const Offset(850, 100);
      final p3 = const Offset(850, 520);
      final p4 = const Offset(100, 520);

      walls.add(Wall(p1, p2, thicknessCm: 25));
      walls.add(Wall(p2, p3, thicknessCm: 25));
      walls.add(Wall(p3, p4, thicknessCm: 25));
      walls.add(Wall(p4, p1, thicknessCm: 25));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь в коридор',
        position: const Offset(100, 310),
        rotation: math.pi / 2,
        widthMeters: 0.9,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Панорамное окно в пол',
        position: const Offset(850, 310),
        rotation: math.pi / 2,
        widthMeters: 2.6,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно над мойкой',
        position: const Offset(320, 100),
        rotation: 0,
        widthMeters: 1.4,
      ));

      // Гарнитур вдоль верхней стены
      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Кухонный фронт с техникой',
        position: const Offset(350, 140),
        widthMeters: 3.4,
        depthMeters: 0.6,
      ));
      // Остров
      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Кухонный остров с баром',
        position: const Offset(350, 260),
        widthMeters: 2.0,
        depthMeters: 0.9,
      ));
      // Обеденная зона
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Обеденный стол (6 персон)',
        position: const Offset(620, 210),
        widthMeters: 1.8,
        depthMeters: 0.9,
      ));
      // Зона отдыха
      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Большой диван',
        position: const Offset(550, 450),
        rotationDeg: 180,
        widthMeters: 2.8,
        depthMeters: 1.0,
      ));
      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Журнальный столик',
        position: const Offset(550, 360),
        widthMeters: 1.1,
        depthMeters: 0.6,
      ));
      objects.add(InteriorObject(
        category: 'appliances',
        name: 'ТВ-консоль',
        position: const Offset(230, 460),
        rotationDeg: 180,
        widthMeters: 1.8,
        depthMeters: 0.45,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _loadTemplateBathroomLuxury() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      // Просторный санузел 3.4 × 2.4 м (8.1 м²)
      final p1 = const Offset(120, 120);
      final p2 = const Offset(460, 120);
      final p3 = const Offset(460, 360);
      final p4 = const Offset(120, 360);

      walls.add(Wall(p1, p2, thicknessCm: 20));
      walls.add(Wall(p2, p3, thicknessCm: 20));
      walls.add(Wall(p3, p4, thicknessCm: 20));
      walls.add(Wall(p4, p1, thicknessCm: 20));

      // Стеклянная душевая перегородка
      walls.add(Wall(const Offset(340, 120), const Offset(340, 220), thicknessCm: 8));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь скрытого монтажа',
        position: const Offset(120, 240),
        rotation: math.pi / 2,
        widthMeters: 0.8,
      ));

      // Отдельностоящая ванна
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Отдельностоящая ванна',
        position: const Offset(240, 305),
        rotationDeg: 180,
        widthMeters: 1.75,
        depthMeters: 0.8,
      ));
      // Двойная подвесная тумба
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Подвесная тумба с 2 раковинами',
        position: const Offset(230, 155),
        widthMeters: 1.4,
        depthMeters: 0.52,
      ));
      // Душевой трап / стойка
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Тропический душ',
        position: const Offset(400, 165),
        widthMeters: 0.9,
        depthMeters: 0.9,
      ));
      // Унитаз
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Инсталляция с безободковым унитазом',
        position: const Offset(410, 310),
        rotationDeg: 270,
        widthMeters: 0.42,
        depthMeters: 0.65,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _loadTemplateOffice() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      // Рабочий кабинет 5.2 × 4.0 м (20.8 м²)
      final p1 = const Offset(100, 100);
      final p2 = const Offset(620, 100);
      final p3 = const Offset(620, 500);
      final p4 = const Offset(100, 500);

      walls.add(Wall(p1, p2, thicknessCm: 20));
      walls.add(Wall(p2, p3, thicknessCm: 20));
      walls.add(Wall(p3, p4, thicknessCm: 20));
      walls.add(Wall(p4, p1, thicknessCm: 20));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь кабинета',
        position: const Offset(100, 300),
        rotation: math.pi / 2,
        widthMeters: 0.9,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Панорамное окно',
        position: const Offset(620, 300),
        rotation: math.pi / 2,
        widthMeters: 2.2,
      ));

      // Стол руководителя
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Массивный стол руководителя',
        position: const Offset(450, 220),
        widthMeters: 1.9,
        depthMeters: 0.9,
      ));
      // Офисное кресло
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Эргономичное кресло',
        position: const Offset(450, 155),
        widthMeters: 0.65,
        depthMeters: 0.65,
      ));
      // Стеллаж для книг и документации
      objects.add(InteriorObject(
        category: 'storage',
        name: 'Стеллаж-библиотека',
        position: const Offset(230, 140),
        widthMeters: 2.2,
        depthMeters: 0.45,
      ));
      // Зона переговоров
      objects.add(InteriorObject(
        category: 'living_room',
        name: 'Кожаный диван для гостей',
        position: const Offset(360, 440),
        rotationDeg: 180,
        widthMeters: 2.0,
        depthMeters: 0.85,
      ));
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Журнальный стол переговорный',
        position: const Offset(360, 360),
        widthMeters: 0.9,
        depthMeters: 0.6,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }


  void _loadTemplate1Room() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      final p1 = const Offset(80, 80);
      final p2 = const Offset(980, 80);
      final p3 = const Offset(980, 640);
      final p4 = const Offset(80, 640);

      walls.add(Wall(p1, p2, thicknessCm: 25));
      walls.add(Wall(p2, p3, thicknessCm: 25));
      walls.add(Wall(p3, p4, thicknessCm: 25));
      walls.add(Wall(p4, p1, thicknessCm: 25));

      walls.add(Wall(const Offset(530, 80), const Offset(530, 640), thicknessCm: 15));
      walls.add(Wall(const Offset(80, 340), const Offset(530, 340), thicknessCm: 15));
      walls.add(Wall(const Offset(320, 80), const Offset(320, 340), thicknessCm: 15));

      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Входная дверь',
        position: const Offset(80, 210),
        rotation: math.pi / 2,
        widthMeters: 0.95,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь в спальню',
        position: const Offset(530, 210),
        rotation: math.pi / 2,
        widthMeters: 0.85,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь на кухню',
        position: const Offset(430, 340),
        rotation: 0,
        widthMeters: 0.85,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь в санузел',
        position: const Offset(320, 210),
        rotation: math.pi / 2,
        widthMeters: 0.75,
      ));

      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно спальни',
        position: const Offset(980, 360),
        rotation: math.pi / 2,
        widthMeters: 1.8,
      ));
      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно кухни',
        position: const Offset(280, 640),
        rotation: 0,
        widthMeters: 1.5,
      ));

      objects.add(InteriorObject(
        category: 'bedroom',
        name: 'Кровать двуспальная',
        position: const Offset(780, 230),
        rotationDeg: 90,
        widthMeters: 1.8,
        depthMeters: 2.05,
      ));
      objects.add(InteriorObject(
        category: 'storage',
        name: 'Шкаф-купе',
        position: const Offset(740, 580),
        rotationDeg: 180,
        widthMeters: 2.4,
        depthMeters: 0.6,
      ));

      objects.add(InteriorObject(
        category: 'kitchen',
        name: 'Кухонный гарнитур',
        position: const Offset(230, 390),
        widthMeters: 2.6,
        depthMeters: 0.6,
      ));
      objects.add(InteriorObject(
        category: 'tables_chairs',
        name: 'Стол обеденный',
        position: const Offset(240, 520),
        widthMeters: 1.4,
        depthMeters: 0.85,
      ));

      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Ванна акриловая',
        position: const Offset(170, 140),
        widthMeters: 1.7,
        depthMeters: 0.75,
      ));
      objects.add(InteriorObject(
        category: 'plumbing',
        name: 'Унитаз-инсталляция',
        position: const Offset(280, 150),
        rotationDeg: 90,
        widthMeters: 0.4,
        depthMeters: 0.65,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _loadTemplateStandardRoom() {
    _recordSnapshotForUndo();
    setState(() {
      walls.clear();
      zones.clear();
      openings.clear();
      objects.clear();
      customDimensions.clear();

      final p1 = const Offset(120, 120);
      final p2 = const Offset(620, 120);
      final p3 = const Offset(620, 480);
      final p4 = const Offset(120, 480);

      walls.add(Wall(p1, p2, thicknessCm: 20));
      walls.add(Wall(p2, p3, thicknessCm: 20));
      walls.add(Wall(p3, p4, thicknessCm: 20));
      walls.add(Wall(p4, p1, thicknessCm: 20));

      openings.add(WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно',
        position: const Offset(370, 120),
        rotation: 0,
        widthMeters: 1.6,
      ));
      openings.add(WallOpening(
        type: OpeningType.door,
        subtypeName: 'Дверь',
        position: const Offset(120, 300),
        rotation: math.pi / 2,
        widthMeters: 0.9,
      ));

      objects.add(InteriorObject(
        category: 'bedroom',
        name: 'Кровать двуспальная',
        position: const Offset(470, 300),
        rotationDeg: 90,
        widthMeters: 1.8,
        depthMeters: 2.05,
      ));
      objects.add(InteriorObject(
        category: 'storage',
        name: 'Шкаф-купе',
        position: const Offset(280, 440),
        rotationDeg: 180,
        widthMeters: 1.8,
        depthMeters: 0.6,
      ));

      _rebuildAutoZonesFromWalls();
      _autoSaveCurrentProject();
    });
    _fitPlanToScreen();
  }

  void _showTemplatesModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDarkTheme ? const Color(0xFF38383C) : const Color(0xFFE2E8F0)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF0D99FF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Готовые шаблоны планировок',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Выберите типовой проект с чертежами стен, проёмов и расстановкой мебели',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkTheme ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: isDarkTheme ? Colors.white60 : Colors.black54),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(680.0, MediaQuery.of(ctx).size.width - 32),
          height: math.min(560.0, MediaQuery.of(ctx).size.height * 0.8),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildTemplateCard(
                previewType: 'studio',
                title: 'Студия (32 м²)',
                areaBadge: '32 м²',
                desc: 'Компактное зонирование: прихожая с гардеробом, совмещённый санузел, кухонный фронт, обеденная зона и гостиная.',
                tags: const ['Студия', 'Кухня', 'Ванная', 'Диван'],
                color: const Color(0xFF0D99FF),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplateStudio();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'one_room',
                title: '1-комнатная квартира (45 м²)',
                areaBadge: '45 м²',
                desc: 'Изолированная мастер-спальня с гардеробом, просторная кухня-столовая, раздельный санузел и прихожая зона.',
                tags: const ['1 комната', 'Спальня', 'Кухня-столовая'],
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplate1Room();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'two_room',
                title: '2-комнатная / Евро-трешка (68 м²)',
                areaBadge: '68 м²',
                desc: 'Мастер-спальня, кабинет/детская комната, большая кухня-гостиная с ТВ-зоной, раздельный санузел.',
                tags: const ['2 спальни', 'Евро-3', 'Гостиная', 'Семейная'],
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplate2Room();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'kitchen_living',
                title: 'Кухня-гостиная с островом (31.5 м²)',
                areaBadge: '31.5 м²',
                desc: 'Современный открытый open-space: большой кухонный гарнитур, остров с барной стойкой, обеденная группа и лаунж-диван.',
                tags: const ['Кухня', 'Остров', 'Open-space', 'ТВ-зона'],
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplateKitchenLiving();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'bathroom',
                title: 'Премиум санузел с ванной и душем (8.1 м²)',
                areaBadge: '8.1 м²',
                desc: 'Отдельно стоящая овальная ванна, душевая зона с прозрачной перегородкой, двойная подвесная тумба и инсталляция.',
                tags: const ['Ванна', 'Душ', 'Инсталляция', 'СПА'],
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplateBathroomLuxury();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'office',
                title: 'Рабочий кабинет / Офис (20.8 м²)',
                areaBadge: '20.8 м²',
                desc: 'Стол руководителя с креслом, библиотечные стеллажи, переговорная группа с мягким диваном и столиком.',
                tags: const ['Кабинет', 'Офис', 'Переговорная'],
                color: const Color(0xFFEC4899),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplateOffice();
                },
              ),
              const SizedBox(height: 10),
              _buildTemplateCard(
                previewType: 'bedroom',
                title: 'Спальня 5 × 3.6 м (18 м²)',
                areaBadge: '18 м²',
                desc: 'Базовый контур прямоугольной комнаты с двуспальной кроватью, прикроватным пространством и вместительным шкафом-купе.',
                tags: const ['Спальня', 'Быстрый старт'],
                color: const Color(0xFF6366F1),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTemplateStandardRoom();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard({
    required String previewType,
    required String title,
    required String areaBadge,
    required String desc,
    required List<String> tags,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool dark = isDarkTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF26262B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? const Color(0xFF38383E) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Чертежный предпросмотр плана
            TemplateThumbnail(type: previewType, width: 118, height: 78),
            const SizedBox(width: 14),
            // Описание шаблона
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: dark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Text(
                          areaBadge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: dark ? const Color(0xFFA1A1AA) : const Color(0xFF475569),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: dark ? const Color(0xFFD4D4D8) : const Color(0xFF334155),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Кнопка перехода
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Открыть',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetTierCard({
    required String title,
    required String rate,
    required String total,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(rate, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(total, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPropertyInspector({bool isMobile = false, double? maxWidth}) {
    // Hide inspector while dragging or moving to prevent obstructing view
    if (draggedOpening != null || draggedObject != null || draggedCornerOriginal != null || draggedElectricalItem != null || currentStart != null) {
      return const SizedBox.shrink();
    }
    if (selectedObject == null && selectedWall == null && selectedOpening == null && editingBoundaryZone == null && selectedDimension == null) {
      return const SizedBox.shrink();
    }
    final actualWidth = maxWidth ?? (isMobile ? (MediaQuery.of(context).size.width - 24) : 280.0);

    if (selectedDimension != null) {
      return Container(
        width: actualWidth,
        margin: EdgeInsets.only(top: isMobile ? 0 : 10, right: isMobile ? 0 : 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Размерная линия',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    selectedDimension = null;
                    selectedDimensions.clear();
                  }),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),
            Text(
              'Длина: ${formatLength(selectedDimension!.lengthInMeters)}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.25),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Удалить размер (Del)'),
                onPressed: () {
                  _recordSnapshotForUndo();
                  setState(() {
                    customDimensions.remove(selectedDimension);
                    selectedDimensions.remove(selectedDimension);
                    selectedDimension = null;
                    _autoSaveCurrentProject();
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: actualWidth,
      constraints: BoxConstraints(maxHeight: isMobile ? 260 : 480),
      margin: EdgeInsets.only(top: isMobile ? 0 : 10, right: isMobile ? 0 : 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selectedObject != null
                      ? Icons.chair_rounded
                      : selectedWall != null
                          ? Icons.view_column_rounded
                          : selectedOpening != null
                              ? (selectedOpening!.type == OpeningType.door ? Icons.door_front_door : Icons.window)
                              : Icons.crop_square_rounded,
                  color: const Color(0xFF38BDF8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedObject != null
                        ? selectedObject!.name
                        : selectedWall != null
                            ? 'Стена (${selectedWall!.lengthInMeters.toStringAsFixed(2)} м)'
                            : selectedOpening != null
                                ? selectedOpening!.subtypeName
                                : editingBoundaryZone!.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    selectedObject = null;
                    selectedWall = null;
                    selectedOpening = null;
                    editingBoundaryZone = null;
                  }),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),

            if (selectedObject != null) ...[
              const Text('Габариты (Ш × Г × В в метрах):', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildInspectorInput(
                      label: 'Ш (м)',
                      value: selectedObject!.widthMeters.toStringAsFixed(2),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.'));
                        if (val != null && val > 0.1) {
                          _recordSnapshotForUndo();
                          setState(() => selectedObject!.widthMeters = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildInspectorInput(
                      label: 'Г (м)',
                      value: selectedObject!.depthMeters.toStringAsFixed(2),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.'));
                        if (val != null && val > 0.1) {
                          _recordSnapshotForUndo();
                          setState(() => selectedObject!.depthMeters = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildInspectorInput(
                      label: 'В (м)',
                      value: selectedObject!.heightMeters.toStringAsFixed(2),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.'));
                        if (val != null && val > 0.1) {
                          _recordSnapshotForUndo();
                          setState(() => selectedObject!.heightMeters = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Секция текстуры / материала объекта
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF28282D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3E3E44)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.texture_rounded, color: Color(0xFF38BDF8), size: 16),
                            SizedBox(width: 6),
                            Text('Материал / Текстура:', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (selectedObject!.textureId != null)
                          GestureDetector(
                            onTap: () {
                              _recordSnapshotForUndo();
                              setState(() {
                                selectedObject!.textureId = null;
                                _autoSaveCurrentProject();
                              });
                            },
                            child: const Text('Сбросить', style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => activeDockFlyout = ActiveDockFlyout.textures),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF4A4A52)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: const Color(0xFF334155),
                                border: Border.all(color: Colors.white24),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: selectedObject!.textureId != null && _resolveTextureImage(selectedObject!.textureId, _loadedImages) != null
                                  ? CustomPaint(
                                      painter: _SingleTexturePreviewPainter(image: _resolveTextureImage(selectedObject!.textureId, _loadedImages)!),
                                    )
                                  : const Icon(Icons.style_outlined, color: Colors.white60, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedObject!.textureId != null
                                        ? (kTextureItemDisplayNamesRu[selectedObject!.textureId!.split('/').last] ??
                                           kTextureItemDisplayNamesRu[selectedObject!.textureId!.split('/').last.replaceAll('.jpg', '')] ??
                                           selectedObject!.textureId!.split('/').last)
                                        : 'Базовый цвет (нажмите для выбора)',
                                    style: TextStyle(
                                      color: selectedObject!.textureId != null ? Colors.white : Colors.white60,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedObject!.textureId != null ? 'Нажмите, чтобы сменить' : 'Дерево, кожа, ткань, металл',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Поворот:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('${selectedObject!.rotationDeg.round()}°', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickRotateBtn('-90°', -90),
                  _buildQuickRotateBtn('-45°', -45),
                  _buildQuickRotateBtn('+45°', 45),
                  _buildQuickRotateBtn('+90°', 90),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        _recordSnapshotForUndo();
                        setState(() {
                          final copy = InteriorObject(
                            category: selectedObject!.category,
                            name: selectedObject!.name,
                            position: selectedObject!.position + const Offset(30, 30),
                            widthMeters: selectedObject!.widthMeters,
                            depthMeters: selectedObject!.depthMeters,
                            heightMeters: selectedObject!.heightMeters,
                            rotationDeg: selectedObject!.rotationDeg,
                            textureId: selectedObject!.textureId,
                            model3dPath: selectedObject!.model3dPath,
                            previewImagePath: selectedObject!.previewImagePath,
                          );
                          objects.add(copy);
                          selectedObject = copy;
                          _autoSaveCurrentProject();
                        });
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Копия', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        _recordSnapshotForUndo();
                        setState(() {
                          objects.remove(selectedObject);
                          selectedObject = null;
                          _autoSaveCurrentProject();
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Удалить', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ] else if (selectedElectricalItem != null) ...[
              _buildElectricalInspectorContent(),
            ] else if (selectedWall != null) ...[
              Text('Длина стены: ${formatLength(selectedWall!.lengthInMeters)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Внутренний размер: ${formatLength(_getWallInternalLength(selectedWall!))}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF28282D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3E3E44)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.layers_rounded, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 6),
                            Text('Слои отделки (пирог):', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          '+${(selectedWall!.totalLayersThicknessCm * 10).round()} мм',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Фактическая толщина: ${(selectedWall!.totalEffectiveThicknessCm * 10).round()} мм (основа: ${formatCm(selectedWall!.thicknessCm)})',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final idx = walls.indexOf(selectedWall!);
                          if (idx != -1) _showEditWallDialog(idx);
                        },
                        icon: const Icon(Icons.edit_road, size: 15),
                        label: const Text('Настроить слои (пирог)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Толщина перегородки:', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 6),
              // Текстура стены в инспекторе
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF28282D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3E3E44)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wallpaper_rounded, color: Color(0xFF38BDF8), size: 16),
                            SizedBox(width: 6),
                            Text('Материал стены:', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (selectedWall!.textureSideA != null || selectedWall!.textureSideB != null)
                          GestureDetector(
                            onTap: () {
                              _recordSnapshotForUndo();
                              setState(() {
                                selectedWall!.textureSideA = null;
                                selectedWall!.textureSideB = null;
                                _autoSaveCurrentProject();
                              });
                            },
                            child: const Text('Сбросить', style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => activeDockFlyout = ActiveDockFlyout.textures),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF4A4A52)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: const Color(0xFF334155),
                                border: Border.all(color: Colors.white24),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (selectedWall!.textureSideA != null || selectedWall!.textureSideB != null) &&
                                      _resolveTextureImage(selectedWall!.textureSideA ?? selectedWall!.textureSideB, _loadedImages) != null
                                  ? CustomPaint(
                                      painter: _SingleTexturePreviewPainter(
                                          image: _resolveTextureImage(selectedWall!.textureSideA ?? selectedWall!.textureSideB, _loadedImages)!),
                                    )
                                  : const Icon(Icons.format_paint_outlined, color: Colors.white60, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (selectedWall!.textureSideA ?? selectedWall!.textureSideB) != null
                                    ? (kTextureItemDisplayNamesRu[(selectedWall!.textureSideA ?? selectedWall!.textureSideB)!.split('/').last] ??
                                       'Текстура применена')
                                    : 'Выбрать материал (кирпич, бетон, штукатурка)',
                                style: TextStyle(
                                  color: (selectedWall!.textureSideA ?? selectedWall!.textureSideB) != null ? Colors.white : Colors.white60,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [10.0, 15.0, 20.0, 25.0, 38.0].map((th) {
                  final sel = (selectedWall!.thicknessCm - th).abs() < 1;
                  return ChoiceChip(
                    label: Text('${th.round()} см', style: const TextStyle(fontSize: 11)),
                    selected: sel,
                    onSelected: (_) {
                      _recordSnapshotForUndo();
                      setState(() {
                        selectedWall!.thicknessCm = th;
                        _autoSaveCurrentProject();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () {
                    _recordSnapshotForUndo();
                    setState(() {
                      walls.remove(selectedWall);
                      selectedWall = null;
                      _rebuildAutoZonesFromWalls();
                      _autoSaveCurrentProject();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Удалить стену'),
                ),
              ),
            ] else if (selectedOpening != null) ...[
              Text('Тип: ${selectedOpening!.type == OpeningType.door ? "Дверь" : "Окно"}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ширина проема:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('${(selectedOpening!.widthMeters * 100).round()} см', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Slider(
                value: selectedOpening!.widthMeters,
                min: 0.6,
                max: 3.0,
                divisions: 24,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (v) {
                  setState(() => selectedOpening!.widthMeters = v);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () {
                    _recordSnapshotForUndo();
                    setState(() {
                      openings.remove(selectedOpening);
                      selectedOpening = null;
                      _autoSaveCurrentProject();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Удалить проем'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRotateBtn(String label, double deltaDeg) {
    return InkWell(
      onTap: () {
        _recordSnapshotForUndo();
        setState(() {
          selectedObject!.rotationDeg = (selectedObject!.rotationDeg + deltaDeg) % 360.0;
          if (selectedObject!.rotationDeg < 0) selectedObject!.rotationDeg += 360.0;
          _autoSaveCurrentProject();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInspectorInput({required String label, required String value, required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: value,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF38BDF8)), borderRadius: BorderRadius.circular(6)),
      ),
      onFieldSubmitted: onChanged,
    );
  }

  Widget _buildCompassWidget() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('N', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 10)),
          Icon(Icons.navigation, color: Colors.white70, size: 14),
          Text('S', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  void _showMobilePlanMetricsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkTheme ? const Color(0xFF242428) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Color(0xFF0D99FF), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Параметры плана',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildExplicationItem(
                  icon: Icons.crop_free_rounded,
                  label: 'Площадь пола (${zones.length} зон):',
                  value: '${totalZonesAreaSqM.toStringAsFixed(2)} м²',
                  color: const Color(0xFF34D399),
                ),
                const SizedBox(height: 10),
                _buildExplicationItem(
                  icon: Icons.straighten_rounded,
                  label: 'Периметр стен:',
                  value: '${totalPerimeter.toStringAsFixed(2)} м',
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 10),
                _buildExplicationItem(
                  icon: Icons.view_quilt_outlined,
                  label: 'Площадь стен (H=${wallHeightMeters.toStringAsFixed(1)}м):',
                  value: '${totalWallsAreaSqM.toStringAsFixed(1)} м²',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => showEstimateFlyout = true);
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Смета и расчёт', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Очистить чертёж?'),
          ],
        ),
        content: const Text(
          'Все стены, комнаты, проёмы, мебель и размеры будут удалены с холста.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _recordSnapshotForUndo();
              setState(() {
                walls.clear();
                zones.clear();
                openings.clear();
                objects.clear();
                electricalItems.clear();
                customDimensions.clear();
                editingBoundaryZone = null;
                selectedObject = null;
                selectedWall = null;
                selectedOpening = null;
                selectedDimension = null;
                selectedObjects.clear();
                selectedWalls.clear();
                selectedOpenings.clear();
                selectedDimensions.clear();
                _autoSaveCurrentProject();
              });
            },
            child: const Text('Очистить всё', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMenuButton() {
    return PopupMenuButton<String>(
      tooltip: 'Файл и экспорт',
      icon: Container(
        height: 32,
        width: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1)),
        ),
        child: Icon(Icons.folder_open_rounded, size: 18, color: isDarkTheme ? Colors.cyanAccent : const Color(0xFF0284C7)),
      ),
      color: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val == 'save') _exportProjectJsonFile();
        if (val == 'open') _importProjectJsonFile();
        if (val == 'pdf') _exportPlanAsVectorPdf();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save_outlined, color: Color(0xFF0284C7), size: 18),
              SizedBox(width: 10),
              Text('Сохранить проект (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open_outlined, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Text('Загрузить проект (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 10),
              Text('Экспорт в векторный PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePlanMetricsBtn(BuildContext context) {
    return InkWell(
      onTap: () => _showMobilePlanMetricsSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D99FF).withValues(alpha: isDarkTheme ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF0D99FF), width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF0D99FF), size: 15),
            const SizedBox(width: 4),
            Text(
              '${totalZonesAreaSqM.toStringAsFixed(1)} м²',
              style: const TextStyle(color: Color(0xFF0D99FF), fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF0D99FF), size: 15),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: is3DMode ? const Color(0xFF0F172A) : (isDarkTheme ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          final isMobile = constraints.maxWidth < 700;

          return Stack(
            children: [
              Listener(
                onPointerDown: (event) {
                  activePointers++;
                  if (activeDockFlyout != ActiveDockFlyout.none || showEstimateFlyout) {
                    setState(() {
                      activeDockFlyout = ActiveDockFlyout.none;
                      showEstimateFlyout = false;
                    });
                  }
                  if (event.buttons == kMiddleMouseButton) {
                    setState(() {
                      _isMiddleMousePanning = true;
                      _lastMiddleMousePos = event.localPosition;
                      draggedObject = null;
                      draggedOpening = null;
                      draggedCornerOriginal = null;
                      currentStart = null;
                      currentEnd = null;
                    });
                  }
                },
                onPointerMove: (event) {
                  if (_isMiddleMousePanning || event.buttons == kMiddleMouseButton) {
                    final prev = _lastMiddleMousePos ?? event.localPosition;
                    final delta = event.localPosition - prev;
                    _lastMiddleMousePos = event.localPosition;
                    setState(() {
                      if (is3DMode) {
                        cameraPan3D += delta;
                      } else {
                        canvasOffset += delta;
                      }
                    });
                  }
                },
                onPointerUp: (_) {
                  activePointers = math.max(0, activePointers - 1);
                  _isMiddleMousePanning = false;
                  _lastMiddleMousePos = null;
                  _stopAutoPan();
                },
                onPointerCancel: (_) {
                  activePointers = math.max(0, activePointers - 1);
                  _isMiddleMousePanning = false;
                  _lastMiddleMousePos = null;
                  _stopAutoPan();
                },
                onPointerHover: (event) {
                  if (selectedTool == EditorTool.drawDimension && !is3DMode) {
                    final worldPos = _screenToWorld(event.localPosition);
                    setState(() {
                      _snapPoint(worldPos, allowOrtho: false, preferWallFaces: true);
                    });
                  } else if (pendingElectricalPreset != null && !is3DMode) {
                    final worldPos = _screenToWorld(event.localPosition);
                    setState(() {
                      currentElectricalPreviewPos = worldPos;
                    });
                  }
                },
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    if (is3DMode) {
                      setState(() {
                        cameraZoom3D = (cameraZoom3D * (event.scrollDelta.dy < 0 ? 1.12 : 0.89)).clamp(0.25, 3.8);
                      });
                    } else {
                      final newScale = (canvasScale * (event.scrollDelta.dy < 0 ? 1.12 : 0.89)).clamp(0.25, 4.0);
                      final worldFocal = _screenToWorld(event.localPosition);
                      setState(() {
                        canvasScale = newScale;
                        canvasOffset = event.localPosition - worldFocal * canvasScale;
                      });
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _onTapCanvas(details.localPosition),
                  onScaleStart: (details) {
                    if (_isMiddleMousePanning) return;

                    if (is3DMode) {
                      _last3DPointerPos = details.localFocalPoint;
                      _baseScale = cameraZoom3D;
                      return;
                    }

                    _hasMovedDraggedItem = false;
                    if (showWallThicknessSlider) {
                      setState(() => showWallThicknessSlider = false);
                    }

                    _baseScale = canvasScale;
                    _baseFocalPoint = details.localFocalPoint;
                    _baseCanvasOffset = canvasOffset;
                    if (details.pointerCount >= 2 || activePointers >= 2) return;

                    final worldPos = _screenToWorld(details.localFocalPoint);

                    if (editingBoundaryZone != null) {
                      for (int i = 0; i < editingBoundaryZone!.polygon.length; i++) {
                        if ((editingBoundaryZone!.polygon[i] - worldPos).distance < 28.0 / canvasScale) {
                          _recordSnapshotForUndo();
                          draggedZoneVertexIndex = i;
                          return;
                        }
                      }
                    }

                    if (selectedTool == EditorTool.drawWall ||
                        selectedTool == EditorTool.drawRoomBox ||
                        selectedTool == EditorTool.drawDimension) {
                      setState(() {
                        currentStart = _snapPoint(
                          worldPos,
                          allowOrtho: false,
                          preferWallFaces: selectedTool == EditorTool.drawDimension,
                        );
                        currentEnd = currentStart;
                      });
                    } else if (selectedTool == EditorTool.wallDimensions) {
                      for (int i = 0; i < walls.length; i++) {
                        final w = walls[i];
                        final dim = computeWallFaceDimension(w, walls, zones);
                        if ((worldPos - dim.badgePos).distance < 36.0 / canvasScale ||
                            (worldPos - (dim.innerStart + dim.innerEnd) / 2).distance < 36.0 / canvasScale) {
                          _showQuickClearDimensionDialog(i, dim);
                          return;
                        }
                      }
                    } else if (selectedTool == EditorTool.overview) {
                      if (showElectricalLayer) {
                        for (final item in electricalItems.reversed) {
                          if ((item.position - worldPos).distance < 24.0 / canvasScale) {
                            _recordSnapshotForUndo();
                            setState(() {
                              draggedElectricalItem = item;
                              selectedElectricalItem = item;
                              if (!selectedElectricalItems.contains(item)) {
                                selectedElectricalItems.clear();
                                selectedElectricalItems.add(item);
                              }
                              selectedObject = null;
                              selectedWall = null;
                              selectedOpening = null;
                              selectedDimension = null;
                            });
                            return;
                          }
                        }
                      }
                      for (final op in openings.reversed) {
                        if ((op.position - worldPos).distance < math.max(op.widthMeters * 50, 28 / canvasScale)) {
                          _recordSnapshotForUndo();
                          setState(() {
                            draggedOpening = op;
                            selectedOpening = op;
                            selectedObject = null;
                            selectedWall = null;
                          });
                          return;
                        }
                      }
                      for (final obj in objects.reversed) {
                        if ((obj.position - worldPos).distance < math.max(obj.widthMeters, obj.depthMeters) * 50) {
                          _recordSnapshotForUndo();
                          setState(() {
                            draggedObject = obj;
                            selectedObject = obj;
                            selectedOpening = null;
                            selectedWall = null;
                          });
                          return;
                        }
                      }
                      for (final w in walls) {
                        if ((w.start - worldPos).distance < 28.0 / canvasScale) {
                          _recordSnapshotForUndo();
                          draggedCornerOriginal = w.start;
                          return;
                        }
                        if ((w.end - worldPos).distance < 28.0 / canvasScale) {
                          _recordSnapshotForUndo();
                          draggedCornerOriginal = w.end;
                          return;
                        }
                      }
                      if (showElectricalLayer && showSocketDimensions) {
                        for (final item in electricalItems) {
                          final binding = _getElectricalWallBinding(item, walls, canvasScale);
                          if (binding != null && (binding.badgeCenter - worldPos).distance < 24.0 / canvasScale) {
                            return;
                          }
                        }
                      }
                      // Start Marquee Selection if clicking on empty canvas
                      setState(() {
                        if (!HardwareKeyboard.instance.isShiftPressed) {
                          selectedObjects.clear();
                          selectedWalls.clear();
                          selectedOpenings.clear();
                          selectedDimensions.clear();
                          selectedElectricalItems.clear();
                          selectedObject = null;
                          selectedWall = null;
                          selectedOpening = null;
                          selectedDimension = null;
                          selectedElectricalItem = null;
                        }
                        _selectionMarqueeStart = worldPos;
                        selectionMarquee = Rect.fromPoints(worldPos, worldPos);
                      });
                    }
                  },
                  onScaleUpdate: (details) {
                    if (_isMiddleMousePanning) return;

                    if (is3DMode) {
                      if (details.pointerCount >= 2) {
                        setState(() {
                          cameraZoom3D = (_baseScale * details.scale).clamp(0.25, 3.8);
                        });
                      } else if (_last3DPointerPos != null) {
                        final delta = details.localFocalPoint - _last3DPointerPos!;
                        _last3DPointerPos = details.localFocalPoint;
                        setState(() {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            cameraPan3D += delta;
                          } else {
                            cameraYaw += delta.dx * 0.0085;
                            cameraPitch = (cameraPitch + delta.dy * 0.0065).clamp(0.18, 1.48);
                          }
                        });
                      }
                      return;
                    }

                    if (details.pointerCount >= 2 || activePointers >= 2) {
                      _stopAutoPan();
                      setState(() {
                        currentStart = null;
                        currentEnd = null;
                        canvasScale = (_baseScale * details.scale).clamp(0.25, 4.0);
                        canvasOffset = details.localFocalPoint - ((_baseFocalPoint - _baseCanvasOffset) / _baseScale) * canvasScale;
                      });
                      return;
                    }

                    final screenPos = details.localFocalPoint;
                    final worldPos = _screenToWorld(screenPos);

                    if (editingBoundaryZone != null && draggedZoneVertexIndex != null) {
                      _startOrUpdateAutoPan(screenPos);
                      setState(() {
                        editingBoundaryZone!.polygon[draggedZoneVertexIndex!] = _snapPoint(worldPos, allowOrtho: false);
                        editingBoundaryZone!.isManuallyAdjusted = true;
                      });
                      return;
                    }

                    if ((selectedTool == EditorTool.drawWall || selectedTool == EditorTool.drawDimension) &&
                        currentStart != null) {
                      _startOrUpdateAutoPan(screenPos);
                      setState(() => currentEnd = _snapPoint(
                        worldPos,
                        referenceStart: currentStart,
                        allowOrtho: true,
                        preferWallFaces: selectedTool == EditorTool.drawDimension,
                      ));
                    } else if (selectedTool == EditorTool.drawRoomBox && currentStart != null) {
                      _startOrUpdateAutoPan(screenPos);
                      setState(() => currentEnd = _snapPoint(worldPos, allowOrtho: false));
                    } else if (selectedTool == EditorTool.overview) {
                      if (draggedOpening != null) {
                        _hasMovedDraggedItem = true;
                        setState(() => _snapOpeningToNearestWall(draggedOpening!, worldPos));
                      } else if (draggedObject != null) {
                        _hasMovedDraggedItem = true;
                        final step = snapConfig.gridStepCm;
                        setState(() => draggedObject!.position = snapConfig.snapToGrid
                            ? Offset((worldPos.dx / step).round() * step, (worldPos.dy / step).round() * step)
                            : worldPos);
                      } else if (draggedElectricalItem != null) {
                        if (draggedElectricalItem!.type == ElectricalType.light) {
                          final step = snapConfig.gridStepCm;
                          setState(() => draggedElectricalItem!.position = snapConfig.snapToGrid
                              ? Offset((worldPos.dx / step).round() * step, (worldPos.dy / step).round() * step)
                              : worldPos);
                        } else {
                          final snapRes = _snapElectricalToWall(worldPos, draggedElectricalItem!.type, walls, snapToGrid: snapConfig.snapToGrid, gridStepCm: snapConfig.gridStepCm);
                          setState(() {
                            draggedElectricalItem!.position = snapRes.pos;
                            draggedElectricalItem!.rotationDeg = snapRes.angleDeg;
                          });
                        }
                      } else if (draggedCornerOriginal != null) {
                        _startOrUpdateAutoPan(screenPos);
                        setState(() {
                          final nc = _snapPoint(worldPos, ignorePoint: draggedCornerOriginal);
                          _moveConnectedCorner(draggedCornerOriginal!, nc);
                          draggedCornerOriginal = nc;
                        });
                      } else if (_selectionMarqueeStart != null) {
                        setState(() {
                          isMarqueeLeftToRight = worldPos.dx >= _selectionMarqueeStart!.dx;
                          selectionMarquee = Rect.fromPoints(_selectionMarqueeStart!, worldPos);
                        });
                      } else {
                        setState(() => canvasOffset = _baseCanvasOffset + (screenPos - _baseFocalPoint));
                      }
                    }
                  },
                  onScaleEnd: (details) {
                    _last3DPointerPos = null;
                    if (is3DMode) return;
                    _stopAutoPan();
                    setState(() {
                      _finishDrawingShape();
                      if (draggedOpening != null || draggedObject != null || draggedCornerOriginal != null || draggedElectricalItem != null) {
                        _autoSaveCurrentProject();
                        draggedElectricalItem = null;
                      }
                      if (draggedOpening != null && _hasMovedDraggedItem) {
                        selectedOpening = null;
                      }
                      if (draggedObject != null && _hasMovedDraggedItem) {
                        selectedObject = null;
                      }
                      if (selectionMarquee != null && selectionMarquee!.width > 12 && selectionMarquee!.height > 12) {
                        for (final obj in objects) {
                          final objRect = Rect.fromCenter(
                            center: obj.position,
                            width: obj.widthMeters * 100,
                            height: obj.depthMeters * 100,
                          );
                          if (selectionMarquee!.overlaps(objRect)) {
                            selectedObjects.add(obj);
                          }
                        }
                        // Размерные линии попадают под рамку выделения
                        for (final dim in customDimensions) {
                          if (_segmentIntersectsRect(dim.start, dim.end, selectionMarquee!)) {
                            selectedDimensions.add(dim);
                          }
                        }
                        // Электрические компоненты попадают под рамку выделения
                        if (showElectricalLayer) {
                          for (final eItem in electricalItems) {
                            if (selectionMarquee!.contains(eItem.position) ||
                                selectionMarquee!.inflate(12.0 / canvasScale).contains(eItem.position)) {
                              selectedElectricalItems.add(eItem);
                            }
                          }
                        }
                        // Слева направо: выделяется всё (стены, мебель, двери/окна, размеры, электрика).
                        // Справа налево: выделяются мебель, размеры, электрика.
                        if (isMarqueeLeftToRight) {
                          for (final w in walls) {
                            if (selectionMarquee!.contains(w.start) ||
                                selectionMarquee!.contains(w.end) ||
                                _segmentIntersectsRect(w.start, w.end, selectionMarquee!)) {
                              selectedWalls.add(w);
                            }
                          }
                          for (final op in openings) {
                            final opRect = Rect.fromCenter(
                              center: op.position,
                              width: op.widthMeters * 100.0,
                              height: op.depthCm + 14.0,
                            );
                            if (selectionMarquee!.overlaps(opRect)) {
                              selectedOpenings.add(op);
                            }
                          }
                        }
                        if (selectedObjects.length == 1 && selectedWalls.isEmpty && selectedDimensions.isEmpty && selectedElectricalItems.isEmpty) {
                          selectedObject = selectedObjects.first;
                        } else if (selectedDimensions.length == 1 && selectedObjects.isEmpty && selectedWalls.isEmpty && selectedElectricalItems.isEmpty) {
                          selectedDimension = selectedDimensions.first;
                        } else if (selectedElectricalItems.length == 1 && selectedObjects.isEmpty && selectedWalls.isEmpty && selectedDimensions.isEmpty) {
                          selectedElectricalItem = selectedElectricalItems.first;
                        }
                      }
                      _selectionMarqueeStart = null;
                      selectionMarquee = null;
                      currentStart = null;
                      currentEnd = null;
                      draggedCornerOriginal = null;
                      draggedOpening = null;
                      draggedObject = null;
                      draggedZoneVertexIndex = null;
                      snappedPointHighlight = null;
                      activeGreenGuides.clear();
                    });
                  },
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: is3DMode
                          ? Isometric3DPlanPainter(
                              walls: walls,
                              zones: zones,
                              openings: openings,
                              objects: objects,
                              loadedImages: _loadedImages,
                              loaded3DMeshes: _loaded3DMeshes,
                              selectedWall: selectedWall,
                              selectedWallSide: selectedWallSide,
                              selectedObject: selectedObject,
                              wallViewMode: wallViewMode3D,
                              wallHitPolygonsOut: _last3DWallHitPolygons,
                              wallHeightMeters: wallHeightMeters *
                                  CurvedAnimation(parent: _wallRiseController, curve: Curves.easeOutCubic).value,
                              yaw: cameraYaw,
                              pitch: cameraPitch,
                              zoom: cameraZoom3D,
                              panOffset: cameraPan3D,
                              showZonesLayer: showZonesLayer,
                            )
                          : GridAndWallsPainter(
                              isDarkTheme: isDarkTheme,
                              showGrid: showGrid,
                              walls: walls,
                              selectedObjects: selectedObjects,
                              selectedWalls: selectedWalls,
                              selectedOpenings: selectedOpenings,
                              selectedDimensions: selectedDimensions,
                              selectedDimension: selectedDimension,
                              selectedElectricalItems: selectedElectricalItems,
                              selectionMarquee: selectionMarquee,
                              isMarqueeLeftToRight: isMarqueeLeftToRight,
                              zones: zones,
                              editingBoundaryZone: editingBoundaryZone,
                              openings: openings,
                              objects: objects,
                              customDimensions: customDimensions,
                              selectedObject: selectedObject,
                              selectedWall: selectedWall,
                              selectedOpening: selectedOpening,
                              canvasOffset: canvasOffset,
                              canvasScale: canvasScale,
                              selectedTool: selectedTool,
                              currentStart: currentStart,
                              currentEnd: currentEnd,
                              currentThicknessCm: currentThicknessCm,
                              snappedPointHighlight: snappedPointHighlight,
                              greenGuides: activeGreenGuides,
                              loadedImages: _loadedImages,
                              unitFormat: currentUnit,
                              electricalItems: electricalItems,
                              selectedElectricalItem: selectedElectricalItem,
                              showFurnitureLayer: showFurnitureLayer,
                              showElectricalLayer: showElectricalLayer,
                              showDimensionsLayer: showDimensionsLayer,
                              showZonesLayer: showZonesLayer,
                              showElectricalLabels: showElectricalLabels,
                              showSocketDimensions: showSocketDimensions,
                              showLightDimensions: showLightDimensions,
                              pendingElectricalPreset: pendingElectricalPreset,
                              currentElectricalPreviewPos: currentElectricalPreviewPos,
                            ),
                    ),
                  ),
                ),
              ),

              // А) ВЕРТИКАЛЬНАЯ ПАРЯЩАЯ ПАНЕЛЬ ВВЕРХУ СЛЕВА (Метрики, Площади, Периметр, Стены, Смета)
              // ПАРЯЩАЯ ПАНЕЛЬ СМЕТЫ И СПЕЦИФИКАЦИИ (рядом с окном параметров плана)
              if (showEstimateFlyout && !is3DMode)
                Align(
                  alignment: isMobile ? Alignment.topCenter : Alignment.topLeft,
                  child: SafeArea(
                    child: Container(
                      width: isMobile ? (constraints.maxWidth - 20) : 380,
                      constraints: BoxConstraints(maxHeight: isMobile ? (constraints.maxHeight * 0.72) : 460),
                      margin: EdgeInsets.only(left: isMobile ? 10 : 236, right: isMobile ? 10 : 0, top: isMobile ? 48 : 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? const Color(0xFF222226).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 4))],
                      ),
                      child: _buildEstimateFlyoutContent(),
                    ),
                  ),
                ),

              if (!isMobile)
                Align(
                  alignment: Alignment.topLeft,
                  child: SafeArea(
                    child: Container(
                      width: 215,
                      margin: const EdgeInsets.only(left: 14, top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkTheme ? const Color(0xFF242428).withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDarkTheme ? const Color(0xFF38383E) : const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Color(0xFF0D99FF), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Параметры плана',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildExplicationItem(
                          icon: Icons.crop_free_rounded,
                          label: 'Площадь пола (${zones.length} зон):',
                          value: '${totalZonesAreaSqM.toStringAsFixed(2)} м²',
                          color: const Color(0xFF34D399),
                        ),
                        const SizedBox(height: 7),
                        _buildExplicationItem(
                          icon: Icons.straighten_rounded,
                          label: 'Периметр стен:',
                          value: '${totalPerimeter.toStringAsFixed(2)} м',
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(height: 7),
                        _buildExplicationItem(
                          icon: Icons.view_quilt_outlined,
                          label: 'Площадь стен (H=${wallHeightMeters.toStringAsFixed(1)}м):',
                          value: '${totalWallsAreaSqM.toStringAsFixed(1)} м²',
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => setState(() => showEstimateFlyout = !showEstimateFlyout),
                            icon: const Icon(Icons.calculate_outlined, size: 16),
                            label: const Text('Смета и расчёт', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ПЛАВАЮЩИЙ БАННЕР РЕЖИМА "ПРОИЗВОЛЬНАЯ ПЛАНИРОВКА"
              if (isCustomSketchMode)
                _buildCustomSketchOverlayBanner(),

              // ПАРЯЩИЕ ОКНА НАСТРОЕК И ФИЛЬТРОВ СЛОЁВ
              if (showFilterFlyout && !is3DMode)
                Align(
                  alignment: isMobile ? Alignment.topCenter : Alignment.topRight,
                  child: SafeArea(
                    child: Container(
                      width: isMobile ? (constraints.maxWidth - 20) : 340,
                      constraints: BoxConstraints(maxHeight: isMobile ? (constraints.maxHeight * 0.75) : 580),
                      margin: EdgeInsets.only(right: isMobile ? 10 : 60, left: isMobile ? 10 : 0, top: isMobile ? 48 : 56),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? const Color(0xFF222226).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 4))],
                      ),
                      child: SingleChildScrollView(child: _buildFilterFlyoutContent()),
                    ),
                  ),
                ),

              if (showSettingsFlyout && !is3DMode)
                Align(
                  alignment: isMobile ? Alignment.topCenter : Alignment.topRight,
                  child: SafeArea(
                    child: Container(
                      width: isMobile ? (constraints.maxWidth - 20) : 380,
                      constraints: BoxConstraints(maxHeight: isMobile ? (constraints.maxHeight * 0.72) : 560),
                      margin: EdgeInsets.only(right: isMobile ? 10 : 20, left: isMobile ? 10 : 0, top: isMobile ? 48 : 56),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? const Color(0xFF222226).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 4))],
                      ),
                      child: SingleChildScrollView(child: _buildSettingsFlyoutContent()),
                    ),
                  ),
                ),

              // Б) ТОНКАЯ ПАРЯЩАЯ ПАНЕЛЬ СВЕРХУ (Undo, Redo, Save, Load, PDF, Fit, Grid, Theme, Clear)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Container(
                    margin: EdgeInsets.only(left: isMobile ? 8 : 240, right: isMobile ? 8 : 14, top: isMobile ? 4 : 10),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDarkTheme ? const Color(0xFF2C2C2E).withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E42) : const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMobile) ...[
                            _buildMobilePlanMetricsBtn(context),
                            _buildTopBarDivider(),
                          ],
                          // Отменить (Undo)
                          Container(
                            height: 32,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _undoStack.isEmpty
                                  ? (isDarkTheme ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC))
                                  : (isDarkTheme ? const Color(0xFFF59E0B).withValues(alpha: 0.25) : const Color(0xFFFEF3C7)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _undoStack.isEmpty
                                    ? (isDarkTheme ? Colors.white10 : const Color(0xFFE2E8F0))
                                    : (isDarkTheme ? const Color(0xFFFBBF24).withValues(alpha: 0.8) : const Color(0xFFF59E0B)),
                                width: 1.1,
                              ),
                            ),
                            child: IconButton(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Отменить действие (Ctrl+Z)',
                              icon: Icon(
                                Icons.undo_rounded,
                                size: 19,
                                color: _undoStack.isEmpty
                                    ? (isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1))
                                    : (isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                              ),
                              onPressed: _undoStack.isEmpty ? null : _undo,
                            ),
                          ),
                          // Повторить (Redo)
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: _redoStack.isEmpty
                                  ? (isDarkTheme ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC))
                                  : (isDarkTheme ? const Color(0xFFF59E0B).withValues(alpha: 0.25) : const Color(0xFFFEF3C7)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _redoStack.isEmpty
                                    ? (isDarkTheme ? Colors.white10 : const Color(0xFFE2E8F0))
                                    : (isDarkTheme ? const Color(0xFFFBBF24).withValues(alpha: 0.8) : const Color(0xFFF59E0B)),
                                width: 1.1,
                              ),
                            ),
                            child: IconButton(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Повторить действие (Ctrl+Y)',
                              icon: Icon(
                                Icons.redo_rounded,
                                size: 19,
                                color: _redoStack.isEmpty
                                    ? (isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1))
                                    : (isDarkTheme ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                              ),
                              onPressed: _redoStack.isEmpty ? null : _redo,
                            ),
                          ),
                          _buildTopBarDivider(),
                          _buildFileMenuButton(),
                          _buildTopBarDivider(),
                          IconButton(
                            tooltip: 'Умная раскладка плитки и калькулятор',
                            icon: Icon(
                              Icons.grid_view_rounded,
                              color: isDarkTheme ? Colors.tealAccent : const Color(0xFF0D9488),
                              size: 19,
                            ),
                            onPressed: () => _openTileLayoutStudio(),
                          ),
                          IconButton(
                            tooltip: 'Вписать весь чертёж в экран',
                            icon: Icon(
                              Icons.fit_screen_rounded,
                              color: isDarkTheme ? Colors.lightGreenAccent : const Color(0xFF16A34A),
                              size: 19,
                            ),
                            onPressed: _fitPlanToScreen,
                          ),
                          _buildTopBarDivider(),
                          IconButton(
                            tooltip: 'Фильтры и видимость слоёв (мебель, электрика, размеры)',
                            icon: Icon(
                              Icons.layers_outlined,
                              color: showFilterFlyout
                                  ? (isDarkTheme ? Colors.cyanAccent : const Color(0xFF0284C7))
                                  : (showFurnitureLayer && showElectricalLayer && showDimensionsLayer && showZonesLayer
                                      ? (isDarkTheme ? Colors.white70 : const Color(0xFF334155))
                                      : (isDarkTheme ? Colors.amberAccent : const Color(0xFFD97706))),
                              size: 19,
                            ),
                            onPressed: () => setState(() {
                              showFilterFlyout = !showFilterFlyout;
                              showSettingsFlyout = false;
                            }),
                          ),
                          IconButton(
                            tooltip: 'Настройки САПР (единицы мм/м, сетка, стены)',
                            icon: Icon(
                              Icons.settings_outlined,
                              color: showSettingsFlyout
                                  ? (isDarkTheme ? Colors.cyanAccent : const Color(0xFF0284C7))
                                  : (isDarkTheme ? Colors.white70 : const Color(0xFF334155)),
                              size: 19,
                            ),
                            onPressed: () => setState(() {
                              showSettingsFlyout = !showSettingsFlyout;
                              showFilterFlyout = false;
                            }),
                          ),
                          _buildTopBarDivider(),
                          IconButton(
                            tooltip: 'Очистить всё',
                            icon: Icon(
                              Icons.delete_sweep_outlined,
                              color: isDarkTheme ? Colors.redAccent : const Color(0xFFDC2626),
                              size: 19,
                            ),
                            onPressed: () => _confirmClearAll(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ВЕРТИКАЛЬНЫЙ ПОЛЗУНОК ТОЛЩИНЫ СТЕНЫ ПРИ РИСОВАНИИ СТЕН (скрывается после выбора)
              if (selectedTool == EditorTool.drawWall && showWallThicknessSlider && !is3DMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isDarkTheme ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1), width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D99FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${currentThicknessCm.round()} см',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() => showWallThicknessSlider = false),
                                child: const Icon(Icons.close, size: 16, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            width: 36,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                                ),
                                child: Slider(
                                  value: currentThicknessCm,
                                  min: 5,
                                  max: 50,
                                  divisions: 45,
                                  activeColor: const Color(0xFF0D99FF),
                                  onChanged: (v) => setState(() => currentThicknessCm = v),
                                  onChangeEnd: (v) => setState(() => showWallThicknessSlider = false),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(() => showWallThicknessSlider = false),
                            child: const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF0D99FF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // В) 3D VIEW-CUBE В ЛЕВОМ НИЖНЕМ УГЛУ
              Align(
                alignment: Alignment.bottomLeft,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isMobile ? 12 : 18,
                      bottom: isMobile ? ((selectedObject != null || selectedWall != null || selectedOpening != null || editingBoundaryZone != null || selectedDimension != null) ? 270 : 68) : 18,
                    ),
                    child: _CadViewCubeButton(
                      is3DMode: is3DMode,
                      onTap: _toggle3DMode,
                    ),
                  ),
                ),
              ),

              if (editingBoundaryZone != null && !is3DMode)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.only(top: 60),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Корректировка «»: тяните зеленые точки',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () => setState(() => editingBoundaryZone = null),
                            child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Align(
                alignment: isMobile ? Alignment.bottomCenter : Alignment.topRight,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isMobile ? 0 : 80,
                      right: isMobile ? 0 : 14,
                      bottom: isMobile ? 66 : 0,
                    ),
                    child: _buildPropertyInspector(isMobile: isMobile, maxWidth: constraints.maxWidth - 20),
                  ),
                ),
              ),

              () {
                final totalMultiSelected = selectedObjects.length +
                    selectedWalls.length +
                    selectedOpenings.length +
                    selectedDimensions.length;
                if (totalMultiSelected > 1 || (totalMultiSelected >= 1 && selectedDimensions.isNotEmpty && selectedObject == null && selectedWall == null)) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.only(top: 75),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D99FF),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_box_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Выделено: $totalMultiSelected ${totalMultiSelected == 1 ? "элемент" : "элементов"}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 14),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                _recordSnapshotForUndo();
                                setState(() {
                                  objects.removeWhere((o) => selectedObjects.contains(o));
                                  walls.removeWhere((w) => selectedWalls.contains(w));
                                  openings.removeWhere((o) => selectedOpenings.contains(o));
                                  customDimensions.removeWhere((d) => selectedDimensions.contains(d));
                                  selectedObjects.clear();
                                  selectedWalls.clear();
                                  selectedOpenings.clear();
                                  selectedDimensions.clear();
                                  selectedObject = null;
                                  selectedWall = null;
                                  selectedOpening = null;
                                  selectedDimension = null;
                                  _rebuildAutoZonesFromWalls();
                                  _autoSaveCurrentProject();
                                });
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Удалить (Del)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: () => setState(() {
                                selectedObjects.clear();
                                selectedWalls.clear();
                                selectedOpenings.clear();
                                selectedDimensions.clear();
                                selectedDimension = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }(),

              if (!isMobile)
                Align(
                  alignment: Alignment.bottomRight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14, bottom: 80),
                      child: FloatingActionButton.extended(
                        heroTag: 'shortcuts_btn',
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      onPressed: _showKeyboardShortcutsModal,
                      icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                      label: const Text('Клавиши', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedObject != null) ...[
                        const SizedBox(height: 10),
                        FloatingActionButton.small(
                          heroTag: 'rot_obj_btn',
                          tooltip: 'Повернуть мебель на 45° (R)',
                          backgroundColor: const Color(0xFF0D99FF),
                          foregroundColor: Colors.white,
                          onPressed: () {
                            _recordSnapshotForUndo();
                            setState(() {
                              selectedObject!.rotationDeg = (selectedObject!.rotationDeg + 45.0) % 360.0;
                              _autoSaveCurrentProject();
                            });
                          },
                          child: const Icon(Icons.rotate_right),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'edit_obj_btn',
                          tooltip: 'Точные отступы от стен',
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          onPressed: () {
                            final idx = objects.indexOf(selectedObject!);
                            if (idx != -1) _showEditInteriorObjectDialog(idx);
                          },
                          child: const Icon(Icons.straighten),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'del_obj_btn',
                          tooltip: 'Удалить (Delete)',
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            _recordSnapshotForUndo();
                            setState(() {
                              objects.remove(selectedObject);
                              selectedObject = null;
                              _autoSaveCurrentProject();
                            });
                          },
                          child: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: is3DMode
                      ? Container(
                          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
                          ),
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_outlined, color: Color(0xFF38BDF8), size: 19),
                                  SizedBox(width: 6),
                                  Text(
                                    'Вид стен:',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              ChoiceChip(
                                label: const Text('Авто (Симс)'),
                                selected: wallViewMode3D == WallViewMode3D.cutawaySims,
                                onSelected: (_) => setState(() => wallViewMode3D = WallViewMode3D.cutawaySims),
                              ),
                              ChoiceChip(
                                label: const Text('Все стены'),
                                selected: wallViewMode3D == WallViewMode3D.fullWalls,
                                onSelected: (_) => setState(() => wallViewMode3D = WallViewMode3D.fullWalls),
                              ),
                              ChoiceChip(
                                label: const Text('Низкие'),
                                selected: wallViewMode3D == WallViewMode3D.lowWalls,
                                onSelected: (_) => setState(() => wallViewMode3D = WallViewMode3D.lowWalls),
                              ),
                              const SizedBox(width: 6),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.height, color: Color(0xFF34D399), size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    'Высота:',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 150,
                                child: Slider(
                                  value: wallHeightMeters,
                                  min: 0.2,
                                  max: 4.5,
                                  divisions: 43,
                                  activeColor: const Color(0xFF34D399),
                                  label: '${wallHeightMeters.toStringAsFixed(2)} м',
                                  onChanged: (v) {
                                    setState(() => wallHeightMeters = v);
                                    _autoSaveCurrentProject();
                                  },
                                ),
                              ),
                              Text(
                                '${wallHeightMeters.toStringAsFixed(2)} м',
                                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white38),
                                ),
                                onPressed: () => setState(() {
                                  cameraYaw = -0.65;
                                  cameraPitch = 0.72;
                                  cameraZoom3D = 0.95;
                                  cameraPan3D = Offset.zero;
                                }),
                                icon: const Icon(Icons.center_focus_strong, size: 17),
                                label: const Text('Сбросить ракурс'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ВСПЛЫВАЮЩИЕ МЕНЮ НАД КНОПКАМИ НИЖНЕЙ ПАНЕЛИ (Строительство, Шаблоны, Текстуры, Мебель)
                            _buildDockFlyoutContainer(constraints, isMobile),

                            if (_hoveringWallToolBtn || _hoveringThicknessPopup)
                              MouseRegion(
                                onEnter: (_) {
                                  _hideThicknessTimer?.cancel();
                                  setState(() => _hoveringThicknessPopup = true);
                                },
                                onExit: (_) {
                                  _hoveringThicknessPopup = false;
                                  _scheduleHideThicknessPopup();
                                },
                                child: Container(
                                  width: 320,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.line_weight, size: 16, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Толщина: ${currentThicknessCm.round()} см',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: currentThicknessCm,
                                          min: 5,
                                          max: 50,
                                          divisions: 45,
                                          onChanged: (v) => setState(() => currentThicknessCm = v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              margin: EdgeInsets.only(left: isMobile ? 6 : 12, right: isMobile ? 6 : 12, bottom: isMobile ? 6 : 14),
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 6 : 8),
                              decoration: BoxDecoration(
                                color: isDarkTheme ? const Color(0xFF2C2C2E).withValues(alpha: 0.96) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E42) : const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkTheme ? Colors.black54 : Colors.black12,
                                    blurRadius: isDarkTheme ? 20 : 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildToolBtn(EditorTool.overview, Icons.touch_app_outlined, 'Выделение'),
                                    _buildWallHoverToolBtn(EditorTool.drawWall, Icons.edit_road, 'Стена (${currentThicknessCm.round()} см)'),
                                    _buildToolBtn(EditorTool.wallDimensions, Icons.straighten_rounded, 'Размеры'),
                                    
                                    // РАЗДЕЛ СТРОИТЕЛЬСТВО (Окна, Двери, Коробка, Шаблоны)
                                    InkWell(
                                      onTap: () => setState(() {
                                        activeDockFlyout = (activeDockFlyout == ActiveDockFlyout.construction)
                                            ? ActiveDockFlyout.none
                                            : ActiveDockFlyout.construction;
                                      }),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: (selectedTool == EditorTool.addDoor ||
                                                  selectedTool == EditorTool.addWindow ||
                                                  selectedTool == EditorTool.drawRoomBox)
                                              ? const Color(0xFF0D99FF)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.foundation_rounded,
                                              size: 18,
                                              color: (selectedTool == EditorTool.addDoor ||
                                                      selectedTool == EditorTool.addWindow ||
                                                      selectedTool == EditorTool.drawRoomBox)
                                                  ? Colors.white
                                                  : (isDarkTheme ? Colors.white70 : Colors.black87),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              selectedTool == EditorTool.addDoor
                                                  ? 'Дверь'
                                                  : selectedTool == EditorTool.addWindow
                                                      ? 'Окно'
                                                      : selectedTool == EditorTool.drawRoomBox
                                                          ? 'Коробка'
                                                          : 'Строительство ▾',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: (selectedTool == EditorTool.addDoor ||
                                                        selectedTool == EditorTool.addWindow ||
                                                        selectedTool == EditorTool.drawRoomBox)
                                                    ? Colors.white
                                                    : (isDarkTheme ? Colors.white : Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    _buildToolBtn(EditorTool.drawDimension, Icons.straighten_rounded, 'Размер'),
                                    InkWell(
                                      onTap: () => setState(() {
                                        activeDockFlyout = (activeDockFlyout == ActiveDockFlyout.furniture)
                                            ? ActiveDockFlyout.none
                                            : ActiveDockFlyout.furniture;
                                      }),
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: (activeDockFlyout == ActiveDockFlyout.furniture || selectedTool == EditorTool.addObject)
                                              ? const Color(0xFF0D99FF)
                                              : (isDarkTheme ? Colors.transparent : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.chair_outlined,
                                              size: 16,
                                              color: (activeDockFlyout == ActiveDockFlyout.furniture || selectedTool == EditorTool.addObject)
                                                  ? Colors.white
                                                  : (isDarkTheme ? Colors.white70 : Colors.black87),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Мебель / 3D ▾',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: (activeDockFlyout == ActiveDockFlyout.furniture || selectedTool == EditorTool.addObject)
                                                    ? Colors.white
                                                    : (isDarkTheme ? Colors.white : Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // РАЗДЕЛ ЭЛЕКТРИКА В НИЖНЕЙ ПАНЕЛИ
                                    InkWell(
                                      onTap: () => setState(() {
                                        activeDockFlyout = (activeDockFlyout == ActiveDockFlyout.electrical)
                                            ? ActiveDockFlyout.none
                                            : ActiveDockFlyout.electrical;
                                      }),
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: (activeDockFlyout == ActiveDockFlyout.electrical || pendingElectricalPreset != null)
                                              ? const Color(0xFFF59E0B)
                                              : (isDarkTheme ? Colors.transparent : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.electrical_services_rounded,
                                              size: 16,
                                              color: (activeDockFlyout == ActiveDockFlyout.electrical || pendingElectricalPreset != null)
                                                  ? Colors.white
                                                  : (isDarkTheme ? Colors.white70 : Colors.black87),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Электрика ▾',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: (activeDockFlyout == ActiveDockFlyout.electrical || pendingElectricalPreset != null)
                                                    ? Colors.white
                                                    : (isDarkTheme ? Colors.white : Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // ТЕКСТУРЫ В НИЖНЕЙ ПАНЕЛИ
                                    InkWell(
                                      onTap: () => setState(() {
                                        activeDockFlyout = (activeDockFlyout == ActiveDockFlyout.textures)
                                            ? ActiveDockFlyout.none
                                            : ActiveDockFlyout.textures;
                                      }),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.texture_rounded, size: 18, color: Color(0xFF0D99FF)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Текстуры',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkTheme ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.grid_4x4, size: 16, color: Color(0xFF0D99FF)),
                                      label: Text('Шаг: ${snapConfig.gridStepCm.round()} см',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () {
                                        const steps = [5.0, 10.0, 25.0, 50.0];
                                        final nextIdx = (steps.indexOf(snapConfig.gridStepCm) + 1) % steps.length;
                                        setState(() => snapConfig.gridStepCm = steps[nextIdx]);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (btnCtx) => OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: activeDockFlyout == ActiveDockFlyout.snapping
                                              ? Colors.white
                                              : const Color(0xFF059669),
                                          backgroundColor: activeDockFlyout == ActiveDockFlyout.snapping
                                              ? const Color(0xFF059669)
                                              : null,
                                          side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showCadSnapsMenu(btnCtx),
                                        icon: const Icon(Icons.attractions_outlined, size: 17),
                                        label: const Text('Привязки', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  
  Widget _buildExplicationItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkTheme ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBarDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDarkTheme ? const Color(0xFF4A4A52) : const Color(0xFFCBD5E1),
    );
  }



  Widget _buildWallHoverToolBtn(EditorTool tool, IconData icon, String label) {
    return MouseRegion(
      onEnter: (_) {
        _hideThicknessTimer?.cancel();
        setState(() => _hoveringWallToolBtn = true);
      },
      onExit: (_) {
        _hoveringWallToolBtn = false;
        _scheduleHideThicknessPopup();
      },
      child: _buildToolBtn(tool, icon, label),
    );
  }

  Widget _buildToolBtn(EditorTool tool, IconData icon, String label) {
    final isSel = selectedTool == tool;
    return InkWell(
      onTap: () => setState(() {
        if (tool == EditorTool.drawWall) {
          if (selectedTool == EditorTool.drawWall) {
            showWallThicknessSlider = !showWallThicknessSlider;
          } else {
            selectedTool = EditorTool.drawWall;
            showWallThicknessSlider = true;
          }
        } else {
          selectedTool = tool;
          showWallThicknessSlider = false;
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFF0D99FF)
              : (isDarkTheme ? Colors.transparent : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSel ? Colors.white : (isDarkTheme ? const Color(0xFFD4D4D8) : const Color(0xFF334155)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : (isDarkTheme ? const Color(0xFFD4D4D8) : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================================
  // КОМПАКТНЫЕ ПРИВЯЗАННЫЕ ВСПЛЫВАЮЩИЕ ПАНЕЛИ (РЯДОМ С КНОПКАМИ, БЕЗ ПЕРЕКРЫТИЯ)
  // =========================================================================

  Widget _buildDockFlyoutContainer([BoxConstraints? constraints, bool isMobile = false]) {
    if (activeDockFlyout == ActiveDockFlyout.none || is3DMode) {
      return const SizedBox.shrink();
    }

    Widget content;
    Alignment alignment;
    double width = 430;

    switch (activeDockFlyout) {
      case ActiveDockFlyout.construction:
        alignment = Alignment.bottomLeft;
        width = 430;
        content = _buildConstructionFlyoutContent();
        break;
      case ActiveDockFlyout.templates:
        alignment = Alignment.bottomLeft;
        width = 480;
        content = _buildTemplatesFlyoutContent();
        break;
      case ActiveDockFlyout.textures:
        alignment = Alignment.bottomRight;
        width = 460;
        content = _buildTexturesFlyoutContent();
        break;
      case ActiveDockFlyout.furniture:
        alignment = Alignment.bottomCenter;
        width = 460;
        content = _buildFurnitureFlyoutContent();
        break;
      case ActiveDockFlyout.electrical:
        alignment = Alignment.bottomCenter;
        width = 470;
        content = _buildElectricalFlyoutContent();
        break;
      case ActiveDockFlyout.snapping:
        alignment = Alignment.bottomRight;
        width = 400;
        content = _buildSnappingFlyoutContent();
        break;
      case ActiveDockFlyout.none:
        return const SizedBox.shrink();
    }

    final screenW = constraints?.maxWidth ?? MediaQuery.of(context).size.width;
    final screenH = constraints?.maxHeight ?? MediaQuery.of(context).size.height;
    final flyoutWidth = isMobile ? math.min(screenW - 16, 480.0) : width;
    final flyoutMaxHeight = isMobile ? math.min(screenH * 0.48, 360.0) : 425.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(maxWidth: flyoutWidth),
      alignment: isMobile ? Alignment.bottomCenter : alignment,
      child: Container(
        width: flyoutWidth,
        constraints: BoxConstraints(maxHeight: flyoutMaxHeight),
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: isDarkTheme
              ? const Color(0xFF222226).withValues(alpha: 0.98)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        child: content,
      ),
    );
  }

  // =========================================================================
  // ВСПЛЫВАЮЩАЯ ПАНЕЛЬ: ОБЪЕКТНЫЕ ПРИВЯЗКИ CAD (КОМПАКТНАЯ НАД КНОПКОЙ)
  // =========================================================================
  Widget _buildSnappingFlyoutContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attractions_outlined, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 8),
            Text(
              'Привязки CAD (Snapping)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isDarkTheme ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Шаг сетки:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDarkTheme ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [5.0, 10.0, 25.0, 50.0].map((step) {
                    final isSel = snapConfig.gridStepCm == step;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text('${step.round()} см', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        onSelected: (_) => setState(() => snapConfig.gridStepCm = step),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Привязка к сетке (шаг ${snapConfig.gridStepCm.round()} см)', style: const TextStyle(fontSize: 12)),
                value: snapConfig.snapToGrid,
                onChanged: (v) => setState(() => snapConfig.snapToGrid = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('К краям (граням) стен (Face/Edge)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('Для точной рулетки и чистовых размеров', style: TextStyle(fontSize: 10)),
                value: snapConfig.snapToWallFaces,
                onChanged: (v) => setState(() => snapConfig.snapToWallFaces = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('К концам и углам стен (Endpoint)', style: TextStyle(fontSize: 12)),
                value: snapConfig.snapToEndpoints,
                onChanged: (v) => setState(() => snapConfig.snapToEndpoints = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('К линиям стен (Nearest)', style: TextStyle(fontSize: 12)),
                value: snapConfig.snapToWallLines,
                onChanged: (v) => setState(() => snapConfig.snapToWallLines = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('К серединам стен (Midpoint)', style: TextStyle(fontSize: 12)),
                value: snapConfig.snapToMidpoints,
                onChanged: (v) => setState(() => snapConfig.snapToMidpoints = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Линии выравнивания (Extension)', style: TextStyle(fontSize: 12)),
                value: snapConfig.snapAlignmentLines,
                onChanged: (v) => setState(() => snapConfig.snapAlignmentLines = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ортогональность 0° / 90° (Ortho)', style: TextStyle(fontSize: 12)),
                value: snapConfig.snapOrtho90,
                onChanged: (v) => setState(() => snapConfig.snapOrtho90 = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ПАРЯЩЕЕ МЕНЮ: ФИЛЬТРЫ И СЛОИ ЧЕРТЕЖА (СОВРЕМЕННЫЙ ДИЗАЙН С КАРТОЧКАМИ)
  // =========================================================================
  Widget _buildFilterFlyoutContent() {
    final isDark = isDarkTheme;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded, color: Color(0xFF0D99FF), size: 20),
                const SizedBox(width: 8),
                Text('Слои и видимость', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textColor)),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close, size: 18, color: subTextColor),
              onPressed: () => setState(() => showFilterFlyout = false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: cardBorder, height: 1),
        const SizedBox(height: 10),

        // КАРТОЧКА 1: ОСНОВНЫЕ СЛОИ ПЛАНИРОВКИ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Планировка и элементы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: subTextColor)),
              const SizedBox(height: 6),
              _buildModernLayerRow(
                icon: Icons.chair_rounded,
                color: const Color(0xFF38BDF8),
                title: 'Мебель и сантехника',
                count: objects.length,
                value: showFurnitureLayer,
                onChanged: (v) => setState(() => showFurnitureLayer = v),
              ),
              _buildModernLayerRow(
                icon: Icons.crop_square_rounded,
                color: const Color(0xFF818CF8),
                title: 'Зоны и экспликация комнат',
                count: zones.length,
                value: showZonesLayer,
                onChanged: (v) => setState(() => showZonesLayer = v),
              ),
              _buildModernLayerRow(
                icon: Icons.straighten_rounded,
                color: const Color(0xFF10B981),
                title: 'Размеры стен и выноски',
                count: walls.length,
                value: showDimensionsLayer,
                onChanged: (v) => setState(() => showDimensionsLayer = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // КАРТОЧКА 2: ИНЖЕНЕРНЫЕ СЕТИ (ЭЛЕКТРИКА)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Инженерные сети', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: subTextColor)),
              const SizedBox(height: 6),
              _buildModernLayerRow(
                icon: Icons.electrical_services_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Электрика и розетки',
                count: electricalItems.length,
                value: showElectricalLayer,
                onChanged: (v) => setState(() => showElectricalLayer = v),
              ),
              if (showElectricalLayer) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Column(
                    children: [
                      _buildModernSubToggle('Подписи и группы электрики', showElectricalLabels, (v) => setState(() => showElectricalLabels = v)),
                      _buildModernSubToggle('Размеры розеток от углов стен', showSocketDimensions, (v) => setState(() => showSocketDimensions = v)),
                      _buildModernSubToggle('Размеры светильников до стен', showLightDimensions, (v) => setState(() => showLightDimensions = v)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // КАРТОЧКА 3: НАПРАВЛЯЮЩИЕ И СЕТКА
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: _buildModernLayerRow(
            icon: Icons.grid_4x4_rounded,
            color: const Color(0xFF94A3B8),
            title: 'Координатная сетка CAD',
            value: showGrid,
            onChanged: (v) => setState(() {
              showGrid = v;
              snapConfig.snapToGrid = v;
            }),
          ),
        ),
        const SizedBox(height: 10),

        // БЫСТРЫЕ ПРЕСЕТЫ
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D99FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => setState(() {
                  showFurnitureLayer = true;
                  showElectricalLayer = true;
                  showDimensionsLayer = true;
                  showZonesLayer = true;
                  showGrid = true;
                  snapConfig.snapToGrid = true;
                }),
                icon: const Icon(Icons.visibility, size: 15),
                label: const Text('Все слои', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                  side: BorderSide(color: cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() {
                  showFurnitureLayer = false;
                  showElectricalLayer = false;
                  showDimensionsLayer = true;
                  showZonesLayer = true;
                }),
                icon: const Icon(Icons.crop_square, size: 15),
                label: const Text('Только стены', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernLayerRow({
    required IconData icon,
    required Color color,
    required String title,
    int? count,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = isDarkTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: value ? color.withValues(alpha: 0.15) : (isDark ? Colors.white10 : Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: value ? color : (isDark ? Colors.white38 : Colors.black38)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: value ? FontWeight.bold : FontWeight.w500,
                        color: value ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: value ? color.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: value ? color : (isDark ? Colors.white38 : Colors.black38)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSubToggle(String label, bool value, ValueChanged<bool> onChanged) {
    final isDark = isDarkTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 14, color: value ? const Color(0xFFF59E0B) : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: value ? (isDark ? Colors.white70 : Colors.black87) : (isDark ? Colors.white38 : Colors.black38)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ПАРЯЩЕЕ МЕНЮ: НАСТРОЙКИ САПР (ЕДИНИЦЫ ИЗМЕРЕНИЯ ММ/М, СЕТКА, СТЕНЫ)
  // =========================================================================
  Widget _buildSettingsFlyoutContent() {
    final isDark = isDarkTheme;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color sectionTitleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color labelColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    Widget buildSegmentedBtn<T>({
      required T value,
      required T groupValue,
      required String label,
      required ValueChanged<T> onSelected,
    }) {
      final isSel = (value == groupValue);
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF0D99FF) : cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel ? const Color(0xFF0D99FF) : cardBorder,
                width: isSel ? 1.4 : 1.0,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? Colors.white : labelColor,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_outlined, color: Color(0xFF0D99FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Настройки САПР',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textColor),
                ),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close, size: 18, color: subTextColor),
              onPressed: () => setState(() => showSettingsFlyout = false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 12),

        // 0. ТЕМА ОФОРМЛЕНИЯ И СЕТКА
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF0D99FF)),
                  const SizedBox(width: 6),
                  Text('Тема оформления холста:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: labelColor)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  buildSegmentedBtn<bool>(
                    value: false,
                    groupValue: isDark,
                    label: '☀️ Светлая',
                    onSelected: (v) {
                      setState(() {
                        isDarkTheme = false;
                        isDarkThemeNotifier.value = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  buildSegmentedBtn<bool>(
                    value: true,
                    groupValue: isDark,
                    label: '🌙 Тёмная (Figma)',
                    onSelected: (v) {
                      setState(() {
                        isDarkTheme = true;
                        isDarkThemeNotifier.value = true;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Показывать координатную сетку', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                value: showGrid,
                onChanged: (v) {
                  setState(() {
                    showGrid = v;
                    snapConfig.snapToGrid = v;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 1. ЕДИНИЦЫ ИЗМЕРЕНИЯ (Метры / Миллиметры с мгновенным пересчетом)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: Color(0xFF0D99FF)),
                  const SizedBox(width: 6),
                  Text('Единицы измерения размеров:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: labelColor)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  buildSegmentedBtn<UnitFormat>(
                    value: UnitFormat.millimeters,
                    groupValue: currentUnit,
                    label: 'Миллиметры (мм)',
                    onSelected: (u) {
                      setState(() {
                        currentUnit = u;
                        _autoSaveCurrentProject();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  buildSegmentedBtn<UnitFormat>(
                    value: UnitFormat.meters,
                    groupValue: currentUnit,
                    label: 'Метры (м)',
                    onSelected: (u) {
                      setState(() {
                        currentUnit = u;
                        _autoSaveCurrentProject();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                currentUnit == UnitFormat.millimeters
                    ? '✓ Все размеры на чертеже отображаются в миллиметрах (напр. 1500 мм, 700 мм)'
                    : '✓ Все размеры на чертеже отображаются в метрах (напр. 1.50 м, 0.70 м)',
                style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. ШАГ СЕТКИ
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Шаг сетки чертежа:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
            Text(formatCm(snapConfig.gridStepCm), style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < [5.0, 10.0, 20.0, 50.0].length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              buildSegmentedBtn<double>(
                value: [5.0, 10.0, 20.0, 50.0][i],
                groupValue: snapConfig.gridStepCm,
                label: formatCm([5.0, 10.0, 20.0, 50.0][i]),
                onSelected: (stepCm) => setState(() => snapConfig.gridStepCm = stepCm),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // 3. ВЫСОТА ПОТОЛКА
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Высота потолка:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
            Text(formatLength(wallHeightMeters), style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < [2.50, 2.70, 3.00, 3.20].length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              buildSegmentedBtn<double>(
                value: [2.50, 2.70, 3.00, 3.20][i],
                groupValue: wallHeightMeters,
                label: formatLength([2.50, 2.70, 3.00, 3.20][i]),
                onSelected: (h) => setState(() {
                  wallHeightMeters = h;
                  _autoSaveCurrentProject();
                }),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // 4. ПРИВЯЗКИ
        Text('Привязки CAD (Snapping):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 4),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Привязка к краям (граням) стен (рулетка)', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: snapConfig.snapToWallFaces,
          onChanged: (v) => setState(() => snapConfig.snapToWallFaces = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Привязка к вершинам и серединам стен', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: snapConfig.snapToEndpoints,
          onChanged: (v) => setState(() => snapConfig.snapToEndpoints = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Ортогональный режим (строго 90°)', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: snapConfig.snapOrtho90,
          onChanged: (v) => setState(() => snapConfig.snapOrtho90 = v ?? true),
        ),

        const SizedBox(height: 12),

        // 5. ЭЛЕКТРИКА И РАЗМЕРЫ (2D)
        Text('Электрика и размеры (2D):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sectionTitleColor)),
        const SizedBox(height: 4),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Показать подписи групп электрики', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: showElectricalLabels,
          onChanged: (v) => setState(() => showElectricalLabels = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Размеры розеток и выключателей от стен', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: showSocketDimensions,
          onChanged: (v) => setState(() => showSocketDimensions = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF0D99FF),
          checkColor: Colors.white,
          title: Text('Размеры светильников до ближайших стен', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
          value: showLightDimensions,
          onChanged: (v) => setState(() => showLightDimensions = v ?? true),
        ),
      ],
    );
  }
  // =========================================================================
  // ВСПЛЫВАЮЩАЯ ПАНЕЛЬ: ЭЛЕКТРИКА И ОСВЕЩЕНИЕ (РОЗЕТКИ, ВЫКЛЮЧАТЕЛИ, СВЕТ)
  // =========================================================================
  Widget _buildElectricalFlyoutContent() {
    return DefaultTabController(
      length: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.electrical_services_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Text('Электрика и освещение (2D)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkTheme ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white70 : const Color(0xFF64748B)),
                onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: 10),
            labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            indicatorColor: Color(0xFFF59E0B),
            tabs: [
              Tab(text: 'Розетки 220V'),
              Tab(text: 'Выключатели'),
              Tab(text: 'Светильники'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 290,
            child: TabBarView(
              children: [
                // 1. РОЗЕТКИ
                ListView(
                  children: [
                    _buildElectricalPresetTile(
                      icon: Icons.power,
                      color: const Color(0xFF0D99FF),
                      title: 'Одинарная розетка 220V',
                      subtitle: 'Стандартная, h=${formatMm(300)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_single', 'Розетка 220V', 300.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.power_rounded,
                      color: const Color(0xFF0D99FF),
                      title: 'Двойная розетка 220V',
                      subtitle: 'Блок на 2 поста, h=${formatMm(300)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_double', 'Розетка 2x220V', 300.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.countertops_outlined,
                      color: const Color(0xFF38BDF8),
                      title: 'Розетка фартука кухни',
                      subtitle: 'Рабочая зона, h=${formatMm(1050)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_kitchen', 'Розетка фартука', 1050.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.tv_rounded,
                      color: const Color(0xFF818CF8),
                      title: 'Розетка ТВ и Интернет (RJ-45)',
                      subtitle: 'Подвесной ТВ, h=${formatMm(1100)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_tv', 'Розетка ТВ/LAN', 1100.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.water_drop_outlined,
                      color: const Color(0xFF06B6D4),
                      title: 'Влагозащитная розетка IP44',
                      subtitle: 'Для санузлов, h=${formatMm(1000)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_ip44', 'Розетка IP44', 1000.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.flash_on_rounded,
                      color: const Color(0xFFEF4444),
                      title: 'Силовая розетка (плита/духовка)',
                      subtitle: 'Высокая мощность, h=${formatMm(100)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.socket, 'socket_power', 'Розетка силовая', 100.0),
                    ),
                  ],
                ),

                // 2. ВЫКЛЮЧАТЕЛИ
                ListView(
                  children: [
                    _buildElectricalPresetTile(
                      icon: Icons.toggle_on_outlined,
                      color: const Color(0xFF10B981),
                      title: 'Одноклавишный выключатель',
                      subtitle: 'Основной свет, h=${formatMm(900)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.switchItem, 'switch_1k', 'Выключатель 1-клав', 900.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.view_stream_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Двухклавишный выключатель',
                      subtitle: '2 группы света, h=${formatMm(900)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.switchItem, 'switch_2k', 'Выключатель 2-клав', 900.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.sync_alt_rounded,
                      color: const Color(0xFF34D399),
                      title: 'Проходной / коридорный выключатель',
                      subtitle: 'Управление из 2 мест, h=${formatMm(900)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.switchItem, 'switch_cross', 'Выключатель проходной', 900.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF059669),
                      title: 'Диммер (регулятор яркости)',
                      subtitle: 'Плавная регулировка, h=${formatMm(900)} от пола',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.switchItem, 'switch_dimmer', 'Диммер света', 900.0),
                    ),
                  ],
                ),

                // 3. СВЕТИЛЬНИКИ
                ListView(
                  children: [
                    _buildElectricalPresetTile(
                      icon: Icons.adjust_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Точечный светильник (спот)',
                      subtitle: 'Потолочный встроенный, h=${formatMm(2600)}',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.light, 'spot', 'Точечный спот', 2600.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.light_rounded,
                      color: const Color(0xFFFBBF24),
                      title: 'Люстра потолочная (подвес)',
                      subtitle: 'Центральный свет, h=${formatMm(2400)}',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.light, 'chandelier', 'Люстра потолочная', 2400.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.wb_incandescent_outlined,
                      color: const Color(0xFFF97316),
                      title: 'Настенное бра',
                      subtitle: 'Прикроватный/зонный свет, h=${formatMm(1800)}',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.light, 'sconce', 'Бра настенное', 1800.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.linear_scale_rounded,
                      color: const Color(0xFFFBBF24),
                      title: 'Светодиодная лента (LED)',
                      subtitle: 'Контурная подсветка, h=${formatMm(2500)}',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.light, 'led', 'Светодиодная лента LED', 2500.0),
                    ),
                    _buildElectricalPresetTile(
                      icon: Icons.more_horiz_rounded,
                      color: const Color(0xFFEAB308),
                      title: 'Трековый светильник',
                      subtitle: 'Шинопровод, h=${formatMm(2600)}',
                      onTap: () => _startPlacingElectricalItem(ElectricalType.light, 'track', 'Трековый светильник', 2600.0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectricalPresetTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDarkTheme ? const Color(0xFF333338) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDarkTheme ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0D99FF)),
            ],
          ),
        ),
      ),
    );
  }

    void _startPlacingElectricalItem(ElectricalType type, String subType, String name, double heightMm) {
    setState(() {
      pendingElectricalPreset = (
        type: type,
        subType: subType,
        name: name,
        defaultHeightMm: heightMm,
      );
      activeDockFlyout = ActiveDockFlyout.none;
      selectedElectricalItem = null;
      selectedObject = null;
      selectedWall = null;
      selectedOpening = null;
      selectedTool = EditorTool.overview;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == ElectricalType.light
              ? 'Размещение: $name. Кликните в любом месте потолка.'
              : 'Размещение: $name. Наведите курсор на стену (прилипает к внутренней стороне) и кликните.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _setElectricalItemDistanceAlongWall(ElectricalItem item, double newDistCm, {bool? fromStart}) {
    if (item.type == ElectricalType.light) return;
    final binding = _getElectricalWallBinding(item, walls, canvasScale);
    if (binding == null) return;

    final wall = binding.wall;
    final wallVec = wall.end - wall.start;
    final wallLen = binding.wallLenCm;
    if (wallLen < 0.1) return;
    final u = wallVec / wallLen;
    final norm = Offset(-u.dy, u.dx);
    final side = binding.side;
    final halfThick = wall.thicknessCm / 2.0;
    const defaultR = 8.5;

    // Minimum distance from wall corners to avoid penetrating into perpendicular walls
    final minMargin = 6.0;
    final maxMargin = math.max(minMargin, wallLen - minMargin);
    final clampedDist = newDistCm.clamp(minMargin, maxMargin);

    final bool useFromStart = fromStart ?? binding.fromStart;
    final targetT = useFromStart ? clampedDist : (wallLen - clampedDist);
    final newProj = wall.start + u * targetT;

    double ang = math.atan2(u.dy, u.dx) * 180 / math.pi;
    if (side < 0) {
      ang = (ang + 180) % 360;
    }

    _recordSnapshotForUndo();
    setState(() {
      item.position = newProj + norm * (side * (halfThick + defaultR));
      item.rotationDeg = ang;
      _autoSaveCurrentProject();
    });
  }

  void _showQuickEditElectricalDistanceDialog(ElectricalItem item) {
    final binding = _getElectricalWallBinding(item, walls, canvasScale);
    if (binding == null) return;

    final isMm = currentUnit == UnitFormat.millimeters;
    final double curVal = isMm ? (binding.distCm * 10.0).roundToDouble() : (binding.distCm / 100.0);
    final String unitSuffix = isMm ? 'мм' : 'м';
    final String wallLenStr = isMm ? '${(binding.wallLenCm * 10.0).round()} мм' : '${(binding.wallLenCm / 100.0).toStringAsFixed(2)} м';
    final String cornerName = binding.fromStart ? 'начала стены' : 'конца стены';

    final textCtrl = TextEditingController(
      text: isMm ? '${curVal.round()}' : curVal.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = isDarkTheme;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final Color inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

        void applyDistance(String text) {
          final val = double.tryParse(text.replaceAll(',', '.').trim());
          if (val != null && val > 0) {
            final newDistCm = isMm ? (val / 10.0) : (val * 100.0);
            _setElectricalItemDistanceAlongWall(item, newDistCm, fromStart: binding.fromStart);
          }
          Navigator.pop(ctx);
        }

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: Container(
            width: math.min(330.0, MediaQuery.of(context).size.width - 32),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D99FF).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.type == ElectricalType.socket
                            ? Icons.power
                            : (item.type == ElectricalType.switchItem ? Icons.toggle_on_outlined : Icons.lightbulb_outline),
                        size: 20,
                        color: const Color(0xFF0D99FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Расстояние от $cornerName',
                            style: TextStyle(fontSize: 11.5, color: subTextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: subTextColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Введите точное расстояние ($unitSuffix):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        decoration: InputDecoration(
                          suffixText: unitSuffix,
                          suffixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subTextColor),
                          isDense: true,
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 2)),
                        ),
                        onSubmitted: applyDistance,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final delta in isMm ? [-100.0, -50.0, 50.0, 100.0] : [-0.1, -0.05, 0.05, 0.1])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              final cur = double.tryParse(textCtrl.text.replaceAll(',', '.').trim()) ?? curVal;
                              final next = math.max(0.0, cur + delta);
                              textCtrl.text = isMm ? '${next.round()}' : next.toStringAsFixed(2);
                            },
                            child: Text(
                              '${delta > 0 ? '+' : ''}${isMm ? delta.round() : delta}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Длина стены: $wallLenStr',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D99FF),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => applyDistance(textCtrl.text),
                      child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickEditLightDistanceDialog(ElectricalItem item, ({Wall wall, Offset proj, double distCm}) wInfo) {
    final isMm = currentUnit == UnitFormat.millimeters;
    final double curVal = isMm ? (wInfo.distCm * 10.0).roundToDouble() : (wInfo.distCm / 100.0);
    final String unitSuffix = isMm ? 'мм' : 'м';

    final textCtrl = TextEditingController(
      text: isMm ? '${curVal.round()}' : curVal.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = isDarkTheme;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final Color inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

        void applyDistance(String text) {
          final val = double.tryParse(text.replaceAll(',', '.').trim());
          if (val != null && val > 0) {
            final newDistCm = isMm ? (val / 10.0) : (val * 100.0);
            final vec = item.position - wInfo.proj;
            final curD = vec.distance;
            if (curD > 0.001) {
              final dir = vec / curD;
              final halfThick = wInfo.wall.thicknessCm / 2.0;
              final newPos = wInfo.proj + dir * (newDistCm + halfThick);
              _recordSnapshotForUndo();
              setState(() {
                item.position = newPos;
                _autoSaveCurrentProject();
              });
            }
          }
          Navigator.pop(ctx);
        }

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: Container(
            width: math.min(330.0, MediaQuery.of(context).size.width - 32),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D99FF).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFF0D99FF)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                          Text('Расстояние от светильника до стены', style: TextStyle(fontSize: 11.5, color: subTextColor)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: subTextColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Введите точное расстояние ($unitSuffix):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(
                    suffixText: unitSuffix,
                    suffixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subTextColor),
                    isDense: true,
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 2)),
                  ),
                  onSubmitted: applyDistance,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final delta in isMm ? [-100.0, -50.0, 50.0, 100.0] : [-0.1, -0.05, 0.05, 0.1])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              final cur = double.tryParse(textCtrl.text.replaceAll(',', '.').trim()) ?? curVal;
                              final next = math.max(0.0, cur + delta);
                              textCtrl.text = isMm ? '${next.round()}' : next.toStringAsFixed(2);
                            },
                            child: Text(
                              '${delta > 0 ? '+' : ''}${isMm ? delta.round() : delta}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D99FF),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => applyDistance(textCtrl.text),
                      child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showElectricalItemConfigDialog(ElectricalItem item) {
    final groupCtrl = TextEditingController(text: item.groupLabel);
    final heightCtrl = TextEditingController(text: '${item.heightFromFloorMm.round()}');

    final isMm = currentUnit == UnitFormat.millimeters;
    final unitSuffix = isMm ? 'мм' : 'м';
    final binding = _getElectricalWallBinding(item, walls, canvasScale);

    double initialDist = 0.0;
    if (binding != null) {
      initialDist = isMm ? (binding.distCm * 10.0).roundToDouble() : (binding.distCm / 100.0);
    }
    final distCtrl = TextEditingController(
      text: binding != null ? (isMm ? '${initialDist.round()}' : initialDist.toStringAsFixed(2)) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = isDarkTheme;
          final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          final Color labelColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
          final Color inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
          final Color inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: math.min(380.0, MediaQuery.of(context).size.width - 32),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D99FF).withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.type == ElectricalType.socket
                              ? Icons.power
                              : (item.type == ElectricalType.switchItem ? Icons.toggle_on_outlined : Icons.lightbulb_outline),
                          size: 22,
                          color: const Color(0xFF0D99FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.type == ElectricalType.light
                                  ? 'Потолочный светильник'
                                  : (item.type == ElectricalType.socket ? 'Розетка' : 'Выключатель'),
                              style: TextStyle(fontSize: 12, color: subTextColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: subTextColor),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 14),

                  Text('Группа электрики / Назначение:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: labelColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: groupCtrl,
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'например: кухня, ТВ, рабочая зона...',
                      hintStyle: TextStyle(fontSize: 12, color: subTextColor.withValues(alpha: 0.8)),
                      isDense: true,
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.5)),
                    ),
                    onChanged: (val) {
                      _recordSnapshotForUndo();
                      setState(() {
                        item.groupLabel = val.trim();
                        _autoSaveCurrentProject();
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF0D99FF),
                    checkColor: Colors.white,
                    title: Text(
                      'Показать подпись над компонентом',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: textColor),
                    ),
                    value: item.showLabel,
                    onChanged: (val) {
                      _recordSnapshotForUndo();
                      setDlgState(() => item.showLabel = val ?? true);
                      setState(() {
                        _autoSaveCurrentProject();
                      });
                    },
                  ),

                  if (item.type != ElectricalType.light && binding != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Расстояние от угла стены:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: labelColor)),
                        Text(
                          binding.fromStart ? '(от начала стены)' : '(от конца стены)',
                          style: TextStyle(fontSize: 11, color: subTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, size: 22, color: subTextColor),
                          onPressed: () {
                            final cur = double.tryParse(distCtrl.text.replaceAll(',', '.').trim()) ?? initialDist;
                            final step = isMm ? 50.0 : 0.05;
                            final next = math.max(isMm ? 50.0 : 0.05, cur - step);
                            distCtrl.text = isMm ? '${next.round()}' : next.toStringAsFixed(2);
                            final newDistCm = isMm ? (next / 10.0) : (next * 100.0);
                            _setElectricalItemDistanceAlongWall(item, newDistCm, fromStart: binding.fromStart);
                            setDlgState(() {});
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: distCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            decoration: InputDecoration(
                              suffixText: unitSuffix,
                              suffixStyle: TextStyle(fontWeight: FontWeight.w600, color: subTextColor, fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.5)),
                            ),
                            onSubmitted: (val) {
                              final d = double.tryParse(val.replaceAll(',', '.').trim());
                              if (d != null && d > 0) {
                                final newDistCm = isMm ? (d / 10.0) : (d * 100.0);
                                _setElectricalItemDistanceAlongWall(item, newDistCm, fromStart: binding.fromStart);
                                setDlgState(() {});
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, size: 22, color: subTextColor),
                          onPressed: () {
                            final cur = double.tryParse(distCtrl.text.replaceAll(',', '.').trim()) ?? initialDist;
                            final step = isMm ? 50.0 : 0.05;
                            final next = cur + step;
                            distCtrl.text = isMm ? '${next.round()}' : next.toStringAsFixed(2);
                            final newDistCm = isMm ? (next / 10.0) : (next * 100.0);
                            _setElectricalItemDistanceAlongWall(item, newDistCm, fromStart: binding.fromStart);
                            setDlgState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Высота от пола:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: labelColor)),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: heightCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            decoration: InputDecoration(
                              suffixText: 'мм',
                              suffixStyle: TextStyle(fontWeight: FontWeight.w600, color: subTextColor, fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D99FF), width: 1.5)),
                            ),
                            onSubmitted: (val) {
                              final h = double.tryParse(val);
                              if (h != null) {
                                _recordSnapshotForUndo();
                                setState(() {
                                  item.heightFromFloorMm = h;
                                  _autoSaveCurrentProject();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (item.type == ElectricalType.light) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Привязка к ближайшим стенам:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
                          const SizedBox(height: 6),
                          ..._findNearestWallsForLightOnWalls(item.position, walls).map((wInfo) {
                            final distM = wInfo.distCm / 100.0;
                            final distStr = currentUnit == UnitFormat.millimeters
                                ? '${(distM * 1000).round()} мм'
                                : '${distM.toStringAsFixed(2)} м';
                            return Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text('• До стены: $distStr', style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500)),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Удалить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          _recordSnapshotForUndo();
                          setState(() {
                            electricalItems.remove(item);
                            selectedElectricalItem = null;
                            _autoSaveCurrentProject();
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      FilledButton(
                        onPressed: () {
                          if (binding != null) {
                            final d = double.tryParse(distCtrl.text.replaceAll(',', '.').trim());
                            if (d != null && d > 0) {
                              final newDistCm = isMm ? (d / 10.0) : (d * 100.0);
                              _setElectricalItemDistanceAlongWall(item, newDistCm, fromStart: binding.fromStart);
                            }
                          }
                          final h = double.tryParse(heightCtrl.text.replaceAll(',', '.').trim());
                          if (h != null && h >= 0 && h != item.heightFromFloorMm) {
                            _recordSnapshotForUndo();
                            setState(() {
                              item.heightFromFloorMm = h;
                              _autoSaveCurrentProject();
                            });
                          }
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D99FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Готово', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

    Widget _buildElectricalInspectorContent() {
    final item = selectedElectricalItem!;
    final binding = _getElectricalWallBinding(item, walls, canvasScale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.electrical_services_rounded, color: Color(0xFFF59E0B), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (item.groupLabel.isNotEmpty)
                    Text(
                      'Группа: ${item.groupLabel}',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0D99FF)),
              tooltip: 'Настроить группу и параметры',
              onPressed: () => _showElectricalItemConfigDialog(item),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (item.type != ElectricalType.light && binding != null) ...[
          Builder(builder: (ctx) {
            final isMm = currentUnit == UnitFormat.millimeters;
            final curVal = isMm ? (binding.distCm * 10.0).round() : (binding.distCm / 100.0).toStringAsFixed(2);
            final unitSuffix = isMm ? 'мм' : 'м';
            final cornerName = binding.fromStart ? 'начала' : 'конца';
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkTheme ? const Color(0xFF28282D) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Расстояние от $cornerName стены:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('$curVal $unitSuffix', style: const TextStyle(color: Color(0xFF0D99FF), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                          onPressed: () {
                            final stepCm = 5.0; // 50 mm / 5 cm
                            _setElectricalItemDistanceAlongWall(item, math.max(6.0, binding.distCm - stepCm), fromStart: binding.fromStart);
                          },
                          child: Text(isMm ? '-50 мм' : '-5 см', style: const TextStyle(fontSize: 10.5)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                          onPressed: () {
                            final stepCm = 5.0;
                            _setElectricalItemDistanceAlongWall(item, binding.distCm + stepCm, fromStart: binding.fromStart);
                          },
                          child: Text(isMm ? '+50 мм' : '+5 см', style: const TextStyle(fontSize: 10.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF28282D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Высота от пола:', style: TextStyle(fontSize: 11)),
                Text(
                  formatMm(item.heightFromFloorMm),
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        if (item.type == ElectricalType.light) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF28282D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDarkTheme ? const Color(0xFF3E3E44) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Расстояния до ближайших стен:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ..._findNearestWallsForLightOnWalls(item.position, walls).map((wInfo) {
                  final distM = wInfo.distCm / 100.0;
                  final distStr = currentUnit == UnitFormat.millimeters ? '${(distM * 1000).round()} мм' : '${distM.toStringAsFixed(2)} м';
                  return Text('• $distStr', style: const TextStyle(fontSize: 11, color: Color(0xFF0D99FF), fontWeight: FontWeight.w600));
                }),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: () => _showElectricalItemConfigDialog(item),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Группа и параметры', style: TextStyle(fontSize: 11.5)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              style: IconButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  electricalItems.remove(item);
                  selectedElectricalItem = null;
                  _autoSaveCurrentProject();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConstructionFlyoutContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.foundation_rounded, color: Color(0xFF0D99FF), size: 18),
              const SizedBox(width: 8),
              Text(
                'Строительство',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDarkTheme ? Colors.white : Colors.black87),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          _buildConstructionSectionHeader(Icons.window_outlined, 'Окна:', const Color(0xFF38BDF8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildConstructionChoiceChip(
                label: '⚙️ Свой размер',
                subtitle: 'Ш × В',
                isSelected: selectedTool == EditorTool.addWindow && pendingWindowPreset == null,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  setState(() {
                    pendingWindowPreset = null;
                    selectedTool = EditorTool.addWindow;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                iconWidget: _buildWindowIcon(1),
                label: '1-створчатое',
                subtitle: '0.8×1.4м',
                isSelected: false,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  setState(() {
                    pendingWindowPreset = (width: 0.80, height: 1.40, sill: 0.85, name: 'Одностворчатое окно');
                    selectedTool = EditorTool.addWindow;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                iconWidget: _buildWindowIcon(2),
                label: '2-створчатое',
                subtitle: '1.4×1.4м',
                isSelected: false,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  setState(() {
                    pendingWindowPreset = (width: 1.40, height: 1.40, sill: 0.85, name: 'Двустворчатое окно');
                    selectedTool = EditorTool.addWindow;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                iconWidget: _buildWindowIcon(3),
                label: '3-створчатое',
                subtitle: '2.0×1.4м',
                isSelected: false,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  setState(() {
                    pendingWindowPreset = (width: 2.00, height: 1.40, sill: 0.85, name: 'Трёхстворчатое окно');
                    selectedTool = EditorTool.addWindow;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                iconWidget: _buildWindowIcon(4),
                label: 'Панорамное',
                subtitle: '2.4×2.2м',
                isSelected: false,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  setState(() {
                    pendingWindowPreset = (width: 2.40, height: 2.20, sill: 0.0, name: 'Панорамное окно');
                    selectedTool = EditorTool.addWindow;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildConstructionSectionHeader(Icons.door_front_door_outlined, 'Двери:', const Color(0xFF10B981)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildConstructionChoiceChip(
                label: '⚙️ Свой размер',
                subtitle: 'Ш × В',
                isSelected: selectedTool == EditorTool.addDoor && isCustomDoorSelected,
                color: const Color(0xFF10B981),
                onTap: () {
                  setState(() {
                    isCustomDoorSelected = true;
                    pendingDoorPreset = null;
                    selectedTool = EditorTool.addDoor;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                label: 'Межкомнатная',
                subtitle: '0.8×2.1м',
                isSelected: false,
                color: const Color(0xFF10B981),
                onTap: () {
                  setState(() {
                    isCustomDoorSelected = false;
                    pendingDoorPreset = (width: 0.80, height: 2.10, name: 'Межкомнатная дверь');
                    selectedTool = EditorTool.addDoor;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                label: 'Входная',
                subtitle: '0.95×2.1м',
                isSelected: false,
                color: const Color(0xFF10B981),
                onTap: () {
                  setState(() {
                    isCustomDoorSelected = false;
                    pendingDoorPreset = (width: 0.95, height: 2.10, name: 'Входная дверь');
                    selectedTool = EditorTool.addDoor;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
              _buildConstructionChoiceChip(
                label: 'Раздвижная',
                subtitle: '1.2×2.15м',
                isSelected: false,
                color: const Color(0xFF10B981),
                onTap: () {
                  setState(() {
                    isCustomDoorSelected = false;
                    pendingDoorPreset = (width: 1.20, height: 2.15, name: 'Раздвижная дверь');
                    selectedTool = EditorTool.addDoor;
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTool = EditorTool.drawRoomBox;
                      activeDockFlyout = ActiveDockFlyout.none;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0D99FF).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.crop_square_rounded, size: 16, color: Color(0xFF0D99FF)),
                        SizedBox(width: 4),
                        Text('Коробка', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D99FF))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _startCustomSketchMode();
                    setState(() => activeDockFlyout = ActiveDockFlyout.none);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.architecture_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 4),
                        Text('Планировка', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF8B5CF6))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => activeDockFlyout = ActiveDockFlyout.templates);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_outlined, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Шаблоны', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesFlyoutContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: 'Назад в строительство',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.construction),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 8),
            Text(
              'Шаблоны планировок',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDarkTheme ? Colors.white : Colors.black87),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTemplateCard(
                previewType: 'studio',
                title: 'Студия (32 м²)',
                areaBadge: '32 м²',
                desc: 'Прихожая, санузел, кухонный фронт, обеденная зона и гостиная.',
                tags: const ['Студия', 'Кухня', 'Ванная'],
                color: const Color(0xFF0D99FF),
                onTap: () {
                  _loadTemplateStudio();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'one_room',
                title: '1-комнатная квартира (45 м²)',
                areaBadge: '45 м²',
                desc: 'Спальня с гардеробом, кухня-столовая, раздельный санузел.',
                tags: const ['1 комната', 'Спальня'],
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  _loadTemplate1Room();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'two_room',
                title: '2-комнатная / Евро-3 (68 м²)',
                areaBadge: '68 м²',
                desc: 'Мастер-спальня, кабинет/детская, большая кухня-гостиная с ТВ-зоной.',
                tags: const ['2 спальни', 'Евро-3', 'Гостиная'],
                color: const Color(0xFF10B981),
                onTap: () {
                  _loadTemplate2Room();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'kitchen_living',
                title: 'Кухня-гостиная с островом (31.5 м²)',
                areaBadge: '31.5 м²',
                desc: 'Гарнитур, остров с баром, обеденная группа и лаунж-диван.',
                tags: const ['Кухня', 'Остров', 'Open-space'],
                color: const Color(0xFFF59E0B),
                onTap: () {
                  _loadTemplateKitchenLiving();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'bathroom',
                title: 'Ванная комната люкс (9.6 м²)',
                areaBadge: '9.6 м²',
                desc: 'Отдельностоящая ванна, душевой трап, инсталляция, стиральный блок.',
                tags: const ['Санузел', 'Ванная', 'Люкс'],
                color: const Color(0xFF06B6D4),
                onTap: () {
                  _loadTemplateBathroomLuxury();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'office',
                title: 'Офис / переговорная (24 м²)',
                areaBadge: '24 м²',
                desc: 'Большой стол переговоров на 8 персон, кофе-поинт, ТВ-панель.',
                tags: const ['Офис', 'Переговорная'],
                color: const Color(0xFF6366F1),
                onTap: () {
                  _loadTemplateOffice();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
              const SizedBox(height: 8),
              _buildTemplateCard(
                previewType: 'standard_room',
                title: 'Универсальная комната (16 м²)',
                areaBadge: '16 м²',
                desc: 'Базовая прямоугольная планировка с окном и входной дверью.',
                tags: const ['Базовый', 'Комната'],
                color: const Color(0xFF84CC16),
                onTap: () {
                  _loadTemplateStandardRoom();
                  setState(() => activeDockFlyout = ActiveDockFlyout.none);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTexturesFlyoutContent() {
    final categories = ['Все', ...myTextureCatalog.map((t) => t.category).toSet()];
    final filtered = activeTextureFlyoutCategory == 'Все'
        ? myTextureCatalog
        : myTextureCatalog.where((t) => t.category == activeTextureFlyoutCategory).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.texture_rounded, color: Color(0xFF0D99FF), size: 18),
            const SizedBox(width: 8),
            Text(
              'Каталог текстур',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDarkTheme ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 8),
            if (selectedObject != null || selectedWall != null || editingBoundaryZone != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedObject != null
                      ? 'Объект'
                      : (selectedWall != null ? 'Стена' : 'Зона'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF0D99FF), fontWeight: FontWeight.bold),
                ),
              ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Выпадающий список категорий текстур (Dropdown)
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: categories.contains(activeTextureFlyoutCategory) ? activeTextureFlyoutCategory : 'Все',
              isExpanded: true,
              dropdownColor: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF0D99FF)),
              items: categories.map((cat) {
                final count = cat == 'Все' ? myTextureCatalog.length : myTextureCatalog.where((t) => t.category == cat).length;
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(
                        cat == 'Все' ? Icons.category_rounded : Icons.folder_open_rounded,
                        size: 16,
                        color: const Color(0xFF0D99FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: cat == activeTextureFlyoutCategory ? FontWeight.bold : FontWeight.w500,
                            color: isDarkTheme ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isDarkTheme ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(fontSize: 10.5, color: isDarkTheme ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newCat) {
                if (newCat != null) setState(() => activeTextureFlyoutCategory = newCat);
              },
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 10),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, idx) {
              final tex = filtered[idx];
              final displayName = kTextureItemDisplayNamesRu[tex.id] ?? tex.name;
              return InkWell(
                onTap: () {
                  _recordSnapshotForUndo();
                  setState(() {
                    if (selectedObject != null) {
                      selectedObject!.textureId = tex.id;
                    } else if (selectedWall != null) {
                      selectedWall!.textureSideA = tex.id;
                      selectedWall!.textureSideB = tex.id;
                    } else if (editingBoundaryZone != null) {
                      editingBoundaryZone!.textureId = tex.id;
                    } else if (selectedOpening != null) {
                      selectedOpening!.textureId = tex.id;
                    } else {
                      for (final z in zones) {
                        z.textureId = tex.id;
                      }
                    }
                    _autoSaveCurrentProject();
                    activeDockFlyout = ActiveDockFlyout.none;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDarkTheme ? Colors.white24 : Colors.black12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(tex.assetPath, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade800)),
                      Container(
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: Colors.black54,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFurnitureFlyoutContent() {
    final List<String> allCats = ['Все', ...kModelCategoryNamesRu.values];
    final userModels = activeFurnitureFlyoutCategory == 'Все'
        ? my3DModelCatalog
        : my3DModelCatalog.where((m) => m.categoryRu == activeFurnitureFlyoutCategory).toList();
    final builtIn = activeFurnitureFlyoutCategory == 'Все'
        ? kBuiltInPresets
        : kBuiltInPresets.where((p) => p.$1 == activeFurnitureFlyoutCategory).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chair_outlined, color: Color(0xFF0D99FF), size: 18),
            const SizedBox(width: 8),
            Text(
              'Каталог 3D мебели',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDarkTheme ? Colors.white : Colors.black87),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => activeDockFlyout = ActiveDockFlyout.none),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Выпадающий список категорий мебели (Dropdown)
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: allCats.contains(activeFurnitureFlyoutCategory) ? activeFurnitureFlyoutCategory : 'Все',
              isExpanded: true,
              dropdownColor: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF0D99FF)),
              items: allCats.map((cat) {
                final userCount = cat == 'Все' ? my3DModelCatalog.length : my3DModelCatalog.where((m) => m.categoryRu == cat).length;
                final builtinCount = cat == 'Все' ? kBuiltInPresets.length : kBuiltInPresets.where((p) => p.$1 == cat).length;
                final total = userCount + builtinCount;
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(
                        cat == 'Все' ? Icons.weekend_rounded : Icons.chair_rounded,
                        size: 16,
                        color: const Color(0xFF0D99FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: cat == activeFurnitureFlyoutCategory ? FontWeight.bold : FontWeight.w500,
                            color: isDarkTheme ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isDarkTheme ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$total',
                          style: TextStyle(fontSize: 10.5, color: isDarkTheme ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newCat) {
                if (newCat != null) setState(() => activeFurnitureFlyoutCategory = newCat);
              },
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 10),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...userModels.map((m) => InkWell(
                    onTap: () {
                      _recordSnapshotForUndo();
                      final worldPos = pendingFurnitureWorldPos ??
                          (Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2) - canvasOffset) / canvasScale;
                      final newObj = InteriorObject(
                        category: m.categoryRu,
                        name: m.name,
                        position: worldPos,
                        widthMeters: m.defaultWidthM,
                        depthMeters: m.defaultDepthM,
                        heightMeters: m.defaultHeightM,
                        model3dPath: m.modelAssetPath,
                        previewImagePath: m.previewImagePath,
                      );
                      setState(() {
                        objects.add(newObj);
                        selectedObject = newObj;
                        selectedTool = EditorTool.overview;
                        pendingFurnitureWorldPos = null;
                        activeDockFlyout = ActiveDockFlyout.none;
                        _autoSaveCurrentProject();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDarkTheme ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D99FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF0D99FF), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDarkTheme ? Colors.white : Colors.black87)),
                                const SizedBox(height: 2),
                                Text('${m.defaultWidthM.toStringAsFixed(2)} × ${m.defaultDepthM.toStringAsFixed(2)} × ${m.defaultHeightM.toStringAsFixed(2)} м',
                                    style: TextStyle(fontSize: 10.5, color: isDarkTheme ? Colors.white60 : Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0D99FF)),
                        ],
                      ),
                    ),
                  )),
              ...builtIn.map((item) => InkWell(
                    onTap: () {
                      _recordSnapshotForUndo();
                      final worldPos = pendingFurnitureWorldPos ??
                          (Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2) - canvasOffset) / canvasScale;
                      final newObj = InteriorObject(
                        category: item.$1,
                        name: item.$2,
                        position: worldPos,
                        widthMeters: item.$3,
                        depthMeters: item.$4,
                        heightMeters: item.$5,
                        textureId: myTextureCatalog.isNotEmpty ? myTextureCatalog.first.id : null,
                      );
                      setState(() {
                        objects.add(newObj);
                        selectedObject = newObj;
                        selectedTool = EditorTool.overview;
                        pendingFurnitureWorldPos = null;
                        activeDockFlyout = ActiveDockFlyout.none;
                        _autoSaveCurrentProject();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDarkTheme ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.chair_outlined, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$2, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDarkTheme ? Colors.white : Colors.black87)),
                                const SizedBox(height: 2),
                                Text('${item.$3.toStringAsFixed(2)} × ${item.$4.toStringAsFixed(2)} × ${item.$5.toStringAsFixed(2)} м',
                                    style: TextStyle(fontSize: 10.5, color: isDarkTheme ? Colors.white60 : Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateFlyoutContent() {
    final Map<String, double> floorByMaterial = {};
    double totalSkirtingM = 0.0;

    for (final z in zones) {
      String matName = 'Без текстуры (${z.name})';
      if (z.textureId != null) {
        final found = myTextureCatalog.where((t) => t.id == z.textureId).firstOrNull;
        matName = found != null ? '${found.category}: ${found.name}' : z.textureId!.split('/').last;
      }
      floorByMaterial[matName] = (floorByMaterial[matName] ?? 0.0) + z.areaSqM;
      totalSkirtingM += z.perimeterM;
    }

    final double doorsWidthM = openings
        .where((o) => o.type == OpeningType.door)
        .fold(0.0, (s, d) => s + d.widthMeters);
    final double netSkirtingM = (totalSkirtingM - doorsWidthM).clamp(0.0, double.infinity);
    final double grossWallAreaSqM = totalPerimeter * wallHeightMeters;

    final int doorsCount = openings.where((o) => o.type == OpeningType.door).length;
    final int windowsCount = openings.where((o) => o.type == OpeningType.window).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calculate_outlined, color: Color(0xFF0D99FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Спецификация и смета',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkTheme ? Colors.white : Colors.black87),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: isDarkTheme ? Colors.white60 : Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => showEstimateFlyout = false),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildEstimateRow(Icons.layers_outlined, 'Чистовой пол (по материалам):', ''),
              ...floorByMaterial.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('• ${e.key}', style: TextStyle(fontSize: 11.5, color: isDarkTheme ? Colors.white70 : Colors.black87))),
                        Text('${e.value.toStringAsFixed(2)} м²', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              _buildEstimateRow(Icons.straighten_rounded, 'Плинтус напольный (net):', '${netSkirtingM.toStringAsFixed(2)} пог. м'),
              const SizedBox(height: 6),
              _buildEstimateRow(Icons.view_quilt_outlined, 'Площадь стен под отделку:', '${grossWallAreaSqM.toStringAsFixed(1)} м²'),
              const SizedBox(height: 6),
              _buildEstimateRow(Icons.door_front_door_outlined, 'Дверные блоки:', '$doorsCount шт.'),
              const SizedBox(height: 6),
              _buildEstimateRow(Icons.window_outlined, 'Оконные блоки:', '$windowsCount шт.'),
              const SizedBox(height: 6),
              _buildEstimateRow(Icons.chair_outlined, 'Мебель и элементы интерьера:', '${objects.length} шт.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D99FF)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkTheme ? Colors.white : Colors.black87),
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
          ),
      ],
    );
  }

}


// =========================================================================
// ИНТЕРАКТИВНАЯ СТУДИЯ И КАЛЬКУЛЯТОР РАСКЛАДКИ ПЛИТКИ (ПОЛ + СТЕНЫ ЗОНЫ)
// =========================================================================

enum TileSurfaceMode {
  floor, // Пол комнаты
  roomWalls, // Стены по всему периметру зоны
}

class WallSegmentElevation {
  final int index;
  final String label;
  final double lengthMeters;
  final double startXCm;
  final double endXCm;

  WallSegmentElevation({
    required this.index,
    required this.label,
    required this.lengthMeters,
    required this.startXCm,
    required this.endXCm,
  });
}

class WallOpeningElevation {
  final Rect rect;
  final String label;
  final OpeningType type;

  WallOpeningElevation({
    required this.rect,
    required this.label,
    required this.type,
  });
}

class TileLayoutStudioDialog extends StatefulWidget {
  final RoomZone initialZone;
  final List<RoomZone> allZones;
  final bool isDarkTheme;
  final double wallHeightMeters;
  final List<Wall> allWalls;
  final List<WallOpening> allOpenings;
  final Wall? targetWall;
  final void Function(RoomZone zone, TileLayoutConfig config, bool isWall, {bool applyToAllWalls}) onSave;
  final void Function(RoomZone zone, bool isWall) onReset;
  final void Function(RoomZone zone, TileLayoutConfig config, bool isWall) onExportPdf;

  const TileLayoutStudioDialog({
    super.key,
    required this.initialZone,
    required this.allZones,
    required this.isDarkTheme,
    this.wallHeightMeters = 2.70,
    this.allWalls = const [],
    this.allOpenings = const [],
    this.targetWall,
    required this.onSave,
    required this.onReset,
    required this.onExportPdf,
  });

  @override
  State<TileLayoutStudioDialog> createState() => _TileLayoutStudioDialogState();
}

class _TileLayoutStudioDialogState extends State<TileLayoutStudioDialog> {
  late RoomZone currentZone;
  late TileSurfaceMode surfaceMode;
  late TileLayoutConfig floorConfig;
  late TileLayoutConfig wallConfig;
  late TileLayoutConfig config;
  late TileCalculationReport report;
  bool showCustomGroutPicker = false;
  double customHue = 210.0;
  double customSaturation = 0.2;
  double customValue = 0.7;

  List<WallSegmentElevation> wallSegments = [];
  List<WallOpeningElevation> wallOpenings = [];
  List<Offset> activePolygon = [];

  late TextEditingController wCtrl;
  late TextEditingController hCtrl;
  late TextEditingController jointCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController reserveCtrl;
  late TextEditingController boxCtrl;

  @override
  void initState() {
    super.initState();
    currentZone = widget.initialZone;
    surfaceMode = widget.targetWall != null ? TileSurfaceMode.roomWalls : TileSurfaceMode.floor;

    floorConfig = (currentZone.tileConfig ?? TileLayoutConfig()).clone();
    wallConfig = (currentZone.wallTileConfig ??
            (widget.targetWall?.tileConfig ??
                TileLayoutConfig(
                  tileWidthMm: 300.0,
                  tileHeightMm: 600.0,
                  jointWidthMm: 2.0,
                  pricePerSqM: 2500.0,
                )))
        .clone();

    config = (surfaceMode == TileSurfaceMode.floor ? floorConfig : wallConfig);
    _initControllers();
    _rebuildActivePolygon();
    _recompute();
  }

  void _initControllers() {
    wCtrl = TextEditingController(text: config.tileWidthMm.round().toString());
    hCtrl = TextEditingController(text: config.tileHeightMm.round().toString());
    jointCtrl = TextEditingController(text: config.jointWidthMm.toString());
    priceCtrl = TextEditingController(text: config.pricePerSqM.round().toString());
    reserveCtrl = TextEditingController(text: config.reservePercent.round().toString());
    boxCtrl = TextEditingController(text: config.tilesPerBox.toString());
  }

  @override
  void dispose() {
    wCtrl.dispose();
    hCtrl.dispose();
    jointCtrl.dispose();
    priceCtrl.dispose();
    reserveCtrl.dispose();
    boxCtrl.dispose();
    super.dispose();
  }

  void _rebuildActivePolygon() {
    wallSegments.clear();
    wallOpenings.clear();

    if (surfaceMode == TileSurfaceMode.floor) {
      activePolygon = List.from(currentZone.polygon);
    } else {
      // Wall unwrapping for room perimeter (or single wall)
      if (widget.targetWall != null) {
        final wLenCm = widget.targetWall!.lengthInMeters * 100.0;
        final wHgtCm = widget.wallHeightMeters * 100.0;
        activePolygon = [
          const Offset(0, 0),
          Offset(wLenCm, 0),
          Offset(wLenCm, wHgtCm),
          Offset(0, wHgtCm),
        ];
        wallSegments.add(WallSegmentElevation(
          index: 1,
          label: 'Стена (${widget.targetWall!.lengthInMeters.toStringAsFixed(2)} м)',
          lengthMeters: widget.targetWall!.lengthInMeters,
          startXCm: 0.0,
          endXCm: wLenCm,
        ));
      } else {
        // Unwrapping all perimeter wall segments of the room zone
        final poly = currentZone.polygon;
        double curXCm = 0.0;
        final wallHgtCm = widget.wallHeightMeters * 100.0;

        for (int i = 0; i < poly.length; i++) {
          final p1 = poly[i];
          final p2 = poly[(i + 1) % poly.length];
          final segLenCm = (p2 - p1).distance;
          final segLenM = segLenCm / 100.0;
          if (segLenCm < 5.0) continue;

          final startX = curXCm;
          final endX = curXCm + segLenCm;
          wallSegments.add(WallSegmentElevation(
            index: wallSegments.length + 1,
            label: 'Стена ${wallSegments.length + 1} (${segLenM.toStringAsFixed(2)} м)',
            lengthMeters: segLenM,
            startXCm: startX,
            endXCm: endX,
          ));

          // Find openings along this segment
          for (final op in widget.allOpenings) {
            final segVec = p2 - p1;
            final segLen = segVec.distance;
            if (segLen > 0.001) {
              final segDir = segVec / segLen;
              final opRel = op.position - p1;
              final projDist = opRel.dx * segDir.dx + opRel.dy * segDir.dy;
              final perpDist = (opRel.dx * (-segDir.dy) + opRel.dy * segDir.dx).abs();

              if (perpDist < 25.0 && projDist >= -5.0 && projDist <= segLen + 5.0) {
                final opWidthCm = op.widthMeters * 100.0;
                final opHeightCm = op.heightMeters * 100.0;
                final sillCm = op.sillHeightMeters * 100.0;
                final opLeft = startX + projDist - (opWidthCm / 2.0);
                final opBottom = wallHgtCm - sillCm;
                final opTop = opBottom - opHeightCm;

                wallOpenings.add(WallOpeningElevation(
                  rect: Rect.fromLTWH(opLeft, opTop, opWidthCm, opHeightCm),
                  label: '${op.subtypeName} (${op.widthMeters.toStringAsFixed(2)}×${op.heightMeters.toStringAsFixed(2)} м)',
                  type: op.type,
                ));
              }
            }
          }

          curXCm = endX;
        }

        activePolygon = [
          const Offset(0, 0),
          Offset(curXCm, 0),
          Offset(curXCm, wallHgtCm),
          Offset(0, wallHgtCm),
        ];
      }
    }
  }

  void _recompute() {
    final rawReport = TileLayoutCalculator.calculate(activePolygon, config);

    // If wall mode and we have openings, deduct opening areas from pieces and counts
    if (surfaceMode == TileSurfaceMode.roomWalls && wallOpenings.isNotEmpty) {
      final filteredPieces = <PlacedTilePiece>[];
      int full = 0, large = 0, small = 0, crit = 0;
      double openingsAreaSqM = 0.0;

      for (final op in wallOpenings) {
        openingsAreaSqM += (op.rect.width / 100.0) * (op.rect.height / 100.0);
      }

      for (final p in rawReport.pieces) {
        bool completelyInsideOpening = false;
        bool touchesOpening = false;

        for (final op in wallOpenings) {
          if (op.rect.contains(p.bounds.topLeft) &&
              op.rect.contains(p.bounds.topRight) &&
              op.rect.contains(p.bounds.bottomLeft) &&
              op.rect.contains(p.bounds.bottomRight)) {
            completelyInsideOpening = true;
            break;
          }
          if (op.rect.overlaps(p.bounds)) {
            touchesOpening = true;
          }
        }

        if (completelyInsideOpening) continue;

        var cutType = p.cutType;
        if (touchesOpening && cutType == TileCutType.full) {
          cutType = TileCutType.large;
        }

        switch (cutType) {
          case TileCutType.full:
            full++;
            break;
          case TileCutType.large:
            large++;
            break;
          case TileCutType.small:
            small++;
            break;
          case TileCutType.critical:
            crit++;
            break;
        }

        filteredPieces.add(PlacedTilePiece(
          id: filteredPieces.length + 1,
          col: p.col,
          row: p.row,
          bounds: p.bounds,
          shape: p.shape,
          cutType: cutType,
          areaSqM: p.areaSqM,
          clippedWidthCm: p.clippedWidthCm,
          clippedHeightCm: p.clippedHeightCm,
        ));
      }

      final netWallAreaSqM = math.max(0.1, rawReport.roomAreaSqM - openingsAreaSqM);
      final totalPurchased = math.max(1, (netWallAreaSqM / rawReport.singleTileAreaSqM * (1.0 + config.reservePercent / 100.0)).ceil());
      final totalBoxes = (totalPurchased / math.max(1, config.tilesPerBox)).ceil();
      final grossArea = totalPurchased * rawReport.singleTileAreaSqM;
      final totalCost = grossArea * config.pricePerSqM;
      final adhesiveKg = netWallAreaSqM * config.glueThicknessMm * 1.35;

      report = TileCalculationReport(
        roomAreaSqM: netWallAreaSqM,
        singleTileAreaSqM: rawReport.singleTileAreaSqM,
        totalVisiblePieces: filteredPieces.length,
        fullTiles: full,
        largeCuts: large,
        smallCuts: small,
        criticalCuts: crit,
        totalPurchasedTiles: totalPurchased,
        totalBoxes: totalBoxes,
        grossAreaSqM: grossArea,
        adhesiveKg: adhesiveKg,
        glueThicknessMm: config.glueThicknessMm,
        groutKg: rawReport.groutKg * (netWallAreaSqM / math.max(0.1, rawReport.roomAreaSqM)),
        totalCostRub: totalCost,
        pieces: filteredPieces,
      );
    } else {
      report = rawReport;
    }
  }

  double _getRecommendedJoint(double w, double h) {
    return TileLayoutCalculator.getEstimaRecommendedJointMm(
      isFloor: surfaceMode == TileSurfaceMode.floor,
      material: config.tileMaterial,
      widthMm: w,
      heightMm: h,
    );
  }

  void _switchZone(RoomZone newZone) {
    setState(() {
      currentZone = newZone;
      floorConfig = (currentZone.tileConfig ?? TileLayoutConfig()).clone();
      wallConfig = (currentZone.wallTileConfig ??
              TileLayoutConfig(
                tileWidthMm: 300.0,
                tileHeightMm: 600.0,
                jointWidthMm: 2.0,
                pricePerSqM: 2500.0,
              ))
          .clone();
      config = (surfaceMode == TileSurfaceMode.floor ? floorConfig : wallConfig);
      _initControllers();
      _rebuildActivePolygon();
      _recompute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkTheme;
    final bgCol = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: bgCol,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 750 ? 8 : 24, vertical: MediaQuery.of(context).size.width < 750 ? 8 : 20),
      child: Container(
        width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.width < 750 ? 0.98 : 0.94),
        height: MediaQuery.of(context).size.height * (MediaQuery.of(context).size.width < 750 ? 0.98 : 0.92),
        constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),
        child: Column(
          children: [
            // TOP HEADER
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 750 ? 12 : 20,
                vertical: MediaQuery.of(context).size.width < 750 ? 8 : 12,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: MediaQuery.of(context).size.width < 750
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.grid_view_rounded, color: Color(0xFF0D9488), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Раскладка плитки',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textCol),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: subTextCol),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderCol),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<RoomZone>(
                              value: currentZone,
                              isExpanded: true,
                              dropdownColor: cardBg,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D9488)),
                              items: widget.allZones.map((z) {
                                return DropdownMenuItem<RoomZone>(
                                  value: z,
                                  child: Row(
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 16, color: z.color),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${z.name} (${z.areaSqM.toStringAsFixed(1)} м²)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textCol),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (nz) {
                                if (nz != null) _switchZone(nz);
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: Color(0xFF0D9488), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Мастер умной раскладки плитки и калькулятор',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textCol),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                surfaceMode == TileSurfaceMode.floor
                                    ? 'Раскладка пола: расчет подрезок, швов и сметы материалов'
                                    : 'Развёртка стен по периметру помещения с вычетом дверей и окон',
                                style: TextStyle(fontSize: 12, color: subTextCol),
                              ),
                            ],
                          ),
                        ),
                        // Room dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderCol),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<RoomZone>(
                              value: currentZone,
                              dropdownColor: cardBg,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D9488)),
                              items: widget.allZones.map((z) {
                                return DropdownMenuItem<RoomZone>(
                                  value: z,
                                  child: Row(
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 16, color: z.color),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${z.name} (${z.areaSqM.toStringAsFixed(1)} м²)',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textCol),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (nz) {
                                if (nz != null) _switchZone(nz);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subTextCol),
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
            ),

            // MAIN CONTENT BODY
            Expanded(
              child: LayoutBuilder(
                builder: (context, tileConstraints) {
                  final needScroll = tileConstraints.maxWidth < 950;
                  final content = Row(
                    children: [
                      // LEFT SIDE: PARAMETERS & ESTIMATE (440 px)
                      SizedBox(
                        width: tileConstraints.maxWidth < 750 ? 380 : 440,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderCol)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          // SURFACE MODE SELECTOR (Floor vs Walls)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: SegmentedButton<TileSurfaceMode>(
                              segments: const [
                                ButtonSegment(
                                  value: TileSurfaceMode.floor,
                                  icon: Icon(Icons.crop_square_rounded, size: 16),
                                  label: Text('Пол комнаты'),
                                ),
                                ButtonSegment(
                                  value: TileSurfaceMode.roomWalls,
                                  icon: Icon(Icons.view_carousel_outlined, size: 16),
                                  label: Text('Стены периметра'),
                                ),
                              ],
                              selected: {surfaceMode},
                              onSelectionChanged: (val) {
                                setState(() {
                                  surfaceMode = val.first;
                                  config = (surfaceMode == TileSurfaceMode.floor ? floorConfig : wallConfig);
                                  _initControllers();
                                  _rebuildActivePolygon();
                                  _recompute();
                                });
                              },
                            ),
                          ),

                          // 0. TILE MATERIAL & ESTIMA STANDARDS
                          _buildSectionTitle(Icons.category_rounded, 'Тип материала плитки (по ГОСТ / Estima)', textCol),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<TileMaterialType>(
                            initialValue: config.tileMaterial,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12.5, color: textCol, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(
                                value: TileMaterialType.porcelainRectified,
                                child: Text('Керамогранит ректифицированный (шов 1-2 мм)'),
                              ),
                              DropdownMenuItem(
                                value: TileMaterialType.porcelainClassic,
                                child: Text('Керамогранит классический (шов 2-3.5 мм)'),
                              ),
                              DropdownMenuItem(
                                value: TileMaterialType.ceramicWall,
                                child: Text('Керамическая настенная плитка / Кафель (шов 1.5-2.5 мм)'),
                              ),
                              DropdownMenuItem(
                                value: TileMaterialType.ceramicFloor,
                                child: Text('Керамическая плитка для пола (шов 2.5-4 мм)'),
                              ),
                              DropdownMenuItem(
                                value: TileMaterialType.mosaic,
                                child: Text('Мозаика (шов 1.5-2 мм)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  config.tileMaterial = val;
                                  final rec = _getRecommendedJoint(config.tileWidthMm, config.tileHeightMm);
                                  config.jointWidthMm = rec;
                                  jointCtrl.text = rec.toString();
                                  _recompute();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // 1. TILE DIMENSIONS
                          _buildSectionTitle(Icons.aspect_ratio_rounded, 'Размеры плитки (мм)', textCol),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildSizePresetChip(600, 600, isDark),
                              _buildSizePresetChip(600, 1200, isDark),
                              _buildSizePresetChip(300, 600, isDark),
                              _buildSizePresetChip(200, 600, isDark),
                              _buildSizePresetChip(300, 300, isDark),
                              _buildSizePresetChip(200, 200, isDark),
                              _buildSizePresetChip(1200, 200, isDark),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: wCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Ширина (мм)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    suffixText: 'мм',
                                    labelStyle: TextStyle(color: subTextCol, fontSize: 12),
                                  ),
                                  style: TextStyle(fontSize: 13, color: textCol),
                                  onChanged: (val) {
                                    final d = double.tryParse(val.trim());
                                    if (d != null && d >= 50 && d <= 3000) {
                                      setState(() {
                                        config.tileWidthMm = d;
                                        _recompute();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Поменять ширину и высоту местами (повернуть плитку)',
                                icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488), size: 22),
                                onPressed: () {
                                  setState(() {
                                    final tmp = config.tileWidthMm;
                                    config.tileWidthMm = config.tileHeightMm;
                                    config.tileHeightMm = tmp;
                                    wCtrl.text = config.tileWidthMm.round().toString();
                                    hCtrl.text = config.tileHeightMm.round().toString();
                                    _recompute();
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: hCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Высота (мм)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    suffixText: 'мм',
                                    labelStyle: TextStyle(color: subTextCol, fontSize: 12),
                                  ),
                                  style: TextStyle(fontSize: 13, color: textCol),
                                  onChanged: (val) {
                                    final d = double.tryParse(val.trim());
                                    if (d != null && d >= 50 && d <= 3000) {
                                      setState(() {
                                        config.tileHeightMm = d;
                                        _recompute();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 2. JOINT & GROUT
                          _buildSectionTitle(Icons.border_style_rounded, 'Межплиточный шов и затирка', textCol),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...[1.5, 2.0, 2.5, 3.0, 4.0].map((j) {
                                final isSel = (config.jointWidthMm - j).abs() < 0.1;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('$j мм', style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                    selected: isSel,
                                    selectedColor: const Color(0xFF0D9488),
                                    onSelected: (val) {
                                      setState(() {
                                        config.jointWidthMm = j;
                                        jointCtrl.text = j.toString();
                                        _recompute();
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.recommend_rounded, size: 14, color: Color(0xFF0D9488)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'По СП для ${config.tileWidthMm.round()}×${config.tileHeightMm.round()} мм: рекомендуем ${_getRecommendedJoint(config.tileWidthMm, config.tileHeightMm)} мм',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Цвет затирки швов:', style: TextStyle(fontSize: 12, color: subTextCol)),
                              TextButton.icon(
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                                icon: const Icon(Icons.palette_outlined, size: 14, color: Color(0xFF0D9488)),
                                label: Text(showCustomGroutPicker ? 'Скрыть палитру' : '🎨 Спектр / Любой цвет',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  setState(() => showCustomGroutPicker = !showCustomGroutPicker);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildGroutColorChip(const Color(0xFFFFFFFF), 'Белый', isDark),
                              _buildGroutColorChip(const Color(0xFFCBD5E1), 'Светло-серый', isDark),
                              _buildGroutColorChip(const Color(0xFF94A3B8), 'Серебристый', isDark),
                              _buildGroutColorChip(const Color(0xFF475569), 'Графит', isDark),
                              _buildGroutColorChip(const Color(0xFF1E293B), 'Антрацит', isDark),
                              _buildGroutColorChip(const Color(0xFFF5EBE0), 'Бежевый', isDark),
                              _buildGroutColorChip(const Color(0xFFD4A373), 'Карамель', isDark),
                              _buildGroutColorChip(const Color(0xFF000000), 'Черный', isDark),
                            ],
                          ),
                          if (showCustomGroutPicker) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderCol),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: config.jointColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Выбранный цвет: #${config.jointColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textCol),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Спектр оттенка (Hue):', style: TextStyle(fontSize: 11, color: subTextCol)),
                                  Slider(
                                    value: customHue,
                                    min: 0.0,
                                    max: 360.0,
                                    activeColor: const Color(0xFF0D9488),
                                    onChanged: (val) {
                                      setState(() {
                                        customHue = val;
                                        config.jointColor = HSVColor.fromAHSV(1.0, customHue, customSaturation, customValue).toColor();
                                        _recompute();
                                      });
                                    },
                                  ),
                                  Text('Насыщенность / Яркость:', style: TextStyle(fontSize: 11, color: subTextCol)),
                                  Slider(
                                    value: customValue,
                                    min: 0.1,
                                    max: 1.0,
                                    activeColor: const Color(0xFF0D9488),
                                    onChanged: (val) {
                                      setState(() {
                                        customValue = val;
                                        config.jointColor = HSVColor.fromAHSV(1.0, customHue, customSaturation, customValue).toColor();
                                        _recompute();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // 3. GLUE THICKNESS
                          _buildSectionTitle(Icons.layers_outlined, 'Толщина слоя клея', textCol),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...[3.0, 4.0, 6.0, 8.0, 10.0].map((th) {
                                final isSel = (config.glueThicknessMm - th).abs() < 0.1;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('${th.round()} мм', style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                    selected: isSel,
                                    selectedColor: const Color(0xFF0D9488),
                                    onSelected: (val) {
                                      setState(() {
                                        config.glueThicknessMm = th;
                                        _recompute();
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 4. PATTERN
                          _buildSectionTitle(Icons.dashboard_customize_rounded, 'Схема раскладки', textCol),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildPatternChip(TilePattern.straight, 'Прямая (шов в шов)'),
                              _buildPatternChip(TilePattern.brickHalf, 'Вразбежку 1/2'),
                              _buildPatternChip(TilePattern.brickThird, 'Вразбежку 1/3'),
                              _buildPatternChip(TilePattern.diagonal, 'Диагональ 45°'),
                              _buildPatternChip(TilePattern.herringbone, '«Ёлочка» (паркет)'),
                              _buildPatternChip(TilePattern.checkerboard, 'Шахматная / модульная'),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 5. ALIGNMENT & NUDGE
                          _buildSectionTitle(Icons.filter_center_focus_rounded, 'Привязка (Базовая точка)', textCol),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildAlignChip(TileOriginAlignment.center, '🎯 По центру'),
                              _buildAlignChip(TileOriginAlignment.topLeft, '↖ Левый верх'),
                              _buildAlignChip(TileOriginAlignment.topRight, '↗ Правый верх'),
                              _buildAlignChip(TileOriginAlignment.bottomLeft, '↙ Левый низ'),
                              _buildAlignChip(TileOriginAlignment.bottomRight, '↘ Правый низ'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderCol),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Тонкая подгонка швов:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
                                    Text('X: ${(config.offsetXCm * 10).round()} мм, Y: ${(config.offsetYCm * 10).round()} мм',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('По X: ', style: TextStyle(fontSize: 11)),
                                    _buildNudgeBtn('-50', () => _nudge(-5.0, 0)),
                                    _buildNudgeBtn('-10', () => _nudge(-1.0, 0)),
                                    _buildNudgeBtn('+10', () => _nudge(1.0, 0)),
                                    _buildNudgeBtn('+50', () => _nudge(5.0, 0)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('По Y: ', style: TextStyle(fontSize: 11)),
                                    _buildNudgeBtn('-50', () => _nudge(0, -5.0)),
                                    _buildNudgeBtn('-10', () => _nudge(0, -1.0)),
                                    _buildNudgeBtn('+10', () => _nudge(0, 1.0)),
                                    _buildNudgeBtn('+50', () => _nudge(0, 5.0)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 6. CUT ANALYSIS & QUALITY
                          _buildSectionTitle(Icons.content_cut_rounded, 'Анализ подрезок (Smart Quality)', textCol),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatBadge(const Color(0xFF10B981), 'Целых', '${report.fullTiles}'),
                              const SizedBox(width: 6),
                              _buildStatBadge(const Color(0xFFF59E0B), '>50%', '${report.largeCuts}'),
                              const SizedBox(width: 6),
                              _buildStatBadge(const Color(0xFF3B82F6), '<50%', '${report.smallCuts}'),
                              const SizedBox(width: 6),
                              _buildStatBadge(const Color(0xFFEF4444), '<50 мм', '${report.criticalCuts}'),
                            ],
                          ),
                          if (report.criticalCuts > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Найдено ${report.criticalCuts} узких срезов (< 50 мм). Нажмите «По центру» или сместите раскладку, чтобы избежать сколов!',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Подсвечивать подрезки цветом', style: TextStyle(fontSize: 12)),
                            value: config.showCutColors,
                            onChanged: (val) {
                              setState(() {
                                config.showCutColors = val ?? true;
                              });
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Показывать номера и размеры плиток', style: TextStyle(fontSize: 12)),
                            value: config.showTileNumbers,
                            onChanged: (val) {
                              setState(() {
                                config.showTileNumbers = val ?? false;
                              });
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Показывать базовую точку (0,0)', style: TextStyle(fontSize: 12)),
                            value: config.showBasePointMarker,
                            onChanged: (val) {
                              setState(() {
                                config.showBasePointMarker = val ?? true;
                              });
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Фоновая координатная сетка', style: TextStyle(fontSize: 12)),
                            value: config.showStudioGrid,
                            onChanged: (val) {
                              setState(() {
                                config.showStudioGrid = val ?? false;
                              });
                            },
                          ),

                          const SizedBox(height: 18),

                          // 7. MATERIAL ESTIMATE
                          _buildSectionTitle(Icons.receipt_long_rounded, 'Ведомость материалов и смета', textCol),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderCol),
                            ),
                            child: Column(
                              children: [
                                _buildEstimateRow(
                                    surfaceMode == TileSurfaceMode.floor ? 'Площадь пола:' : 'Площадь стен (чистая):',
                                    '${report.roomAreaSqM.toStringAsFixed(2)} м²',
                                    textCol),
                                const Divider(height: 12),
                                _buildEstimateRow('Заказ плитки (+${config.reservePercent.round()}%):',
                                    '${report.totalPurchasedTiles} шт (${report.totalBoxes} кор. / ${report.grossAreaSqM.toStringAsFixed(2)} м²)', textCol, isBold: true),
                                const Divider(height: 12),
                                _buildEstimateRow('Плиточный клей (~${config.glueThicknessMm.round()} мм слой):',
                                    '${report.adhesiveKg.toStringAsFixed(1)} кг (~${(report.adhesiveKg / 25).ceil()} меш. по 25 кг)', textCol),
                                const Divider(height: 12),
                                _buildEstimateRow('Затирка швов (${config.jointWidthMm} мм):', '${report.groutKg.toStringAsFixed(2)} кг', textCol),
                                const Divider(height: 12),
                                if (report.svpClipsCount > 0) ...[
                                  _buildEstimateRow('СВП: Зажимы (одноразовые):', '${report.svpClipsCount} шт (~${report.svpClipsPacks} упак. по 250 шт)', textCol),
                                  const Divider(height: 12),
                                  _buildEstimateRow('СВП: Клинья (многоразовые):', '${report.svpWedgesCount} шт', textCol),
                                  const Divider(height: 12),
                                ],
                                _buildEstimateRow('Дистанционные крестики (${config.jointWidthMm} мм):', '${report.crossSpacersCount} шт (~${report.crossSpacersPacks} упак. по 300 шт)', textCol),
                                const Divider(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: priceCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Цена плитки (₽/м²)',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                          labelStyle: TextStyle(color: subTextCol, fontSize: 11),
                                        ),
                                        style: TextStyle(fontSize: 12, color: textCol),
                                        onChanged: (val) {
                                          final p = double.tryParse(val.trim());
                                          if (p != null) {
                                            setState(() {
                                              config.pricePerSqM = p;
                                              _recompute();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: reserveCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Запас плитки (%)',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                          labelStyle: TextStyle(color: subTextCol, fontSize: 11),
                                        ),
                                        style: TextStyle(fontSize: 12, color: textCol),
                                        onChanged: (val) {
                                          final r = double.tryParse(val.trim());
                                          if (r != null) {
                                            setState(() {
                                              config.reservePercent = r;
                                              _recompute();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 14),
                                _buildEstimateRow('Итого стоимость плитки:', '${report.totalCostRub.toStringAsFixed(0)} ₽', const Color(0xFF0D9488), isBold: true, fontSize: 14),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // RIGHT SIDE: INTERACTIVE CANVAS
                  Expanded(
                    child: Column(
                      children: [
                        // Tool strip above canvas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: borderCol)),
                            color: cardBg.withValues(alpha: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                surfaceMode == TileSurfaceMode.floor ? Icons.crop_square_rounded : Icons.view_carousel_outlined,
                                size: 16,
                                color: const Color(0xFF0D9488),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  surfaceMode == TileSurfaceMode.floor
                                      ? 'План пола: кликните в любую точку комнаты для установки привязки (0,0)'
                                      : 'Развёртка стен: показаны все стены по периметру, проёмы дверей и окон с вычетом из сметы',
                                  style: TextStyle(fontSize: 12, color: subTextCol),
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                label: Text(surfaceMode == TileSurfaceMode.floor ? 'PDF плана пола' : 'PDF развёртки стен'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  foregroundColor: const Color(0xFF0284C7),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                ),
                                onPressed: () {
                                  widget.onExportPdf(currentZone, config, surfaceMode == TileSurfaceMode.roomWalls);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Interactive CustomPaint Canvas
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                onTapUp: (details) {
                                  _handleCanvasTap(details.localPosition, Size(constraints.maxWidth, constraints.maxHeight));
                                },
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, constraints.maxHeight),
                                  painter: TileStudioInteractivePainter(
                                    polygon: activePolygon,
                                    config: config,
                                    report: report,
                                    isDark: isDark,
                                    isWallMode: surfaceMode == TileSurfaceMode.roomWalls,
                                    wallSegments: wallSegments,
                                    wallOpenings: wallOpenings,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Bottom Actions Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: borderCol)),
                            color: cardBg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                label: Text(
                                  surfaceMode == TileSurfaceMode.floor ? 'Сбросить плитку пола' : 'Сбросить плитку стен',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                                onPressed: () {
                                  widget.onReset(currentZone, surfaceMode == TileSurfaceMode.roomWalls);
                                  Navigator.pop(context);
                                },
                              ),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Отмена'),
                                  ),
                                  const SizedBox(width: 12),
                                  if (surfaceMode == TileSurfaceMode.roomWalls) ...[
                                    if (widget.targetWall != null) ...[
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F766E),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                        icon: const Icon(Icons.crop_square_rounded, size: 16),
                                        label: const Text('Применить к текущей стене', style: TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          widget.onSave(currentZone, config, true, applyToAllWalls: false);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D9488),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.select_all_rounded, size: 16),
                                      label: const Text('Применить ко всем стенам', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        widget.onSave(currentZone, config, true, applyToAllWalls: true);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ] else ...[
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D9488),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                      label: const Text('Применить к полу', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        widget.onSave(currentZone, config, false, applyToAllWalls: false);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              return needScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: 960,
                        child: content,
                      ),
                    )
                  : content;
            },
          ),
        ),
      ],
    ),
  ),
);
  }

  void _handleCanvasTap(Offset tapPos, Size size) {
    if (activePolygon.length < 3) return;
    double minX = activePolygon.first.dx, maxX = activePolygon.first.dx;
    double minY = activePolygon.first.dy, maxY = activePolygon.first.dy;
    for (final p in activePolygon) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final roomW = math.max(1.0, maxX - minX);
    final roomH = math.max(1.0, maxY - minY);
    const pad = 70.0;
    final scaleX = (size.width - pad * 2) / roomW;
    final scaleY = (size.height - pad * 2) / roomH;
    final scale = math.min(scaleX, scaleY).clamp(0.01, 10.0);
    final offsetX = (size.width - roomW * scale) / 2.0 - minX * scale;
    final offsetY = (size.height - roomH * scale) / 2.0 - minY * scale;

    final worldX = (tapPos.dx - offsetX) / scale;
    final worldY = (tapPos.dy - offsetY) / scale;

    setState(() {
      config.originAlignment = TileOriginAlignment.custom;
      config.offsetXCm = worldX - minX;
      config.offsetYCm = worldY - minY;
      _recompute();
    });
  }

  void _nudge(double dxCm, double dyCm) {
    setState(() {
      config.originAlignment = TileOriginAlignment.custom;
      config.offsetXCm += dxCm;
      config.offsetYCm += dyCm;
      _recompute();
    });
  }

  Widget _buildSectionTitle(IconData icon, String title, Color textCol) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textCol)),
      ],
    );
  }

  Widget _buildSizePresetChip(int w, int h, bool isDark) {
    final isSel = (config.tileWidthMm.round() == w && config.tileHeightMm.round() == h);
    return ActionChip(
      label: Text('$w×$h', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      backgroundColor: isSel ? const Color(0xFF0D9488).withValues(alpha: 0.2) : null,
      side: BorderSide(color: isSel ? const Color(0xFF0D9488) : (isDark ? Colors.white24 : Colors.black12)),
      onPressed: () {
        setState(() {
          config.tileWidthMm = w.toDouble();
          config.tileHeightMm = h.toDouble();
          wCtrl.text = w.toString();
          hCtrl.text = h.toString();
          final rec = _getRecommendedJoint(w.toDouble(), h.toDouble());
          config.jointWidthMm = rec;
          jointCtrl.text = rec.toString();
          _recompute();
        });
      },
    );
  }

  Widget _buildGroutColorChip(Color color, String name, bool isDark) {
    final isSel = config.jointColor == color;
    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: () {
          setState(() {
            config.jointColor = color;
            _recompute();
          });
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSel ? const Color(0xFF0D9488) : (isDark ? Colors.white38 : Colors.black26),
              width: isSel ? 2.5 : 1.0,
            ),
          ),
          child: isSel ? const Icon(Icons.check, size: 14, color: Color(0xFF0D9488)) : null,
        ),
      ),
    );
  }

  Widget _buildPatternChip(TilePattern pat, String name) {
    final isSel = config.pattern == pat;
    return ChoiceChip(
      label: Text(name, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      selected: isSel,
      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.25),
      onSelected: (val) {
        setState(() {
          config.pattern = pat;
          _recompute();
        });
      },
    );
  }

  Widget _buildAlignChip(TileOriginAlignment align, String name) {
    final isSel = config.originAlignment == align;
    return ChoiceChip(
      label: Text(name, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      selected: isSel,
      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.25),
      onSelected: (val) {
        setState(() {
          config.originAlignment = align;
          config.offsetXCm = 0.0;
          config.offsetYCm = 0.0;
          _recompute();
        });
      },
    );
  }

  Widget _buildNudgeBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
        ),
      ),
    );
  }

  Widget _buildStatBadge(Color color, String title, String count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateRow(String label, String value, Color textCol, {bool isBold = false, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: isBold ? textCol : textCol.withValues(alpha: 0.75))),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: textCol)),
      ],
    );
  }
}

class TileStudioInteractivePainter extends CustomPainter {
  final List<Offset> polygon;
  final TileLayoutConfig config;
  final TileCalculationReport report;
  final bool isDark;
  final bool isWallMode;
  final List<WallSegmentElevation> wallSegments;
  final List<WallOpeningElevation> wallOpenings;

  TileStudioInteractivePainter({
    required this.polygon,
    required this.config,
    required this.report,
    required this.isDark,
    this.isWallMode = false,
    this.wallSegments = const [],
    this.wallOpenings = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 3) return;

    double minX = polygon.first.dx, maxX = polygon.first.dx;
    double minY = polygon.first.dy, maxY = polygon.first.dy;
    for (final p in polygon) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final roomW = math.max(1.0, maxX - minX);
    final roomH = math.max(1.0, maxY - minY);

    const pad = 70.0;
    final scaleX = (size.width - pad * 2) / roomW;
    final scaleY = (size.height - pad * 2) / roomH;
    final scale = math.min(scaleX, scaleY).clamp(0.01, 10.0);

    final offsetX = (size.width - roomW * scale) / 2.0 - minX * scale;
    final offsetY = (size.height - roomH * scale) / 2.0 - minY * scale;

    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (config.showStudioGrid) {
      final gridPaint = Paint()
        ..color = isDark ? const Color(0x15FFFFFF) : const Color(0x15000000)
        ..strokeWidth = 1.0;
      for (double x = 0; x <= size.width; x += 30.0) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y <= size.height; y += 30.0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final roomPath = Path()..addPolygon(polygon, true);

    final baseFloorPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    canvas.drawPath(roomPath, baseFloorPaint);

    canvas.save();
    canvas.clipPath(roomPath);

    final jointPaint = Paint()
      ..color = config.jointColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0 / scale, config.jointWidthMm / 10.0);

    final fullPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.fill;
    final largePaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.fill;
    final smallPaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.fill;
    final critPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.65 : 0.55)
      ..style = PaintingStyle.fill;
    final neutralPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    for (final piece in report.pieces) {
      if (config.showCutColors) {
        Paint p;
        switch (piece.cutType) {
          case TileCutType.full:
            p = fullPaint;
            break;
          case TileCutType.large:
            p = largePaint;
            break;
          case TileCutType.small:
            p = smallPaint;
            break;
          case TileCutType.critical:
            p = critPaint;
            break;
        }
        canvas.drawRect(piece.bounds, p);
      } else {
        canvas.drawRect(piece.bounds, neutralPaint);
      }

      canvas.drawRect(piece.bounds, jointPaint);

      if (piece.cutType == TileCutType.critical) {
        final alertBorder = Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / scale;
        canvas.drawRect(piece.bounds, alertBorder);
      }

      if (config.showTileNumbers) {
        final fontSize = (10.0 / scale).clamp(4.0, 14.0);
        String label = '${piece.id}';
        if (piece.cutType != TileCutType.full) {
          final wMm = (piece.clippedWidthCm * 10).round();
          final hMm = (piece.clippedHeightCm * 10).round();
          label = '${piece.id}\n$wMm×$hMm';
        }
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, piece.bounds.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // In Wall Mode: draw door/window cutouts
    if (isWallMode) {
      for (final op in wallOpenings) {
        final opBg = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
        canvas.drawRect(op.rect, opBg);
        final opBorder = Paint()
          ..color = op.type == OpeningType.door ? const Color(0xFFD97706) : const Color(0xFF0284C7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / scale;
        canvas.drawRect(op.rect, opBorder);

        final opTp = TextPainter(
          text: TextSpan(
            text: op.label,
            style: TextStyle(
              fontSize: (11.0 / scale).clamp(6.0, 14.0),
              fontWeight: FontWeight.bold,
              color: op.type == OpeningType.door ? const Color(0xFFD97706) : const Color(0xFF0284C7),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        opTp.paint(canvas, op.rect.center - Offset(opTp.width / 2, opTp.height / 2));
      }
    }

    canvas.restore(); // Restore clip

    // Room wall perimeter
    final wallBorderPaint = Paint()
      ..color = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 / scale
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(roomPath, wallBorderPaint);

    // In Wall Mode: draw dividers between walls
    if (isWallMode && wallSegments.length > 1) {
      final divPaint = Paint()
        ..color = const Color(0xFF0D9488)
        ..strokeWidth = 2.0 / scale;

      for (int i = 0; i < wallSegments.length; i++) {
        final seg = wallSegments[i];
        if (i > 0) {
          canvas.drawLine(Offset(seg.startXCm, minY), Offset(seg.startXCm, maxY), divPaint);
        }
        final segTp = TextPainter(
          text: TextSpan(
            text: seg.label,
            style: TextStyle(
              fontSize: (11.0 / scale).clamp(7.0, 14.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D9488),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        segTp.paint(canvas, Offset((seg.startXCm + seg.endXCm) / 2 - segTp.width / 2, minY + 6.0 / scale));
      }
    }

    // Draw base point only if showBasePointMarker is true
    if (config.showBasePointMarker) {
      final anchorPt = Offset(minX + config.offsetXCm, minY + config.offsetYCm);
      final anchorRadius = 8.0 / scale;
      final anchorPaint = Paint()
        ..color = const Color(0xFF06B6D4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchorPt, anchorRadius, anchorPaint);
      canvas.drawCircle(
        anchorPt,
        anchorRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scale,
      );

      final chLen = 14.0 / scale;
      final chPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8 / scale;
      canvas.drawLine(anchorPt - Offset(chLen, 0), anchorPt + Offset(chLen, 0), chPaint);
      canvas.drawLine(anchorPt - Offset(0, chLen), anchorPt + Offset(0, chLen), chPaint);

      final anchorTp = TextPainter(
        text: TextSpan(
          text: '🎯 (0,0)',
          style: TextStyle(
            fontSize: (11.0 / scale).clamp(6.0, 14.0),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF06B6D4),
            backgroundColor: isDark ? Colors.black87 : Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      anchorTp.paint(canvas, anchorPt + Offset(anchorRadius + 2.0 / scale, -anchorTp.height / 2));
    }

    final dimPaint = Paint()
      ..color = isDark ? Colors.cyanAccent : const Color(0xFF0284C7)
      ..strokeWidth = 1.5 / scale;
    final dimTextSize = (11.0 / scale).clamp(6.0, 14.0);

    final topDimY = minY - 24.0 / scale;
    canvas.drawLine(Offset(minX, topDimY), Offset(maxX, topDimY), dimPaint);
    canvas.drawLine(Offset(minX, topDimY - 6.0 / scale), Offset(minX, topDimY + 6.0 / scale), dimPaint);
    canvas.drawLine(Offset(maxX, topDimY - 6.0 / scale), Offset(maxX, topDimY + 6.0 / scale), dimPaint);
    final topTp = TextPainter(
      text: TextSpan(
        text: isWallMode
            ? 'Периметр стен: ${(roomW * 10).round()} мм (${(roomW / 100).toStringAsFixed(2)} м)'
            : '${(roomW * 10).round()} мм (${(roomW / 100).toStringAsFixed(2)} м)',
        style: TextStyle(
          fontSize: dimTextSize,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    topTp.paint(canvas, Offset((minX + maxX) / 2 - topTp.width / 2, topDimY - topTp.height - 2.0 / scale));

    final leftDimX = minX - 24.0 / scale;
    canvas.drawLine(Offset(leftDimX, minY), Offset(leftDimX, maxY), dimPaint);
    canvas.drawLine(Offset(leftDimX - 6.0 / scale, minY), Offset(leftDimX + 6.0 / scale, minY), dimPaint);
    canvas.drawLine(Offset(leftDimX - 6.0 / scale, maxY), Offset(leftDimX + 6.0 / scale, maxY), dimPaint);
    final leftTp = TextPainter(
      text: TextSpan(
        text: isWallMode
            ? 'Высота: ${(roomH * 10).round()} мм (${(roomH / 100).toStringAsFixed(2)} м)'
            : '${(roomH * 10).round()} мм (${(roomH / 100).toStringAsFixed(2)} м)',
        style: TextStyle(
          fontSize: dimTextSize,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    leftTp.paint(canvas, Offset(leftDimX - leftTp.width - 4.0 / scale, (minY + maxY) / 2 - leftTp.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileStudioInteractivePainter oldDelegate) => true;
}

class _SingleTexturePreviewPainter extends CustomPainter {
  final ui.Image image;
  _SingleTexturePreviewPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(0.45, 0.45, 1.0, 1.0)).storage,
      );
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);
}

class _WallHitPolygon3D {
  final Wall wall;
  final int sideSign;
  final List<Offset> screenQuad;
  final double depth;
  _WallHitPolygon3D(this.wall, this.sideSign, this.screenQuad, this.depth);
}

class _Face3D {
  final List<Offset> screenPoints;
  final double depth;
  final Color color;
  final Color? borderColor;
  final ui.Shader? textureShader;
  final String? label;
  final Wall? sourceWall;
  final int wallSideSign;

  _Face3D({
    required this.screenPoints,
    required this.depth,
    required this.color,
    this.borderColor,
    this.textureShader,
    this.label,
    this.sourceWall,
    this.wallSideSign = 0,
  });
}

ui.Shader _createPerspectiveWallTextureShader({
  required ui.Image image,
  required Offset pBottomLeft,
  required Offset pBottomRight,
  required Offset pTopLeft,
  required double lengthMeters,
  required double heightMeters,
}) {
  const double tileSizeMeters = 1.6;
  final double uSpanPx = math.max(1.0, (lengthMeters / tileSizeMeters) * image.width);
  final double vSpanPx = math.max(1.0, (heightMeters / tileSizeMeters) * image.height);

  final Offset dU = (pBottomRight - pBottomLeft) / uSpanPx;
  final Offset dV = (pBottomLeft - pTopLeft) / vSpanPx;

  final Float64List m = Float64List(16);
  m[0] = dU.dx;
  m[1] = dU.dy;
  m[4] = dV.dx;
  m[5] = dV.dy;
  m[10] = 1.0;
  m[12] = pTopLeft.dx;
  m[13] = pTopLeft.dy;
  m[15] = 1.0;

  return ui.ImageShader(
    image,
    ui.TileMode.repeated,
    ui.TileMode.repeated,
    m,
  );
}

class Isometric3DPlanPainter extends CustomPainter {
  final List<Wall> walls;
  final List<RoomZone> zones;
  final List<WallOpening> openings;
  final List<InteriorObject> objects;
  final Map<String, ui.Image> loadedImages;
  final Map<String, Parsed3DMesh> loaded3DMeshes;
  final Wall? selectedWall;
  final int? selectedWallSide;
  final InteriorObject? selectedObject;
  final WallViewMode3D wallViewMode;
  final List<_WallHitPolygon3D> wallHitPolygonsOut;
  final double wallHeightMeters;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset panOffset;
  final bool showZonesLayer;

  Isometric3DPlanPainter({
    required this.walls,
    required this.zones,
    required this.openings,
    required this.objects,
    required this.loadedImages,
    required this.loaded3DMeshes,
    required this.selectedWall,
    required this.selectedWallSide,
    required this.selectedObject,
    required this.wallViewMode,
    required this.wallHitPolygonsOut,
    required this.wallHeightMeters,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.panOffset,
    this.showZonesLayer = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    wallHitPolygonsOut.clear();

    double minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
    for (final w in walls) {
      minX = math.min(minX, math.min(w.start.dx, w.end.dx));
      minY = math.min(minY, math.min(w.start.dy, w.end.dy));
      maxX = math.max(maxX, math.max(w.start.dx, w.end.dx));
      maxY = math.max(maxY, math.max(w.start.dy, w.end.dy));
    }
    if (minX > maxX) {
      minX = 0;
      minY = 0;
      maxX = 600;
      maxY = 400;
    }
    final Offset pivot = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final Offset screenCenter = Offset(size.width / 2, size.height / 2 + 60) + panOffset;

    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);
    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);

    (Offset, double) project(_Vec3 pt) {
      final double dx = (pt.x - pivot.dx) * zoom;
      final double dy = (pt.y - pivot.dy) * zoom;
      final double dz = pt.z * zoom;

      final double rx = dx * cosY - dy * sinY;
      final double ry = dx * sinY + dy * cosY;

      final double sx = screenCenter.dx + rx;
      final double sy = screenCenter.dy + ry * sinP - dz * cosP;
      final double depth = ry * cosP + dz * sinP;
      return (Offset(sx, sy), depth);
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    for (double gx = ((minX - 300) ~/ 100) * 100.0; gx <= maxX + 300; gx += 100.0) {
      final p1 = project(_Vec3(gx, minY - 300, 0)).$1;
      final p2 = project(_Vec3(gx, maxY + 300, 0)).$1;
      canvas.drawLine(p1, p2, gridPaint);
    }
    for (double gy = ((minY - 300) ~/ 100) * 100.0; gy <= maxY + 300; gy += 100.0) {
      final p1 = project(_Vec3(minX - 300, gy, 0)).$1;
      final p2 = project(_Vec3(maxX + 300, gy, 0)).$1;
      canvas.drawLine(p1, p2, gridPaint);
    }

    for (final zone in zones) {
      if (zone.polygon.length < 3) continue;
      final path = Path();
      for (int i = 0; i < zone.polygon.length; i++) {
        final pt = project(_Vec3(zone.polygon[i].dx, zone.polygon[i].dy, 0)).$1;
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();

      final floorPaint = Paint();
      final zoneImg = _resolveTextureImage(zone.textureId, loadedImages);
      if (zoneImg != null) {
        final img = zoneImg;
        final p0 = project(_Vec3(pivot.dx, pivot.dy, 0)).$1;
        final pX = project(_Vec3(pivot.dx + 250.0, pivot.dy, 0)).$1;
        final pY = project(_Vec3(pivot.dx, pivot.dy + 250.0, 0)).$1;

        final dU = (pX - p0) / img.width.toDouble();
        final dV = (pY - p0) / img.height.toDouble();
        final Float64List m = Float64List(16);
        m[0] = dU.dx;
        m[1] = dU.dy;
        m[4] = dV.dx;
        m[5] = dV.dy;
        m[10] = 1.0;
        m[12] = p0.dx;
        m[13] = p0.dy;
        m[15] = 1.0;

        floorPaint.shader = ui.ImageShader(
          img,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          m,
        );
      } else {
        floorPaint.color = zone.color.withValues(alpha: 0.78);
      }

      canvas.drawPath(path, floorPaint);

      // Отрисовка раскладки плитки пола в 3D
      if (zone.tileConfig != null) {
        final floorCfg = zone.tileConfig!;
        final floorReport = TileLayoutCalculator.calculate(zone.polygon, floorCfg);
        if (floorReport.pieces.isNotEmpty) {
          canvas.save();
          canvas.clipPath(path);
          final jointStroke = Paint()
            ..color = floorCfg.jointColor.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          for (final piece in floorReport.pieces) {
            final p1 = project(_Vec3(piece.bounds.left, piece.bounds.top, 0)).$1;
            final p2 = project(_Vec3(piece.bounds.right, piece.bounds.top, 0)).$1;
            final p3 = project(_Vec3(piece.bounds.right, piece.bounds.bottom, 0)).$1;
            final p4 = project(_Vec3(piece.bounds.left, piece.bounds.bottom, 0)).$1;
            final piecePath = Path()
              ..moveTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy)
              ..lineTo(p3.dx, p3.dy)
              ..lineTo(p4.dx, p4.dy)
              ..close();
            canvas.drawPath(piecePath, jointStroke);
          }
          canvas.restore();
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white30
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final List<_Face3D> allFaces = [];

    void addWallSegment3D({
      required Wall wall,
      required Offset p1,
      required Offset p2,
      required double zBottom,
      required double zTop,
    }) {
      if (zTop <= zBottom + 0.5) return;
      final vec = p2 - p1;
      final len = vec.distance;
      if (len < 1.0) return;
      final dir = vec / len;
      final normal = Offset(-dir.dy, dir.dx) * (wall.thicknessCm / 2.0);

      final c1 = p1 + normal;
      final c2 = p2 + normal;
      final c3 = p2 - normal;
      final c4 = p1 - normal;

      final b1 = _Vec3(c1.dx, c1.dy, zBottom);
      final b2 = _Vec3(c2.dx, c2.dy, zBottom);
      final b3 = _Vec3(c3.dx, c3.dy, zBottom);
      final b4 = _Vec3(c4.dx, c4.dy, zBottom);

      final t1 = _Vec3(c1.dx, c1.dy, zTop);
      final t2 = _Vec3(c2.dx, c2.dy, zTop);
      final t3 = _Vec3(c3.dx, c3.dy, zTop);
      final t4 = _Vec3(c4.dx, c4.dy, zTop);

      final double segLenM = len / 100.0;
      final double segHeightM = (zTop - zBottom) / 100.0;

      final ui.Image? imgSideA = (wall.textureSideA != null) ? loadedImages[wall.textureSideA] : null;
      final ui.Image? imgSideB = (wall.textureSideB != null) ? loadedImages[wall.textureSideB] : null;

      final bool isSelA = (wall == selectedWall && (selectedWallSide == null || selectedWallSide! >= 0));
      final bool isSelB = (wall == selectedWall && (selectedWallSide != null && selectedWallSide! < 0));

      final (startDed, endDed) = calcWallDeductions(wall, walls);
      final double totalWallLenPx = (wall.end - wall.start).distance;
      final double sClear = startDed;
      final double eClear = math.max(sClear, totalWallLenPx - endDed);

      final double segD1 = (p1 - wall.start).distance;
      final double segD2 = (p2 - wall.start).distance;
      final double sHigh = math.max(segD1, sClear);
      final double eHigh = math.min(segD2, eClear);
      final bool hasClearHighlight = (eHigh > sHigh + 0.5);

      {
        final prB1 = project(b1);
        final prB2 = project(b2);
        final prT2 = project(t2);
        final prT1 = project(t1);
        final avgDepth = (prB1.$2 + prB2.$2 + prT2.$2 + prT1.$2) / 4.0;

        ui.Shader? shaderA;
        if (imgSideA != null) {
          shaderA = _createPerspectiveWallTextureShader(
            image: imgSideA,
            pBottomLeft: prB1.$1,
            pBottomRight: prB2.$1,
            pTopLeft: prT1.$1,
            lengthMeters: segLenM,
            heightMeters: segHeightM,
          );
        }

        // Базовая плоскость стены (нейтральная отделка/текстура)
        allFaces.add(_Face3D(
          screenPoints: [prB1.$1, prB2.$1, prT2.$1, prT1.$1],
          depth: avgDepth,
          color: const Color(0xFFE2E8F0),
          borderColor: Colors.black26,
          textureShader: shaderA,
          sourceWall: !isSelA ? wall : null,
          wallSideSign: 1,
        ));

        // Выделение только в границах чистой видимой поверхности (без нахлеста на соседние стены)
        if (isSelA && hasClearHighlight) {
          final pA = wall.start + dir * sHigh;
          final pB = wall.start + dir * eHigh;
          final cA1 = pA + normal;
          final cA2 = pB + normal;
          final bA1 = _Vec3(cA1.dx, cA1.dy, zBottom);
          final bA2 = _Vec3(cA2.dx, cA2.dy, zBottom);
          final tA2 = _Vec3(cA2.dx, cA2.dy, zTop);
          final tA1 = _Vec3(cA1.dx, cA1.dy, zTop);
          final pB1 = project(bA1);
          final pB2 = project(bA2);
          final pT2 = project(tA2);
          final pT1 = project(tA1);
          allFaces.add(_Face3D(
            screenPoints: [pB1.$1, pB2.$1, pT2.$1, pT1.$1],
            depth: (pB1.$2 + pB2.$2 + pT2.$2 + pT1.$2) / 4.0 - 0.05,
            color: const Color(0xFFFDE047),
            borderColor: const Color(0xFFD97706),
            sourceWall: wall,
            wallSideSign: 1,
          ));
        }
      }

      {
        final prB3 = project(b3);
        final prB4 = project(b4);
        final prT4 = project(t4);
        final prT3 = project(t3);
        final avgDepth = (prB3.$2 + prB4.$2 + prT4.$2 + prT3.$2) / 4.0;

        ui.Shader? shaderB;
        if (imgSideB != null) {
          shaderB = _createPerspectiveWallTextureShader(
            image: imgSideB,
            pBottomLeft: prB3.$1,
            pBottomRight: prB4.$1,
            pTopLeft: prT3.$1,
            lengthMeters: segLenM,
            heightMeters: segHeightM,
          );
        }

        allFaces.add(_Face3D(
          screenPoints: [prB3.$1, prB4.$1, prT4.$1, prT3.$1],
          depth: avgDepth,
          color: const Color(0xFFCBD5E1),
          borderColor: Colors.black26,
          textureShader: shaderB,
          sourceWall: !isSelB ? wall : null,
          wallSideSign: -1,
        ));

        if (isSelB && hasClearHighlight) {
          final pA = wall.start + dir * sHigh;
          final pB = wall.start + dir * eHigh;
          final cB1 = pB - normal;
          final cB2 = pA - normal;
          final bB1 = _Vec3(cB1.dx, cB1.dy, zBottom);
          final bB2 = _Vec3(cB2.dx, cB2.dy, zBottom);
          final tB2 = _Vec3(cB2.dx, cB2.dy, zTop);
          final tB1 = _Vec3(cB1.dx, cB1.dy, zTop);
          final pB1 = project(bB1);
          final pB2 = project(bB2);
          final pT2 = project(tB2);
          final pT1 = project(tB1);
          allFaces.add(_Face3D(
            screenPoints: [pB1.$1, pB2.$1, pT2.$1, pT1.$1],
            depth: (pB1.$2 + pB2.$2 + pT2.$2 + pT1.$2) / 4.0 - 0.05,
            color: const Color(0xFFFDE047),
            borderColor: const Color(0xFFD97706),
            sourceWall: wall,
            wallSideSign: -1,
          ));
        }
      }

      void pushCap(_Vec3 v1, _Vec3 v2, _Vec3 v3, _Vec3 v4, Color col) {
        final pr1 = project(v1);
        final pr2 = project(v2);
        final pr3 = project(v3);
        final pr4 = project(v4);
        allFaces.add(_Face3D(
          screenPoints: [pr1.$1, pr2.$1, pr3.$1, pr4.$1],
          depth: (pr1.$2 + pr2.$2 + pr3.$2 + pr4.$2) / 4.0,
          color: col,
          borderColor: Colors.black26,
        ));
      }

      // Не отрисовываем торцевые заглушки в местах стыковки и внешних углов стен
      final bool connectsAtP2 = (p2 == wall.end) && walls.any((w) => !identical(w, wall) && ((w.start - p2).distance < 12.0 || (w.end - p2).distance < 12.0));
      final bool connectsAtP1 = (p1 == wall.start) && walls.any((w) => !identical(w, wall) && ((w.start - p1).distance < 12.0 || (w.end - p1).distance < 12.0));

      if (!connectsAtP2) {
        pushCap(b2, b3, t3, t2, const Color(0xFFCBD5E1));
      }
      if (!connectsAtP1) {
        pushCap(b4, b1, t1, t4, const Color(0xFFCBD5E1));
      }
      pushCap(t1, t2, t3, t4, const Color(0xFFF8FAFC));
    }

    void addPrismBox(
      Offset p1,
      Offset p2,
      double thickness,
      double zBottom,
      double zTop,
      Color baseColor, {
      String? topLabel,
      Color? stroke,
    }) {
      if (zTop <= zBottom + 0.5) return;
      final vec = p2 - p1;
      final len = vec.distance;
      if (len < 1.0) return;
      final dir = vec / len;
      final normal = Offset(-dir.dy, dir.dx) * (thickness / 2.0);

      final c1 = p1 + normal;
      final c2 = p2 + normal;
      final c3 = p2 - normal;
      final c4 = p1 - normal;

      final b1 = _Vec3(c1.dx, c1.dy, zBottom);
      final b2 = _Vec3(c2.dx, c2.dy, zBottom);
      final b3 = _Vec3(c3.dx, c3.dy, zBottom);
      final b4 = _Vec3(c4.dx, c4.dy, zBottom);

      final t1 = _Vec3(c1.dx, c1.dy, zTop);
      final t2 = _Vec3(c2.dx, c2.dy, zTop);
      final t3 = _Vec3(c3.dx, c3.dy, zTop);
      final t4 = _Vec3(c4.dx, c4.dy, zTop);

      final hsl = HSLColor.fromColor(baseColor);
      final sideLight = hsl.withLightness((hsl.lightness * 0.92).clamp(0.1, 0.95)).toColor();
      final sideDark = hsl.withLightness((hsl.lightness * 0.74).clamp(0.08, 0.90)).toColor();
      final topCap = hsl.withLightness((hsl.lightness * 1.08).clamp(0.15, 0.98)).toColor();
      final border = stroke ?? Colors.black.withValues(alpha: 0.30);

      void pushQuad(_Vec3 v1, _Vec3 v2, _Vec3 v3, _Vec3 v4, Color col, {String? lbl}) {
        final pr1 = project(v1);
        final pr2 = project(v2);
        final pr3 = project(v3);
        final pr4 = project(v4);
        final avgDepth = (pr1.$2 + pr2.$2 + pr3.$2 + pr4.$2) / 4.0;
        allFaces.add(_Face3D(
          screenPoints: [pr1.$1, pr2.$1, pr3.$1, pr4.$1],
          depth: avgDepth,
          color: col,
          borderColor: border,
          label: lbl,
        ));
      }

      pushQuad(b1, b2, t2, t1, sideLight);
      pushQuad(b2, b3, t3, t2, sideDark);
      pushQuad(b3, b4, t4, t3, sideLight);
      pushQuad(b4, b1, t1, t4, sideDark);
      pushQuad(t1, t2, t3, t4, topCap, lbl: topLabel);
    }

    for (final wall in walls) {
      final wallVec = wall.end - wall.start;
      final wallLen = wallVec.distance;
      if (wallLen < 2.0) continue;
      final dir = wallVec / wallLen;

      final wallMid = Offset((wall.start.dx + wall.end.dx) / 2, (wall.start.dy + wall.end.dy) / 2);
      final double relX = wallMid.dx - pivot.dx;
      final double relY = wallMid.dy - pivot.dy;
      final double camRy = relX * sinY + relY * cosY;

      double effectiveWallHeightM = wallHeightMeters;
      if (wallViewMode == WallViewMode3D.lowWalls) {
        effectiveWallHeightM = math.min(wallHeightMeters, 0.28);
      } else if (wallViewMode == WallViewMode3D.cutawaySims && camRy > 25.0) {
        effectiveWallHeightM = math.min(wallHeightMeters, 0.25);
      }
      final double hPx = effectiveWallHeightM * 100.0;

      final List<(double, double, WallOpening)> wallOpenings = [];
      for (final op in openings) {
        final proj = _projectPointOnSegment(op.position, wall.start, wall.end);
        if ((proj - op.position).distance < 8.0) {
          final centerDist = (proj - wall.start).distance;
          final halfW = (op.widthMeters * 100.0) / 2.0;
          final sDist = (centerDist - halfW).clamp(0.0, wallLen);
          final eDist = (centerDist + halfW).clamp(0.0, wallLen);
          if (eDist > sDist + 2.0) {
            wallOpenings.add((sDist, eDist, op));
          }
        }
      }
      wallOpenings.sort((a, b) => a.$1.compareTo(b.$1));

      double cursor = 0.0;

      for (final item in wallOpenings) {
        final sDist = item.$1;
        final eDist = item.$2;
        final op = item.$3;

        if (sDist > cursor + 1.0) {
          addWallSegment3D(
            wall: wall,
            p1: wall.start + dir * cursor,
            p2: wall.start + dir * sDist,
            zBottom: 0.0,
            zTop: hPx,
          );
        }

        final opStartPt = wall.start + dir * sDist;
        final opEndPt = wall.start + dir * eDist;

        final double sillPx = (op.sillHeightMeters * 100.0).clamp(0.0, hPx);
        final double openingTopPx = ((op.sillHeightMeters + op.heightMeters) * 100.0).clamp(sillPx, hPx);

        if (sillPx > 1.5) {
          addWallSegment3D(
            wall: wall,
            p1: opStartPt,
            p2: opEndPt,
            zBottom: 0.0,
            zTop: sillPx,
          );
        }

        if (openingTopPx > sillPx + 2.0) {
          if (op.type == OpeningType.door) {
            addPrismBox(
              opStartPt,
              opEndPt,
              4.0,
              sillPx,
              openingTopPx,
              const Color(0xFFB45309).withValues(alpha: 0.55),
            );
          } else {
            // 3D OKHO: стекло ближе к наружной части стены, импост (1- или 2-створчатое) и подоконник
            final double wallThick = wall.totalEffectiveThicknessCm;
            final double halfThick = wallThick / 2.0;
            final Offset wallNormal = Offset(-dir.dy, dir.dx);

            // Определяем комнатную сторону (интерьер) по зонам
            final midProbe = (opStartPt + opEndPt) / 2.0 + wallNormal * (halfThick + 20.0);
            bool sideAIsInterior = false;
            for (final z in zones) {
              if (z.containsPoint(midProbe)) {
                sideAIsInterior = true;
                break;
              }
            }
            final Offset intNorm = sideAIsInterior ? wallNormal : -wallNormal;
            final Offset extNorm = -intNorm;

            // 1. Оконная рама и стекло сдвинуты ближе к наружной части стены
            final double frameOffset = (halfThick - 6.0).clamp(2.0, halfThick);
            final Offset frameShift = extNorm * frameOffset;
            final p1Frame = opStartPt + frameShift;
            final p2Frame = opEndPt + frameShift;

            // Рама ПВХ
            addPrismBox(
              p1Frame,
              p2Frame,
              6.5,
              sillPx,
              openingTopPx,
              const Color(0xFFF8FAFC),
              stroke: const Color(0xFFCBD5E1),
            );

            // 1- или 2-створчатое окно: центральный импост для окон шире 0.95м
            final bool isTwoSashes = op.widthMeters >= 0.95 || op.subtypeName.toLowerCase().contains('двух');
            if (isTwoSashes) {
              final midFrame = (p1Frame + p2Frame) / 2.0;
              final p1Impost = midFrame - dir * 2.8;
              final p2Impost = midFrame + dir * 2.8;
              addPrismBox(
                p1Impost,
                p2Impost,
                6.8,
                sillPx,
                openingTopPx,
                const Color(0xFFF1F5F9),
                stroke: const Color(0xFF94A3B8),
              );
            }

            // Стеклопакет (прозрачное стекло с окантовкой)
            addPrismBox(
              p1Frame,
              p2Frame,
              2.5,
              sillPx + 3.0,
              openingTopPx - 3.0,
              const Color(0xFF38BDF8).withValues(alpha: 0.42),
              stroke: const Color(0xFF0284C7),
            );

            // 2. Внутренний подоконник со стороны комнаты (с ушками и вылетом)
            final double sillDepth = halfThick + frameOffset + 4.0;
            final Offset sillShift = intNorm * ((halfThick + 4.0 - frameOffset) / 2.0);
            final p1Sill = opStartPt + sillShift - dir * 4.5;
            final p2Sill = opEndPt + sillShift + dir * 4.5;
            addPrismBox(
              p1Sill,
              p2Sill,
              sillDepth,
              sillPx,
              sillPx + 3.2,
              const Color(0xFFF8FAFC),
              stroke: const Color(0xFFE2E8F0),
            );

            // 3. Наружный металлический отлив (с уличной стороны)
            final double extSillDepth = (halfThick - frameOffset + 3.0).clamp(5.0, 30.0);
            final Offset extSillShift = extNorm * (halfThick + 1.0 - extSillDepth / 2.0);
            final p1ExtSill = opStartPt + extSillShift;
            final p2ExtSill = opEndPt + extSillShift;
            addPrismBox(
              p1ExtSill,
              p2ExtSill,
              extSillDepth,
              sillPx - 1.2,
              sillPx,
              const Color(0xFFE2E8F0),
              stroke: const Color(0xFFCBD5E1),
            );
          }
        }

        if (hPx > openingTopPx + 1.5) {
          addWallSegment3D(
            wall: wall,
            p1: opStartPt,
            p2: opEndPt,
            zBottom: openingTopPx,
            zTop: hPx,
          );
        }

        cursor = math.max(cursor, eDist);
      }

      if (cursor < wallLen - 1.0) {
        addWallSegment3D(
          wall: wall,
          p1: wall.start + dir * cursor,
          p2: wall.end,
          zBottom: 0.0,
          zTop: hPx,
        );
      }
    }

    // 3D Монолитные сопряжения углов стен (устранение щелей, ступенек и сквозной прозрачности)
    void drawWallJunctionPatches3D() {
      if (walls.length < 2) return;

      final List<Offset> nodes = [];
      for (final w in walls) {
        for (final pt in [w.start, w.end]) {
          if (!nodes.any((n) => (n - pt).distance < 2.5)) {
            nodes.add(pt);
          }
        }
      }

      for (final node in nodes) {
        final List<(Wall, Offset)> connected = [];
        for (final w in walls) {
          if ((w.start - node).distance < 4.0) {
            final len = (w.end - w.start).distance;
            if (len > 1.0) connected.add((w, (w.end - w.start) / len));
          } else if ((w.end - node).distance < 4.0) {
            final len = (w.start - w.end).distance;
            if (len > 1.0) connected.add((w, (w.start - w.end) / len));
          }
        }

        if (connected.length < 2) continue;

        connected.sort((a, b) => math.atan2(a.$2.dy, a.$2.dx).compareTo(math.atan2(b.$2.dy, b.$2.dx)));

        final int k = connected.length;
        for (int i = 0; i < k; i++) {
          final w1 = connected[i].$1;
          final dir1 = connected[i].$2;
          final w2 = connected[(i + 1) % k].$1;
          final dir2 = connected[(i + 1) % k].$2;

          final double det = dir1.dx * dir2.dy - dir1.dy * dir2.dx;
          if (det.abs() < 0.05) continue;

          final t1 = w1.totalEffectiveThicknessCm;
          final t2 = w2.totalEffectiveThicknessCm;
          final n1 = Offset(-dir1.dy, dir1.dx);
          final n2 = Offset(dir2.dy, -dir2.dx);

          final e1 = node + n1 * (t1 / 2.0);
          final e2 = node + n2 * (t2 / 2.0);

          final diff = e2 - e1;
          final t = (diff.dx * dir2.dy - diff.dy * dir2.dx) / det;
          Offset miterPt = e1 + dir1 * t;

          final maxCornerDist = math.max(t1, t2) * 2.2;
          if ((miterPt - node).distance > maxCornerDist || t < -maxCornerDist) {
            miterPt = (e1 + e2) / 2.0;
          }

          final double relX = node.dx - pivot.dx;
          final double relY = node.dy - pivot.dy;
          final double camRy = relX * sinY + relY * cosY;
          double effH = wallHeightMeters;
          if (wallViewMode == WallViewMode3D.lowWalls) {
            effH = math.min(wallHeightMeters, 0.28);
          } else if (wallViewMode == WallViewMode3D.cutawaySims && camRy > 25.0) {
            effH = math.min(wallHeightMeters, 0.25);
          }
          final double hPx = effH * 100.0;

          final prB1 = project(_Vec3(e1.dx, e1.dy, 0.0));
          final prB2 = project(_Vec3(miterPt.dx, miterPt.dy, 0.0));
          final prT2 = project(_Vec3(miterPt.dx, miterPt.dy, hPx));
          final prT1 = project(_Vec3(e1.dx, e1.dy, hPx));
          allFaces.add(_Face3D(
            screenPoints: [prB1.$1, prB2.$1, prT2.$1, prT1.$1],
            depth: (prB1.$2 + prB2.$2 + prT2.$2 + prT1.$2) / 4.0,
            color: const Color(0xFFE2E8F0),
            borderColor: Colors.black26,
          ));

          final prB3 = project(_Vec3(e2.dx, e2.dy, 0.0));
          final prT3 = project(_Vec3(e2.dx, e2.dy, hPx));
          allFaces.add(_Face3D(
            screenPoints: [prB2.$1, prB3.$1, prT3.$1, prT2.$1],
            depth: (prB2.$2 + prB3.$2 + prT3.$2 + prT2.$2) / 4.0,
            color: const Color(0xFFCBD5E1),
            borderColor: Colors.black26,
          ));

          final prN = project(_Vec3(node.dx, node.dy, hPx));
          allFaces.add(_Face3D(
            screenPoints: [prN.$1, prT1.$1, prT2.$1, prT2.$1],
            depth: (prN.$2 + prT1.$2 + prT2.$2) / 3.0,
            color: const Color(0xFFF8FAFC),
            borderColor: Colors.black26,
          ));
          allFaces.add(_Face3D(
            screenPoints: [prN.$1, prT2.$1, prT3.$1, prT3.$1],
            depth: (prN.$2 + prT2.$2 + prT3.$2) / 3.0,
            color: const Color(0xFFF8FAFC),
            borderColor: Colors.black26,
          ));
        }
      }
    }
    drawWallJunctionPatches3D();

    for (final obj in objects) {
      final rad = obj.rotationDeg * math.pi / 180.0;
      final cosR = math.cos(rad);
      final sinR = math.sin(rad);
      final dir = Offset(cosR, sinR);
      final perp = Offset(-sinR, cosR);

      final wPx = obj.widthMeters * 100.0;
      final dPx = obj.depthMeters * 100.0;
      final objHeightPx = obj.heightMeters * 100.0;

      final bool isSelObj = (obj == selectedObject);
      final Color baseCol = isSelObj
          ? const Color(0xFFFBBF24)
          : (obj.model3dPath != null ? const Color(0xFF10B981) : const Color(0xFF60A5FA));

      final Parsed3DMesh? mesh = (obj.model3dPath != null) ? loaded3DMeshes[obj.model3dPath] : null;

      // Если 3D-модель (сетка) загрузилась и распарсилась — рендерим её!
      if (mesh != null) {
        final hslBase = HSLColor.fromColor(baseCol);

        for (final tri in mesh.faces) {
          final v0 = mesh.vertices[tri.$1];
          final v1 = mesh.vertices[tri.$2];
          final v2 = mesh.vertices[tri.$3];

          _Vec3 toWorld(_Vec3 lv) {
            final lx = lv.x * wPx;
            final ly = lv.y * dPx;
            final lz = lv.z * objHeightPx;
            final wx = obj.position.dx + lx * cosR - ly * sinR;
            final wy = obj.position.dy + lx * sinR + ly * cosR;
            return _Vec3(wx, wy, lz);
          }

          final w0 = toWorld(v0);
          final w1 = toWorld(v1);
          final w2 = toWorld(v2);

          final ux = w1.x - w0.x, uy = w1.y - w0.y, uz = w1.z - w0.z;
          final vx = w2.x - w0.x, vy = w2.y - w0.y, vz = w2.z - w0.z;
          double nx = uy * vz - uz * vy;
          double ny = uz * vx - ux * vz;
          double nz = ux * vy - uy * vx;
          final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
          if (nLen > 1e-5) {
            nx /= nLen;
            ny /= nLen;
            nz /= nLen;
          }

          final dotLight = (nx * 0.45 - ny * 0.35 + nz * 0.82).abs();
          final litLightness = (hslBase.lightness * (0.58 + 0.50 * dotLight)).clamp(0.18, 0.92);
          final shadedColor = hslBase.withLightness(litLightness).toColor();

          final pr0 = project(w0);
          final pr1 = project(w1);
          final pr2 = project(w2);
          final depth = (pr0.$2 + pr1.$2 + pr2.$2) / 3.0;

          allFaces.add(_Face3D(
            screenPoints: [pr0.$1, pr1.$1, pr2.$1, pr2.$1], // треугольник как вырожденный 4-угольник
            depth: depth,
            color: shadedColor,
            borderColor: null,
          ));
        }
        continue;
      }

      // Если 3D-модели нет (или это процедурная мебель без mesh) — строим блоками
      final lowerName = '${obj.name} ${obj.category}'.toLowerCase();
      // Отключаем процедурную мебель, если у объекта ЕСТЬ путь к модели, но она просто не загрузилась
      if (obj.model3dPath != null) {
        addPrismBox(
          obj.position - dir * (wPx / 2),
          obj.position + dir * (wPx / 2),
          dPx,
          0.0,
          objHeightPx,
          baseCol,
          topLabel: obj.name,
        );
        continue;
      }

      if (lowerName.contains('stellazh') ||
          lowerName.contains('стеллаж') ||
          lowerName.contains('шкаф') ||
          lowerName.contains('storage') ||
          lowerName.contains('полк')) {
        const int shelves = 5;
        for (int s = 0; s < shelves; s++) {
          final z0 = (objHeightPx / (shelves - 1)) * s;
          final zBottom = (z0 - 3.5).clamp(0.0, objHeightPx);
          final zTop = (z0 + 3.5).clamp(2.0, objHeightPx);
          addPrismBox(
            obj.position - dir * (wPx / 2),
            obj.position + dir * (wPx / 2),
            dPx,
            zBottom,
            zTop,
            const Color(0xFFD97706),
            topLabel: s == shelves - 1 ? obj.name : null,
          );
        }
        for (final sx in [-1.0, 1.0]) {
          for (final sy in [-1.0, 1.0]) {
            final postCenter = obj.position + dir * (sx * (wPx / 2 - 4)) + perp * (sy * (dPx / 2 - 4));
            addPrismBox(
              postCenter - dir * 3,
              postCenter + dir * 3,
              6.0,
              0.0,
              objHeightPx,
              const Color(0xFF334155),
            );
          }
        }
      } else if (lowerName.contains('диван') || lowerName.contains('sofa') || lowerName.contains('кресло') || lowerName.contains('мягкая')) {
        addPrismBox(
          obj.position - dir * (wPx / 2),
          obj.position + dir * (wPx / 2),
          dPx,
          0.0,
          objHeightPx * 0.45,
          baseCol,
        );
        final backOffset = -perp * (dPx * 0.35);
        addPrismBox(
          obj.position + backOffset - dir * (wPx / 2),
          obj.position + backOffset + dir * (wPx / 2),
          dPx * 0.28,
          objHeightPx * 0.45,
          objHeightPx,
          baseCol,
          topLabel: obj.name,
        );
        for (final side in [-1.0, 1.0]) {
          final armCenter = obj.position + dir * (side * (wPx / 2 - 10));
          addPrismBox(
            armCenter - dir * 10,
            armCenter + dir * 10,
            dPx,
            objHeightPx * 0.45,
            objHeightPx * 0.72,
            baseCol,
          );
        }
      } else if (lowerName.contains('стол') || lowerName.contains('table')) {
        addPrismBox(
          obj.position - dir * (wPx / 2),
          obj.position + dir * (wPx / 2),
          dPx,
          objHeightPx * 0.88,
          objHeightPx,
          const Color(0xFFB45309),
          topLabel: obj.name,
        );
        for (final sx in [-1.0, 1.0]) {
          for (final sy in [-1.0, 1.0]) {
            final leg = obj.position + dir * (sx * (wPx / 2 - 6)) + perp * (sy * (dPx / 2 - 6));
            addPrismBox(leg - dir * 3, leg + dir * 3, 6.0, 0.0, objHeightPx * 0.88, const Color(0xFF1E293B));
          }
        }
      } else if (lowerName.contains('кроват') || lowerName.contains('bed') || lowerName.contains('спальн')) {
        addPrismBox(
          obj.position - dir * (wPx / 2),
          obj.position + dir * (wPx / 2),
          dPx,
          0.0,
          objHeightPx * 0.48,
          const Color(0xFFF8FAFC),
          topLabel: obj.name,
        );
        final headOffset = -perp * (dPx * 0.42);
        addPrismBox(
          obj.position + headOffset - dir * (wPx / 2),
          obj.position + headOffset + dir * (wPx / 2),
          dPx * 0.15,
          0.0,
          objHeightPx,
          baseCol,
        );
      } else {
        addPrismBox(
          obj.position - dir * (wPx / 2),
          obj.position + dir * (wPx / 2),
          dPx,
          0.0,
          objHeightPx,
          baseCol,
          topLabel: obj.name,
        );
      }
    }

    allFaces.sort((a, b) => a.depth.compareTo(b.depth));

    for (final face in allFaces) {
      final path = Path()
        ..moveTo(face.screenPoints[0].dx, face.screenPoints[0].dy)
        ..lineTo(face.screenPoints[1].dx, face.screenPoints[1].dy)
        ..lineTo(face.screenPoints[2].dx, face.screenPoints[2].dy)
        ..lineTo(face.screenPoints[3].dx, face.screenPoints[3].dy)
        ..close();

      if (face.sourceWall != null && face.wallSideSign != 0) {
        wallHitPolygonsOut.add(_WallHitPolygon3D(face.sourceWall!, face.wallSideSign, face.screenPoints, face.depth));
      }

      if (face.textureShader != null) {
        canvas.drawPath(path, Paint()..shader = face.textureShader);
      } else {
        canvas.drawPath(path, Paint()..color = face.color);
      }

      // Draw realistic 3D tile grid joints if wall has tile layout or adjacent zone has wallTileConfig
      if (face.sourceWall != null && face.screenPoints.length == 4) {
        final wallTileCfg = face.sourceWall!.tileConfig ??
            zones.where((z) => z.wallTileConfig != null && z.polygon.any((pt) => (pt - face.sourceWall!.start).distance < 15.0)).firstOrNull?.wallTileConfig;
        if (wallTileCfg != null) {
          final pBL = face.screenPoints[0];
          final pBR = face.screenPoints[1];
          final pTR = face.screenPoints[2];
          final pTL = face.screenPoints[3];
          final clearInternal = calcWallInternalLength(face.sourceWall!, walls);
          final wallLenM = clearInternal > 0.05 ? clearInternal : face.sourceWall!.lengthInMeters;
          final wallHgtM = wallHeightMeters;

          final tileWM = wallTileCfg.tileWidthMm / 1000.0;
          final tileHM = wallTileCfg.tileHeightMm / 1000.0;
          final cols = math.min(60, (wallLenM / tileWM).ceil());
          final rows = math.min(30, (wallHgtM / tileHM).ceil());

          final jointStroke = Paint()
            ..color = wallTileCfg.jointColor.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          for (int c = 1; c < cols; c++) {
            final u = (c * tileWM) / wallLenM;
            if (u >= 1.0) break;
            final bot = Offset.lerp(pBL, pBR, u)!;
            final top = Offset.lerp(pTL, pTR, u)!;
            canvas.drawLine(bot, top, jointStroke);
          }
          for (int r = 1; r < rows; r++) {
            final v = (r * tileHM) / wallHgtM;
            if (v >= 1.0) break;
            final left = Offset.lerp(pBL, pTL, v)!;
            final right = Offset.lerp(pBR, pTR, v)!;
            canvas.drawLine(left, right, jointStroke);
          }
        }
      }

      if (face.borderColor != null) {
        final bool isHighlightedSide =
            face.sourceWall != null && face.sourceWall == selectedWall && face.wallSideSign == selectedWallSide;
        canvas.drawPath(
          path,
          Paint()
            ..color = face.borderColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = isHighlightedSide ? 2.6 : 1.0,
        );
      }

      if (face.label != null) {
        final center = Offset(
          (face.screenPoints[0].dx + face.screenPoints[2].dx) / 2,
          (face.screenPoints[0].dy + face.screenPoints[2].dy) / 2,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: face.label,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bg = Rect.fromCenter(center: center, width: tp.width + 8, height: tp.height + 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, const Radius.circular(4)),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      }
    }

    if (showZonesLayer) {
      for (final zone in zones) {
        final c2d = zone.visualCenter;
        final pt = project(_Vec3(c2d.dx, c2d.dy, 12.0)).$1;
        final tp = TextPainter(
        text: TextSpan(
          text: '${zone.name}\n${zone.areaSqM.toStringAsFixed(2)} м²',
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final bg = Rect.fromCenter(center: pt, width: tp.width + 12, height: tp.height + 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(6)),
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.78),
      );
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridAndWallsPainter extends CustomPainter {
  final bool isDarkTheme;
  final bool showGrid;
  final List<Wall> walls;
  final Set<InteriorObject> selectedObjects;
  final Set<Wall> selectedWalls;
  final Set<WallOpening> selectedOpenings;
  final Set<CustomDimensionLine> selectedDimensions;
  final Set<ElectricalItem> selectedElectricalItems;
  final CustomDimensionLine? selectedDimension;
  final Rect? selectionMarquee;
  final bool isMarqueeLeftToRight;
  final List<RoomZone> zones;
  final RoomZone? editingBoundaryZone;
  final List<WallOpening> openings;
  final List<InteriorObject> objects;
  final List<CustomDimensionLine> customDimensions;
  final InteriorObject? selectedObject;
  final Wall? selectedWall;
  final WallOpening? selectedOpening;
  final Offset canvasOffset;
  final double canvasScale;
  final EditorTool selectedTool;
  final Offset? currentStart, currentEnd, snappedPointHighlight;
  final double currentThicknessCm;
  final List<SnapGuideLine> greenGuides;
  final Map<String, ui.Image> loadedImages;
  final UnitFormat unitFormat;
  final List<ElectricalItem> electricalItems;
  final ElectricalItem? selectedElectricalItem;
  final bool showFurnitureLayer;
  final bool showElectricalLayer;
  final bool showDimensionsLayer;
  final bool showZonesLayer;
  final bool showElectricalLabels;
  final bool showSocketDimensions;
  final bool showLightDimensions;
  final ({ElectricalType type, String subType, String name, double defaultHeightMm})? pendingElectricalPreset;
  final Offset? currentElectricalPreviewPos;

  GridAndWallsPainter({
    this.isDarkTheme = true,
    this.showGrid = true,
    required this.walls,
    this.selectedObjects = const {},
    this.selectedWalls = const {},
    this.selectedOpenings = const {},
    this.selectedDimensions = const {},
    this.selectedElectricalItems = const {},
    this.selectedDimension,
    this.selectionMarquee,
    this.isMarqueeLeftToRight = true,
    required this.zones,
    this.editingBoundaryZone,
    required this.openings,
    required this.objects,
    required this.customDimensions,
    this.selectedObject,
    this.selectedWall,
    this.selectedOpening,
    required this.canvasOffset,
    required this.canvasScale,
    required this.selectedTool,
    this.currentStart,
    this.currentEnd,
    required this.currentThicknessCm,
    this.snappedPointHighlight,
    required this.greenGuides,
    required this.loadedImages,
    this.unitFormat = UnitFormat.meters,
    this.electricalItems = const [],
    this.selectedElectricalItem,
    this.showFurnitureLayer = true,
    this.showElectricalLayer = true,
    this.showDimensionsLayer = true,
    this.showZonesLayer = true,
    this.showElectricalLabels = true,
    this.showSocketDimensions = true,
    this.showLightDimensions = true,
    this.pendingElectricalPreset,
    this.currentElectricalPreviewPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);

    final left = -canvasOffset.dx / canvasScale;
    final top = -canvasOffset.dy / canvasScale;
    final right = (size.width - canvasOffset.dx) / canvasScale;
    final bottom = (size.height - canvasOffset.dy) / canvasScale;

    if (showGrid) {
      if (canvasScale > 0.45) {
        final subGrid = Paint()
          ..color = isDarkTheme ? const Color(0xFF28282A) : Colors.blueGrey.withValues(alpha: 0.12)
          ..strokeWidth = 1.0 / canvasScale;
        for (double x = (left / 10).floor() * 10.0; x <= right; x += 10) {
          canvas.drawLine(Offset(x, top), Offset(x, bottom), subGrid);
        }
        for (double y = (top / 10).floor() * 10.0; y <= bottom; y += 10) {
          canvas.drawLine(Offset(left, y), Offset(right, y), subGrid);
        }
      }

      final mainGrid = Paint()
        ..color = isDarkTheme ? const Color(0xFF38383C) : Colors.blueGrey.withValues(alpha: 0.28)
        ..strokeWidth = (isDarkTheme ? 1.2 : 1.5) / canvasScale;
      for (double x = (left / 100).floor() * 100.0; x <= right; x += 100) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), mainGrid);
      }
      for (double y = (top / 100).floor() * 100.0; y <= bottom; y += 100) {
        canvas.drawLine(Offset(left, y), Offset(right, y), mainGrid);
      }
    }

    if (showZonesLayer || editingBoundaryZone != null) {
      for (final zone in zones) {
        if (!showZonesLayer && editingBoundaryZone != zone) continue;
        if (zone.polygon.length < 3) continue;
        final path = Path()..addPolygon(zone.polygon, true);
        final fillPaint = Paint();

        if (zone.textureId != null && loadedImages.containsKey(zone.textureId)) {
          final img = loadedImages[zone.textureId]!;
          // Динамический масштаб текстуры: 1 единица паттерна = 1.0 метр (100 px чертежа)
          const double realWorldTileMeters = 1.0;
          final double scaleFactor = (realWorldTileMeters * 100.0) / img.width;

          fillPaint.shader = ui.ImageShader(
            img,
            ui.TileMode.repeated,
            ui.TileMode.repeated,
            (Matrix4.identity()..scaleByDouble(scaleFactor, scaleFactor, 1.0, 1.0)).storage,
          );
        } else {
          fillPaint.color = zone.color.withValues(alpha: zone.isOpenContour ? 0.24 : 0.34);
        }
        canvas.drawPath(path, fillPaint);

        if (zone.tileConfig != null) {
          _drawZoneTileLayout(canvas, zone, path);
        }

        if (zone.isOpenContour || editingBoundaryZone == zone) {
          canvas.drawPath(
            path,
            Paint()
              ..color = editingBoundaryZone == zone ? const Color(0xFF059669) : zone.color.withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (editingBoundaryZone == zone ? 3.0 : 1.8) / canvasScale,
          );
        }
      }
    }

    final guidePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.0 / canvasScale
      ..style = PaintingStyle.stroke;

    for (final g in greenGuides) {
      _drawDashedLine(canvas, g.from, g.to, guidePaint);
      canvas.drawCircle(g.from, 5 / canvasScale, Paint()..color = const Color(0xFF10B981));
      if (g.label.isNotEmpty && g.from != g.to) {
        final mid = Offset((g.from.dx + g.to.dx) / 2, (g.from.dy + g.to.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: g.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bg = Rect.fromCenter(center: mid, width: tp.width + 6 / canvasScale, height: tp.height + 4 / canvasScale);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, Radius.circular(3 / canvasScale)),
          Paint()..color = const Color(0xFF059669).withValues(alpha: 0.90),
        );
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }

    if (showFurnitureLayer) {
      for (final obj in objects) {
        _drawInteriorObject(canvas, obj);
        if (obj == selectedObject) {
          _drawFurnitureDimensionsToWalls(canvas, obj);
        }
      }
    }

    for (final wall in walls) {
      _drawWall(canvas, wall);
    }
    _drawWallJunctionPatches(canvas);

    for (final dim in customDimensions) {
      final isSel = selectedDimensions.contains(dim) || (dim == selectedDimension);
      _drawCustomDimension(canvas, dim.start, dim.end, isSelected: isSel);
    }

    if (currentStart != null && currentEnd != null) {
      if (selectedTool == EditorTool.drawWall) {
        _drawWall(canvas, Wall(currentStart!, currentEnd!, thicknessCm: currentThicknessCm), isPreview: true);
        final pVec = currentEnd! - currentStart!;
        final pLen = pVec.distance;
        if (pLen > 5.0) {
          final liveLenM = pLen / 100.0;
          final liveLenText = (unitFormat == UnitFormat.millimeters)
              ? '${(liveLenM * 1000.0).round()} мм'
              : '${liveLenM.toStringAsFixed(2)} м';
          final pMid = (currentStart! + currentEnd!) / 2.0;
          final pDir = pVec / pLen;
          final pNorm = Offset(-pDir.dy, pDir.dx);
          final badgeCenter = pMid + pNorm * (currentThicknessCm / 2.0 + 16.0 / canvasScale);
          
          final tp = TextPainter(
            text: TextSpan(
              text: liveLenText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11 / canvasScale.clamp(0.5, 2.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final bg = Rect.fromCenter(
            center: badgeCenter,
            width: tp.width + 12 / canvasScale,
            height: tp.height + 6 / canvasScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bg, Radius.circular(6 / canvasScale)),
            Paint()..color = const Color(0xFF0284C7).withValues(alpha: 0.95),
          );
          tp.paint(canvas, badgeCenter - Offset(tp.width / 2, tp.height / 2));
        }
      } else if (selectedTool == EditorTool.drawDimension) {
        _drawCustomDimension(canvas, currentStart!, currentEnd!, isPreview: true);
      } else if (selectedTool == EditorTool.drawRoomBox) {
        _drawRoomBoxPreview(canvas, Rect.fromPoints(currentStart!, currentEnd!));
      }
    }

    for (final op in openings) {
      _drawOpening(canvas, op);

      Wall? hostWall;
      for (final w in walls) {
        if ((_projectPointOnSegment(op.position, w.start, w.end) - op.position).distance < 5.0) {
          hostWall = w;
          break;
        }
      }
      if (hostWall != null) {
        _drawOpeningDimensions(canvas, op, hostWall);
      }
    }

    if (showElectricalLayer) {
      for (final item in electricalItems) {
        _drawElectricalItem(canvas, item);
      }
      if (pendingElectricalPreset != null && currentElectricalPreviewPos != null) {
        _drawElectricalPlacementPreview(canvas, pendingElectricalPreset!, currentElectricalPreviewPos!);
      }
    }

    if (showZonesLayer) {
      for (final zone in zones) {
        _drawZoneCenterBadge(canvas, zone);
      }
    }

    if (editingBoundaryZone != null) {
      for (final pt in editingBoundaryZone!.polygon) {
        canvas.drawCircle(pt, 9 / canvasScale, Paint()..color = const Color(0xFF10B981));
        canvas.drawCircle(
          pt,
          9 / canvasScale,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / canvasScale,
        );
      }
    }

    if (snappedPointHighlight != null) {
      canvas.drawCircle(
        snappedPointHighlight!,
        11 / canvasScale,
        Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / canvasScale,
      );
      canvas.drawRect(
        Rect.fromCenter(center: snappedPointHighlight!, width: 10 / canvasScale, height: 10 / canvasScale),
        Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / canvasScale,
      );
    }

    // Draw Multi-Selection Marquee Rectangle with CAD direction coloring:
    // Слева направо: синий цвет (выделяет всё: стены + мебель)
    // Справа налево: изумрудный цвет (выделяет ТОЛЬКО объекты интерьера)
    if (selectionMarquee != null) {
      final Color marqueeColor = isMarqueeLeftToRight
          ? const Color(0xFF0D99FF) // Синий: Всё
          : const Color(0xFF10B981); // Зелёный: Только мебель

      canvas.drawRect(
        selectionMarquee!,
        Paint()..color = marqueeColor.withValues(alpha: 0.16),
      );
      canvas.drawRect(
        selectionMarquee!,
        Paint()
          ..color = marqueeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / canvasScale,
      );

      final label = isMarqueeLeftToRight ? 'Выделение: Всё' : 'Выделение: Только мебель';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10 / canvasScale,
            fontWeight: FontWeight.bold,
            backgroundColor: marqueeColor.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(selectionMarquee!.left + 4 / canvasScale, selectionMarquee!.top + 4 / canvasScale));
    }

    // Highlight multi-selected objects with Figma-blue bounding box
    for (final obj in selectedObjects) {
      final wPx = obj.widthMeters * 100.0;
      final dPx = obj.depthMeters * 100.0;
      canvas.save();
      canvas.translate(obj.position.dx, obj.position.dy);
      canvas.rotate(obj.rotationDeg * math.pi / 180.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-wPx / 2 - 4, -dPx / 2 - 4, wPx + 8, dPx + 8), const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFF0D99FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / canvasScale,
      );
      canvas.restore();
    }

    // Highlight multi-selected walls
    for (final w in selectedWalls) {
      canvas.drawLine(
        w.start,
        w.end,
        Paint()
          ..color = const Color(0xFF0D99FF)
          ..strokeWidth = (w.thicknessCm + 6.0)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.restore();
  }

  void _drawFurnitureDimensionsToWalls(Canvas canvas, InteriorObject obj) {
    final dists = _computeFurnitureWallDistances(obj, walls);
    final halfW = (obj.widthMeters * 100.0) / 2.0;
    final halfD = (obj.depthMeters * 100.0) / 2.0;
    final isSelected = (obj == selectedObject);

    final linePaint = Paint()
      ..color = isSelected ? const Color(0xFF059669) : const Color(0xFF64748B).withValues(alpha: 0.65)
      ..strokeWidth = (isSelected ? 1.6 : 1.1) / canvasScale;

    final badgeBg = isSelected ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9);

    if (dists.leftWallPt != null && dists.leftDistM != null && dists.leftDistM! >= 0.02) {
      final objEdge = Offset(obj.position.dx - halfW, obj.position.dy);
      _drawDashedLine(canvas, dists.leftWallPt!, objEdge, linePaint);
      _drawDimText(canvas, dists.leftWallPt!, objEdge, dists.leftDistM!, badgeColor: badgeBg);
    }
    if (dists.rightWallPt != null && dists.rightDistM != null && dists.rightDistM! >= 0.02) {
      final objEdge = Offset(obj.position.dx + halfW, obj.position.dy);
      _drawDashedLine(canvas, objEdge, dists.rightWallPt!, linePaint);
      _drawDimText(canvas, objEdge, dists.rightWallPt!, dists.rightDistM!, badgeColor: badgeBg);
    }
    if (dists.topWallPt != null && dists.topDistM != null && dists.topDistM! >= 0.02) {
      final objEdge = Offset(obj.position.dx, obj.position.dy - halfD);
      _drawDashedLine(canvas, dists.topWallPt!, objEdge, linePaint);
      _drawDimText(canvas, dists.topWallPt!, objEdge, dists.topDistM!, badgeColor: badgeBg);
    }
    if (dists.bottomWallPt != null && dists.bottomDistM != null && dists.bottomDistM! >= 0.02) {
      final objEdge = Offset(obj.position.dx, obj.position.dy + halfD);
      _drawDashedLine(canvas, objEdge, dists.bottomWallPt!, linePaint);
      _drawDimText(canvas, objEdge, dists.bottomWallPt!, dists.bottomDistM!, badgeColor: badgeBg);
    }
  }

  void _drawCustomDimension(
    Canvas canvas,
    Offset p1,
    Offset p2, {
    bool isPreview = false,
    bool isSelected = false,
  }) {
    final vec = p2 - p1;
    final len = vec.distance;
    if (len < 2.0) return;

    final dir = vec / len;
    final normal = Offset(-dir.dy, dir.dx);
    final tick = normal * ((isSelected ? 8.0 : 6.0) / canvasScale);

    final color = isPreview
        ? const Color(0xFF0D99FF)
        : (isSelected ? const Color(0xFFEF4444) : const Color(0xFFD97706));
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = (isSelected ? 3.0 : 1.8) / canvasScale;

    if (isSelected) {
      final haloPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.28)
        ..strokeWidth = 10.0 / canvasScale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, haloPaint);
      canvas.drawCircle(p1, 5.0 / canvasScale, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(p2, 5.0 / canvasScale, Paint()..color = const Color(0xFFEF4444));
    }

    canvas.drawLine(p1, p2, linePaint);
    canvas.drawLine(p1 - tick, p1 + tick, linePaint);
    canvas.drawLine(p2 - tick, p2 + tick, linePaint);

    _drawDimText(
      canvas,
      p1,
      p2,
      len / 100.0,
      badgeColor: isSelected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
    );
  }

  void _drawOpeningDimensions(Canvas canvas, WallOpening op, Wall wall) {
    final wallVec = wall.end - wall.start;
    final wallLen = wallVec.distance;
    if (wallLen < 1.0) return;

    final dir = wallVec / wallLen;
    final normal = Offset(-dir.dy, dir.dx);
    final offsetNormal = normal * (25.0 / canvasScale);

    final centerDist = (op.position - wall.start).distance;
    final wPx = op.widthMeters * 100.0;

    final edge1Dist = centerDist - wPx / 2;
    final edge2Dist = centerDist + wPx / 2;

    final ptStart = wall.start + offsetNormal;
    final ptEdge1 = wall.start + dir * edge1Dist + offsetNormal;
    final ptEdge2 = wall.start + dir * edge2Dist + offsetNormal;
    final ptEnd = wall.end + offsetNormal;

    final paint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.2 / canvasScale;

    canvas.drawLine(ptStart, ptEdge1, paint);
    canvas.drawLine(ptEdge2, ptEnd, paint);

    final tick = normal * (4.0 / canvasScale);
    canvas.drawLine(ptStart - tick, ptStart + tick, paint);
    canvas.drawLine(ptEdge1 - tick, ptEdge1 + tick, paint);
    canvas.drawLine(ptEdge2 - tick, ptEdge2 + tick, paint);
    canvas.drawLine(ptEnd - tick, ptEnd + tick, paint);

    final dimConnPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.6)
      ..strokeWidth = 1.0 / canvasScale
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, wall.start, ptStart, dimConnPaint);
    _drawDashedLine(canvas, wall.start + dir * edge1Dist, ptEdge1, dimConnPaint);
    _drawDashedLine(canvas, wall.start + dir * edge2Dist, ptEdge2, dimConnPaint);
    _drawDashedLine(canvas, wall.end, ptEnd, dimConnPaint);

    _drawDimText(canvas, ptStart, ptEdge1, edge1Dist / 100.0);
    _drawDimText(canvas, ptEdge2, ptEnd, (wallLen - edge2Dist) / 100.0);
  }

  void _drawDimText(Canvas canvas, Offset p1, Offset p2, double valueM, {Color? badgeColor}) {
    if (valueM < 0.05) return;
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final String dimLabel = (unitFormat == UnitFormat.millimeters)
        ? '${(valueM * 1000.0).round()} мм'
        : '${valueM.toStringAsFixed(2)} м';
    final tp = TextPainter(
      text: TextSpan(
        text: dimLabel,
        style: TextStyle(
          color: const Color(0xFF334155),
          fontSize: 9.5 / canvasScale.clamp(0.5, 2.0),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Rect.fromCenter(center: mid, width: tp.width + 6 / canvasScale, height: tp.height + 4 / canvasScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(4 / canvasScale)),
      Paint()..color = (badgeColor ?? const Color(0xFFF1F5F9)).withValues(alpha: 0.94),
    );
    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final totalDist = (p2 - p1).distance;
    if (totalDist < 1) return;
    final dir = (p2 - p1) / totalDist;
    final dashLen = 10.0 / canvasScale;
    final gapLen = 6.0 / canvasScale;
    double curr = 0;
    while (curr < totalDist) {
      final end = math.min(curr + dashLen, totalDist);
      canvas.drawLine(p1 + dir * curr, p1 + dir * end, paint);
      curr += dashLen + gapLen;
    }
  }

  void _drawZoneTileLayout(Canvas canvas, RoomZone zone, Path roomPath) {
    final cfg = zone.tileConfig!;
    final report = TileLayoutCalculator.calculate(zone.polygon, cfg);
    if (report.pieces.isEmpty) return;

    canvas.save();
    canvas.clipPath(roomPath);

    final jointPaint = Paint()
      ..color = cfg.jointColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6 / canvasScale, (cfg.jointWidthMm / 10.0));

    final fullTilePaint = Paint()
      ..color = isDarkTheme ? const Color(0x3310B981) : const Color(0x2810B981)
      ..style = PaintingStyle.fill;
    final largeCutPaint = Paint()
      ..color = isDarkTheme ? const Color(0x33F59E0B) : const Color(0x28F59E0B)
      ..style = PaintingStyle.fill;
    final smallCutPaint = Paint()
      ..color = isDarkTheme ? const Color(0x333B82F6) : const Color(0x283B82F6)
      ..style = PaintingStyle.fill;
    final critCutPaint = Paint()
      ..color = isDarkTheme ? const Color(0x55EF4444) : const Color(0x40EF4444)
      ..style = PaintingStyle.fill;
    final neutralTilePaint = Paint()
      ..color = isDarkTheme ? const Color(0x18FFFFFF) : const Color(0x1F000000)
      ..style = PaintingStyle.fill;

    for (final piece in report.pieces) {
      if (cfg.showCutColors) {
        Paint p;
        switch (piece.cutType) {
          case TileCutType.full:
            p = fullTilePaint;
            break;
          case TileCutType.large:
            p = largeCutPaint;
            break;
          case TileCutType.small:
            p = smallCutPaint;
            break;
          case TileCutType.critical:
            p = critCutPaint;
            break;
        }
        canvas.drawRect(piece.bounds, p);
      } else {
        canvas.drawRect(piece.bounds, neutralTilePaint);
      }
      canvas.drawRect(piece.bounds, jointPaint);

      if (cfg.showTileNumbers && canvasScale > 0.8) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${piece.id}',
            style: TextStyle(
              fontSize: 8.0 / canvasScale,
              color: isDarkTheme ? Colors.white70 : const Color(0xFF334155),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, piece.bounds.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    canvas.restore();
  }

  void _drawZoneCenterBadge(Canvas canvas, RoomZone zone) {
    final center = zone.visualCenter;
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${zone.name}\n',
            style: TextStyle(
              color: const Color(0xFF1E293B),
              fontSize: 13 / canvasScale.clamp(0.6, 1.8),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: '${zone.areaSqM.toStringAsFixed(2)} м²',
            style: TextStyle(
              color: const Color(0xFFB45309),
              fontSize: 12.5 / canvasScale.clamp(0.6, 1.8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Rect.fromCenter(
      center: center,
      width: tp.width + 18 / canvasScale,
      height: tp.height + 10 / canvasScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(10 / canvasScale)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(10 / canvasScale)),
      Paint()
        ..color = zone.color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / canvasScale,
    );
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawRoomBoxPreview(Canvas canvas, Rect rect) {
    final double inWM = rect.width.abs() / 100.0;
    final double inHM = rect.height.abs() / 100.0;
    final double inAreaSqM = inWM * inHM;

    final T = currentThicknessCm;
    final H = T / 2.0;
    final outerRect = Rect.fromLTRB(rect.left - H, rect.top - H, rect.right + H, rect.bottom + H);

    // Заливка чистого внутреннего пространства комнаты
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0D99FF).withValues(alpha: 0.12),
    );

    // Стены коробки снаружи внутреннего контура
    canvas.drawRect(
      outerRect,
      Paint()
        ..color = const Color(0xFF0D99FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = T,
    );

    // Внутренняя чистая линия периметра
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / canvasScale,
    );

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'ВНУТРЕННИЙ РАЗМЕР В СВЕТУ:\n',
            style: TextStyle(
              color: const Color(0xFF059669),
              fontSize: 10 / canvasScale.clamp(0.6, 1.8),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: '${inWM.toStringAsFixed(2)} × ${inHM.toStringAsFixed(2)} м\n',
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: 14 / canvasScale.clamp(0.6, 1.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'Площадь пола: ${inAreaSqM.toStringAsFixed(2)} м²',
            style: TextStyle(
              color: const Color(0xFF0D99FF),
              fontSize: 11 / canvasScale.clamp(0.6, 1.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Rect.fromCenter(
      center: rect.center,
      width: tp.width + 16 / canvasScale,
      height: tp.height + 12 / canvasScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(8 / canvasScale)),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(8 / canvasScale)),
      Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / canvasScale,
    );
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  void _drawInteriorObject(Canvas canvas, InteriorObject obj) {
    canvas.save();
    canvas.translate(obj.position.dx, obj.position.dy);
    canvas.rotate(obj.rotationDeg * math.pi / 180.0);

    final rect = Rect.fromCenter(center: Offset.zero, width: obj.widthMeters * 100, height: obj.depthMeters * 100);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final bool isSelected = (obj == selectedObject);

    // 1. Если задана текстура материала — отрисовываем её в первую очередь с масштабированием
    final objTex = _resolveTextureImage(obj.textureId, loadedImages);
    if (objTex != null) {
      final double texScale = math.min(1.0, math.max(0.15, (obj.widthMeters * 100.0) / objTex.width));
      final p = Paint()
        ..shader = ui.ImageShader(
          objTex,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          (Matrix4.identity()..scaleByDouble(texScale, texScale, 1.0, 1.0)).storage,
        );
      canvas.drawRRect(rrect, p);
    } else if (obj.previewImagePath != null && loadedImages.containsKey(obj.previewImagePath)) {
      final img = loadedImages[obj.previewImagePath]!;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        rect,
        Paint(),
      );
    } else {
      final p = Paint()
        ..color = obj.model3dPath != null ? const Color(0xFFA7F3D0) : Colors.blueGrey.shade200;
      canvas.drawRRect(rrect, p);
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isSelected
            ? const Color(0xFFD97706)
            : (obj.model3dPath != null ? const Color(0xFF059669) : Colors.black87)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 3.5 : 2.0) / canvasScale,
    );

    final badge = obj.model3dPath != null ? '[3D] ' : '';
    final String objDimsStr = (unitFormat == UnitFormat.millimeters)
        ? '${(obj.widthMeters * 1000).round()}×${(obj.depthMeters * 1000).round()} мм'
        : '${obj.widthMeters.toStringAsFixed(2)}×${obj.depthMeters.toStringAsFixed(2)} м';
    final tp = TextPainter(
      text: TextSpan(
        text: '$badge${obj.name}\n$objDimsStr',
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: 10 / canvasScale.clamp(0.6, 2.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawWallJunctionPatches(Canvas canvas) {
    if (walls.length < 2) return;

    final List<Offset> nodes = [];
    for (final w in walls) {
      for (final pt in [w.start, w.end]) {
        if (!nodes.any((n) => (n - pt).distance < 2.5)) {
          nodes.add(pt);
        }
      }
    }

    for (final node in nodes) {
      final List<(Wall, Offset)> connected = [];
      for (final w in walls) {
        if ((w.start - node).distance < 3.5) {
          final len = (w.end - w.start).distance;
          if (len > 1.0) connected.add((w, (w.end - w.start) / len));
        } else if ((w.end - node).distance < 3.5) {
          final len = (w.start - w.end).distance;
          if (len > 1.0) connected.add((w, (w.start - w.end) / len));
        }
      }

      if (connected.length < 2) continue;

      connected.sort((a, b) => math.atan2(a.$2.dy, a.$2.dx).compareTo(math.atan2(b.$2.dy, b.$2.dx)));

      final int k = connected.length;
      for (int i = 0; i < k; i++) {
        final w1 = connected[i].$1;
        final dir1 = connected[i].$2;
        final w2 = connected[(i + 1) % k].$1;
        final dir2 = connected[(i + 1) % k].$2;

        final double det = dir1.dx * dir2.dy - dir1.dy * dir2.dx;
        if (det.abs() < 0.05) continue;

        final t1 = w1.totalEffectiveThicknessCm;
        final t2 = w2.totalEffectiveThicknessCm;
        final n1 = Offset(-dir1.dy, dir1.dx);
        final n2 = Offset(dir2.dy, -dir2.dx);

        final e1 = node + n1 * (t1 / 2.0);
        final e2 = node + n2 * (t2 / 2.0);

        final diff = e2 - e1;
        final t = (diff.dx * dir2.dy - diff.dy * dir2.dx) / det;
        Offset miterPt = e1 + dir1 * t;

        final maxCornerDist = math.max(t1, t2) * 2.2;
        if ((miterPt - node).distance > maxCornerDist || t < -maxCornerDist) {
          miterPt = (e1 + e2) / 2.0;
        }

        final patchPath = Path()
          ..moveTo(node.dx, node.dy)
          ..lineTo(e1.dx, e1.dy)
          ..lineTo(miterPt.dx, miterPt.dy)
          ..lineTo(e2.dx, e2.dy)
          ..close();

        canvas.drawPath(
          patchPath,
          Paint()
            ..color = const Color(0xFF1E293B)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawWall(Canvas canvas, Wall wall, {bool isPreview = false}) {
    final bool isSel = (wall == selectedWall);
    final p = Paint()
      ..strokeWidth = wall.thicknessCm
      ..strokeCap = StrokeCap.butt;
    final texId = wall.textureSideA ?? wall.textureSideB;
    final wallImg = _resolveTextureImage(texId, loadedImages);
    if (wallImg != null && !isPreview) {
      final double scale = math.min(1.0, math.max(0.2, (wall.thicknessCm * 2.0) / wallImg.width));
      p.shader = ui.ImageShader(
        wallImg,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0)).storage,
      );
    } else {
      p.color = isPreview ? const Color(0xFF0D99FF) : const Color(0xFF1E293B);
    }
    canvas.drawLine(wall.start, wall.end, p);
    if (isSel || selectedWalls.contains(wall)) {
      canvas.drawCircle(wall.start, 4.0 / canvasScale, Paint()..color = const Color(0xFF0D99FF));
      canvas.drawCircle(wall.end, 4.0 / canvasScale, Paint()..color = const Color(0xFF0D99FF));
    }

    final double axialLenPx = (wall.end - wall.start).distance;
    final double axialLenM = wall.lengthInMeters;
    if (axialLenM < 0.05) return;

    final dir = (wall.end - wall.start) / axialLenPx;

    // Расчёт вычетов с максимальной точностью по RoomZone или сопряжённым граням
    final (startDeduction, endDeduction) = calcWallDeductions(wall, walls, zones);

    // Внутренние опорные точки грани стены (чистый размер в свету для раскладки плитки)
    final innerStart = wall.start + dir * startDeduction;
    final innerEnd = wall.end - dir * endDeduction;
    final mid = Offset((innerStart.dx + innerEnd.dx) / 2, (innerStart.dy + innerEnd.dy) / 2);

    // Подсветка выделенной стены: строго видимая внутренняя часть (куда кладётся плитка)
    if (isSel || selectedWalls.contains(wall)) {
      final selGlow = Paint()
        ..color = const Color(0xFF0D99FF).withValues(alpha: 0.35)
        ..strokeWidth = math.max(7.0 / canvasScale, wall.thicknessCm * 0.85)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(innerStart, innerEnd, selGlow);
      final selPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = math.max(3.5 / canvasScale, wall.thicknessCm * 0.45)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(innerStart, innerEnd, selPaint);
      canvas.drawCircle(innerStart, 5.5 / canvasScale, Paint()..color = const Color(0xFF0D99FF));
      canvas.drawCircle(innerEnd, 5.5 / canvasScale, Paint()..color = const Color(0xFF0D99FF));
      canvas.drawCircle(innerStart, 3.0 / canvasScale, Paint()..color = Colors.white);
      canvas.drawCircle(innerEnd, 3.0 / canvasScale, Paint()..color = Colors.white);
    }

    // Отрисовка слоев отделки стены (штукатурка, плитка, клей)
    if (wall.layersThicknessSideACm > 0 || wall.layersThicknessSideBCm > 0) {
      final normal = Offset(-dir.dy, dir.dx);
      if (wall.layersThicknessSideACm > 0) {
        final offsetA = normal * (wall.thicknessCm / 2.0 + wall.layersThicknessSideACm / 2.0);
        canvas.drawLine(
          wall.start + offsetA,
          wall.end + offsetA,
          Paint()
            ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75)
            ..strokeWidth = wall.layersThicknessSideACm
            ..style = PaintingStyle.stroke,
        );
      }
      if (wall.layersThicknessSideBCm > 0) {
        final offsetB = -normal * (wall.thicknessCm / 2.0 + wall.layersThicknessSideBCm / 2.0);
        canvas.drawLine(
          wall.start + offsetB,
          wall.end + offsetB,
          Paint()
            ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75)
            ..strokeWidth = wall.layersThicknessSideBCm
            ..style = PaintingStyle.stroke,
        );
      }
    }

    if (!showDimensionsLayer) return;

    final faceDim = computeWallFaceDimension(wall, walls, zones);
    final isDimMode = (selectedTool == EditorTool.wallDimensions);

    if (isDimMode) {
      final witPaint = Paint()
        ..color = const Color(0xFF0D99FF).withValues(alpha: 0.8)
        ..strokeWidth = 1.2 / canvasScale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(faceDim.innerStart, faceDim.witnessStartExt, witPaint);
      canvas.drawLine(faceDim.innerEnd, faceDim.witnessEndExt, witPaint);

      final dimLinePaint = Paint()
        ..color = const Color(0xFF0D99FF)
        ..strokeWidth = 1.5 / canvasScale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(faceDim.witnessStartExt, faceDim.witnessEndExt, dimLinePaint);

      final tickVec = (dir + faceDim.roomNormal);
      final tickLen = tickVec.distance;
      final tickDir = (tickLen > 0.001 ? tickVec / tickLen : const Offset(1, 1)) * (4.5 / canvasScale);
      canvas.drawLine(faceDim.witnessStartExt - tickDir, faceDim.witnessStartExt + tickDir, dimLinePaint);
      canvas.drawLine(faceDim.witnessEndExt - tickDir, faceDim.witnessEndExt + tickDir, dimLinePaint);

      final tp = TextPainter(
        text: TextSpan(
          text: (unitFormat == UnitFormat.millimeters) ? '${faceDim.lengthMm} мм' : '${faceDim.lengthM.toStringAsFixed(2)} м',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 / canvasScale.clamp(0.5, 2.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bg = Rect.fromCenter(
        center: faceDim.badgePos,
        width: tp.width + 12 / canvasScale,
        height: tp.height + 6 / canvasScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, Radius.circular(6 / canvasScale)),
        Paint()..color = const Color(0xFF0D99FF),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, Radius.circular(6 / canvasScale)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / canvasScale,
      );
      tp.paint(canvas, Offset(faceDim.badgePos.dx - tp.width / 2, faceDim.badgePos.dy - tp.height / 2));
    } else {
      final String wallLenText = (unitFormat == UnitFormat.millimeters)
          ? '${faceDim.lengthMm} мм'
          : '${faceDim.lengthM.toStringAsFixed(2)} м';

      final tp = TextPainter(
        text: TextSpan(
          text: wallLenText,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: 11 / canvasScale.clamp(0.5, 2.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bg = Rect.fromCenter(
        center: mid,
        width: tp.width + 8 / canvasScale,
        height: tp.height + 4 / canvasScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, Radius.circular(5 / canvasScale)),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, Radius.circular(5 / canvasScale)),
        Paint()
          ..color = const Color(0xFF0D99FF).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 / canvasScale,
      );
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  void _drawElectricalItem(Canvas canvas, ElectricalItem item) {
    final isSel = (item == selectedElectricalItem || selectedElectricalItems.contains(item));
    final double r = 8.5 / canvasScale.clamp(0.6, 2.0);
    final pos = item.position;

    // 1. РАЗМЕРНЫЕ ЛИНИИ
    if (item.type == ElectricalType.light) {
      if (showLightDimensions) {
        final nearestWalls = _findNearestWallsForLightOnWalls(pos, walls);
        for (final wInfo in nearestWalls) {
          final pWall = wInfo.proj;
          final distM = wInfo.distCm / 100.0;
          final distText = (unitFormat == UnitFormat.millimeters)
              ? '${(distM * 1000.0).round()} мм'
              : '${distM.toStringAsFixed(2)} м';

          final dimPaint = Paint()
            ..color = (isDarkTheme ? Colors.white54 : const Color(0xFF64748B)).withValues(alpha: isSel ? 0.95 : 0.65)
            ..strokeWidth = 1.0 / canvasScale
            ..style = PaintingStyle.stroke;

          canvas.drawLine(pos, pWall, dimPaint);

          final tickVec = (pos - pWall);
          if (tickVec.distance > 0.1) {
            final norm = Offset(-tickVec.dy, tickVec.dx) / tickVec.distance * (4.0 / canvasScale);
            canvas.drawLine(pWall - norm, pWall + norm, dimPaint);
          }

          final midPt = Offset((pos.dx + pWall.dx) / 2, (pos.dy + pWall.dy) / 2);
          final tp = TextPainter(
            text: TextSpan(
              text: distText,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final bg = Rect.fromCenter(
            center: midPt,
            width: tp.width + 6 / canvasScale,
            height: tp.height + 2 / canvasScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bg, Radius.circular(3 / canvasScale)),
            Paint()..color = (isDarkTheme ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.92),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bg, Radius.circular(3 / canvasScale)),
            Paint()
              ..color = (isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8 / canvasScale,
          );
          tp.paint(canvas, Offset(midPt.dx - tp.width / 2, midPt.dy - tp.height / 2));
        }
      }
    } else {
      if (showSocketDimensions) {
        final binding = _getElectricalWallBinding(item, walls, canvasScale);
        if (binding != null && (pos - binding.proj).distance < 120.0) {
          final u = (binding.wall.end - binding.wall.start) / binding.wallLenCm;
          final roomDir = binding.roomDir;
          final halfThick = binding.wall.thicknessCm / 2.0;
          final cornerCenter = binding.fromStart ? binding.wall.start : binding.wall.end;

          final distM = binding.distCm / 100.0;
          final distText = (unitFormat == UnitFormat.millimeters)
              ? '${(distM * 1000.0).round()} мм'
              : '${distM.toStringAsFixed(2)} м';

          final cornerFace = cornerCenter + roomDir * halfThick;
          final socketFace = binding.proj + roomDir * halfThick;

          // Выносим размерную линию в помещение (чтобы не пряталась за стеной)
          final dimOffset = roomDir * (r + 18.0 / canvasScale);
          final dimP1 = cornerFace + dimOffset;
          final dimP2 = socketFace + dimOffset;

          final guidePaint = Paint()
            ..color = (isDarkTheme ? Colors.white70 : const Color(0xFF475569)).withValues(alpha: isSel ? 0.95 : 0.75)
            ..strokeWidth = 1.0 / canvasScale
            ..style = PaintingStyle.stroke;

          // Выносные линии от стены к размерной линии
          canvas.drawLine(cornerFace, dimP1 + roomDir * (3.5 / canvasScale), guidePaint);
          canvas.drawLine(socketFace, dimP2 + roomDir * (3.5 / canvasScale), guidePaint);

          // Сама размерная линия
          canvas.drawLine(dimP1, dimP2, guidePaint);

          // Засечки (45 градусов)
          final slashVec = u + roomDir;
          final slash = (slashVec.distance > 0.001 ? slashVec / slashVec.distance : slashVec) * (4.0 / canvasScale);
          canvas.drawLine(dimP1 - slash, dimP1 + slash, guidePaint);
          canvas.drawLine(dimP2 - slash, dimP2 + slash, guidePaint);

          final midPt = binding.badgeCenter;
          final tpDist = TextPainter(
            text: TextSpan(
              text: distText,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final bgDist = Rect.fromCenter(
            center: midPt,
            width: tpDist.width + 8 / canvasScale,
            height: tpDist.height + 4 / canvasScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bgDist, Radius.circular(3 / canvasScale)),
            Paint()..color = (isDarkTheme ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.96),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bgDist, Radius.circular(3 / canvasScale)),
            Paint()
              ..color = isSel ? const Color(0xFF0D99FF) : (isDarkTheme ? Colors.white30 : const Color(0xFF94A3B8))
              ..style = PaintingStyle.stroke
              ..strokeWidth = (isSel ? 1.4 : 0.8) / canvasScale,
          );
          tpDist.paint(canvas, Offset(midPt.dx - tpDist.width / 2, midPt.dy - tpDist.height / 2));
        }
      }
    }

    // 2. ЧЕРНО-БЕЛОЕ ОБОЗНАЧЕНИЕ (Белое в темной теме, черное в светлой теме)
    final Color symbolColor = isDarkTheme ? Colors.white : const Color(0xFF18181B);
    final Color symbolFill = isDarkTheme ? const Color(0xFF1E293B) : Colors.white;

    if (isSel) {
      canvas.drawCircle(
        pos,
        r + 4.5 / canvasScale,
        Paint()
          ..color = const Color(0xFF0D99FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / canvasScale,
      );
    }

    canvas.drawCircle(pos, r, Paint()..color = symbolFill);
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = symbolColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / canvasScale,
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(item.rotationDeg * math.pi / 180);

    if (item.type == ElectricalType.socket) {
      final rect = Rect.fromCircle(center: Offset.zero, radius: r * 0.72);
      canvas.drawArc(
        rect,
        0,
        math.pi,
        false,
        Paint()
          ..color = symbolColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / canvasScale,
      );
      if (item.subType == 'socket_double') {
        canvas.drawLine(Offset(-r * 0.35, 0), Offset(-r * 0.35, -r * 0.6), Paint()..color = symbolColor..strokeWidth = 1.3 / canvasScale);
        canvas.drawLine(Offset(0, 0), Offset(0, -r * 0.6), Paint()..color = symbolColor..strokeWidth = 1.3 / canvasScale);
        canvas.drawLine(Offset(r * 0.35, 0), Offset(r * 0.35, -r * 0.6), Paint()..color = symbolColor..strokeWidth = 1.3 / canvasScale);
      } else {
        canvas.drawLine(Offset(-r * 0.28, 0), Offset(-r * 0.28, -r * 0.55), Paint()..color = symbolColor..strokeWidth = 1.3 / canvasScale);
        canvas.drawLine(Offset(r * 0.28, 0), Offset(r * 0.28, -r * 0.55), Paint()..color = symbolColor..strokeWidth = 1.3 / canvasScale);
      }
    } else if (item.type == ElectricalType.switchItem) {
      canvas.drawCircle(Offset.zero, r * 0.32, Paint()..color = symbolColor);
      canvas.drawLine(
        Offset.zero,
        Offset(r * 0.75, -r * 0.75),
        Paint()..color = symbolColor..strokeWidth = 1.5 / canvasScale,
      );
      canvas.drawLine(
        Offset(r * 0.75, -r * 0.75),
        Offset(r * 0.4, -r * 0.75),
        Paint()..color = symbolColor..strokeWidth = 1.5 / canvasScale,
      );
      if (item.subType == 'switch_2k') {
        canvas.drawLine(
          Offset(r * 0.55, -r * 0.55),
          Offset(r * 0.2, -r * 0.55),
          Paint()..color = symbolColor..strokeWidth = 1.5 / canvasScale,
        );
      }
    } else {
      if (item.subType == 'spot') {
        canvas.drawCircle(Offset.zero, r * 0.45, Paint()..color = symbolColor);
      } else {
        canvas.drawLine(
          Offset(-r * 0.55, -r * 0.55),
          Offset(r * 0.55, r * 0.55),
          Paint()..color = symbolColor..strokeWidth = 1.5 / canvasScale,
        );
        canvas.drawLine(
          Offset(-r * 0.55, r * 0.55),
          Offset(r * 0.55, -r * 0.55),
          Paint()..color = symbolColor..strokeWidth = 1.5 / canvasScale,
        );
      }
    }
    canvas.restore();

    // 3. ВЫСОТА ОТ ПОЛА (ТОЛЬКО ДЛЯ РОЗЕТОК И ВЫКЛЮЧАТЕЛЕЙ - СВЕТИЛЬНИКИ БЕЗ ВЫСОТЫ!)
    if (item.type != ElectricalType.light) {
      final hText = (unitFormat == UnitFormat.millimeters)
          ? 'h=${item.heightFromFloorMm.round()} мм'
          : 'h=${(item.heightFromFloorMm / 1000.0).toStringAsFixed(2)} м';

      final tpH = TextPainter(
        text: TextSpan(
          text: hText,
          style: TextStyle(
            color: isDarkTheme ? Colors.white70 : const Color(0xFF334155),
            fontSize: 8.5 / canvasScale.clamp(0.5, 2.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final hOffset = Offset(pos.dx + r + 4 / canvasScale, pos.dy - tpH.height / 2);
      final bgH = Rect.fromLTWH(
        hOffset.dx - 2 / canvasScale,
        hOffset.dy - 1 / canvasScale,
        tpH.width + 4 / canvasScale,
        tpH.height + 2 / canvasScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgH, Radius.circular(3 / canvasScale)),
        Paint()..color = (isDarkTheme ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.9),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgH, Radius.circular(3 / canvasScale)),
        Paint()
          ..color = (isDarkTheme ? Colors.white24 : const Color(0xFFCBD5E1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 / canvasScale,
      );
      tpH.paint(canvas, hOffset);
    }

    // 4. ПОДПИСЬ ГРУППЫ ЭЛЕКТРИКИ (ВЫНОС В СТОРОНУ ПОМЕЩЕНИЯ)
    if (showElectricalLabels && item.showLabel && item.groupLabel.isNotEmpty) {
      final tpLabel = TextPainter(
        text: TextSpan(
          text: item.groupLabel,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
            fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      Offset labelCenter = Offset(pos.dx, pos.dy - r - 8 / canvasScale);
      if (item.type != ElectricalType.light && walls.isNotEmpty) {
        Wall? nearestW;
        double minD = 999999.0;
        Offset? nearestProj;
        for (final w in walls) {
          final p = _projectPointOnSegment(pos, w.start, w.end);
          final d = (pos - p).distance;
          if (d < minD) {
            minD = d;
            nearestW = w;
            nearestProj = p;
          }
        }
        if (nearestProj != null && nearestW != null) {
          final toPos = pos - nearestProj;
          final d = toPos.distance;
          if (d > 0.001) {
            final roomDir = toPos / d;
            labelCenter = pos + roomDir * (r + 14.0 / canvasScale);
          }
        }
      }

      final bgLabel = Rect.fromCenter(
        center: labelCenter,
        width: tpLabel.width + 8 / canvasScale,
        height: tpLabel.height + 3 / canvasScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgLabel, Radius.circular(3 / canvasScale)),
        Paint()..color = (isDarkTheme ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)).withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgLabel, Radius.circular(3 / canvasScale)),
        Paint()
          ..color = (isDarkTheme ? Colors.white38 : const Color(0xFF94A3B8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 / canvasScale,
      );
      tpLabel.paint(canvas, Offset(labelCenter.dx - tpLabel.width / 2, labelCenter.dy - tpLabel.height / 2));
    }
  }

  void _drawElectricalPlacementPreview(
    Canvas canvas,
    ({ElectricalType type, String subType, String name, double defaultHeightMm}) preset,
    Offset cursorWorld,
  ) {
    final snapRes = _snapElectricalToWall(cursorWorld, preset.type, walls);
    final pos = snapRes.pos;
    final r = 8.5 / canvasScale.clamp(0.6, 2.0);

    canvas.drawCircle(
      pos,
      r + 6 / canvasScale,
      Paint()
        ..color = const Color(0xFF0D99FF).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    final Color symbolColor = (isDarkTheme ? Colors.white : Colors.black87).withValues(alpha: 0.75);
    final Color symbolFill = (isDarkTheme ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.85);

    canvas.drawCircle(pos, r, Paint()..color = symbolFill);
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = symbolColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / canvasScale,
    );

    if (preset.type == ElectricalType.light) {
      final nearestWalls = _findNearestWallsForLightOnWalls(pos, walls);
      for (final wInfo in nearestWalls) {
        final pWall = wInfo.proj;
        final distM = wInfo.distCm / 100.0;
        final distText = (unitFormat == UnitFormat.millimeters)
            ? '${(distM * 1000.0).round()} мм'
            : '${distM.toStringAsFixed(2)} м';

        final dimPaint = Paint()
          ..color = const Color(0xFF0D99FF).withValues(alpha: 0.8)
          ..strokeWidth = 1.2 / canvasScale
          ..style = PaintingStyle.stroke;

        canvas.drawLine(pos, pWall, dimPaint);

        final midPt = Offset((pos.dx + pWall.dx) / 2, (pos.dy + pWall.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: distText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final bg = Rect.fromCenter(
          center: midPt,
          width: tp.width + 6 / canvasScale,
          height: tp.height + 2 / canvasScale,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, Radius.circular(3 / canvasScale)),
          Paint()..color = const Color(0xFF0D99FF).withValues(alpha: 0.9),
        );
        tp.paint(canvas, Offset(midPt.dx - tp.width / 2, midPt.dy - tp.height / 2));
      }
    } else if (snapRes.wall != null) {
      final w = snapRes.wall!;
      final wallVec = w.end - w.start;
      final wallLen = wallVec.distance;
      if (wallLen > 0.1) {
        final u = wallVec / wallLen;
        final norm = Offset(-u.dy, u.dx);
        final proj = _projectPointOnSegment(pos, w.start, w.end);
        final toPos = pos - proj;
        final side = (toPos.dx * norm.dx + toPos.dy * norm.dy) >= 0 ? 1.0 : -1.0;
        final roomDir = norm * side;
        final halfThick = w.thicknessCm / 2.0;

        final dStart = (proj - w.start).distance;
        final dEnd = (proj - w.end).distance;
        final cornerCenter = dStart <= dEnd ? w.start : w.end;
        final distM = math.min(dStart, dEnd) / 100.0;
        final distText = (unitFormat == UnitFormat.millimeters)
            ? '${(distM * 1000.0).round()} мм'
            : '${distM.toStringAsFixed(2)} м';

        final cornerFace = cornerCenter + roomDir * halfThick;
        final socketFace = proj + roomDir * halfThick;

        // Выносим размерную линию в помещение
        final dimOffset = roomDir * (r + 18.0 / canvasScale);
        final dimP1 = cornerFace + dimOffset;
        final dimP2 = socketFace + dimOffset;

        final dimPaint = Paint()
          ..color = const Color(0xFF0D99FF).withValues(alpha: 0.85)
          ..strokeWidth = 1.2 / canvasScale
          ..style = PaintingStyle.stroke;

        // Выносные линии
        canvas.drawLine(cornerFace, dimP1 + roomDir * (3.5 / canvasScale), dimPaint);
        canvas.drawLine(socketFace, dimP2 + roomDir * (3.5 / canvasScale), dimPaint);

        // Размерная линия
        canvas.drawLine(dimP1, dimP2, dimPaint);

        // Засечки (45 градусов)
        final slashVec = u + roomDir;
        final slash = (slashVec.distance > 0.001 ? slashVec / slashVec.distance : slashVec) * (4.0 / canvasScale);
        canvas.drawLine(dimP1 - slash, dimP1 + slash, dimPaint);
        canvas.drawLine(dimP2 - slash, dimP2 + slash, dimPaint);

        final midPt = Offset((dimP1.dx + dimP2.dx) / 2, (dimP1.dy + dimP2.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: distText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.0 / canvasScale.clamp(0.5, 2.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final bg = Rect.fromCenter(
          center: midPt,
          width: tp.width + 6 / canvasScale,
          height: tp.height + 2 / canvasScale,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, Radius.circular(3 / canvasScale)),
          Paint()..color = const Color(0xFF0D99FF).withValues(alpha: 0.9),
        );
        tp.paint(canvas, Offset(midPt.dx - tp.width / 2, midPt.dy - tp.height / 2));
      }
    }
  }

  void _drawOpening(Canvas canvas, WallOpening op) {
    Wall? hostWall;
    for (final w in walls) {
      if ((_projectPointOnSegment(op.position, w.start, w.end) - op.position).distance <= w.totalEffectiveThicknessCm) {
        hostWall = w;
        break;
      }
    }
    final double wallThick = hostWall != null ? hostWall.totalEffectiveThicknessCm : op.depthCm;

    canvas.save();
    canvas.translate(op.position.dx, op.position.dy);
    canvas.rotate(op.rotation);

    if (op.type == OpeningType.window) {
      final double w = op.widthMeters * 100.0;
      final double halfW = w / 2.0;
      final double halfT = wallThick / 2.0;

      final dir = Offset(math.cos(op.rotation), math.sin(op.rotation));
      final norm = Offset(-dir.dy, dir.dx);
      final probeInt = op.position + norm * (halfT + 20.0);
      bool plusYIsInterior = false;
      for (final z in zones) {
        if (z.containsPoint(probeInt)) {
          plusYIsInterior = true;
          break;
        }
      }
      final double intSign = plusYIsInterior ? 1.0 : -1.0;

      final bool isTwoSashes = op.widthMeters >= 0.95 || op.subtypeName.toLowerCase().contains('двух');
      final bool isThreeSashes = op.widthMeters >= 1.9 || op.subtypeName.toLowerCase().contains('трех');

      // 1. Проем в теле стены (строго по толщине стены, не торчит за пределы)
      final openingBg = Rect.fromLTWH(-halfW, -halfT, w, wallThick);
      canvas.drawRect(
        openingBg,
        Paint()..color = isDarkTheme ? const Color(0xFF0F172A) : Colors.white,
      );

      final jambPaint = Paint()
        ..color = isDarkTheme ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)
        ..strokeWidth = 2.0 / canvasScale;
      // Линии откосов стены по краям проема
      canvas.drawLine(Offset(-halfW, -halfT), Offset(-halfW, halfT), jambPaint);
      canvas.drawLine(Offset(halfW, -halfT), Offset(halfW, halfT), jambPaint);

      // 2. Внутренний подоконник (комнатная сторона) с ушками по ГОСТ
      final double sillY = intSign * (halfT + 2.5);
      final sillPaint = Paint()
        ..color = isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF64748B)
        ..strokeWidth = 1.6 / canvasScale;
      canvas.drawLine(Offset(-halfW - 4.0, sillY), Offset(halfW + 4.0, sillY), sillPaint);
      canvas.drawLine(Offset(-halfW - 4.0, sillY), Offset(-halfW - 4.0, intSign * halfT), sillPaint);
      canvas.drawLine(Offset(halfW + 4.0, sillY), Offset(halfW + 4.0, intSign * halfT), sillPaint);

      // 3. Наружный отлив (уличная сторона)
      final double extSillY = -intSign * (halfT + 1.8);
      canvas.drawLine(
        Offset(-halfW, extSillY),
        Offset(halfW, extSillY),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.0 / canvasScale,
      );

      // 4. Оконная рама ПВХ (сдвинута к наружной части стены)
      final double frameCenterY = -intSign * (halfT * 0.35);
      final double frameDepth = math.min(7.5, wallThick * 0.42);
      final frameRect = Rect.fromCenter(center: Offset(0, frameCenterY), width: w - 2.0, height: frameDepth);
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(1.5)),
        Paint()..color = isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(1.5)),
        Paint()
          ..color = const Color(0xFF64748B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 / canvasScale,
      );

      // 5. Остекление и импост (ГОСТ обозначение 1- или 2-створчатого)
      final glassPaint = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 1.3 / canvasScale;
      final sashBorderPaint = Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 / canvasScale;

      if (!isTwoSashes && !isThreeSashes) {
        // ОДНОСТВОРЧАТОЕ ОКНО
        final sashRect = Rect.fromCenter(center: Offset(0, frameCenterY), width: w - 5.0, height: frameDepth - 2.2);
        canvas.drawRect(sashRect, sashBorderPaint);
        canvas.drawLine(Offset(-halfW + 3.5, frameCenterY - 1.1), Offset(halfW - 3.5, frameCenterY - 1.1), glassPaint);
        canvas.drawLine(Offset(-halfW + 3.5, frameCenterY + 1.1), Offset(halfW - 3.5, frameCenterY + 1.1), glassPaint);
      } else if (!isThreeSashes) {
        // ДВУХСТВОРЧАТОЕ ОКНО С ЦЕНТРАЛЬНЫМ ИМПОСТОМ
        final impost = Rect.fromCenter(center: Offset(0, frameCenterY), width: 5.5, height: frameDepth);
        canvas.drawRect(impost, Paint()..color = isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
        canvas.drawRect(impost, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 1.0 / canvasScale);

        final sashW = (w - 11.0) / 2.0;
        final leftMidX = -halfW + 2.5 + sashW / 2.0;
        final rightMidX = halfW - 2.5 - sashW / 2.0;

        // Левая створка
        canvas.drawRect(Rect.fromCenter(center: Offset(leftMidX, frameCenterY), width: sashW, height: frameDepth - 2.2), sashBorderPaint);
        canvas.drawLine(Offset(-halfW + 3.5, frameCenterY - 1.1), Offset(-3.5, frameCenterY - 1.1), glassPaint);
        canvas.drawLine(Offset(-halfW + 3.5, frameCenterY + 1.1), Offset(-3.5, frameCenterY + 1.1), glassPaint);

        // Правая створка
        canvas.drawRect(Rect.fromCenter(center: Offset(rightMidX, frameCenterY), width: sashW, height: frameDepth - 2.2), sashBorderPaint);
        canvas.drawLine(Offset(3.5, frameCenterY - 1.1), Offset(halfW - 3.5, frameCenterY - 1.1), glassPaint);
        canvas.drawLine(Offset(3.5, frameCenterY + 1.1), Offset(halfW - 3.5, frameCenterY + 1.1), glassPaint);
      } else {
        // ТРЁХСТВОРЧАТОЕ ОКНО
        final impostW = 4.5;
        final sashW = (w - 2 * impostW - 6.0) / 3.0;
        final i1X = -halfW + 3.0 + sashW + impostW / 2.0;
        final i2X = halfW - 3.0 - sashW - impostW / 2.0;

        canvas.drawRect(Rect.fromCenter(center: Offset(i1X, frameCenterY), width: impostW, height: frameDepth), Paint()..color = const Color(0xFF64748B));
        canvas.drawRect(Rect.fromCenter(center: Offset(i2X, frameCenterY), width: impostW, height: frameDepth), Paint()..color = const Color(0xFF64748B));

        for (final mX in [-halfW + 3.0 + sashW / 2.0, 0.0, halfW - 3.0 - sashW / 2.0]) {
          canvas.drawRect(Rect.fromCenter(center: Offset(mX, frameCenterY), width: sashW, height: frameDepth - 2.2), sashBorderPaint);
          canvas.drawLine(Offset(mX - sashW / 2.0 + 1.0, frameCenterY - 1.0), Offset(mX + sashW / 2.0 - 1.0, frameCenterY - 1.0), glassPaint);
          canvas.drawLine(Offset(mX - sashW / 2.0 + 1.0, frameCenterY + 1.0), Offset(mX + sashW / 2.0 - 1.0, frameCenterY + 1.0), glassPaint);
        }
      }

      // 6. Подсветка при выделении
      if (op == selectedOpening) {
        canvas.drawRect(
          Rect.fromLTWH(-halfW - 1, -halfT - 1, w + 2, wallThick + 2),
          Paint()
            ..color = const Color(0xFF0D99FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 / canvasScale,
        );
      }

      // 7. Подпись параметров окна по ГОСТ
      final sashTag = isThreeSashes ? '3-ств.' : (isTwoSashes ? '2-ств.' : '1-ств.');
      final String wStr = (unitFormat == UnitFormat.millimeters)
          ? '${(op.widthMeters * 1000.0).round()} мм'
          : '${op.widthMeters.toStringAsFixed(2)} м';
      final String hStr = (unitFormat == UnitFormat.millimeters)
          ? '${(op.heightMeters * 1000.0).round()} мм'
          : '${op.heightMeters.toStringAsFixed(2)} м';
      final String sillStr = (unitFormat == UnitFormat.millimeters)
          ? '${(op.sillHeightMeters * 1000.0).round()} мм'
          : '${op.sillHeightMeters.toStringAsFixed(2)} м';
      final tp = TextPainter(
        text: TextSpan(
          text: '$sashTag $wStr × $hStr\nh_под = $sillStr',
          style: TextStyle(
            color: const Color(0xFF0369A1),
            fontSize: 8.5 / canvasScale.clamp(0.6, 1.8),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelY = (intSign > 0)
          ? halfT + 12.0 / canvasScale
          : -halfT - tp.height - 12.0 / canvasScale;

      final normAngle = (op.rotation % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      final bool isUpsideDown = normAngle > math.pi / 2 && normAngle < 3 * math.pi / 2;

      canvas.save();
      final labelCenter = Offset(0, labelY + tp.height / 2);
      canvas.translate(labelCenter.dx, labelCenter.dy);
      if (isUpsideDown) {
        canvas.rotate(math.pi);
      }
      final localBg = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6 / canvasScale,
        height: tp.height + 4 / canvasScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(localBg, Radius.circular(3 / canvasScale)),
        Paint()..color = (isDarkTheme ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.90),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

    } else if (op.type == OpeningType.door) {
      final rect = Rect.fromCenter(center: Offset.zero, width: op.widthMeters * 100, height: wallThick);
      final p = Paint();
      final opImg = _resolveTextureImage(op.textureId, loadedImages);
      if (opImg != null) {
        p.shader = ui.ImageShader(
          opImg,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          (Matrix4.identity()..scaleByDouble(0.5, 0.5, 1.0, 1.0)).storage,
        );
      } else {
        p.color = Colors.white;
      }
      canvas.drawRect(rect, p);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.brown
          ..style = PaintingStyle.stroke
          ..strokeWidth = (op == selectedOpening ? 3.5 : 2.0) / canvasScale,
      );
      final dirX = op.flipHorizontal ? -1.0 : 1.0;
      final dirY = op.flipVertical ? -1.0 : 1.0;
      final hinge = Offset(-op.widthMeters * 50 * dirX, 0);
      final tip = Offset(-op.widthMeters * 50 * dirX, op.widthMeters * 100 * dirY);
      canvas.drawLine(
        hinge,
        tip,
        Paint()
          ..color = Colors.brown
          ..strokeWidth = 3 / canvasScale,
      );
      canvas.drawArc(
        Rect.fromCircle(center: hinge, radius: op.widthMeters * 100),
        dirX > 0 ? (dirY > 0 ? 0 : -math.pi / 2) : (dirY > 0 ? math.pi / 2 : -math.pi),
        math.pi / 2,
        false,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / canvasScale,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Миниатюрный архитектурный чертёж-предпросмотр (Blueprint Thumbnail Preview)
class TemplateThumbnail extends StatelessWidget {
  final String type;
  final double width;
  final double height;

  const TemplateThumbnail({
    super.key,
    required this.type,
    this.width = 115,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Инженерный синий чертёжный фон
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _TemplateThumbnailPainter(type: type),
      ),
    );
  }
}

class _TemplateThumbnailPainter extends CustomPainter {
  final String type;

  _TemplateThumbnailPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Тонкая координатная сетка миллиметровки
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 0.8;
    for (double x = 0; x <= size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Краски для чертежа
    final outerWallPaint = Paint()
      ..color = const Color(0xFF38BDF8) // Яркий CAD Cyan
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final innerWallPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final windowPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 2.0;

    final doorArcPaint = Paint()
      ..color = const Color(0xFF34D399) // Изумрудный радиус открывания
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final furniturePaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;

    final furnitureStroke = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final plumbingPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final pad = 7.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    switch (type) {
      case 'studio':
        // Наружный контур
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Санузел
        canvas.drawLine(Offset(pad, pad + h * 0.45), Offset(pad + w * 0.35, pad + h * 0.45), innerWallPaint);
        canvas.drawLine(Offset(pad + w * 0.35, pad), Offset(pad + w * 0.35, pad + h * 0.45), innerWallPaint);
        // Ванна в санузле
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + 3, pad + 3, w * 0.16, h * 0.36), const Radius.circular(2)),
          plumbingPaint,
        );
        // Кухонный фронт
        canvas.drawRect(Rect.fromLTWH(pad + w * 0.45, pad + 2, w * 0.4, 6), furniturePaint);
        // Диван
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.48, pad + h - 14, w * 0.38, 11), const Radius.circular(2)),
          furniturePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.48, pad + h - 14, w * 0.38, 11), const Radius.circular(2)),
          furnitureStroke,
        );
        // Окно
        canvas.drawLine(Offset(pad + w, pad + h * 0.3), Offset(pad + w, pad + h * 0.7), windowPaint);
        // Дверь
        canvas.drawArc(Rect.fromCircle(center: Offset(pad, pad + h * 0.7), radius: 8), 0, math.pi / 2, false, doorArcPaint);
        break;

      case 'one_room':
        // Наружный контур
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Стена между комнатой и кухней/коридором
        canvas.drawLine(Offset(pad + w * 0.52, pad), Offset(pad + w * 0.52, pad + h), innerWallPaint);
        // Стена санузла
        canvas.drawLine(Offset(pad, pad + h * 0.45), Offset(pad + w * 0.32, pad + h * 0.45), innerWallPaint);
        canvas.drawLine(Offset(pad + w * 0.32, pad), Offset(pad + w * 0.32, pad + h * 0.45), innerWallPaint);
        // Кровать в спальне
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.65, pad + 6, w * 0.26, h * 0.42), const Radius.circular(2)),
          furniturePaint,
        );
        // Диван/кухня
        canvas.drawRect(Rect.fromLTWH(pad + 4, pad + h - 12, w * 0.4, 8), furniturePaint);
        // Ванна
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pad + 3, pad + 3, w * 0.15, h * 0.36), const Radius.circular(2)), plumbingPaint);
        // Окна
        canvas.drawLine(Offset(pad + w * 0.68, pad), Offset(pad + w * 0.88, pad), windowPaint);
        canvas.drawLine(Offset(pad + 10, pad + h), Offset(pad + w * 0.35, pad + h), windowPaint);
        break;

      case 'two_room':
        // 2-комнатная квартира
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Перегородки
        canvas.drawLine(Offset(pad + w * 0.48, pad), Offset(pad + w * 0.48, pad + h * 0.6), innerWallPaint);
        canvas.drawLine(Offset(pad, pad + h * 0.6), Offset(pad + w * 0.48, pad + h * 0.6), innerWallPaint);
        canvas.drawLine(Offset(pad + w * 0.72, pad), Offset(pad + w * 0.72, pad + h * 0.52), innerWallPaint);
        canvas.drawLine(Offset(pad + w * 0.48, pad + h * 0.52), Offset(pad + w * 0.72, pad + h * 0.52), innerWallPaint);
        // Спальня 1
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + 8, pad + 6, w * 0.28, h * 0.38), const Radius.circular(2)),
          furniturePaint,
        );
        // Спальня 2
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.76, pad + 6, w * 0.18, h * 0.36), const Radius.circular(2)),
          furniturePaint,
        );
        // Гостиная - диван
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.58, pad + h - 14, w * 0.34, 10), const Radius.circular(2)),
          furniturePaint,
        );
        // Окна
        canvas.drawLine(Offset(pad + 14, pad), Offset(pad + w * 0.38, pad), windowPaint);
        canvas.drawLine(Offset(pad + w * 0.8, pad), Offset(pad + w * 0.95, pad), windowPaint);
        canvas.drawLine(Offset(pad + w, pad + h * 0.65), Offset(pad + w, pad + h * 0.9), windowPaint);
        break;

      case 'kitchen_living':
        // Кухня-гостиная с островом
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Кухонный фронт
        canvas.drawRect(Rect.fromLTWH(pad + 4, pad + 3, w * 0.45, 7), furniturePaint);
        // Остров по центру
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.1, pad + h * 0.4, w * 0.28, 12), const Radius.circular(2)),
          furniturePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.1, pad + h * 0.4, w * 0.28, 12), const Radius.circular(2)),
          furnitureStroke,
        );
        // Обеденный стол
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.55, pad + 8, w * 0.32, 14), const Radius.circular(2)),
          furniturePaint,
        );
        // Диван угловой
        final sofaPath = Path()
          ..moveTo(pad + w * 0.55, pad + h - 4)
          ..lineTo(pad + w - 4, pad + h - 4)
          ..lineTo(pad + w - 4, pad + h * 0.45)
          ..lineTo(pad + w - 12, pad + h * 0.45)
          ..lineTo(pad + w - 12, pad + h - 12)
          ..lineTo(pad + w * 0.55, pad + h - 12)
          ..close();
        canvas.drawPath(sofaPath, furniturePaint);
        canvas.drawPath(sofaPath, furnitureStroke);
        // Окно
        canvas.drawLine(Offset(pad + w, pad + h * 0.25), Offset(pad + w, pad + h * 0.8), windowPaint);
        break;

      case 'bathroom':
        // Премиум санузел
        final rect = Rect.fromLTWH(pad + 8, pad, w - 16, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Отдельностоящая ванна (овал)
        canvas.drawOval(
          Rect.fromLTWH(pad + 14, pad + h * 0.46, (w - 16) * 0.48, h * 0.45),
          plumbingPaint,
        );
        // Стеклянная душевая зона
        final showerRect = Rect.fromLTWH(pad + w - 24 - (w - 16) * 0.38, pad + 3, (w - 16) * 0.38, h * 0.44);
        canvas.drawRect(showerRect, Paint()..color = const Color(0xFF0369A1).withValues(alpha: 0.35));
        canvas.drawLine(Offset(showerRect.left, showerRect.top), Offset(showerRect.left, showerRect.bottom), windowPaint);
        // Раковина
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + 14, pad + 3, (w - 16) * 0.45, 8), const Radius.circular(2)),
          plumbingPaint,
        );
        // Унитаз
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w - 30, pad + h * 0.6, 12, 16), const Radius.circular(3)),
          plumbingPaint,
        );
        break;

      case 'office':
        // Кабинет
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Стол руководителя
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.55, pad + h * 0.25, w * 0.35, 16), const Radius.circular(2)),
          furniturePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.55, pad + h * 0.25, w * 0.35, 16), const Radius.circular(2)),
          furnitureStroke,
        );
        // Кресло
        canvas.drawCircle(Offset(pad + w * 0.725, pad + h * 0.16), 5, furniturePaint);
        // Шкаф-библиотека
        canvas.drawRect(Rect.fromLTWH(pad + 4, pad + 4, w * 0.42, 6), furniturePaint);
        // Диван для посетителей
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + 8, pad + h - 14, w * 0.38, 10), const Radius.circular(2)),
          furniturePaint,
        );
        // Панорамное окно
        canvas.drawLine(Offset(pad + w, pad + h * 0.2), Offset(pad + w, pad + h * 0.8), windowPaint);
        break;

      default: // bedroom / standard
        final rect = Rect.fromLTWH(pad, pad, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), outerWallPaint);
        // Кровать
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.45, pad + 8, w * 0.45, h * 0.55), const Radius.circular(3)),
          furniturePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pad + w * 0.45, pad + 8, w * 0.45, h * 0.55), const Radius.circular(3)),
          furnitureStroke,
        );
        // Подушки
        canvas.drawRect(Rect.fromLTWH(pad + w * 0.48, pad + 10, w * 0.17, 7), Paint()..color = const Color(0xFF64748B));
        canvas.drawRect(Rect.fromLTWH(pad + w * 0.7, pad + 10, w * 0.17, 7), Paint()..color = const Color(0xFF64748B));
        // Шкаф
        canvas.drawRect(Rect.fromLTWH(pad + 4, pad + h - 12, w * 0.45, 8), furniturePaint);
        // Окно
        canvas.drawLine(Offset(pad + w * 0.4, pad), Offset(pad + w * 0.8, pad), windowPaint);
        break;
    }

    // Метка "2D" в углу чертежа
    final tp = TextPainter(
      text: const TextSpan(
        text: 'CAD 2D',
        style: TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pad + 4, size.height - pad - tp.height - 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CAD ViewCube 3D / 2D кнопка-кубик в стиле профессиональных САПР
class _CadViewCubeButton extends StatefulWidget {
  final bool is3DMode;
  final VoidCallback onTap;

  const _CadViewCubeButton({required this.is3DMode, required this.onTap});

  @override
  State<_CadViewCubeButton> createState() => _CadViewCubeButtonState();
}

class _CadViewCubeButtonState extends State<_CadViewCubeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.is3DMode ? 'Вернуться в 2D чертёж' : 'Переключиться в 3D вид',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E22).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered ? const Color(0xFF38BDF8) : const Color(0xFF3E3E44),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered ? const Color(0xFF0D99FF).withValues(alpha: 0.35) : Colors.black45,
                    blurRadius: _isHovered ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _CadViewCubePainter(is3DMode: widget.is3DMode, isHovered: _isHovered),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CadViewCubePainter extends CustomPainter {
  final bool is3DMode;
  final bool isHovered;

  _CadViewCubePainter({required this.is3DMode, required this.isHovered});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final double s = 18.0;

    final pTop = Offset(cx, cy - s * 0.95);
    final pRightTop = Offset(cx + s * 0.9, cy - s * 0.45);
    final pLeftTop = Offset(cx - s * 0.9, cy - s * 0.45);
    final pCenter = Offset(cx, cy + s * 0.05);
    final pRightBottom = Offset(cx + s * 0.9, cy + s * 0.65);
    final pLeftBottom = Offset(cx - s * 0.9, cy + s * 0.65);
    final pBottom = Offset(cx, cy + s * 1.15);

    // Верхняя грань
    final topPath = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..lineTo(pLeftTop.dx, pLeftTop.dy)
      ..close();
    canvas.drawPath(
      topPath,
      Paint()..color = is3DMode ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
    );

    // Левая грань
    final leftPath = Path()
      ..moveTo(pLeftTop.dx, pLeftTop.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pLeftBottom.dx, pLeftBottom.dy)
      ..close();
    canvas.drawPath(
      leftPath,
      Paint()..color = is3DMode ? const Color(0xFFD97706) : const Color(0xFF0284C7),
    );

    // Правая грань
    final rightPath = Path()
      ..moveTo(pCenter.dx, pCenter.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pRightBottom.dx, pRightBottom.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..close();
    canvas.drawPath(
      rightPath,
      Paint()..color = is3DMode ? const Color(0xFFB45309) : const Color(0xFF0369A1),
    );

    // Контурные ребра
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath, strokePaint);
    canvas.drawPath(leftPath, strokePaint);
    canvas.drawPath(rightPath, strokePaint);

    // Текст 3D или 2D
    final tp = TextPainter(
      text: TextSpan(
        text: is3DMode ? '2D' : '3D',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 1));
  }

  @override
  bool shouldRepaint(covariant _CadViewCubePainter oldDelegate) =>
      oldDelegate.is3DMode != is3DMode || oldDelegate.isHovered != isHovered;
}
