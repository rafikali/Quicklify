import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/analytics/analytics_events.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/local/download_dao.dart';
import '../../features/downloads/downloads_provider.dart';
import '../../features/downloads/models/download_item.dart';
import '../../features/premium/screens/premium_screen.dart';
import '../theme/flux_theme.dart';

const String _tag = 'EditCaptionScreen';

// ── Entry widget ─────────────────────────────────────────────────────

class EditCaptionScreen extends StatelessWidget {
  final DownloadItem item;

  const EditCaptionScreen({super.key, required this.item});

  /// Single entry point used by all call sites (v2 Complete CTA, v2 Stream
  /// tile, v1 DownloadTile). Premium check happens here so the gate isn't
  /// duplicated across the UI. Non-premium users get a paywall sheet that
  /// routes to [PremiumScreen].
  static Future<void> guardAndOpen(
      BuildContext context, DownloadItem item) async {
    if (PremiumService.instance.isPremiumSync()) {
      AnalyticsService.instance.logEvent(
        AnalyticsEvent.editorOpened,
        params: {AnalyticsParam.platform: item.platform},
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditCaptionScreen(item: item)),
      );
      return;
    }
    AnalyticsService.instance.logEvent(
      AnalyticsEvent.premiumGateHit,
      params: {AnalyticsParam.reason: 'caption_editor'},
    );
    await _showPaywall(context);
  }

  static Future<void> _showPaywall(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FluxColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FluxColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FluxColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium,
                        color: FluxColors.cyan, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caption editor is Premium',
                          style: TextStyle(
                            color: FluxColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mask burned-in captions and add your own — for Premium users only.',
                          style: TextStyle(
                            color: FluxColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AnalyticsService.instance.logEvent(
                      AnalyticsEvent.premiumUpgradeTap,
                      params: const {AnalyticsParam.reason: 'caption_editor'},
                    );
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    );
                  },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FluxColors.cyan,
                    foregroundColor: FluxColors.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Maybe later',
                  style: TextStyle(
                    color: FluxColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsProvider>();
    return ChangeNotifierProvider<EditCaptionController>(
      create: (_) =>
          EditCaptionController(item: item, downloadsProvider: downloads)
            ..init(),
      child: const _CaptionEditorView(),
    );
  }
}

// ── Controller (all mutable state lives here) ────────────────────────

class EditCaptionController extends ChangeNotifier {
  final DownloadItem item;
  final DownloadsProvider downloadsProvider;

  EditCaptionController({
    required this.item,
    required this.downloadsProvider,
  });

  // Video / source
  VideoPlayerController? _video;
  VideoPlayerController? get video => _video;
  String? _ffmpegInputArg;
  // If we copied a content:// URI into a cache file for ffmpeg, hold the
  // path so we can delete it on dispose.
  String? _sourceCachePath;
  String? _error;
  String? get error => _error;
  bool _initialized = false;
  bool get ready => _initialized && _video != null;

  // Blocks
  final List<CaptionBlock> _blocks = [];
  List<CaptionBlock> get blocks => List.unmodifiable(_blocks);
  int _selectedIndex = -1;
  int get selectedIndex => _selectedIndex;
  CaptionBlock? get selected =>
      _selectedIndex >= 0 && _selectedIndex < _blocks.length
          ? _blocks[_selectedIndex]
          : null;

  // Modes
  bool _previewing = false;
  bool get previewing => _previewing;
  bool _exporting = false;
  bool get exporting => _exporting;
  double _exportProgress = 0;
  double get exportProgress => _exportProgress;

  // The view supplies this so the controller can capture the overlay at
  // video resolution without holding any BuildContext / RenderObject refs.
  Future<Uint8List> Function(Size videoSize)? captureOverlay;

  bool _disposed = false;

