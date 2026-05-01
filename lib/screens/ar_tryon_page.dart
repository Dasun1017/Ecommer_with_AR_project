import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';

class ARTryOnPage extends StatefulWidget {
  final Product product;
  final List<CartItem> cartItems;

  const ARTryOnPage({
    super.key,
    required this.product,
    required this.cartItems,
  });

  @override
  State<ARTryOnPage> createState() => _ARTryOnPageState();
}

class _ARTryOnPageState extends State<ARTryOnPage> {
  late CameraController _cameraController;
  late Flutter3DController _modelController;
  bool _isCameraInitialized = false;
  bool _isPoseDetected = false;
  bool _isProcessing = false;

  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );

  late List<CameraDescription> _cameras;
  Pose? _currentPose;
  int _frameCount = 0;
  int _poseDetectedCount = 0;
  Size? _imageSize;
  InputImageRotation? _imageRotation;
  bool _isFrontCamera = false;
  double? _smoothedTargetX;
  double? _smoothedTargetY;
  double? _smoothedDistance;
  double? _smoothedAngle;

  @override
  void initState() {
    super.initState();
    _modelController = Flutter3DController();
    _initializeCamera();

    // Fallback: Show ready after 3 seconds if detection fails
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isPoseDetected) {
        debugPrint('⏱️ Fallback: Showing Ready after timeout');
        setState(() => _isPoseDetected = true);
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Use front camera for better selfie perspective
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras[0],
      );
      _isFrontCamera = frontCamera.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }

      // Start streaming frames for pose detection
      _startPoseDetectionStream();
    } catch (e) {
      _showError('Camera initialization error: $e');
    }
  }

  void _startPoseDetectionStream() {
    _cameraController.startImageStream((image) async {
      if (_isProcessing) return;
      _isProcessing = true;
      _frameCount++;

      try {
        // Log every 30 frames
        if (_frameCount % 30 == 0) {
          debugPrint('🎥 Frame #$_frameCount received');
        }

        final inputImage = _buildInputImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        // Process image for poses
        final poses = await _poseDetector.processImage(inputImage);

        if (_frameCount % 30 == 0) {
          debugPrint('🔍 Poses detected: ${poses.length}');
        }

        if (mounted) {
          if (poses.isNotEmpty) {
            final pose = poses[0];
            final landmarkCount = pose.landmarks.length;

            if (_frameCount % 30 == 0) {
              debugPrint('✅ Pose found with $landmarkCount landmarks');
            }

            if (landmarkCount > 0) {
              _poseDetectedCount++;
              setState(() {
                _currentPose = pose;
                _isPoseDetected = true;
                _updateModelTransform();
              });
            }
          } else {
            if (_frameCount % 60 == 0) {
              debugPrint('❌ No poses detected');
            }
            // After 60 frames without detection, show ready anyway (fallback)
            if (_frameCount > 60 && !_isPoseDetected) {
              setState(() => _isPoseDetected = true);
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Pose detection error: $e');
        if (mounted && _frameCount > 60) {
          setState(() => _isPoseDetected = true);
        }
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _updateModelTransform() {
    if (_currentPose == null) return;
    if (_currentPose!.landmarks.isEmpty) return;
    if (_imageSize == null || _imageRotation == null) return;

    try {
      // Extract key landmarks using Map access
      final leftShoulder = _currentPose!.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = _currentPose!.landmarks[PoseLandmarkType.rightShoulder];

      if (leftShoulder == null || rightShoulder == null) {
        debugPrint('Missing shoulder landmarks');
        return;
      }

      // Only proceed if shoulders have good confidence
      if (leftShoulder.likelihood < 0.2 || rightShoulder.likelihood < 0.2) {
        debugPrint('Low shoulder confidence: L=${leftShoulder.likelihood}, R=${rightShoulder.likelihood}');
        return;
      }

      final leftPoint = _normalizeLandmark(leftShoulder);
      final rightPoint = _normalizeLandmark(rightShoulder);
      if (leftPoint == null || rightPoint == null) return;

      final shoulderMid = Offset(
        (leftPoint.dx + rightPoint.dx) / 2,
        (leftPoint.dy + rightPoint.dy) / 2,
      );
      final shoulderWidth = (rightPoint.dx - leftPoint.dx).abs();
      if (shoulderWidth <= 0.02) return;

      Offset? hipMid;
      double? torsoHeight;
      final leftHip = _currentPose!.landmarks[PoseLandmarkType.leftHip];
      final rightHip = _currentPose!.landmarks[PoseLandmarkType.rightHip];
      if (leftHip != null && rightHip != null) {
        if (leftHip.likelihood >= 0.2 && rightHip.likelihood >= 0.2) {
          final leftHipPoint = _normalizeLandmark(leftHip);
          final rightHipPoint = _normalizeLandmark(rightHip);
          if (leftHipPoint != null && rightHipPoint != null) {
            hipMid = Offset(
              (leftHipPoint.dx + rightHipPoint.dx) / 2,
              (leftHipPoint.dy + rightHipPoint.dy) / 2,
            );
            torsoHeight = (hipMid.dy - shoulderMid.dy).abs();
          }
        }
      }

      // Chest center is slightly below shoulders
      final center = hipMid != null
          ? shoulderMid + (hipMid - shoulderMid) * 0.35
          : shoulderMid;

      // Calculate body angle (shoulder tilt, used only for debug)
      final shoulderAngle = _calculateAngle(
        leftPoint.dx,
        leftPoint.dy,
        rightPoint.dx,
        rightPoint.dy,
      );

      // Map body metrics to model-viewer camera orbit units.
      // Orbit uses (theta, phi, radius%) where radius is a percentage.
      final radiusByShoulder =
          ((0.42 / shoulderWidth) * 100).clamp(70.0, 160.0);
      var radiusPercent = radiusByShoulder;
      if (torsoHeight != null && torsoHeight > 0.05) {
        final radiusByTorso =
            ((0.55 / torsoHeight) * 100).clamp(70.0, 160.0);
        radiusPercent = (radiusByShoulder + radiusByTorso) / 2;
      }

      final positionScaleMeters =
          (0.35 / shoulderWidth).clamp(0.2, 0.7);

      // Camera target uses meters; scale normalized offsets to keep the model anchored on the torso.
      const targetYOffsetMeters = 0.05;
      final targetX = (center.dx - 0.5) * positionScaleMeters;
      final targetY =
          (0.5 - center.dy) * positionScaleMeters - targetYOffsetMeters;

      const orbitPhi = 75.0;
      const orbitTheta = 0.0;

      final smoothTargetX = _smoothValue(_smoothedTargetX, targetX, 0.2);
      final smoothTargetY = _smoothValue(_smoothedTargetY, targetY, 0.2);
      final smoothRadius = _smoothValue(_smoothedDistance, radiusPercent, 0.2);
      final smoothTheta = _smoothValue(_smoothedAngle, orbitTheta, 0.2);

      _smoothedTargetX = smoothTargetX;
      _smoothedTargetY = smoothTargetY;
      _smoothedDistance = smoothRadius;
      _smoothedAngle = smoothTheta;

      debugPrint(
        'Pose: shoulders=$shoulderWidth, center=(${center.dx},${center.dy}), angle=$shoulderAngle',
      );

      // Apply camera transforms to model
      _applyCameraTransforms(
        smoothTargetX,
        smoothTargetY,
        smoothRadius,
        smoothTheta,
        orbitPhi,
      );
    } catch (e) {
      debugPrint('Model transform calculation error: $e');
    }
  }

  double _smoothValue(double? previous, double next, double alpha) {
    if (previous == null) return next;
    return previous + (next - previous) * alpha;
  }

  InputImage? _buildInputImage(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(
      _cameraController.description.sensorOrientation,
    );
    if (rotation == null) {
      debugPrint('Unsupported input image rotation');
      return null;
    }

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    _imageSize = imageSize;
    _imageRotation = rotation;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final nv21Bytes = _convertYUV420ToNV21(image);
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      debugPrint('Unsupported input image format');
      return null;
    }

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final bufferSize = width * height + (width * height ~/ 2);
    final nv21 = Uint8List(bufferSize);

    var index = 0;
    for (var y = 0; y < height; y++) {
      final yRow = y * yRowStride;
      nv21.setRange(index, index + width, yBytes, yRow);
      index += width;
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    for (var y = 0; y < uvHeight; y++) {
      final uvRow = y * uvRowStride;
      for (var x = 0; x < uvWidth; x++) {
        final uvIndex = uvRow + x * uvPixelStride;
        nv21[index++] = vBytes[uvIndex];
        nv21[index++] = uBytes[uvIndex];
      }
    }

    return nv21;
  }

  Offset? _normalizeLandmark(PoseLandmark landmark) {
    final imageSize = _imageSize;
    final rotation = _imageRotation;
    if (imageSize == null || rotation == null) return null;

    final rotatedPoint = _rotatePoint(
      landmark.x,
      landmark.y,
      imageSize,
      rotation,
    );
    final rotatedSize = _rotatedSize(imageSize, rotation);
    var nx = rotatedPoint.dx / rotatedSize.width;
    var ny = rotatedPoint.dy / rotatedSize.height;

    if (_isFrontCamera) {
      nx = 1 - nx;
    }

    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }

  Size _rotatedSize(Size size, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(size.height, size.width);
      case InputImageRotation.rotation180deg:
      case InputImageRotation.rotation0deg:
        return size;
    }
  }

  Offset _rotatePoint(
    double x,
    double y,
    Size size,
    InputImageRotation rotation,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return Offset(y, size.width - x);
      case InputImageRotation.rotation270deg:
        return Offset(size.height - y, x);
      case InputImageRotation.rotation180deg:
        return Offset(size.width - x, size.height - y);
      case InputImageRotation.rotation0deg:
        return Offset(x, y);
    }
  }

  double _calculateAngle(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return atan2(dy, dx) * 180 / pi;
  }

  void _applyCameraTransforms(
    double targetX,
    double targetY,
    double radiusPercent,
    double orbitTheta,
    double orbitPhi,
  ) {
    try {
      // Set camera target to body center
      debugPrint('📍 Setting camera target: ($targetX, $targetY, 0)');
      _modelController.setCameraTarget(targetX, targetY, 0);

      // Set camera orbit using model-viewer units (theta, phi, radius%)
      debugPrint(
        '🔄 Setting camera orbit: ($orbitTheta deg, $orbitPhi deg, $radiusPercent%)',
      );
      _modelController.setCameraOrbit(orbitTheta, orbitPhi, radiusPercent);
    } catch (e) {
      debugPrint('❌ Camera transform error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addToCart() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      _showError('Please login first');
      return;
    }

    final cartItem = CartItem(
      id: widget.product.id,
      productId: widget.product.id,
      productName: widget.product.name,
      productImage: widget.product.images.first,
      price: widget.product.price,
      quantity: 1,
      selectedColor:
          widget.product.colors.isNotEmpty ? widget.product.colors.first : null,
      selectedSize:
          widget.product.sizes.isNotEmpty ? widget.product.sizes.first : null,
    );

    try {
      await _cartService.addToCart(userId, cartItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.product.name} added to cart!')),
        );
      }
    } catch (e) {
      _showError('Failed to add to cart: $e');
    }
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Try AR - Body Tracking'),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: !_isCameraInitialized
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                // Camera preview background
                CameraPreview(_cameraController),

                // 3D Model viewer with body tracking
                if (_isPoseDetected && widget.product.arModelUrl != null)
                  Positioned.fill(
                    child: Flutter3DViewer(
                      controller: _modelController,
                      src: widget.product.arModelUrl!,
                    ),
                  )
                else if (_isPoseDetected)
                  // Fallback to texture/placeholder if no model URL
                  Container(
                    color: Colors.black54.withValues(alpha: 0.5),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No 3D model available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Pose landmarks visualization overlay
                if (_currentPose != null &&
                    _imageSize != null &&
                    _imageRotation != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PosePainter(
                        pose: _currentPose!,
                        imageSize: _imageSize!,
                        rotation: _imageRotation!,
                        isFrontCamera: _isFrontCamera,
                      ),
                    ),
                  ),

                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: _addToCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Add to Cart',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: Text(
                                    'Cart: ${widget.cartItems.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Pose detection status indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isPoseDetected
                              ? Colors.green.withValues(alpha: 0.8)
                              : Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPoseDetected ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPoseDetected ? 'Ready' : 'Detecting',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Debug info
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Frames: $_frameCount\nPoses: $_poseDetectedCount',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                            fontFamily: 'Courier',
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Custom painter to visualize pose landmarks on camera feed
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightGreen
      ..strokeWidth = 2.0;

    final dotPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3.0;

    // Draw all landmarks as dots
    for (final entry in pose.landmarks.entries) {
      final landmark = entry.value;
      if (landmark.likelihood > 0.3) {
        final point = _normalizePoint(landmark);
        if (point == null) continue;
        canvas.drawCircle(
          Offset(point.dx * size.width, point.dy * size.height),
          5,
          dotPaint,
        );
      }
    }

    // Draw skeleton lines connecting joints
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.nose,
        PoseLandmarkType.leftEye);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.nose,
        PoseLandmarkType.rightEye);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle);
    _drawSkeletonLine(canvas, paint, size, PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle);
  }

  void _drawSkeletonLine(
    Canvas canvas,
    Paint paint,
    Size size,
    PoseLandmarkType from,
    PoseLandmarkType to,
  ) {
    final fromLandmark = pose.landmarks[from];
    final toLandmark = pose.landmarks[to];

    if (fromLandmark != null &&
        toLandmark != null &&
        fromLandmark.likelihood > 0.3 &&
        toLandmark.likelihood > 0.3) {
      final fromPoint = _normalizePoint(fromLandmark);
      final toPoint = _normalizePoint(toLandmark);
      if (fromPoint == null || toPoint == null) return;
      canvas.drawLine(
        Offset(fromPoint.dx * size.width, fromPoint.dy * size.height),
        Offset(toPoint.dx * size.width, toPoint.dy * size.height),
        paint,
      );
    }
  }

  Offset? _normalizePoint(PoseLandmark landmark) {
    final rotatedPoint = _rotatePoint(
      landmark.x,
      landmark.y,
      imageSize,
      rotation,
    );
    final rotatedSize = _rotatedSize(imageSize, rotation);
    var nx = rotatedPoint.dx / rotatedSize.width;
    var ny = rotatedPoint.dy / rotatedSize.height;

    if (isFrontCamera) {
      nx = 1 - nx;
    }

    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }

  Size _rotatedSize(Size size, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(size.height, size.width);
      case InputImageRotation.rotation180deg:
      case InputImageRotation.rotation0deg:
        return size;
    }
  }

  Offset _rotatePoint(
    double x,
    double y,
    Size size,
    InputImageRotation rotation,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return Offset(y, size.width - x);
      case InputImageRotation.rotation270deg:
        return Offset(size.height - y, x);
      case InputImageRotation.rotation180deg:
        return Offset(size.width - x, size.height - y);
      case InputImageRotation.rotation0deg:
        return Offset(x, y);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}
