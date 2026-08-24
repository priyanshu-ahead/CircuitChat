import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';

/// Full call screen — Agora integration placeholder.
///
/// agora_rtc_engine is commented out in pubspec.yaml.
/// To activate:
///   1. Uncomment `agora_rtc_engine: ^6.5.2` in pubspec.yaml
///   2. Run `flutter pub get`
///   3. Replace the placeholder body below with real Agora RtcEngine logic.
///      Reference: circuitchatapp/source/components/call/index.js
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.callType,   // 'audio' | 'video'
    required this.chatName,
    this.isIncoming = false,
  });

  final String callId;
  final String callType;
  final String chatName;
  final bool   isIncoming;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _muted         = false;
  bool _cameraOff     = false;
  bool _speakerOn     = true;
  bool _ending        = false;
  String _status      = 'Calling…';
  Duration _elapsed   = Duration.zero;

  bool get _isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    if (widget.isIncoming) {
      setState(() => _status = 'Incoming call…');
    } else {
      _initiateCall();
    }
  }

  Future<void> _initiateCall() async {
    setState(() => _status = 'Connecting…');
    try {
      // Fetch Agora channel details
      final api = ref.read(apiClientProvider);
      await api.get<Map<String, dynamic>>(
          ApiEndpoints.callChannel(widget.callId));
      // TODO: init AgoraRtcEngine with channel token from response
      setState(() => _status = 'Connected');
      _startTimer();
    } catch (_) {
      setState(() => _status = 'Connection failed');
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _elapsed += const Duration(seconds: 1));
      return _status == 'Connected';
    });
  }

  Future<void> _endCall() async {
    setState(() => _ending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post<void>(ApiEndpoints.callReject(widget.callId));
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _acceptCall() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post<void>(ApiEndpoints.callAccept(widget.callId));
      _initiateCall();
    } catch (_) {}
  }

  String _formatElapsed() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Remote video placeholder
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Remote avatar / video tile
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white38, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white54, size: 64),
                    ),
                    const SizedBox(height: 20),
                    Text(widget.chatName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      _status == 'Connected'
                          ? _formatElapsed()
                          : _status,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15),
                    ),
                    if (_isVideo) ...[
                      const SizedBox(height: 16),
                      // Local self-view placeholder
                      Container(
                        width: 80, height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white24),
                        ),
                        child: const Center(
                          child: Icon(Icons.videocam_rounded,
                              color: Colors.white38, size: 28),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Controls
            _buildControls(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (widget.isIncoming && _status == 'Incoming call…') {
      // Incoming — show accept + reject
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: Icons.call_end_rounded,
            color: const Color(0xFFE53935),
            label: 'Decline',
            onTap: _endCall,
          ),
          _ControlBtn(
            icon: Icons.call_rounded,
            color: const Color(0xFF43A047),
            label: 'Accept',
            onTap: _acceptCall,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlBtn(
          icon: _muted
              ? Icons.mic_off_rounded
              : Icons.mic_rounded,
          color: _muted
              ? const Color(0xFF888888)
              : Colors.white24,
          label: _muted ? 'Unmute' : 'Mute',
          onTap: () => setState(() => _muted = !_muted),
        ),
        if (_isVideo)
          _ControlBtn(
            icon: _cameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            color: _cameraOff
                ? const Color(0xFF888888)
                : Colors.white24,
            label: _cameraOff ? 'Show' : 'Camera',
            onTap: () => setState(() => _cameraOff = !_cameraOff),
          ),
        _ControlBtn(
          icon: _speakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          color: _speakerOn
              ? Colors.white24
              : const Color(0xFF888888),
          label: 'Speaker',
          onTap: () => setState(() => _speakerOn = !_speakerOn),
        ),
        _ControlBtn(
          icon: Icons.call_end_rounded,
          color: const Color(0xFFE53935),
          label: 'End',
          onTap: _ending ? null : _endCall,
        ),
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });
  final IconData   icon;
  final Color      color;
  final String     label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
}