  // ── Init ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _appendBlock(
      rect: const Rect.fromLTWH(0.05, 0.78, 0.9, 0.16),
      text: 'Your caption here',
    );
    notifyListeners();

    try {
      final source = await _resolveSource();
      if (_disposed) return;
      if (source == null) {
        _error =
            'Original file not found — the source video was moved or removed from the gallery.';
        notifyListeners();
        return;
      }
      _ffmpegInputArg = source.ffmpegArg;
      final c = source.previewUri.startsWith('content://')
          ? VideoPlayerController.contentUri(Uri.parse(source.previewUri))
          : VideoPlayerController.file(File(source.previewUri));
      await c.initialize();
      if (_disposed) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      _video = c;
      _initialized = true;
      notifyListeners();
    } catch (e, st) {
      dev.log('init error: $e\n$st', name: _tag);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<_VideoSource?> _resolveSource() async {
    final gallery = item.galleryPath;
    if (gallery != null && gallery.isNotEmpty) {
      if (gallery.startsWith('content://')) {
        // ffmpeg-kit's SAF integration is flaky on some devices ("SAF id N
        // not found"). Copy the URI into the app cache so ffmpeg can read a
        // plain file path. video_player handles the URI itself.
        final tmpDir = await getTemporaryDirectory();
        final cachePath =
            '${tmpDir.path}/ql_source_${DateTime.now().millisecondsSinceEpoch}.mp4';
        dev.log('Copying content URI to cache: $gallery -> $cachePath',
            name: _tag);
        final copied = await StorageService.copyUriToFile(gallery, cachePath);
        if (copied != null && await File(copied).exists()) {
          final size = await File(copied).length();
          dev.log('Cache copy succeeded: $copied (${size}B)', name: _tag);
          _sourceCachePath = copied;
          return _VideoSource(previewUri: gallery, ffmpegArg: copied);
        }
        dev.log(
            'Cache copy FAILED (native copyUriToFile returned null or file missing). '
            'Did you fully rebuild the app after adding the native method? '
            'Falling back to SAF — which is known to fail with "SAF id N not found".',
            name: _tag);
        final saf = await FFmpegKitConfig.getSafParameterForRead(gallery);
        if (saf != null && saf.isNotEmpty) {
          return _VideoSource(previewUri: gallery, ffmpegArg: saf);
        }
      } else if (await File(gallery).exists()) {
        return _VideoSource(previewUri: gallery, ffmpegArg: gallery);
      }
    }
    final saveDir = await StorageService.getDownloadDirectory();
    final tempPath = '$saveDir/${item.filename}';
    if (await File(tempPath).exists()) {
      return _VideoSource(previewUri: tempPath, ffmpegArg: tempPath);
    }
    return null;
  }

  // ── Block mutations ──────────────────────────────────────────────

  void _appendBlock({required Rect rect, required String text}) {
    final block = CaptionBlock(
      rect: rect,
      maskColor: Colors.black,
      textColor: Colors.white,
      fontSize: 22,
      bold: true,
      textAlign: TextAlign.center,
      text: text,
    );
    block.focusNode.addListener(() {
      if (_disposed) return;
      if (block.focusNode.hasFocus) {
        final i = _blocks.indexOf(block);
        if (i >= 0 && i != _selectedIndex) {
          _selectedIndex = i;
          notifyListeners();
        }
      }
    });
    _blocks.add(block);
    _selectedIndex = _blocks.length - 1;
  }

  void addBlock() {
    final n = _blocks.length;
    _appendBlock(
      rect: Rect.fromLTWH(
        0.15,
        (0.15 + n * 0.06).clamp(0.05, 0.6),
        0.4,
        0.12,
      ),
      text: 'Caption ${n + 1}',
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      selected?.focusNode.requestFocus();
    });
  }

  void deleteSelected() {
    final b = selected;
    if (b == null || _blocks.length <= 1) return;
    b.dispose();
    _blocks.removeAt(_selectedIndex);
    _selectedIndex = _selectedIndex.clamp(0, _blocks.length - 1);
    notifyListeners();
  }

  void selectBlock(int i) {
    if (i < 0 || i >= _blocks.length || i == _selectedIndex) return;
    _selectedIndex = i;
    notifyListeners();
  }

  void translateBlock(int i, double dxNorm, double dyNorm) {
    if (i < 0 || i >= _blocks.length) return;
    final b = _blocks[i];
    b.rect = _clampNorm(b.rect.translate(dxNorm, dyNorm));
    if (_selectedIndex != i) _selectedIndex = i;
    notifyListeners();
  }

  void resizeSelected(double dxNorm, double dyNorm, CaptionCorner corner) {
    final b = selected;
    if (b == null) return;
    b.rect = _applyResize(b.rect, dxNorm, dyNorm, corner);
    notifyListeners();
  }

  // ── Style mutations ──────────────────────────────────────────────

  void setFontSize(double v) {
    final b = selected;
    if (b == null) return;
    b.fontSize = v;
    notifyListeners();
  }

  void toggleBold() {
    final b = selected;
    if (b == null) return;
    b.bold = !b.bold;
    notifyListeners();
  }

  void cycleAlign() {
    final b = selected;
    if (b == null) return;
    b.textAlign = switch (b.textAlign) {
      TextAlign.left => TextAlign.center,
      TextAlign.center => TextAlign.right,
      _ => TextAlign.left,
    };
    notifyListeners();
  }

  void setTextColor(Color c) {
    final b = selected;
    if (b == null) return;
    b.textColor = c;
    notifyListeners();
  }

  void setMaskColor(Color c) {
    final b = selected;
    if (b == null) return;
    b.maskColor = c;
    notifyListeners();
  }

  // ── Modes ────────────────────────────────────────────────────────

  void togglePreview() {
    _previewing = !_previewing;
    if (_previewing) {
      for (final b in _blocks) {
        b.focusNode.unfocus();
      }
    }
    notifyListeners();
  }

  // ── Export ───────────────────────────────────────────────────────

  /// Runs the ffmpeg overlay export. Returns the saved filename on success,
  /// or `null` on failure. The view handles toast + navigation.
  Future<String?> runExport() async {
    final c = _video;
    final capture = captureOverlay;
    if (c == null || _ffmpegInputArg == null || capture == null) {
      return null;
    }
    if (_exporting) return null;

    for (final b in _blocks) {
      b.focusNode.unfocus();
    }
    await c.pause();
    _exporting = true;
    _exportProgress = 0;
    _previewing = true; // hide chrome so capture is clean
    notifyListeners();
    AnalyticsService.instance.logEvent(
      AnalyticsEvent.editorExportStart,
      params: {AnalyticsParam.blockCount: _blocks.length},
    );

    try {
      final videoSize = c.value.size;
      if (videoSize.width == 0 || videoSize.height == 0) {
        throw 'Unknown video size';
      }

      await WidgetsBinding.instance.endOfFrame;

      final pngBytes = await capture(videoSize);
      final tmpDir = await getTemporaryDirectory();
      final overlayPath =
          '${tmpDir.path}/ql_overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(overlayPath).writeAsBytes(pngBytes);

      final downloadsDir = await StorageService.getDownloadDirectory();
      final base = item.filename.replaceAll(RegExp(r'\.\w+$'), '');
      final outName =
          '${base}_captioned_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outPath = '$downloadsDir/$outName';

      final cmd =
          '-y -i "$_ffmpegInputArg" -i "$overlayPath" '
          '-filter_complex "[1:v]scale=${videoSize.width.toInt()}:${videoSize.height.toInt()}[ov];[0:v][ov]overlay=0:0" '
          '-c:a copy -movflags +faststart "$outPath"';

      dev.log('ffmpeg cmd: $cmd', name: _tag);

      final totalDurationMs =
          c.value.duration.inMilliseconds.clamp(1, 1 << 31);

      // executeAsync returns immediately — wait on the complete callback,
      // not the future executeAsync hands back, before reading the result.
      final completer = Completer<FFmpegSession>();
      await FFmpegKit.executeAsync(
        cmd,
        (s) {
          if (!completer.isCompleted) completer.complete(s);
        },
        null,
        (Statistics stats) {
          if (_disposed) return;
          final timeMs = stats.getTime();
          if (timeMs > 0) {
            _exportProgress = (timeMs / totalDurationMs).clamp(0.0, 1.0);
            notifyListeners();
          }
        },
      );
      final finished = await completer.future;
      final returnCode = await finished.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await finished.getAllLogsAsString();
        dev.log('ffmpeg failed (code: ${returnCode?.getValue()}): $logs',
            name: _tag);
        throw 'ffmpeg failed (code: ${returnCode?.getValue()})';
      }

      try {
        await File(overlayPath).delete();
      } catch (_) {}

      final size = await File(outPath).length();
      final gallery = await StorageService.saveToGallery(outPath, outName);
      final finalName = gallery?.filename ?? outName;

      final newItem = DownloadItem(
        id: const Uuid().v4(),
        sourceUrl: item.sourceUrl,
        downloadUrl: item.downloadUrl,
        filename: finalName,
        platform: item.platform,
        quality: item.quality,
        status: 2,
        progress: 100,
        completedAt: DateTime.now(),
        fileSize: size,
        galleryPath: gallery?.uri ?? outPath,
      );
      await DownloadDao.insert(newItem);
      downloadsProvider.addCompletedItem(newItem);

      AnalyticsService.instance.logEvent(
        AnalyticsEvent.editorExportOk,
        params: {
          AnalyticsParam.blockCount: _blocks.length,
          AnalyticsParam.fileSize: size,
        },
      );

      return finalName;
    } catch (e, st) {
      dev.log('export error: $e\n$st', name: _tag);
      AnalyticsService.instance.logEvent(
        AnalyticsEvent.editorExportFailed,
        params: {AnalyticsParam.error: e.toString()},
      );
      if (!_disposed) {
        _exporting = false;
        _exportProgress = 0;
        _previewing = false;
        notifyListeners();
      }
      return null;
    }
  }

  // ── Geometry helpers ─────────────────────────────────────────────

  static Rect _clampNorm(Rect r) {
    final w = r.width.clamp(0.05, 1.0);
    final h = r.height.clamp(0.05, 1.0);
    final x = r.left.clamp(0.0, 1.0 - w);
    final y = r.top.clamp(0.0, 1.0 - h);
    return Rect.fromLTWH(x, y, w, h);
  }

  static Rect _applyResize(Rect r, double dx, double dy, CaptionCorner corner) {
    var l = r.left, t = r.top, ri = r.right, b = r.bottom;
    switch (corner) {
      case CaptionCorner.tl:
        l += dx;
        t += dy;
        break;
      case CaptionCorner.tr:
        ri += dx;
        t += dy;
        break;
      case CaptionCorner.bl:
        l += dx;
        b += dy;
        break;
      case CaptionCorner.br:
        ri += dx;
        b += dy;
        break;
    }
    return _clampNorm(Rect.fromLTRB(l, t, ri, b));
  }

  @override
  void dispose() {
    _disposed = true;
    _video?.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    final cache = _sourceCachePath;
    if (cache != null) {
      // Fire and forget — cache cleanup must not block dispose.
      unawaited(File(cache).delete().catchError((_) => File(cache)));
    }
    super.dispose();
  }
}

