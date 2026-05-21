import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String path;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _muted = false;
  double _speed = 1.0;
  Timer? _hideTimer;
  String? _error;

  static const _speedCycle = [1.0, 1.5, 2.0, 0.5];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = widget.path.startsWith('content://')
          ? VideoPlayerController.contentUri(Uri.parse(widget.path))
          : VideoPlayerController.file(File(widget.path));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      await controller.play();
      setState(() => _controller = controller);
      _scheduleHide();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel();
    } else {
      c.play();
      _scheduleHide();
    }
    setState(() {});
  }

  void _skip(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final target = c.value.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > c.value.duration ? c.value.duration : target);
    c.seekTo(clamped);
    _scheduleHide();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    final next = !_muted;
    c.setVolume(next ? 0.0 : 1.0);
    setState(() => _muted = next);
    _scheduleHide();
  }

  void _cycleSpeed() {
    final c = _controller;
    if (c == null) return;
    final idx = (_speedCycle.indexOf(_speed) + 1) % _speedCycle.length;
    final next = _speedCycle[idx];
    c.setPlaybackSpeed(next);
    setState(() => _speed = next);
    _scheduleHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not play this file.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            if (c != null && c.value.isInitialized)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(c),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    final remaining = dur - pos;
    final isPlaying = c.value.isPlaying;
    final mq = MediaQuery.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.25),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _GlassPill(
                      children: [
                        _PillIcon(
                          icon: Icons.picture_in_picture_alt_rounded,
                          onTap: () {},
                        ),
                        _PillIcon(
                          icon: Icons.cast_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    _GlassButton(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlassButton(
                      icon: Icons.replay_10_rounded,
                      size: 56,
                      iconSize: 28,
                      onTap: () => _skip(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 32),
                    _GlassButton(
                      icon: isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 76,
                      iconSize: 44,
                      bright: true,
                      onTap: _togglePlay,
                    ),
                    const SizedBox(width: 32),
                    _GlassButton(
                      icon: Icons.forward_10_rounded,
                      size: 56,
                      iconSize: 28,
                      onTap: () => _skip(const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 64 + mq.padding.bottom,
                child: _GlassButton(
                  icon: Icons.speed_rounded,
                  badge: _speed == 1.0 ? null : '${_speed}x',
                  onTap: _cycleSpeed,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16 + mq.padding.bottom,
                child: _ProgressBar(
                  position: pos,
                  duration: dur,
                  onSeek: (p) {
                    c.seekTo(p);
                    _scheduleHide();
                  },
                  leftLabel: _fmt(pos),
                  rightLabel:
                      '-${_fmt(remaining < Duration.zero ? Duration.zero : remaining)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool bright;
  final String? badge;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.bright = false,
    this.badge,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.bright
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: widget.iconSize,
                  ),
                  if (widget.badge != null)
                    Positioned(
                      bottom: 4,
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final List<Widget> children;
  const _GlassPill({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PillIcon({required this.icon, required this.onTap});

  @override
  State<_PillIcon> createState() => _PillIconState();
}

class _PillIconState extends State<_PillIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(widget.icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final String leftLabel;
  final String rightLabel;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(leftLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: Slider(
                    value: position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble(),
                    min: 0,
                    max: duration.inMilliseconds <= 0
                        ? 1
                        : duration.inMilliseconds.toDouble(),
                    onChanged: (v) =>
                        onSeek(Duration(milliseconds: v.toInt())),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(rightLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ),
    );
  }
}
