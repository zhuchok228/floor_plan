// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'
    show rootBundle, AssetManifest, StandardMessageCodec, LogicalKeyboardKey, HardwareKeyboard, KeyDownEvent;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:html' as html;

void main() {
  runApp(const FloorPlanApp());
}

class FloorPlanApp extends StatelessWidget {
  const FloorPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'План квартиры PRO 2D/3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const FloorPlanEditor(),
    );
  }
}

enum EditorTool {
  overview,
  drawWall,
  drawRoomBox,
  drawDimension,
  addDoor,
  addWindow,
  addObject,
}

enum OpeningType { door, window }

// Русские названия папок текстур
const Map<String, String> kTextureCategoryNamesRu = {
  'concrete': 'Бетон',
  'wood': 'Дерево',
  'brick_stone': 'Кирпич и камень',
  'carpets': 'Ковры',
  'leather': 'Кожа',
  'paint': 'Краска',
  'landscape': 'Ландшафт',
  'metal': 'Металл',
  'marble': 'Мрамор',
  'wallpaper': 'Обои',
  'tile': 'Плитка',
};

// Русские названия папок 3D-моделей мебели
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
  'storage': (1.80, 0.60, 2.20),
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
  });
}

class Wall {
  Offset start;
  Offset end;
  double thicknessCm;
  String? textureId;

  Wall(this.start, this.end, {this.thicknessCm = 15.0, this.textureId});

  double get lengthInMeters => (end - start).distance / 100.0;

  Map<String, dynamic> toJson() => {
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'th': thicknessCm,
        'tex': textureId,
      };

  factory Wall.fromJson(Map<String, dynamic> m) => Wall(
        Offset((m['sx'] as num).toDouble(), (m['sy'] as num).toDouble()),
        Offset((m['ex'] as num).toDouble(), (m['ey'] as num).toDouble()),
        thicknessCm: (m['th'] as num?)?.toDouble() ?? 15.0,
        textureId: m['tex'] as String?,
      );
}

class RoomZone {
  final String id;
  String name;
  List<Offset> polygon;
  Color color;
  String? textureId;
  bool isManuallyAdjusted;
  bool isOpenContour;

  RoomZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.color,
    this.textureId,
    this.isManuallyAdjusted = false,
    this.isOpenContour = false,
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
      );
}

class WallOpening {
  OpeningType type;
  String subtypeName;
  Offset position;
  double rotation;
  double widthMeters;
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
    this.depthCm = 15.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.textureId,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'sub': subtypeName,
        'px': position.dx,
        'py': position.dy,
        'rot': rotation,
        'w': widthMeters,
        'd': depthCm,
        'fh': flipHorizontal,
        'fv': flipVertical,
        'tex': textureId,
      };

  factory WallOpening.fromJson(Map<String, dynamic> m) => WallOpening(
        type: m['type'] == 'window' ? OpeningType.window : OpeningType.door,
        subtypeName: m['sub'] as String? ?? 'Проем',
        position: Offset((m['px'] as num).toDouble(), (m['py'] as num).toDouble()),
        rotation: (m['rot'] as num?)?.toDouble() ?? 0.0,
        widthMeters: (m['w'] as num?)?.toDouble() ?? 0.9,
        depthCm: (m['d'] as num?)?.toDouble() ?? 15.0,
        flipHorizontal: m['fh'] as bool? ?? false,
        flipVertical: m['fv'] as bool? ?? false,
        textureId: m['tex'] as String?,
      );
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

Offset _projectPointOnSegment(Offset p, Offset v, Offset w) {
  final l2 = (w - v).distanceSquared;
  if (l2 == 0) return v;
  double t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
  t = t.clamp(0.0, 1.0);
  return Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
}

class FloorPlanEditor extends StatefulWidget {
  const FloorPlanEditor({super.key});

  @override
  State<FloorPlanEditor> createState() => _FloorPlanEditorState();
}

class _FloorPlanEditorState extends State<FloorPlanEditor> with SingleTickerProviderStateMixin {
  static const String _kAutoSaveKey = 'floor_plan_pro_autosave_v2';

  bool isLoading = true;
  List<CatalogTexture> myTextureCatalog = [];
  List<Catalog3DModel> my3DModelCatalog = [];
  final Map<String, ui.Image> _loadedImages = {};
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

  EditorTool selectedTool = EditorTool.drawWall;
  double currentThicknessCm = 15.0;

  bool _hoveringWallToolBtn = false;
  bool _hoveringThicknessPopup = false;
  Timer? _hideThicknessTimer;

  // Настройки 2D камеры
  Offset canvasOffset = const Offset(80, 120);
  double canvasScale = 0.85;
  int activePointers = 0;
  double _baseScale = 1.0;
  Offset _baseFocalPoint = Offset.zero;
  Offset _baseCanvasOffset = Offset.zero;

  // Настройки 3D-режима и подъема стен
  bool is3DMode = false;
  double wallHeightMeters = 2.70;
  double cameraYaw = -0.65; // Вращение вокруг вертикальной оси
  double cameraPitch = 0.72; // Наклон камеры сверху вниз
  double cameraZoom3D = 0.95;
  Offset cameraPan3D = Offset.zero;
  late final AnimationController _wallRiseController;
  Offset? _last3DPointerPos;

  Timer? _autoPanTimer;
  Offset? _lastPointerScreenPos;
  Size _viewportSize = Size.zero;

  Offset? currentStart;
  Offset? currentEnd;
  Offset? snappedPointHighlight;

