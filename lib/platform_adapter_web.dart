import 'dart:convert';
import 'dart:html' as html;

class PlatformAdapterImpl {
  static void saveLocalStorage(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  static String? loadLocalStorage(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  static void downloadFile(String filename, List<int> bytes, String mimeType) {
    try {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  static void openOrDownloadHtml(String filename, String htmlContent) {
    try {
      final blob = html.Blob([utf8.encode(htmlContent)], 'text/html;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = filename;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.window.open(url, '_blank');
    } catch (_) {}
  }

  static void pickAndReadJson(void Function(String content) onLoaded) {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = '.json';
      uploadInput.click();
      uploadInput.onChange.listen((_) {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final reader = html.FileReader();
          reader.readAsText(files.first);
          reader.onLoadEnd.listen((_) {
            if (reader.result is String) {
              onLoaded(reader.result as String);
            }
          });
        }
      });
    } catch (_) {}
  }
}