// ── A single caption block ──────────────────────────────────────────

class CaptionBlock {
  Rect rect;
  Color maskColor;
  Color textColor;
  double fontSize;
  bool bold;
  TextAlign textAlign;
  final TextEditingController controller;
  final FocusNode focusNode;

  CaptionBlock({
    required this.rect,
    required this.maskColor,
    required this.textColor,
    required this.fontSize,
    required this.bold,
    required this.textAlign,
    required String text,
  })  : controller = TextEditingController(text: text),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

enum CaptionCorner { tl, tr, bl, br }

class _VideoSource {
  final String previewUri;
  final String ffmpegArg;
  const _VideoSource({required this.previewUri, required this.ffmpegArg});
}

// ── Root view ───────────────────────────────────────────────────────

class _CaptionEditorView extends StatefulWidget {
  const _CaptionEditorView();

  @override
  State<_CaptionEditorView> createState() => _CaptionEditorViewState();
}

class _CaptionEditorViewState extends State<_CaptionEditorView> {
  // Owned by the view (not the controller) because it references a
  // RenderObject under this widget's subtree.
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Wire the capture callback after first frame so the controller can
    // call it during export.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EditCaptionController>().captureOverlay =
          _captureOverlayAtVideoSize;
    });
  }

  Future<Uint8List> _captureOverlayAtVideoSize(Size videoSize) async {
    final boundary = _overlayKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final displaySize = boundary.size;
    final pixelRatio = videoSize.width / displaySize.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw 'PNG encode failed';
    return byteData.buffer.asUint8List();
  }

  Future<void> _onExport() async {
    final controller = context.read<EditCaptionController>();
    final finalName = await controller.runExport();
    if (!mounted) return;
    if (finalName != null) {
      Fluttertoast.showToast(msg: 'Captioned video saved');
      Navigator.of(context).pop(true);
    } else if (controller.error == null) {
      Fluttertoast.showToast(msg: 'Export failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluxColors.bg,
      appBar: _AppBar(onExport: _onExport),
      body: _Body(overlayKey: _overlayKey),
      bottomSheet: const _ExportingSheet(),
    );
  }
}

