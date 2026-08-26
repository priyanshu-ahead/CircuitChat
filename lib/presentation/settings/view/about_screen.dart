import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../presentation/common/widgets/legal_page_sheet.dart';

/// App Info screen — mirrors RN's components/setting/appinfo.js.
/// Shows only: Privacy Policy, Terms of Service, About Us.
/// Tapping each opens the LegalPageSheet (fetches from GET /user/page/:key).
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
        title: const Text(
          'App Info',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: ListView(
        children: [
          // ── App identity ────────────────────────────────────────────────
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
            child: Text(
              'CircuitChat',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Color(0xFF1A1A2E)),
            ),
          ),
          Center(
            child: Text(
              'Version $_version (build $_build)',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF888888)),
            ),
          ),
          const SizedBox(height: 28),

          // ── Links — matches RN appinfo.js exactly ────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4)
              ],
            ),
            child: Column(
              children: [
                // Privacy Policy
                ListTile(
                  onTap: () => LegalPageSheet.show(
                    context,
                    pageKey: 'privacy',
                    title:   'Privacy Policy',
                  ),
                  title: const Text('Privacy Policy',
                      style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFAAAAAA)),
                ),
                const Divider(
                    height: 1, indent: 16, color: Color(0xFFEEEEEE)),

                // Terms of Service
                ListTile(
                  onTap: () => LegalPageSheet.show(
                    context,
                    pageKey: 'terms',
                    title:   'Terms of Service',
                  ),
                  title: const Text('Terms of Service',
                      style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFAAAAAA)),
                ),
                const Divider(
                    height: 1, indent: 16, color: Color(0xFFEEEEEE)),

                // About Us
                ListTile(
                  onTap: () => LegalPageSheet.show(
                    context,
                    pageKey: 'about',
                    title:   'About Us',
                  ),
                  title: const Text('About Us',
                      style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
          ),

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
}
