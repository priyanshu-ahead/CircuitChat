import 'package:permission_handler/permission_handler.dart';

/// Centralised permission request helpers (replaces react-native-permissions).
class PermissionService {
  const PermissionService._();
  static const PermissionService instance = PermissionService._();

  // ── Camera & Gallery ─────────────────────────────────────────────────────
  Future<bool> requestCamera() async =>
      (await Permission.camera.request()).isGranted;

  Future<bool> requestPhotos() async =>
      (await Permission.photos.request()).isGranted;

  // ── Microphone ────────────────────────────────────────────────────────────
  Future<bool> requestMicrophone() async =>
      (await Permission.microphone.request()).isGranted;

  // ── Location ──────────────────────────────────────────────────────────────
  Future<bool> requestLocationWhenInUse() async =>
      (await Permission.locationWhenInUse.request()).isGranted;

  Future<bool> requestLocationAlways() async =>
      (await Permission.locationAlways.request()).isGranted;

  // ── Contacts ──────────────────────────────────────────────────────────────
  Future<bool> requestContacts() async =>
      (await Permission.contacts.request()).isGranted;

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  // ── Storage ───────────────────────────────────────────────────────────────
  Future<bool> requestStorage() async =>
      (await Permission.storage.request()).isGranted;

  // ── Batch request ─────────────────────────────────────────────────────────
  Future<Map<Permission, PermissionStatus>> requestMultiple(
    List<Permission> permissions,
  ) =>
      permissions.request();

  // ── Check & open settings ─────────────────────────────────────────────────
  Future<bool> isPermanentlyDenied(Permission permission) async =>
      (await permission.status).isPermanentlyDenied;

  Future<void> openAppSettings() => openAppSettings();
}