// ── App bar ─────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExport;
  const _AppBar({required this.onExport});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Selector: rebuild only when the bits that drive the AppBar change.
    return Selector<EditCaptionController, _AppBarState>(
      selector: (_, c) =>
          _AppBarState(ready: c.ready, previewing: c.previewing, exporting: c.exporting),
      builder: (ctx, s, _) => AppBar(
        backgroundColor: FluxColors.bg,
        title: Text(
          s.previewing ? 'Preview' : 'Edit Caption',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (s.ready && !s.exporting) ...[
            if (!s.previewing) ...[
              IconButton(
                tooltip: 'Preview',
                onPressed: () =>
                    ctx.read<EditCaptionController>().togglePreview(),
                icon: const Icon(Icons.play_arrow_rounded,
                    color: FluxColors.cyan),
              ),
              TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.check_rounded,
                    color: FluxColors.cyan, size: 18),
                label: const Text(
                  'Export',
                  style: TextStyle(
                    color: FluxColors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else
              TextButton.icon(
                onPressed: () =>
                    ctx.read<EditCaptionController>().togglePreview(),
                icon: const Icon(Icons.edit_outlined,
                    color: FluxColors.cyan, size: 18),
                label: const Text(
                  'Back to edit',
                  style: TextStyle(
                    color: FluxColors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppBarState {
  final bool ready;
  final bool previewing;
  final bool exporting;
  const _AppBarState(
      {required this.ready,
      required this.previewing,
      required this.exporting});

  @override
  bool operator ==(Object other) =>
      other is _AppBarState &&
      other.ready == ready &&
      other.previewing == previewing &&
      other.exporting == exporting;

  @override
  int get hashCode => Object.hash(ready, previewing, exporting);
}

// ── Body ────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final GlobalKey overlayKey;
  const _Body({required this.overlayKey});

  @override
  Widget build(BuildContext context) {
    // Coarse selector — rebuild only when loading/error/ready state flips.
    return Selector<EditCaptionController, _BodyShape>(
      selector: (_, c) {
        if (c.error != null) return _BodyShape.error;
        if (!c.ready) return _BodyShape.loading;
        return _BodyShape.ready;
      },
      builder: (ctx, shape, _) {
        switch (shape) {
          case _BodyShape.error:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ctx.read<EditCaptionController>().error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FluxColors.textSecondary),
                ),
              ),
            );
          case _BodyShape.loading:
            return const Center(
              child: CircularProgressIndicator(color: FluxColors.cyan),
            );
          case _BodyShape.ready:
            return Column(
              children: [
                Expanded(child: _PreviewArea(overlayKey: overlayKey)),
                _ToolbarOrEmpty(),
              ],
            );
        }
      },
    );
  }
}

enum _BodyShape { error, loading, ready }

// ── Preview area ────────────────────────────────────────────────────

class _PreviewArea extends StatelessWidget {
  final GlobalKey overlayKey;
  const _PreviewArea({required this.overlayKey});

  @override
  Widget build(BuildContext context) {
    // The VideoPlayer is built once based on the controller reference.
    // It doesn't sit inside any Consumer/Selector that mutates often, so
    // it never re-renders for block / toolbar interactions.
    final video = context.read<EditCaptionController>().video!;
    final aspect = video.value.aspectRatio;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(video)),
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: overlayKey,
                      child: _BlocksLayer(parentW: w, parentH: h),
                    ),
                  ),
                  Positioned.fill(
                    child: _ChromeLayer(parentW: w, parentH: h),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Blocks layer (inside the boundary; gets captured) ────────────────

class _BlocksLayer extends StatelessWidget {
  final double parentW;
  final double parentH;
  const _BlocksLayer({required this.parentW, required this.parentH});

  @override
  Widget build(BuildContext context) {
    // Watches the controller — this is where block drags repaint.
    final c = context.watch<EditCaptionController>();
    final blocks = c.blocks;
    final previewing = c.previewing;
    return Stack(
      children: [
        for (var i = 0; i < blocks.length; i++)
          _BlockBody(
            key: ValueKey(blocks[i]),
            block: blocks[i],
            parentW: parentW,
            parentH: parentH,
            interactive: !previewing,
            onTap: () => c.selectBlock(i),
            onDrag: (dx, dy) => c.translateBlock(i, dx / parentW, dy / parentH),
          ),
      ],
    );
  }
}

// ── Chrome (outside the boundary; never in the PNG) ──────────────────

class _ChromeLayer extends StatelessWidget {
  final double parentW;
  final double parentH;
  const _ChromeLayer({required this.parentW, required this.parentH});

  @override
  Widget build(BuildContext context) {
    return Selector<EditCaptionController, _ChromeState>(
      selector: (_, c) => _ChromeState(
        previewing: c.previewing,
        selectedRect: c.selected?.rect,
      ),
      builder: (ctx, s, _) {
        if (s.previewing || s.selectedRect == null) {
          return const SizedBox.shrink();
        }
        return _SelectionChrome(
          maskRect: s.selectedRect!,
          parentW: parentW,
          parentH: parentH,
          onCornerDrag: (dx, dy, corner) => ctx
              .read<EditCaptionController>()
              .resizeSelected(dx / parentW, dy / parentH, corner),
        );
      },
    );
  }
}

class _ChromeState {
  final bool previewing;
  final Rect? selectedRect;
  const _ChromeState({required this.previewing, required this.selectedRect});

  @override
  bool operator ==(Object other) =>
      other is _ChromeState &&
      other.previewing == previewing &&
      other.selectedRect == selectedRect;

  @override
  int get hashCode => Object.hash(previewing, selectedRect);
}

// ── Toolbar (hidden in preview mode) ─────────────────────────────────

class _ToolbarOrEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<EditCaptionController, bool>(
      selector: (_, c) => c.previewing,
      builder: (_, previewing, child) =>
          previewing ? const SizedBox.shrink() : const _Toolbar(),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EditCaptionController>();
    final b = c.selected;
    return Container(
      decoration: const BoxDecoration(
        color: FluxColors.surface,
        border: Border(top: BorderSide(color: FluxColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  c.blocks.isEmpty
                      ? 'No blocks'
                      : 'Block ${c.selectedIndex + 1} of ${c.blocks.length}',
                  style: const TextStyle(
                    color: FluxColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _ToolToggle(
                  icon: Icons.add_box_outlined,
                  active: true,
                  onTap: c.addBlock,
                ),
                const SizedBox(width: 4),
                _ToolToggle(
                  icon: Icons.delete_outline,
                  active: c.blocks.length > 1,
                  onTap: c.deleteSelected,
                ),
              ],
            ),
            if (b != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.format_size,
                      color: FluxColors.textMuted, size: 18),
                  Expanded(
                    child: Slider(
                      value: b.fontSize,
                      min: 10,
                      max: 48,
                      activeColor: FluxColors.cyan,
                      inactiveColor: FluxColors.surfaceLight,
                      onChanged: c.setFontSize,
                    ),
                  ),
                  _ToolToggle(
                    icon: Icons.format_bold,
                    active: b.bold,
                    onTap: c.toggleBold,
                  ),
                  const SizedBox(width: 4),
                  _ToolToggle(
                    icon: b.textAlign == TextAlign.left
                        ? Icons.format_align_left
                        : b.textAlign == TextAlign.right
                            ? Icons.format_align_right
                            : Icons.format_align_center,
                    active: true,
                    onTap: c.cycleAlign,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _ColorPickerRow(
                label: 'Text',
                selected: b.textColor,
                colors: const [
                  Colors.white,
                  Color(0xFFFFEB3B),
                  FluxColors.cyan,
                  Color(0xFFFF5252),
                  Color(0xFF00E676),
                  Colors.black,
                ],
                onPick: c.setTextColor,
              ),
              const SizedBox(height: 8),
              _ColorPickerRow(
                label: 'Mask',
                selected: b.maskColor,
                colors: const [
                  Colors.black,
                  Color(0xFF1A1A28),
                  Color(0xFF333333),
                  Colors.white,
                  Color(0xFFB71C1C),
                  Color(0xCC000000),
                ],
                onPick: c.setMaskColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Exporting bottom sheet ──────────────────────────────────────────

class _ExportingSheet extends StatelessWidget {
  const _ExportingSheet();

  @override
  Widget build(BuildContext context) {
    return Selector<EditCaptionController, _ExportingState>(
      selector: (_, c) =>
          _ExportingState(exporting: c.exporting, progress: c.exportProgress),
      builder: (_, s, child) {
        if (!s.exporting) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: FluxColors.surface,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Burning caption…',
                  style: TextStyle(
                    color: FluxColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: s.progress == 0 ? null : s.progress,
                  backgroundColor: FluxColors.surfaceLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(FluxColors.cyan),
                ),
                const SizedBox(height: 8),
                Text(
                  s.progress == 0
                      ? 'Preparing'
                      : '${(s.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: FluxColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExportingState {
  final bool exporting;
  final double progress;
  const _ExportingState({required this.exporting, required this.progress});

  @override
  bool operator ==(Object other) =>
      other is _ExportingState &&
      other.exporting == exporting &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(exporting, progress);
}

// ── Block body widget ───────────────────────────────────────────────

class _BlockBody extends StatelessWidget {
  final CaptionBlock block;
  final double parentW;
  final double parentH;
  final bool interactive;
  final void Function(double dx, double dy) onDrag;
  final VoidCallback onTap;

  const _BlockBody({
    super.key,
    required this.block,
    required this.parentW,
    required this.parentH,
    required this.interactive,
    required this.onDrag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final px = Rect.fromLTWH(
      block.rect.left * parentW,
      block.rect.top * parentH,
      block.rect.width * parentW,
      block.rect.height * parentH,
    );
    final body = Container(
      color: block.maskColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextField(
        controller: block.controller,
        focusNode: block.focusNode,
        enabled: interactive,
        maxLines: null,
        textAlign: block.textAlign,
        cursorColor: FluxColors.cyan,
        style: TextStyle(
          color: block.textColor,
          fontSize: block.fontSize,
          fontWeight: block.bold ? FontWeight.w700 : FontWeight.w500,
          height: 1.2,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    return Positioned(
      left: px.left,
      top: px.top,
      width: px.width,
      height: px.height,
      child: interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onPanStart: (_) => onTap(),
              onPanUpdate: (d) => onDrag(d.delta.dx, d.delta.dy),
              child: body,
            )
          : IgnorePointer(child: body),
    );
  }
}

// ── Selection chrome ────────────────────────────────────────────────

class _SelectionChrome extends StatelessWidget {
  final Rect maskRect;
  final double parentW;
  final double parentH;
  final void Function(double dx, double dy, CaptionCorner corner) onCornerDrag;

  const _SelectionChrome({
    required this.maskRect,
    required this.parentW,
    required this.parentH,
    required this.onCornerDrag,
  });

  static const _handle = 22.0;

  @override
  Widget build(BuildContext context) {
    final px = Rect.fromLTWH(
      maskRect.left * parentW,
      maskRect.top * parentH,
      maskRect.width * parentW,
      maskRect.height * parentH,
    );
    return Stack(
      children: [
        Positioned(
          left: px.left,
          top: px.top,
          width: px.width,
          height: px.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: FluxColors.cyan.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        _handleAt(px, CaptionCorner.tl),
        _handleAt(px, CaptionCorner.tr),
        _handleAt(px, CaptionCorner.bl),
        _handleAt(px, CaptionCorner.br),
      ],
    );
  }

  Widget _handleAt(Rect px, CaptionCorner corner) {
    double l, t;
    switch (corner) {
      case CaptionCorner.tl:
        l = px.left - _handle / 2;
        t = px.top - _handle / 2;
        break;
      case CaptionCorner.tr:
        l = px.right - _handle / 2;
        t = px.top - _handle / 2;
        break;
      case CaptionCorner.bl:
        l = px.left - _handle / 2;
        t = px.bottom - _handle / 2;
        break;
      case CaptionCorner.br:
        l = px.right - _handle / 2;
        t = px.bottom - _handle / 2;
        break;
    }
    return Positioned(
      left: l,
      top: t,
      width: _handle,
      height: _handle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onCornerDrag(d.delta.dx, d.delta.dy, corner),
        child: Container(
          decoration: BoxDecoration(
            color: FluxColors.cyan,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

// ── Small reusable bits ─────────────────────────────────────────────

class _ToolToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToolToggle({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? FluxColors.cyan.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? FluxColors.cyan : FluxColors.border,
          ),
        ),
        child: Icon(
          icon,
          color: active ? FluxColors.cyan : FluxColors.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Color> colors;
  final ValueChanged<Color> onPick;

  const _ColorPickerRow({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              color: FluxColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: colors.map((c) {
              final isSel = c.toARGB32() == selected.toARGB32();
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSel ? FluxColors.cyan : FluxColors.border,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
