class PlatformAdapterImpl {
  static final Map<String, String> _memStorage = {};
  static void saveLocalStorage(String key, String value) {
    _memStorage[key] = value;
  }
  static String? loadLocalStorage(String key) => _memStorage[key];
  static void downloadFile(String filename, List<int> bytes, String mimeType) {}
  static void openOrDownloadHtml(String filename, String htmlContent) {}
  static void pickAndReadJson(void Function(String content) onLoaded) {}
}