  Offset? draggedCornerOriginal;
  WallOpening? draggedOpening;
  InteriorObject? draggedObject;

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
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _redo();
        } else {
          _undo();
        }
        return true;
      }
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
        _redo();
        return true;
      }
    }
    return false;
  }

  String _encodeCurrentStateToJson() {
    return jsonEncode({
      'version': 2,
      'wallHeight': wallHeightMeters,
      'walls': walls.map((w) => w.toJson()).toList(),
      'zones': zones.map((z) => z.toJson()).toList(),
      'openings': openings.map((o) => o.toJson()).toList(),
      'objects': objects.map((o) => o.toJson()).toList(),
      'dimensions': customDimensions.map((d) => d.toJson()).toList(),
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
      editingBoundaryZone = null;

      if (saveToLocalStorage) {
        html.window.localStorage[_kAutoSaveKey] = jsonStr;
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
      html.window.localStorage[_kAutoSaveKey] = _encodeCurrentStateToJson();
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
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'floor_plan_${DateTime.now().millisecondsSinceEpoch}.json')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _importProjectJsonFile() {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();
    uploadInput.onChange.listen((_) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsText(files.first);
        reader.onLoadEnd.listen((_) {
          if (reader.result is String) {
            _recordSnapshotForUndo();
            setState(() {
              _restoreStateFromJson(reader.result as String);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проект успешно загружен!')),
              );
            }
          }
        });
      }
    });
  }

  Future<void> _exportPlanAsPng() async {
    const double outWidth = 2200.0;
    const double outHeight = 1500.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outWidth, outHeight));

    canvas.drawRect(const Rect.fromLTWH(0, 0, outWidth, outHeight), Paint()..color = const Color(0xFFF8FAFC));

    if (is3DMode) {
      final painter3d = Isometric3DPlanPainter(
        walls: walls,
        zones: zones,
        openings: openings,
        objects: objects,
        loadedImages: _loadedImages,
        wallHeightMeters: wallHeightMeters * _wallRiseController.value,
        yaw: cameraYaw,
        pitch: cameraPitch,
        zoom: cameraZoom3D * 1.4,
        panOffset: cameraPan3D,
      );
      painter3d.paint(canvas, const Size(outWidth, outHeight));
    } else {
      final painter = GridAndWallsPainter(
        walls: walls,
        zones: zones,
        editingBoundaryZone: null,
        openings: openings,
        objects: objects,
        customDimensions: customDimensions,
        canvasOffset: canvasOffset * 1.4,
        canvasScale: canvasScale * 1.4,
        selectedTool: EditorTool.overview,
        currentThicknessCm: currentThicknessCm,
        greenGuides: const [],
        loadedImages: _loadedImages,
      );
      painter.paint(canvas, const Size(outWidth, outHeight));
    }

    final stampRect = const Rect.fromLTWH(outWidth - 460, outHeight - 260, 430, 230);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stampRect, const Radius.circular(14)),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.94),
    );

    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'ЭКСПЛИКАЦИЯ ПОМЕЩЕНИЙ\n\n',
            style: TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: 'Общая площадь: ${totalZonesAreaSqM.toStringAsFixed(2)} м²\n'
                'Периметр стен: ${totalPerimeter.toStringAsFixed(2)} м (Высота: ${wallHeightMeters.toStringAsFixed(2)} м)\n'
                'Количество зон: ${zones.length}\n'
                'Объектов и 3D-моделей: ${objects.length}\n\n',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
          TextSpan(
            text: zones.take(4).map((z) => '• ${z.name}: ${z.areaSqM.toStringAsFixed(2)} м²').join('\n'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 390);
    tp.paint(canvas, Offset(stampRect.left + 20, stampRect.top + 20));

    final picture = recorder.endRecording();
    final img = await picture.toImage(outWidth.toInt(), outHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final bytes = byteData.buffer.asUint8List();
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'plan_${is3DMode ? "3D" : "2D"}_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _initializeProjectAndAssets() async {
    await _loadFolderAssets();
    final saved = html.window.localStorage[_kAutoSaveKey];
    if (saved != null && saved.isNotEmpty) {
      _restoreStateFromJson(saved, saveToLocalStorage: false);
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
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
        final String name = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;

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
          lower.endsWith('.stl');

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
            currentEnd = _snapPoint(worldPos, referenceStart: currentStart);
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

  Offset _snapPoint(Offset rawWorldPoint, {Offset? referenceStart, Offset? ignorePoint, bool allowOrtho = true}) {
    final double snapRadius = 26.0 / canvasScale;
    final double alignRadius = 15.0 / canvasScale;

    snappedPointHighlight = null;
    activeGreenGuides.clear();

    double x = rawWorldPoint.dx;
    double y = rawWorldPoint.dy;

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
    for (final wall in walls) {
      if ((wall.start - oldCorner).distance < 2.0) wall.start = newCorner;
      if ((wall.end - oldCorner).distance < 2.0) wall.end = newCorner;
    }
    _rebuildAutoZonesFromWalls();
  }

  double get totalPerimeter => walls.fold(0.0, (sum, w) => sum + w.lengthInMeters);
  double get totalZonesAreaSqM => zones.fold(0.0, (sum, z) => sum + z.areaSqM);

  void _onTapCanvas(Offset screenTapPos) {
    if (is3DMode) return;
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

    if (selectedTool == EditorTool.addDoor) {
      _recordSnapshotForUndo();
      final newDoor = WallOpening(
        type: OpeningType.door,
        subtypeName: 'Межкомнатная дверь',
        position: worldPos,
        widthMeters: 0.90,
      );
      setState(() {
        _snapOpeningToNearestWall(newDoor, worldPos);
        openings.add(newDoor);
        selectedTool = EditorTool.overview;
        _autoSaveCurrentProject();
      });
      return;
    }

    if (selectedTool == EditorTool.addWindow) {
      _recordSnapshotForUndo();
      final newWindow = WallOpening(
        type: OpeningType.window,
        subtypeName: 'Окно стандартное',
        position: worldPos,
        widthMeters: 1.20,
      );
      setState(() {
        _snapOpeningToNearestWall(newWindow, worldPos);
        openings.add(newWindow);
        selectedTool = EditorTool.overview;
        _autoSaveCurrentProject();
      });
      return;
    }

    if (selectedTool == EditorTool.addObject) {
      _showAddFurnitureCatalogModal(worldPos);
      return;
    }

    for (int i = customDimensions.length - 1; i >= 0; i--) {
      final dim = customDimensions[i];
      final proj = _projectPointOnSegment(worldPos, dim.start, dim.end);
      if ((worldPos - proj).distance < 22.0 / canvasScale) {
        _showEditDimensionDialog(i);
        return;
      }
    }

    for (int i = openings.length - 1; i >= 0; i--) {
      if ((openings[i].position - worldPos).distance < math.max(openings[i].widthMeters * 50, 25 / canvasScale)) {
        _showEditOpeningDialog(i);
        return;
      }
    }

    for (int i = objects.length - 1; i >= 0; i--) {
      if ((objects[i].position - worldPos).distance < math.max(objects[i].widthMeters, objects[i].depthMeters) * 50) {
        _showEditInteriorObjectDialog(i);
        return;
      }
    }

    for (int i = 0; i < walls.length; i++) {
      final proj = _projectPointOnSegment(worldPos, walls[i].start, walls[i].end);
      if ((worldPos - proj).distance < 18.0 / canvasScale) {
        _showEditWallDialog(i);
        return;
      }
    }

    for (int i = zones.length - 1; i >= 0; i--) {
      if (zones[i].containsPoint(worldPos) || (zones[i].visualCenter - worldPos).distance < 45 / canvasScale) {
        _showEditRoomZoneDialog(i);
        return;
      }
    }
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
                const Icon(Icons.calculate_outlined, color: Color(0xFF2563EB), size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Спецификация материалов и смета площадей',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _exportPlanAsPng,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Скачать PNG чертеж'),
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
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB), fontSize: 14),
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
                            color: const Color(0xFF2563EB)),
                        title: Text('${o.category}: ${o.name}'),
                        subtitle: Text(o.model3dPath != null ? '3D файл: ${o.model3dPath}' : 'Стандартный 2D/3D-габарит'),
                        trailing: Text(
                            '${o.widthMeters.toStringAsFixed(2)} × ${o.depthMeters.toStringAsFixed(2)} × ${o.heightMeters.toStringAsFixed(2)} м'),
                      )),
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
                    const Icon(Icons.view_in_ar_rounded, color: Color(0xFF2563EB), size: 26),
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
                            'Папки для ваших .glb/.obj/.fbx моделей: assets/models/living_room, bedroom, kitchen, plumbing и др.',
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
                                setState(() {
                                  objects.add(InteriorObject(
                                    category: m.categoryRu,
                                    name: m.name,
                                    position: worldPos,
                                    widthMeters: m.defaultWidthM,
                                    depthMeters: m.defaultDepthM,
                                    heightMeters: m.defaultHeightM,
                                    model3dPath: m.modelAssetPath,
                                    previewImagePath: m.previewImagePath,
                                  ));
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
                                            '3D • ${m.extension}',
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
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            '💡 Папки для ваших 3D-моделей готовы в assets/models/ (living_room, bedroom, kitchen, plumbing и т.д.). '
                            'Закиньте туда файлы .glb / .obj / .fbx (или назовите файл sofa_220x95.glb для авторазмера) — они появятся здесь автоматически!',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'БАЗОВЫЕ ШАБЛОНЫ МЕБЕЛИ И САНТЕХНИКИ:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
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
                              setState(() {
                                objects.add(InteriorObject(
                                  category: item.$1,
                                  name: item.$2,
                                  position: worldPos,
                                  widthMeters: item.$3,
                                  depthMeters: item.$4,
                                  heightMeters: item.$5,
                                  textureId: myTextureCatalog.isNotEmpty ? myTextureCatalog.first.id : null,
                                ));
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
              const Icon(Icons.meeting_room_outlined, color: Color(0xFF2563EB)),
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
                const SizedBox(height: 16),
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
                        width: 36,
                        height: 36,
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
                const SizedBox(height: 16),
                const Text('Текстура пола:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: tempTex,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Заливка цветом (без текстуры)', style: TextStyle(fontSize: 12.5)),
                    ),
                    ...myTextureCatalog.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.category}: ${t.name}', style: const TextStyle(fontSize: 12.5)),
                        )),
                  ],
                  onChanged: (val) => setDialogState(() => tempTex = val),
                ),
                const SizedBox(height: 18),
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
                TextField(controller: wCtrl, decoration: const InputDecoration(labelText: 'Ширина (м)', border: OutlineInputBorder())),
                if (hostWall != null) ...[
                  const SizedBox(height: 10),
                  const Text('Отступы от углов стены:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                Slider(value: tempRot < 0 ? tempRot + 360 : tempRot, min: 0, max: 360, divisions: 72, onChanged: (v) => setDialogState(() => tempRot = v)),
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
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: tempTex,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Текстура'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Базовый цвет', style: TextStyle(fontSize: 12))),
                    ...myTextureCatalog.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.category} - ${t.name}', style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) => setDialogState(() => tempTex = val),
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
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                final nw = double.tryParse(wCtrl.text.replaceAll(',', '.'));
                setState(() {
                  if (nw != null && nw > 0.2) op.widthMeters = nw;
                  op.rotation = tempRot * math.pi / 180.0;
                  op.textureId = tempTex;

                  if (hostWall != null) {
                    double finalCenterM = currentCenterM;
                    if (startEdited) {
                      double startV = double.tryParse(offsetStartCtrl.text.replaceAll(',', '.')) ?? (currentCenterM - op.widthMeters / 2);
                      finalCenterM = startV + op.widthMeters / 2;
                    } else if (endEdited) {
                      double endV = double.tryParse(offsetEndCtrl.text.replaceAll(',', '.')) ?? (hostWall.lengthInMeters - currentCenterM - op.widthMeters / 2);
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

  void _showEditWallDialog(int wallIndex) {
    final wall = walls[wallIndex];
    final wCtrl = TextEditingController(text: wall.lengthInMeters.toStringAsFixed(2));
    double tempThick = wall.thicknessCm;
    String? tempTex = wall.textureId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Параметры стены'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: wCtrl, decoration: const InputDecoration(labelText: 'Точная длина (м)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Text('Толщина: ${tempThick.round()} см', style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(value: tempThick, min: 5, max: 50, divisions: 45, onChanged: (v) => setDialogState(() => tempThick = v)),
                DropdownButtonFormField<String?>(
                  initialValue: tempTex,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Отделка'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Без отделки', style: TextStyle(fontSize: 12))),
                    ...myTextureCatalog.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.category} - ${t.name}', style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) => setDialogState(() => tempTex = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  walls.removeAt(wallIndex);
                  _rebuildAutoZonesFromWalls();
                });
                Navigator.pop(context);
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                final nw = double.tryParse(wCtrl.text.replaceAll(',', '.'));
                setState(() {
                  wall.thicknessCm = tempThick;
                  wall.textureId = tempTex;
                  if (nw != null && nw > 0) {
                    final d = (wall.end - wall.start).distance;
                    if (d > 0) _moveConnectedCorner(wall.end, wall.start + ((wall.end - wall.start) / d) * (nw * 100.0));
                  }
                  _rebuildAutoZonesFromWalls();
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

  void _showEditInteriorObjectDialog(int index) {
    final obj = objects[index];
    final nameCtrl = TextEditingController(text: obj.name);
    final wCtrl = TextEditingController(text: obj.widthMeters.toStringAsFixed(2));
    final dCtrl = TextEditingController(text: obj.depthMeters.toStringAsFixed(2));
    final hCtrl = TextEditingController(text: obj.heightMeters.toStringAsFixed(2));
    double tempRot = obj.rotationDeg;
    String? tempTex = obj.textureId;
    String? tempModel = obj.model3dPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Параметры объекта / 3D-модели'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: wCtrl, decoration: const InputDecoration(labelText: 'Ширина (м)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: dCtrl, decoration: const InputDecoration(labelText: 'Глубина (м)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: hCtrl, decoration: const InputDecoration(labelText: 'Высота (м)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Поворот: ${tempRot.round()}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Slider(value: tempRot, min: 0, max: 360, divisions: 72, onChanged: (v) => setDialogState(() => tempRot = v)),
                DropdownButtonFormField<String?>(
                  initialValue: tempModel,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Привязанная 3D-модель (assets/models/)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Без 3D-файла (стандартный блок)', style: TextStyle(fontSize: 12))),
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
                    ...myTextureCatalog.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.category} - ${t.name}', style: const TextStyle(fontSize: 12)))),
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
                  _autoSaveCurrentProject();
                });
                Navigator.pop(context);
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _recordSnapshotForUndo();
                setState(() {
                  obj.name = nameCtrl.text.trim().isEmpty ? obj.name : nameCtrl.text.trim();
                  obj.widthMeters = double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? obj.widthMeters;
                  obj.depthMeters = double.tryParse(dCtrl.text.replaceAll(',', '.')) ?? obj.depthMeters;
                  obj.heightMeters = double.tryParse(hCtrl.text.replaceAll(',', '.')) ?? obj.heightMeters;
                  obj.rotationDeg = tempRot;
                  obj.model3dPath = tempModel;
                  obj.textureId = tempTex;
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('База текстур (assets/textures/)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          Text(
                            'Нажмите на материал, чтобы применить его ко всем зонам (или настройте отдельно кликом по комнате)',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
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
                              for (final z in zones) {
                                z.textureId = tex.id;
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

  void _showCadSnapsMenu(BuildContext btnContext) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.grid_4x4_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Объектные привязки и шаг сетки', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text('Привязка к сетке (шаг ${snapConfig.gridStepCm.round()} см)'),
                value: snapConfig.snapToGrid,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapToGrid = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('К концам стен (Endpoint)'),
                value: snapConfig.snapToEndpoints,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapToEndpoints = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('К линиям стен (Nearest)'),
                value: snapConfig.snapToWallLines,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapToWallLines = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('К серединам стен (Midpoint)'),
                value: snapConfig.snapToMidpoints,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapToMidpoints = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Зеленые линии выравнивания (Extension)'),
                value: snapConfig.snapAlignmentLines,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapAlignmentLines = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Ортогональность 0° / 90° (Ortho)'),
                value: snapConfig.snapOrtho90,
                onChanged: (v) {
                  setModalState(() => snapConfig.snapOrtho90 = v);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Готово')),
          ],
        ),
      ),
    );
  }

  void _finishDrawingShape() {
    if (currentStart == null || currentEnd == null) return;

    if (selectedTool == EditorTool.drawWall) {
      if ((currentEnd! - currentStart!).distance >= 5.0) {
        _recordSnapshotForUndo();
        walls.add(Wall(currentStart!, currentEnd!, thicknessCm: currentThicknessCm));
        _rebuildAutoZonesFromWalls();
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
        final tl = rect.topLeft;
        final tr = rect.topRight;
        final br = rect.bottomRight;
        final bl = rect.bottomLeft;
        walls.add(Wall(tl, tr, thicknessCm: currentThicknessCm));
        walls.add(Wall(tr, br, thicknessCm: currentThicknessCm));
        walls.add(Wall(br, bl, thicknessCm: currentThicknessCm));
        walls.add(Wall(bl, tl, thicknessCm: currentThicknessCm));
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: is3DMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              Listener(
                onPointerDown: (_) => activePointers++,
                onPointerUp: (_) {
                  activePointers = math.max(0, activePointers - 1);
                  _stopAutoPan();
                },
                onPointerCancel: (_) {
                  activePointers = math.max(0, activePointers - 1);
                  _stopAutoPan();
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
                    if (is3DMode) {
                      _last3DPointerPos = details.localFocalPoint;
                      _baseScale = cameraZoom3D;
                      return;
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
                        currentStart = _snapPoint(worldPos, allowOrtho: false);
                        currentEnd = currentStart;
                      });
                    } else if (selectedTool == EditorTool.overview) {
                      for (final op in openings.reversed) {
                        if ((op.position - worldPos).distance < math.max(op.widthMeters * 50, 28 / canvasScale)) {
                          _recordSnapshotForUndo();
                          draggedOpening = op;
                          return;
                        }
                      }
                      for (final obj in objects.reversed) {
                        if ((obj.position - worldPos).distance < math.max(obj.widthMeters, obj.depthMeters) * 50) {
                          _recordSnapshotForUndo();
                          draggedObject = obj;
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
                    }
                  },
                  onScaleUpdate: (details) {
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
                      setState(() => currentEnd = _snapPoint(worldPos, referenceStart: currentStart, allowOrtho: true));
                    } else if (selectedTool == EditorTool.drawRoomBox && currentStart != null) {
                      _startOrUpdateAutoPan(screenPos);
                      setState(() => currentEnd = _snapPoint(worldPos, allowOrtho: false));
                    } else if (selectedTool == EditorTool.overview) {
                      if (draggedOpening != null) {
                        setState(() => _snapOpeningToNearestWall(draggedOpening!, worldPos));
                      } else if (draggedObject != null) {
                        final step = snapConfig.gridStepCm;
                        setState(() => draggedObject!.position = snapConfig.snapToGrid
                            ? Offset((worldPos.dx / step).round() * step, (worldPos.dy / step).round() * step)
                            : worldPos);
                      } else if (draggedCornerOriginal != null) {
                        _startOrUpdateAutoPan(screenPos);
                        setState(() {
                          final nc = _snapPoint(worldPos, ignorePoint: draggedCornerOriginal);
                          _moveConnectedCorner(draggedCornerOriginal!, nc);
                          draggedCornerOriginal = nc;
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
                      if (draggedOpening != null || draggedObject != null || draggedCornerOriginal != null) {
                        _autoSaveCurrentProject();
                      }
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
                              wallHeightMeters: wallHeightMeters *
                                  CurvedAnimation(parent: _wallRiseController, curve: Curves.easeOutCubic).value,
                              yaw: cameraYaw,
                              pitch: cameraPitch,
                              zoom: cameraZoom3D,
                              panOffset: cameraPan3D,
                            )
                          : GridAndWallsPainter(
                              walls: walls,
                              zones: zones,
                              editingBoundaryZone: editingBoundaryZone,
                              openings: openings,
                              objects: objects,
                              customDimensions: customDimensions,
                              canvasOffset: canvasOffset,
                              canvasScale: canvasScale,
                              selectedTool: selectedTool,
                              currentStart: currentStart,
                              currentEnd: currentEnd,
                              currentThicknessCm: currentThicknessCm,
                              snappedPointHighlight: snappedPointHighlight,
                              greenGuides: activeGreenGuides,
                              loadedImages: _loadedImages,
                            ),
                    ),
                  ),
                ),
              ),

              // ВЕРХНЯЯ ПАНЕЛЬ СТАТИСТИКИ, 3D-ПЕРЕКЛЮЧАТЕЛЯ, СМЕТЫ И СОХРАНЕНИЯ
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildStatBadge(
                              title: 'ПЛОЩАДЬ (${zones.length} зон)',
                              value: '${totalZonesAreaSqM.toStringAsFixed(2)} м²',
                              color: const Color(0xFF34D399),
                            ),
                            _buildStatBadge(
                              title: 'ПЕРИМЕТР',
                              value: '${totalPerimeter.toStringAsFixed(2)} м',
                              color: Colors.white,
                            ),
                            // КНОПКА ПЕРЕКЛЮЧЕНИЯ 2D / 3D (ПОДЪЕМ СТЕН)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: is3DMode ? const Color(0xFFD97706) : const Color(0xFF7C3AED),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: _toggle3DMode,
                              icon: Icon(is3DMode ? Icons.map_outlined : Icons.view_in_ar_rounded, size: 18),
                              label: Text(
                                is3DMode ? 'Вернуться в 2D чертёж' : '3D Вид (Поднять стены)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                              onPressed: _openTextureCatalogModal,
                              icon: const Icon(Icons.texture, size: 17),
                              label: Text('Текстуры (${myTextureCatalog.length})'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                              onPressed: _showMaterialsSpecificationModal,
                              icon: const Icon(Icons.calculate_outlined, size: 17),
                              label: const Text('Смета'),
                            ),
                            IconButton(
                              tooltip: 'Отменить шаг (Ctrl+Z)',
                              icon: const Icon(Icons.undo, color: Colors.white),
                              onPressed: _undoStack.isEmpty ? null : _undo,
                            ),
                            IconButton(
                              tooltip: 'Вернуть шаг (Ctrl+Y)',
                              icon: const Icon(Icons.redo, color: Colors.white),
                              onPressed: _redoStack.isEmpty ? null : _redo,
                            ),
                            IconButton(
                              tooltip: 'Сохранить проект в файл (.json)',
                              icon: const Icon(Icons.download_outlined, color: Colors.amberAccent),
                              onPressed: _exportProjectJsonFile,
                            ),
                            IconButton(
                              tooltip: 'Загрузить проект из файла (.json)',
                              icon: const Icon(Icons.folder_open_outlined, color: Colors.amberAccent),
                              onPressed: _importProjectJsonFile,
                            ),
                            IconButton(
                              tooltip: 'Экспорт в картинку PNG',
                              icon: const Icon(Icons.camera_alt_outlined, color: Colors.lightBlueAccent),
                              onPressed: _exportPlanAsPng,
                            ),
                            IconButton(
                              tooltip: 'Очистить всё',
                              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                              onPressed: () {
                                _recordSnapshotForUndo();
                                setState(() {
                                  walls.clear();
                                  zones.clear();
                                  openings.clear();
                                  objects.clear();
                                  customDimensions.clear();
                                  editingBoundaryZone = null;
                                  _autoSaveCurrentProject();
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      if (editingBoundaryZone != null && !is3DMode)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Корректировка «${editingBoundaryZone!.name}»: тяните зеленые точки',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF059669),
                                ),
                                onPressed: () => setState(() => editingBoundaryZone = null),
                                child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // НИЖНЯЯ ПАНЕЛЬ: В 3D РЕЖИМЕ — УПРАВЛЕНИЕ ВЫСОТОЙ СТЕН И КАМЕРОЙ, В 2D — ИНСТРУМЕНТЫ ЧЕРЧЕНИЯ
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
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.height, color: Color(0xFF34D399), size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'Высота стен:',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 200,
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
                              const Text(
                                'Мышь: вращение 360° • Shift + Мышь: панорама • Колесо: зум',
                                style: TextStyle(color: Colors.white60, fontSize: 11.5),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 4))],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildToolBtn(EditorTool.overview, Icons.pan_tool_alt_outlined, 'Обзор'),
                                    _buildWallHoverToolBtn(EditorTool.drawWall, Icons.edit_road, 'Стена (${currentThicknessCm.round()} см)'),
                                    _buildWallHoverToolBtn(EditorTool.drawRoomBox, Icons.crop_square_rounded, 'Коробка'),
                                    _buildToolBtn(EditorTool.drawDimension, Icons.straighten_rounded, 'Размер'),
                                    _buildToolBtn(EditorTool.addDoor, Icons.door_front_door_outlined, 'Дверь'),
                                    _buildToolBtn(EditorTool.addWindow, Icons.window_outlined, 'Окно'),
                                    _buildToolBtn(EditorTool.addObject, Icons.view_in_ar_rounded, 'Мебель / 3D'),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.grid_4x4, size: 16, color: Color(0xFF2563EB)),
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
                                          foregroundColor: const Color(0xFF059669),
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

  Widget _buildStatBadge({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.white60)),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
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
      onTap: () => setState(() => selectedTool = tool),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: isSel ? Colors.white : const Color(0xFF334155)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleTexturePreviewPainter extends CustomPainter {
  final ui.Image image;
  _SingleTexturePreviewPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.mirror,
        ui.TileMode.mirror,
        (Matrix4.identity()..scaleByDouble(0.65, 0.65, 1.0, 1.0)).storage,
      );
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 3D-ДВИЖОК С ПОДНИМАЮЩИМИСЯ СТЕНАМИ, ПРОЕМАМИ ДВЕРЕЙ/ОКОН И 3D-МЕБЕЛЬЮ
// =========================================================================
class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);
}

class _Face3D {
  final List<Offset> screenPoints;
  final double depth;
  final Color color;
  final Color borderColor;
  final String? label;

  _Face3D({
    required this.screenPoints,
    required this.depth,
    required this.color,
    required this.borderColor,
    this.label,
  });
}

class Isometric3DPlanPainter extends CustomPainter {
  final List<Wall> walls;
  final List<RoomZone> zones;
  final List<WallOpening> openings;
  final List<InteriorObject> objects;
  final Map<String, ui.Image> loadedImages;
  final double wallHeightMeters;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset panOffset;

  Isometric3DPlanPainter({
    required this.walls,
    required this.zones,
    required this.openings,
    required this.objects,
    required this.loadedImages,
    required this.wallHeightMeters,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Вычисляем геометрический центр плана, чтобы вращать квартиру вокруг её центра
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

    // Проекция 3D точки (x, y, z) в экранные координаты + глубина для сортировки
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

    // 2. Рисуем 3D-сетку земли (основание)
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

    // 3. Рисуем полы комнат на высоте Z = 0
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

      Color floorColor = zone.color.withValues(alpha: 0.72);
      canvas.drawPath(path, Paint()..color = floorColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white30
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 4. Собираем все 3D-грани (стены с проемами дверей/окон + 3D-мебель)
    final List<_Face3D> allFaces = [];
    final double hPx = wallHeightMeters * 100.0;

    void addPrismBox(Offset p1, Offset p2, double thickness, double zBottom, double zTop, Color baseColor,
        {String? topLabel, Color? stroke}) {
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
      final border = stroke ?? Colors.black.withValues(alpha: 0.35);

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

    // Строим стены с автоматическим вырезанием дверных и оконных проемов
    for (final wall in walls) {
      final wallVec = wall.end - wall.start;
      final wallLen = wallVec.distance;
      if (wallLen < 2.0) continue;
      final dir = wallVec / wallLen;

      // Ищем все двери и окна, лежащие на этой стене
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

      const Color wallBaseColor = Color(0xFFE2E8F0);
      double cursor = 0.0;

      for (final item in wallOpenings) {
        final sDist = item.$1;
        final eDist = item.$2;
        final op = item.$3;

        // Глухой участок стены до проема
        if (sDist > cursor + 1.0) {
          addPrismBox(
            wall.start + dir * cursor,
            wall.start + dir * sDist,
            wall.thicknessCm,
            0.0,
            hPx,
            wallBaseColor,
          );
        }

        final opStartPt = wall.start + dir * sDist;
        final opEndPt = wall.start + dir * eDist;

        if (op.type == OpeningType.door) {
          // Дверной проем: высота двери 2.10 м, сверху перемычка до потолка
          final double doorTopPx = math.min(210.0, hPx);
          if (hPx > doorTopPx + 2.0) {
            addPrismBox(opStartPt, opEndPt, wall.thicknessCm, doorTopPx, hPx, wallBaseColor);
          }
          // Полупрозрачное дверное полотно
          addPrismBox(
            opStartPt,
            opEndPt,
            4.0,
            0.0,
            doorTopPx,
            const Color(0xFFB45309).withValues(alpha: 0.55),
          );
        } else {
          // Оконный проем: подоконник до 0.90 м, окно до 2.10 м, перемычка выше 2.10 м
          final double sillPx = math.min(90.0, hPx);
          final double winTopPx = math.min(210.0, hPx);
          if (sillPx > 2.0) {
            addPrismBox(opStartPt, opEndPt, wall.thicknessCm, 0.0, sillPx, wallBaseColor);
          }
          if (winTopPx > sillPx + 2.0) {
            // Голубое полупрозрачное стекло окна
            addPrismBox(
              opStartPt,
              opEndPt,
              4.0,
              sillPx,
              winTopPx,
              const Color(0xFF38BDF8).withValues(alpha: 0.45),
              stroke: const Color(0xFF0284C7),
            );
          }
          if (hPx > winTopPx + 2.0) {
            addPrismBox(opStartPt, opEndPt, wall.thicknessCm, winTopPx, hPx, wallBaseColor);
          }
        }

        cursor = math.max(cursor, eDist);
      }

      // Остаток глухой стены после последнего проема
      if (cursor < wallLen - 1.0) {
        addPrismBox(
          wall.start + dir * cursor,
          wall.end,
          wall.thicknessCm,
          0.0,
          hPx,
          wallBaseColor,
        );
      }
    }

    // 5. Добавляем 3D-объекты мебели и оборудования
    for (final obj in objects) {
      final rad = obj.rotationDeg * math.pi / 180.0;
      final dir = Offset(math.cos(rad), math.sin(rad));
      final halfLen = (obj.widthMeters * 100.0) / 2.0;
      final p1 = obj.position - dir * halfLen;
      final p2 = obj.position + dir * halfLen;
      final objHeightPx = obj.heightMeters * 100.0 * (wallHeightMeters / 2.70).clamp(0.2, 1.2);

      final Color boxColor = obj.model3dPath != null ? const Color(0xFF34D399) : const Color(0xFF60A5FA);
      addPrismBox(
        p1,
        p2,
        obj.depthMeters * 100.0,
        0.0,
        objHeightPx,
        boxColor,
        topLabel: obj.name,
      );
    }

    // 6. Сортируем все 3D-грани от дальних к ближним (Painter's Algorithm) и рисуем
    allFaces.sort((a, b) => a.depth.compareTo(b.depth));

    for (final face in allFaces) {
      final path = Path()
        ..moveTo(face.screenPoints[0].dx, face.screenPoints[0].dy)
        ..lineTo(face.screenPoints[1].dx, face.screenPoints[1].dy)
        ..lineTo(face.screenPoints[2].dx, face.screenPoints[2].dy)
        ..lineTo(face.screenPoints[3].dx, face.screenPoints[3].dy)
        ..close();

      canvas.drawPath(path, Paint()..color = face.color);
      canvas.drawPath(
        path,
        Paint()
          ..color = face.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      if (face.label != null) {
        final center = Offset(
          (face.screenPoints[0].dx + face.screenPoints[2].dx) / 2,
          (face.screenPoints[0].dy + face.screenPoints[2].dy) / 2,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: face.label,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      }
    }

    // 7. Подписи комнат в 3D
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridAndWallsPainter extends CustomPainter {
  final List<Wall> walls;
  final List<RoomZone> zones;
  final RoomZone? editingBoundaryZone;
  final List<WallOpening> openings;
  final List<InteriorObject> objects;
  final List<CustomDimensionLine> customDimensions;
  final Offset canvasOffset;
  final double canvasScale;
  final EditorTool selectedTool;
  final Offset? currentStart, currentEnd, snappedPointHighlight;
  final double currentThicknessCm;
  final List<SnapGuideLine> greenGuides;
  final Map<String, ui.Image> loadedImages;

  GridAndWallsPainter({
    required this.walls,
    required this.zones,
    this.editingBoundaryZone,
    required this.openings,
    required this.objects,
    required this.customDimensions,
    required this.canvasOffset,
    required this.canvasScale,
    required this.selectedTool,
    this.currentStart,
    this.currentEnd,
    required this.currentThicknessCm,
    this.snappedPointHighlight,
    required this.greenGuides,
    required this.loadedImages,
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

    if (canvasScale > 0.45) {
      final subGrid = Paint()
        ..color = Colors.blueGrey.withValues(alpha: 0.12)
        ..strokeWidth = 1.0 / canvasScale;
      for (double x = (left / 10).floor() * 10.0; x <= right; x += 10) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), subGrid);
      }
      for (double y = (top / 10).floor() * 10.0; y <= bottom; y += 10) {
        canvas.drawLine(Offset(left, y), Offset(right, y), subGrid);
      }
    }

    final mainGrid = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.28)
      ..strokeWidth = 1.5 / canvasScale;
    for (double x = (left / 100).floor() * 100.0; x <= right; x += 100) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), mainGrid);
    }
    for (double y = (top / 100).floor() * 100.0; y <= bottom; y += 100) {
      canvas.drawLine(Offset(left, y), Offset(right, y), mainGrid);
    }

    for (final zone in zones) {
      if (zone.polygon.length < 3) continue;
      final path = Path()..addPolygon(zone.polygon, true);
      final fillPaint = Paint();

      if (zone.textureId != null && loadedImages.containsKey(zone.textureId)) {
        final img = loadedImages[zone.textureId]!;
        const double tileWidthPx = 550.0;
        final double scaleFactor = tileWidthPx / img.width;

        fillPaint.shader = ui.ImageShader(
          img,
          ui.TileMode.mirror,
          ui.TileMode.mirror,
          (Matrix4.identity()..scaleByDouble(scaleFactor, scaleFactor, 1.0, 1.0)).storage,
        );
      } else {
        fillPaint.color = zone.color.withValues(alpha: zone.isOpenContour ? 0.24 : 0.34);
      }
      canvas.drawPath(path, fillPaint);

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

    final guidePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.0 / canvasScale
      ..style = PaintingStyle.stroke;

    for (final g in greenGuides) {
      _drawDashedLine(canvas, g.from, g.to, guidePaint);
      canvas.drawCircle(g.from, 5 / canvasScale, Paint()..color = const Color(0xFF10B981));
    }

    for (final obj in objects) {
      _drawInteriorObject(canvas, obj);
    }

    for (final wall in walls) {
      _drawWall(canvas, wall);
    }

    for (final dim in customDimensions) {
      _drawCustomDimension(canvas, dim.start, dim.end);
    }

    if (currentStart != null && currentEnd != null) {
      if (selectedTool == EditorTool.drawWall) {
        _drawWall(canvas, Wall(currentStart!, currentEnd!, thicknessCm: currentThicknessCm), isPreview: true);
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

    for (final zone in zones) {
      _drawZoneCenterBadge(canvas, zone);
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

    canvas.restore();
  }

  void _drawCustomDimension(Canvas canvas, Offset p1, Offset p2, {bool isPreview = false}) {
    final vec = p2 - p1;
    final len = vec.distance;
    if (len < 2.0) return;

    final dir = vec / len;
    final normal = Offset(-dir.dy, dir.dx);
    final tick = normal * (6.0 / canvasScale);

    final color = isPreview ? const Color(0xFF2563EB) : const Color(0xFFD97706);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 / canvasScale;

    canvas.drawLine(p1, p2, linePaint);
    canvas.drawLine(p1 - tick, p1 + tick, linePaint);
    canvas.drawLine(p2 - tick, p2 + tick, linePaint);

    _drawDimText(canvas, p1, p2, len / 100.0, badgeColor: const Color(0xFFFEF3C7));
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
    final tp = TextPainter(
      text: TextSpan(
        text: '${valueM.toStringAsFixed(2)} м',
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
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentThicknessCm,
    );
    final wM = rect.width.abs() / 100.0;
    final hM = rect.height.abs() / 100.0;
    final area = wM * hM;
    final tp = TextPainter(
      text: TextSpan(
        text: '${wM.toStringAsFixed(2)} × ${hM.toStringAsFixed(2)} м\nПлощадь: ${area.toStringAsFixed(2)} м²',
        style: TextStyle(
          color: const Color(0xFF1D4ED8),
          fontSize: 13 / canvasScale.clamp(0.6, 1.8),
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = Rect.fromCenter(
      center: rect.center,
      width: tp.width + 14 / canvasScale,
      height: tp.height + 8 / canvasScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(6 / canvasScale)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  void _drawInteriorObject(Canvas canvas, InteriorObject obj) {
    canvas.save();
    canvas.translate(obj.position.dx, obj.position.dy);
    canvas.rotate(obj.rotationDeg * math.pi / 180.0);

    final rect = Rect.fromCenter(center: Offset.zero, width: obj.widthMeters * 100, height: obj.depthMeters * 100);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    if (obj.previewImagePath != null && loadedImages.containsKey(obj.previewImagePath)) {
      final img = loadedImages[obj.previewImagePath]!;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        rect,
        Paint(),
      );
    } else {
      final p = Paint();
      if (obj.textureId != null && loadedImages.containsKey(obj.textureId)) {
        p.shader = ui.ImageShader(
          loadedImages[obj.textureId]!,
          ui.TileMode.mirror,
          ui.TileMode.mirror,
          (Matrix4.identity()..scaleByDouble(0.5, 0.5, 1.0, 1.0)).storage,
        );
      } else {
        p.color = obj.model3dPath != null ? const Color(0xFFA7F3D0) : Colors.blueGrey.shade200;
      }
      canvas.drawRRect(rrect, p);
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = obj.model3dPath != null ? const Color(0xFF059669) : Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / canvasScale,
    );

    final badge = obj.model3dPath != null ? '[3D] ' : '';
    final tp = TextPainter(
      text: TextSpan(
        text: '$badge${obj.name}\n${obj.widthMeters.toStringAsFixed(2)}×${obj.depthMeters.toStringAsFixed(2)}м',
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

  void _drawWall(Canvas canvas, Wall wall, {bool isPreview = false}) {
    final p = Paint()
      ..strokeWidth = wall.thicknessCm
      ..strokeCap = StrokeCap.round;
    if (wall.textureId != null && !isPreview && loadedImages.containsKey(wall.textureId)) {
      p.shader = ui.ImageShader(
        loadedImages[wall.textureId]!,
        ui.TileMode.mirror,
        ui.TileMode.mirror,
        (Matrix4.identity()..scaleByDouble(0.5, 0.5, 1.0, 1.0)).storage,
      );
    } else {
      p.color = isPreview ? const Color(0xFF2563EB) : const Color(0xFF1E293B);
    }
    canvas.drawLine(wall.start, wall.end, p);
    canvas.drawCircle(wall.start, 4.5 / canvasScale, Paint()..color = Colors.white);
    canvas.drawCircle(wall.end, 4.5 / canvasScale, Paint()..color = Colors.white);

    final len = wall.lengthInMeters;
    if (len < 0.05) return;
    final mid = Offset((wall.start.dx + wall.end.dx) / 2, (wall.start.dy + wall.end.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: '${len.toStringAsFixed(2)} м',
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
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  void _drawOpening(Canvas canvas, WallOpening op) {
    canvas.save();
    canvas.translate(op.position.dx, op.position.dy);
    canvas.rotate(op.rotation);
    final rect = Rect.fromCenter(center: Offset.zero, width: op.widthMeters * 100, height: op.depthCm + 3);
    final p = Paint();
    if (op.textureId != null && loadedImages.containsKey(op.textureId)) {
      p.shader = ui.ImageShader(
        loadedImages[op.textureId]!,
        ui.TileMode.mirror,
        ui.TileMode.mirror,
        (Matrix4.identity()..scaleByDouble(0.5, 0.5, 1.0, 1.0)).storage,
      );
    } else {
      p.color = Colors.white;
    }
    canvas.drawRect(rect, p);
    canvas.drawRect(
      rect,
      Paint()
        ..color = op.type == OpeningType.door ? Colors.brown : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / canvasScale,
    );
    if (op.type == OpeningType.door) {
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