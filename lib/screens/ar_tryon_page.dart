import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../features/ar_tryon/models/ar_tryon_overlay_data.dart';
import '../features/ar_tryon/services/ar_pose_mapper.dart';
import '../features/ar_tryon/services/ar_product_model_resolver.dart';
import '../features/ar_tryon/services/camera_input_image_factory.dart';
import '../features/ar_tryon/widgets/ar_tryon_controls.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class ARTryOnPage extends StatefulWidget {
  const ARTryOnPage({
    super.key,
    required this.product,
    this.cartItems = const [],
    this.selectedSize,
  });

  final Product product;
  final List<CartItem> cartItems;
  final String? selectedSize;

  @override
  State<ARTryOnPage> createState() => _ARTryOnPageState();
}

class _ARTryOnPageState extends State<ARTryOnPage> {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final Flutter3DController _modelController = Flutter3DController();

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  ArTryOnOverlayData? _overlayData;

  Size _previewViewportSize = Size.zero;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isPoseDetected = false;
  bool _isControlsCollapsed = false;
  String? _errorMessage;
  String? _modelLoadError;
  late final String _modelSource;
  late double _fitScale;
  double _verticalOffset = 0;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _modelSource = ArProductModelResolver.resolve(widget.product);
    _fitScale = _defaultFitScaleForSize(widget.selectedSize);
    unawaited(_initializeTryOn());
  }

  double _defaultFitScaleForSize(String? size) {
    switch (size?.trim().toUpperCase()) {
      case 'XS':
        return 0.82;
      case 'S':
        return 0.90;
      case 'M':
        return 1.0;
      case 'L':
        return 1.1;
      case 'XL':
        return 1.18;
      case 'XXL':
        return 1.26;
      case 'XXXL':
        return 1.32;
      default:
        return 1.0;
    }
  }

  Future<void> _initializeTryOn() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = _pickCamera(cameras);
      if (selectedCamera == null) {
        throw Exception('No camera found on this device.');
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraDescription = selectedCamera;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to start AR try-on: $error';
        _isInitializing = false;
      });
    }
  }

  CameraDescription? _pickCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }

    if (cameras.isNotEmpty) {
      return cameras.first;
    }

    return null;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!mounted ||
        _isProcessingFrame ||
        _cameraController == null ||
        _cameraDescription == null ||
        _previewViewportSize.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastProcessedAt).inMilliseconds < 120) {
      return;
    }
    _lastProcessedAt = now;

    _isProcessingFrame = true;
    try {
      final processedFrame = CameraInputImageFactory.fromCameraImage(
        image: image,
        camera: _cameraDescription!,
        controller: _cameraController!,
      );
      if (processedFrame == null) {
        return;
      }

      final poses = await _poseDetector.processImage(processedFrame.inputImage);
      if (!mounted) {
        return;
      }

      final pose = poses.isNotEmpty ? poses.first : null;
      final overlayData = pose == null
          ? null
          : ArPoseMapper.mapPoseToOverlay(
              pose: pose,
              sourceSize: processedFrame.imageSize,
              viewportSize: _previewViewportSize,
              mirrorHorizontally:
                  _cameraDescription!.lensDirection == CameraLensDirection.front,
              fitScale: _fitScale,
              verticalOffset: _verticalOffset,
            );

      setState(() {
        _overlayData = overlayData;
        _isPoseDetected = overlayData != null;
      });
    } catch (error) {
      debugPrint('AR pose detection failed: $error');
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      unawaited(controller.dispose());
    }
    unawaited(_poseDetector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AR Try On'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return _FullscreenMessage(
        title: 'Camera unavailable',
        message: _errorMessage!,
        icon: Icons.camera_alt_outlined,
      );
    }

    final cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const _FullscreenMessage(
        title: 'Camera not ready',
        message: 'Please reopen the AR try-on page.',
        icon: Icons.camera_outdoor_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _previewViewportSize = constraints.biggest;

        final previewSize = cameraController.value.previewSize;
        final renderSize = previewSize == null
            ? const Size(1080, 1920)
            : Size(previewSize.height, previewSize.width);

        return Stack(
          fit: StackFit.expand,
          children: [
            _CameraPreviewLayer(
              controller: cameraController,
              renderSize: renderSize,
            ),
            _buildModelOverlay(),
            _buildTopInfo(),
            ArTryOnControls(
              productName: widget.product.name,
              selectedSize: widget.selectedSize,
              cartCount: widget.cartItems.length,
              fitScale: _fitScale,
              verticalOffset: _verticalOffset,
              isPoseDetected: _isPoseDetected,
              isCollapsed: _isControlsCollapsed,
              onToggleCollapsed: () {
                setState(() {
                  _isControlsCollapsed = !_isControlsCollapsed;
                });
              },
              onFitScaleChanged: (value) {
                setState(() {
                  _fitScale = value;
                });
              },
              onVerticalOffsetChanged: (value) {
                setState(() {
                  _verticalOffset = value;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildModelOverlay() {
    final overlayData = _overlayData;
    if (overlayData == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fromRect(
      rect: overlayData.frame,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: overlayData.rotation,
          child: Opacity(
            opacity: overlayData.confidence.clamp(0.45, 1.0),
            child: Flutter3DViewer(
              controller: _modelController,
              src: _modelSource,
              enableTouch: false,
              progressBarColor: Colors.transparent,
              onLoad: (_) {
                if (!mounted || _modelLoadError == null) {
                  return;
                }
                setState(() {
                  _modelLoadError = null;
                });
              },
              onError: (error) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _modelLoadError = error;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopInfo() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.view_in_ar, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _modelLoadError == null
                      ? 'Center your shoulders and hips in frame to place the outfit.'
                      : '3D model could not load. Check the model file for this product.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewLayer extends StatelessWidget {
  const _CameraPreviewLayer({
    required this.controller,
    required this.renderSize,
  });

  final CameraController controller;
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: renderSize.width,
          height: renderSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _FullscreenMessage extends StatelessWidget {
  const _FullscreenMessage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
