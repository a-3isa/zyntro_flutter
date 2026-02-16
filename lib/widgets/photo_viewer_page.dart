import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../core/theme/app_theme.dart';

/// Full-screen photo viewer with pinch-to-zoom and pan capabilities.
/// Supports Hero animation for smooth transitions from feed/detail pages.
/// Features:
/// - Pinch-to-zoom and pan
/// - Double-tap to zoom
/// - Tap to dismiss
/// - Swipe down to dismiss
/// - Download/share button
/// - Loading progress indicator
/// - Haptic feedback on interactions
class PhotoViewerPage extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const PhotoViewerPage({super.key, required this.imageUrl, this.heroTag});

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  final TransformationController _transformationController =
      TransformationController();

  bool _isSharing = false;
  bool _isDownloading = false;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  double _previousScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    HapticFeedback.lightImpact();
    _transformationController.value = Matrix4.identity();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _previousScale).abs() > 0.1) {
      HapticFeedback.selectionClick();
      _previousScale = scale;
    }
  }

  /// Copy image URL to clipboard
  Future<void> _shareImage() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      HapticFeedback.mediumImpact();

      // Copy URL to clipboard
      await Clipboard.setData(ClipboardData(text: widget.imageUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image link copied to clipboard! 📋'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  /// Download and save the image to local storage
  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      HapticFeedback.mediumImpact();

      // Download the image using http
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image (${response.statusCode})');
      }

      // Get the downloads/pictures directory
      final Directory? downloadsDir;
      if (Platform.isAndroid) {
        // On Android, use external storage
        downloadsDir = await getExternalStorageDirectory();
      } else {
        // On iOS, use documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not access storage directory');
      }

      // Create a unique filename
      final fileName =
          'workout_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = '${downloadsDir.path}/$fileName';

      // Write the downloaded bytes to file
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo saved to: $fileName 💾'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Only allow vertical drag to dismiss when not zoomed
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale <= 1.1) {
      setState(() {
        _isDragging = true;
        _dragOffset += details.delta.dy;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dy.abs() > 500) {
      // Dismiss with swipe
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    } else {
      // Reset position
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: downloadProgress.progress,
              color: Colors.white,
              strokeWidth: 3,
            ),
            if (downloadProgress.progress != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${(downloadProgress.progress! * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: AppFontSize.sm,
                ),
              ),
            ],
          ],
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () {
                // Force rebuild to retry loading
                setState(() {});
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    final viewerContent = GestureDetector(
      onScaleUpdate: _handleScaleUpdate,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(20),
        onInteractionEnd: (details) {
          // Add haptic feedback at end of zoom gesture
          final scale = _transformationController.value.getMaxScaleOnAxis();
          if ((scale - 1.0).abs() > 0.3) {
            HapticFeedback.selectionClick();
          }
        },
        child: Center(
          child: widget.heroTag != null
              ? Hero(tag: widget.heroTag!, child: imageWidget)
              : imageWidget,
        ),
      ),
    );

    // Calculate opacity based on drag offset
    final backgroundOpacity = _isDragging
        ? (1.0 - (_dragOffset.abs() / 300).clamp(0.0, 0.5))
        : 1.0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backgroundOpacity),
      body: Stack(
        children: [
          // Main Image Viewer
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              onTap: () {
                // Single tap to dismiss
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                // Double tap to toggle zoom
                if (_transformationController.value != Matrix4.identity()) {
                  _resetZoom();
                } else {
                  // Zoom to 2x at center
                  _transformationController.value = Matrix4.diagonal3Values(
                    2.0,
                    2.0,
                    1.0,
                  );
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: _isDragging
                      ? (1.0 - (_dragOffset.abs() / 1000).clamp(0.0, 0.2))
                      : 1.0,
                  child: viewerContent,
                ),
              ),
            ),
          ),

          // Custom Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    _buildControlButton(
                      icon: Icons.close,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Close',
                    ),

                    // Actions
                    Row(
                      children: [
                        // Share button
                        _buildControlButton(
                          icon: Icons.share,
                          onTap: _isSharing ? null : _shareImage,
                          tooltip: 'Copy link',
                          isLoading: _isSharing,
                        ),
                        const SizedBox(width: 8), // Spacing
                        // Download button
                        _buildControlButton(
                          icon: Icons.download,
                          onTap: _isDownloading ? null : _downloadImage,
                          tooltip: 'Save photo',
                          isLoading: _isDownloading,
                        ),
                        const SizedBox(width: 8), // Spacing
                        // Reset zoom button
                        _buildControlButton(
                          icon: Icons.fit_screen,
                          onTap: _resetZoom,
                          tooltip: 'Reset zoom',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    bool isLoading = false,
  }) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
      ),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}
