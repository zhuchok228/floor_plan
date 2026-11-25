import 'platform_adapter_stub.dart'
    if (dart.library.html) 'platform_adapter_web.dart'
    if (dart.library.io) 'platform_adapter_io.dart';

abstract class PlatformAdapter {
  static void saveLocalStorage(String key, String value) =>
      PlatformAdapterImpl.saveLocalStorage(key, value);

  static String? loadLocalStorage(String key) =>
      PlatformAdapterImpl.loadLocalStorage(key);

  static void downloadFile(String filename, List<int> bytes, String mimeType) =>
      PlatformAdapterImpl.downloadFile(filename, bytes, mimeType);

  static void openOrDownloadHtml(String filename, String htmlContent) =>
      PlatformAdapterImpl.openOrDownloadHtml(filename, htmlContent);

  static void pickAndReadJson(void Function(String content) onLoaded) =>
      PlatformAdapterImpl.pickAndReadJson(onLoaded);
}
