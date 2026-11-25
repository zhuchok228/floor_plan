// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  // 1. Папки для текстур
  final texBase = Directory('assets/textures');
  final texFolders = {
    'Бетон': 'concrete',
    'Дерево': 'wood',
    'Кирпич и камень': 'brick_stone',
    'Ковры': 'carpets',
    'Кожа': 'leather',
    'Краска': 'paint',
    'Ландшафт': 'landscape',
    'Металл': 'metal',
    'Мрамор': 'marble',
    'Обои': 'wallpaper',
    'Плитка': 'tile',
  };

  if (!texBase.existsSync()) {
    texBase.createSync(recursive: true);
  }

  texFolders.forEach((ruName, enName) {
    final ruDir = Directory('${texBase.path}/$ruName');
    final enDir = Directory('${texBase.path}/$enName');

    if (ruDir.existsSync()) {
      ruDir.renameSync(enDir.path);
      print('✅ Переименована папка текстур: $ruName ->$enName');
    } else if (!enDir.existsSync()) {
      enDir.createSync(recursive: true);
      print('✅ Создана папка текстур: assets/textures/$enName/');
    }

    final keep = File('${enDir.path}/.gitkeep');
    if (!keep.existsSync()) keep.writeAsStringSync('');
  });

  // 2. Папки для 3D-моделей мебели (.glb, .gltf, .obj, .fbx)
  final modelsBase = Directory('assets/models');
  final modelFolders = {
    'living_room': 'Мягкая мебель (диваны, кресла)',
    'bedroom': 'Спальня (кровати, тумбы)',
    'tables_chairs': 'Столы и стулья',
    'storage': 'Шкафы и хранение',
    'kitchen': 'Кухня и бытовая техника',
    'plumbing': 'Сантехника и ванная',
    'decor': 'Декор, двери, растения',
    'electrical': 'Электрика, свет, радиаторы',
  };

  if (!modelsBase.existsSync()) {
    modelsBase.createSync(recursive: true);
  }

  modelFolders.forEach((enName, description) {
    final dir = Directory('${modelsBase.path}/$enName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final keep = File('${dir.path}/.gitkeep');
    if (!keep.existsSync()) keep.writeAsStringSync('');
    print('📦 Готова папка 3D-моделей: assets/models/$enName/ ($description)');
  });

  print('\n🔥 ВСЕ ПАПКИ ДЛЯ ТЕКСТУР И 3D-МОДЕЛЕЙ ГОТОВЫ!');
}