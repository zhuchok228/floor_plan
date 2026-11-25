import 'dart:io';

class PlatformAdapterImpl {
  static final Map<String, String> _memStorage = {};

  static void saveLocalStorage(String key, String value) {
    _memStorage[key] = value;
    try {
      final file = File('${Directory.systemTemp.path}/$key.json');
      file.writeAsStringSync(value);
    } catch (_) {}
  }

  static String? loadLocalStorage(String key) {
    if (_memStorage.containsKey(key)) return _memStorage[key];
    try {
      final file = File('${Directory.systemTemp.path}/$key.json');
      if (file.existsSync()) {
        final data = file.readAsStringSync();
        _memStorage[key] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  static void downloadFile(String filename, List<int> bytes, String mimeType) {
    try {
      final file = File('${Directory.systemTemp.path}/$filename');
      file.writeAsBytesSync(bytes);
    } catch (_) {}
  }

  static void openOrDownloadHtml(String filename, String htmlContent) {
    try {
      final file = File('${Directory.systemTemp.path}/$filename');
      file.writeAsStringSync(htmlContent);
    } catch (_) {}
  }

  static void pickAndReadJson(void Function(String content) onLoaded) {}
}
