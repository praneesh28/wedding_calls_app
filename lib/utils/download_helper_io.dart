// lib/utils/download_helper_io.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves CSV string to local documents and opens share dialog.
/// Returns saved file path on success, null on failure.
Future<String?> saveAndShareCsv(String csvString, String filename) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsString(csvString);
    // share
    await Share.shareXFiles([XFile(path)], text: 'Wedding Guests CSV');
    return path;
  } catch (e) {
    print('saveAndShareCsv (IO) failed: $e');
    return null;
  }
}
