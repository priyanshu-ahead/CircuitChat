import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches HTML content for a given page key ('terms', 'privacy', 'about')
/// from GET /user/page/:key  — mirrors RN's pageInformation() service call.
final _legalPageProvider =
    FutureProvider.family<String, String>((ref, key) async {
  try {
    final api = ref.read(apiClientProvider);
    final raw = await api.get<dynamic>(ApiEndpoints.page(key));
    // SE returns either a plain HTML string or { data: '<html>…' }
    if (raw is String) return raw;
    if (raw is Map) {
      return (raw['data'] ?? raw['content'] ?? raw['html'] ?? '')
          .toString();
    }
    return '';
  } catch (_) {
    return '';
  }
});

// ── Widget ────────────────────────────────────────────────────────────────────

/// Shows a bottom sheet that fetches and renders an SE page (terms / privacy /
/// about) as HTML — mirrors RN's PrivacyInfo modal (components/setting/modal.js).
///
/// Usage:
///   LegalPageSheet.show(context, key: 'terms', title: 'Terms of Service');
class LegalPageSheet {
  static Future<void> show(
    BuildContext context, {
    required String pageKey,
    required String title,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (_) => _LegalPageContent(pageKey: pageKey, title: title),
    );
  }
}

class _LegalPageContent extends ConsumerWidget {
  const _LegalPageContent({required this.pageKey, required this.title});
  final String pageKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_legalPageProvider(pageKey));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1.0,
      maxChildSize: 1.0,
      minChildSize: 1.0,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF888888)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (_, __) => const Center(
                child: Text(
                  'Failed to load content.',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
              ),
              data: (html) => html.trim().isEmpty
                  ? const Center(
                      child: Text(
                        'No content available.',
                        style: TextStyle(color: Color(0xFF888888)),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Html(
                        data: html,
                        style: {
                          'body': Style(
                            fontSize:  FontSize(14),
                            lineHeight: const LineHeight(1.6),
                            color: const Color(0xFF333333),
                          ),
                          'h2': Style(
                            fontSize: FontSize(18),
                            fontWeight: FontWeight.w700,
                          ),
                          'h3': Style(
                            fontSize: FontSize(16),
                            fontWeight: FontWeight.w600,
                          ),
                          'a': Style(
                            color: const Color(0xFF1976D2),
                          ),
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
