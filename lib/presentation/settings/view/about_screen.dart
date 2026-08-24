import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _version = '';
  String _build   = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _build   = info.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('About CircuitChat',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: ListView(
        children: [
          // ── App identity ──────────────────────────────────────────────────
          const SizedBox(height: 32),
          const Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFF0057FF),
              child: Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('CircuitChat',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Color(0xFF1A1A2E))),
          ),
          Center(
            child: Text('Version $_version (build $_build)',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF888888))),
          ),
          const SizedBox(height: 28),
          // ── Info tiles ────────────────────────────────────────────────────
          _group([
            _tile('Terms of Service', Icons.description_outlined,
                () => _open('${AppConstants.seServerUrl}terms')),
            _tile('Privacy Policy', Icons.privacy_tip_outlined,
                () => _open('${AppConstants.seServerUrl}privacy')),
          ]),
          const SizedBox(height: 12),
          _group([
            _tile('Server',  Icons.dns_outlined, null,
                trailing: AppConstants.baseUrl),
            _tile('Run Mode', Icons.settings_ethernet_rounded, null,
                trailing: AppConstants.runMode),
          ]),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '© 2024 Ahead WebSoft Technologies',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Column(children: children),
      );

  Widget _tile(String label, IconData icon, VoidCallback? onTap,
      {String? trailing}) =>
      ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF1976D2)),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: trailing != null
            ? Text(trailing,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF888888)))
            : onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA))
                : null,
      );

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri);
  }
}
