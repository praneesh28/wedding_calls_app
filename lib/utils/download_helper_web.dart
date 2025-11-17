// lib/utils/download_helper_web.dart
import 'dart:convert';
import 'dart:html' as html;

/// Triggers browser download of CSV. Returns filename on success or null.
Future<String?> saveAndShareCsv(String csvString, String filename) async {
  try {
    final bytes = const Utf8Encoder().convert(csvString);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return filename;
  } catch (e) {
    print('saveAndShareCsv (web) failed: $e');
    return null;
  }
}
