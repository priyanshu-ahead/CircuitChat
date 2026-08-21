import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// File system helpers (replaces react-native-fs).
class AppFileUtils {
  AppFileUtils._();

  /// Returns the app's temporary directory path.
  static Future<String> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Returns the app documents directory path.
  static Future<String> getDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Read file as a string.
  static Future<String> readAsString(String path) =>
      File(path).readAsString();

  /// Read file as bytes.
  static Future<List<int>> readAsBytes(String path) =>
      File(path).readAsBytes();

  /// Write string to file, creating parent directories if needed.
  static Future<File> writeString(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  /// Delete a file if it exists.
  static Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Get file size in bytes, returns 0 if not found.
  static Future<int> fileSize(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// Returns the file extension (without the dot), e.g. "mp4".
  static String extension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Returns true for common image extensions.
  static bool isImage(String path) =>
      {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'}.contains(extension(path));

  /// Returns true for common video extensions.
  static bool isVideo(String path) =>
      {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(extension(path));

  /// Returns true for common audio extensions.
  static bool isAudio(String path) =>
      {'mp3', 'aac', 'm4a', 'wav', 'ogg', 'opus'}.contains(extension(path));
}
