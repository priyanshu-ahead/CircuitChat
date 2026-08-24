import 'dart:developer' as dev;

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Reads device contacts and syncs them to the SE backend.
/// Mirrors RN's services/friend.js syncContacts().
class ContactSyncService {
  const ContactSyncService(this._api);
  final ApiClient _api;

  Future<void> sync() async {
    // Request contacts permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      dev.log('Contacts permission denied — skipping sync',
          name: 'ContactSync');
      return;
    }

    try {
      final contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: false);

      // Build minimal payload matching RN format:
      // [{name, phone}]
      final payload = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => {
                'name': c.displayName,
                'phone': c.phones.first.number
                    .replaceAll(RegExp(r'\s+|-|\(|\)'), ''),
              })
          .toList();

      if (payload.isEmpty) return;

      await _api.post<void>(ApiEndpoints.syncContacts, data: payload);
      dev.log('Contact sync complete — ${payload.length} contacts',
          name: 'ContactSync');
    } catch (e) {
      dev.log('Contact sync failed: $e', name: 'ContactSync');
    }
  }
}
