import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final String? selectedSize;

  const ARTryOnPage({
    super.key,
    required this.product,
    required this.cartItems,
    this.selectedSize,
  });

  @override
  State<ARTryOnPage> createState() => _ARTryOnPageState();
}

class _ARTryOnPageState extends State<ARTryOnPage> {
  static const bool _showDebugOverlay = false;
  static const int _minPoseFrames = 3;
  static const int _poseLostFrames = 6;
  static const double _poseLikelihoodThreshold = 0.4;
  late CameraController _cameraController;
  late Flutter3DController _modelController;
  bool _isCameraInitialized = false;
  bool _isPoseDetected = false;
  bool _isProcessing = false;
  int _frameCount = 0;
  int _poseDetectedCount = 0;
  int _consecutivePoseFrames = 0;
  int _lostPoseFrames = 0;

  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
    ),
  );

  late List<CameraDescription> _cameras;
  Pose? _currentPose;
  Size? _imageSize;               // raw camera image size
  InputImageRotation? _imageRotation;
  bool _isFrontCamera = false;

  // Screen-space overlay rect (set by ML Kit OR smart default)
  Rect? _overlayRect;
  double? _smoothedLeft;
  double? _smoothedTop;
  double? _smoothedWidth;
  double? _smoothedHeight;

  // ── Drag lock: pause ML Kit position updates while user drags ──────────────
  bool _userIsDragging = false;
  DateTime? _lastDragTime;

  // ── Body rotation (radians): 0 = front facing, >0.45 = side view ──────────
  double _bodyRotationAngle = 0.0;
  double _smoothedBodyRotation = 0.0;
  bool _isSideView = false;

  // ── Body-based size recommendation from shoulder width ─────────────────────
  String? _measuredSizeRecommendation;
  double? _lastShoulderPct; // shoulder width as fraction of screen width

  // ── 3D model camera — calibrated for this T-shirt GLTF ───────────────────
  // Model bounds: X[-192..196], Y[-179..-8], Z[-1664..-1051]
  // Center: X≈2, Y≈-93, Z≈-1357
  // We point camera from front (negative Z looking toward +Z direction)
  // theta=0 = right side, phi=90 = equator (front view), radius = distance
  static const double _camTheta  = 0;    // horizontal angle (0 = front for this model)
  static const double _camPhi    = 90;   // vertical angle   (90 = straight ahead)
  static const double _camRadius = 3000; // distance — covers ~389 unit wide model
  // Camera target = model center
  static const double _camTargetX =  2.0;
  static const double _camTargetY = -93.0;
  static const double _camTargetZ = -1357.0;

  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _modelController = Flutter3DController();
    _initializeCamera();

    // After 2s: if no ML Kit detection, show smart default overlay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _overlayRect == null) {
        debugPrint('⏱️ Fallback: using smart default position');
        _setSmartDefaultOverlay();
      }
    });

    // Setup 3D model camera once model finishes loading
    // flutter_3d_controller fires onLoad after WebView renders model
    Future.delayed(const Duration(milliseconds: 800), _setupModelCamera);
  }

  /// Point the 3D camera at the correct position for this T-shirt model.
  /// Called once after model loads, then again when body rotation changes.
  void _setupModelCamera({double? overrideTheta}) {
    if (!mounted) return;
    final theta = overrideTheta ?? _camTheta;
    _modelController.setCameraTarget(_camTargetX, _camTargetY, _camTargetZ);
    _modelController.setCameraOrbit(theta, _camPhi, _camRadius);
    debugPrint('📷 Camera set: theta=$theta phi=$_camPhi radius=$_camRadius '
        'target=($_camTargetX, $_camTargetY, $_camTargetZ)');
  }

  /// Place overlay at chest area — works without body detection
  void _setSmartDefaultOverlay() {
    final screen = MediaQuery.of(context).size;
    final sizeScale = _sizeScaleForLabel(widget.selectedSize);
    // Responsive default: 88% of shortest dimension so it fits tall & wide screens
    final baseW = screen.width < screen.height ? screen.width : screen.height;
    final w = (baseW * 0.88 * sizeScale).clamp(
        screen.width * 0.50, screen.width * 0.95);
    final h = w * 1.35;
    final left = (screen.width - w) / 2;
    // 16% from top — keeps neckline near shoulder area on all aspect ratios
    final top = screen.height * 0.16;
    setState(() {
      _overlayRect = Rect.fromLTWH(left, top, w, h);
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Front camera for selfie-style AR
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras[0],
      );
      _isFrontCamera = frontCamera.lensDirection == CameraLensDirection.front;

      // medium resolution — faster for ML Kit
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        // Do NOT specify imageFormatGroup — let platform pick best format
      );

      await _cameraController.initialize();

      if (mounted) setState(() => _isCameraInitialized = true);

      _startPoseDetectionStream();
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  void _startPoseDetectionStream() {
    _cameraController.startImageStream((CameraImage image) {
      _frameCount++;
      // Process every 3rd frame only — reduce CPU load
      if (_frameCount % 3 != 0) return;
      if (_isProcessing) return;
      _isProcessing = true;

      _processPoseFrame(image).then((_) {
        _isProcessing = false;
      }).catchError((e) {
        debugPrint('❌ Frame processing error: $e');
        _isProcessing = false;
      });
    });
  }

  Future<void> _processPoseFrame(CameraImage image) async {
    final inputImage = _buildInputImage(image);
    if (inputImage == null) return;

    final poses = await _poseDetector.processImage(inputImage);

    if (_frameCount % 30 == 0) {
      debugPrint('🔍 Frame #$_frameCount → ${poses.length} pose(s) found');
    }

    if (!mounted) return;

    if (poses.isNotEmpty && _isPoseValid(poses[0])) {
      _currentPose = poses[0];
      _poseDetectedCount++;
      _consecutivePoseFrames++;
      _lostPoseFrames = 0;

      if (_consecutivePoseFrames >= _minPoseFrames) {
        if (!_isPoseDetected) {
          setState(() => _isPoseDetected = true);
        }
        // Update body rotation (side/front view detection)
        _updateBodyRotation(poses[0]);

        // Only update overlay position if user is NOT dragging recently
        final now = DateTime.now();
        final draggedRecently = _lastDragTime != null &&
            now.difference(_lastDragTime!).inSeconds < 2;
        if (!draggedRecently) {
          _updateModelTransform();
        }
      }
    } else {
      _consecutivePoseFrames = 0;
      _lostPoseFrames++;
      if (_isPoseDetected && _lostPoseFrames >= _poseLostFrames) {
        setState(() => _isPoseDetected = false);
      }
    }
  }

  /// Detect whether person is facing front or turned sideways.
  /// Uses shoulder width ratio + ear distance to estimate rotation angle.
  void _updateBodyRotation(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (ls == null || rs == null) return;
    final lsNorm = _normalizeLandmark(ls);
    final rsNorm = _normalizeLandmark(rs);
    if (lsNorm == null || rsNorm == null) return;

    final shoulderWidthNorm = (rsNorm.dx - lsNorm.dx).abs();

    // acos maps width ratio to rotation angle:
    // ratio=1.0 (full front) → angle=0, ratio<0.6 → turned >53°
    const double maxFrontWidth = 0.35;
    final ratio = (shoulderWidthNorm / maxFrontWidth).clamp(0.0, 1.0);
    final estimated = acos(ratio);

    // Cross-check with ear separation
    bool earSide = false;
    final le = pose.landmarks[PoseLandmarkType.leftEar];
    final re = pose.landmarks[PoseLandmarkType.rightEar];
    if (le != null && re != null) {
      final leN = _normalizeLandmark(le);
      final reN = _normalizeLandmark(re);
      if (leN != null && reN != null) {
        earSide = (reN.dx - leN.dx).abs() < 0.08;
      }
    }

    _smoothedBodyRotation = _smoothValue(_smoothedBodyRotation, estimated, 0.2);
    final newSideView = _smoothedBodyRotation > 0.45 || earSide;

    if (newSideView != _isSideView) {
      setState(() {
        _isSideView = newSideView;
        _bodyRotationAngle = _smoothedBodyRotation;
      });
      // Rotate 3D model camera when view changes
      // theta=0 → front, theta=90 → right side, theta=-90 → left side
      _setupModelCamera(overrideTheta: newSideView ? 90 : 0);
      debugPrint('👤 View: ${newSideView ? "SIDE" : "FRONT"} | angle=${_smoothedBodyRotation.toStringAsFixed(2)}');
    } else {
      _bodyRotationAngle = _smoothedBodyRotation;
    }
  }

  bool _isPoseValid(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (leftShoulder == null || rightShoulder == null) return false;
    if (leftShoulder.likelihood < _poseLikelihoodThreshold) return false;
    if (rightShoulder.likelihood < _poseLikelihoodThreshold) return false;
    return true;
  }

  /// Convert normalised [0-1] landmark coords → screen pixels
  Offset _normToScreen(Offset norm, Size screen) {
    return Offset(norm.dx * screen.width, norm.dy * screen.height);
  }

  void _updateModelTransform() {
    if (_currentPose == null) return;
    if (_currentPose!.landmarks.isEmpty) return;
    if (_imageSize == null || _imageRotation == null) return;

    final screenSize = MediaQuery.of(context).size;

    try {
      final leftShoulder  = _currentPose!.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = _currentPose!.landmarks[PoseLandmarkType.rightShoulder];
      if (leftShoulder == null || rightShoulder == null) return;
      // Lower threshold: 0.15 gives more frames for detection
      if (leftShoulder.likelihood < 0.15 || rightShoulder.likelihood < 0.15) return;

      final leftNorm  = _normalizeLandmark(leftShoulder);
      final rightNorm = _normalizeLandmark(rightShoulder);
      if (leftNorm == null || rightNorm == null) return;

      // Shoulder midpoint and pixel width
      final shoulderMidNorm = Offset(
        (leftNorm.dx + rightNorm.dx) / 2,
        (leftNorm.dy + rightNorm.dy) / 2,
      );
      final shoulderWidthNorm = (rightNorm.dx - leftNorm.dx).abs();
      if (shoulderWidthNorm <= 0.02) return;

      // Try to get hip midpoint for torso height
      Offset? hipMidNorm;
      final leftHip  = _currentPose!.landmarks[PoseLandmarkType.leftHip];
      final rightHip = _currentPose!.landmarks[PoseLandmarkType.rightHip];
      if (leftHip != null && rightHip != null &&
          leftHip.likelihood >= 0.15 && rightHip.likelihood >= 0.15) {
        final lh = _normalizeLandmark(leftHip);
        final rh = _normalizeLandmark(rightHip);
        if (lh != null && rh != null) {
          hipMidNorm = Offset((lh.dx + rh.dx) / 2, (lh.dy + rh.dy) / 2);
        }
      }

      // ── Screen-space calculations ──────────────────────────────────────
      final sizeScale      = _sizeScaleForLabel(widget.selectedSize);
      final shoulderPx     = shoulderWidthNorm * screenSize.width;

      // Measure body size from shoulder width
      _updateMeasuredSize(shoulderPx, screenSize);

      // Side view → shirt appears narrower visually
      // Front: 3.4× shoulder width so shirt covers full torso width
      final viewFactor = _isSideView ? 2.2 : 3.4;

      // Width — clamp to screen width to prevent right overflow
      final clothingWidth = (shoulderPx * viewFactor * sizeScale)
          .clamp(80.0, screenSize.width * 0.92);

      // Height: use torso height if available, else estimate
      double clothingHeight;
      if (hipMidNorm != null) {
        final torsoPx  = (hipMidNorm.dy - shoulderMidNorm.dy).abs() * screenSize.height;
        clothingHeight = (torsoPx * 1.6 * sizeScale).clamp(120.0, screenSize.height * 0.65);
      } else {
        clothingHeight = clothingWidth * 1.35;
      }

      // Shirt top should align with shoulders, not hang below
      // Move up by 35% of height so neckline hits shoulder midpoint
      final midScreen = _normToScreen(shoulderMidNorm, screenSize);
      final rawLeft   = midScreen.dx - clothingWidth / 2;
      final rawTop    = midScreen.dy - clothingHeight * 0.35;

      // Smooth to reduce jitter
      final sl = _smoothValue(_smoothedLeft,   rawLeft,        0.25);
      final st = _smoothValue(_smoothedTop,    rawTop,         0.25);
      final sw = _smoothValue(_smoothedWidth,  clothingWidth,  0.25);
      final sh = _smoothValue(_smoothedHeight, clothingHeight, 0.25);

      // Clamp so overlay never overflows screen edges
      final safeWidth  = sw.clamp(80.0, screenSize.width);
      final safeHeight = sh.clamp(80.0, screenSize.height);
      final clampedLeft = sl.clamp(0.0, (screenSize.width  - safeWidth).clamp(0.0, screenSize.width));
      final clampedTop  = st.clamp(0.0, (screenSize.height - safeHeight).clamp(0.0, screenSize.height));

      _smoothedLeft   = sl;
      _smoothedTop    = st;
      _smoothedWidth  = sw;
      _smoothedHeight = sh;

      setState(() {
        _overlayRect = Rect.fromLTWH(clampedLeft, clampedTop, safeWidth, safeHeight);
      });

      debugPrint('🎯 overlay rect: left=$sl top=$st w=$sw h=$sh | sizeScale=$sizeScale');
    } catch (e) {
      debugPrint('Model transform error: $e');
    }
  }

  /// Recommend size by comparing shoulder pixel width to screen width.
  /// Thresholds calibrated for ~1m distance, medium camera resolution.
  void _updateMeasuredSize(double shoulderPx, Size screenSize) {
    final pct = shoulderPx / screenSize.width;
    _lastShoulderPct = pct;

    final String rec;
    if (pct < 0.18) {
      rec = 'XS';
    } else if (pct < 0.22) {
      rec = 'S';
    } else if (pct < 0.27) {
      rec = 'M';
    } else if (pct < 0.33) {
      rec = 'L';
    } else if (pct < 0.40) {
      rec = 'XL';
    } else {
      rec = 'XXL';
    }

    if (rec != _measuredSizeRecommendation) {
      setState(() => _measuredSizeRecommendation = rec);
      debugPrint('📏 Body size: $rec (shoulder=${(pct * 100).toStringAsFixed(1)}% of screen)');
    }
  }

  double _sizeScaleForLabel(String? sizeLabel) {
    switch (sizeLabel?.toUpperCase()) {
      case 'XS':
        return 0.72;  // Way too small — model shrinks, looks very tight
      case 'S':
        return 0.82;  // Too small — clearly too tight on body
      case 'M':
        return 1.0;   // Medium reference
      case 'L':
        return 1.18;  // Perfect fit for L buyers
      case 'XL':
        return 1.36;  // Slightly loose
      case 'XXL':
        return 1.55;  // Clearly too big — baggy look
      case 'XXXL':
        return 1.75;  // Very oversized
      default:
        return 1.0;
    }
  }

  /// Human-readable fit label for the selected size
  String _fitLabel(String? size) {
    switch (size?.toUpperCase()) {
      case 'XS': return 'Too Small ❌';
      case 'S':  return 'Slightly Small ⚠️';
      case 'M':  return 'Good Fit ✅';
      case 'L':  return 'Perfect Fit ✅';
      case 'XL': return 'Slightly Loose 📦';
      case 'XXL': return 'Too Loose 📦';
      case 'XXXL': return 'Very Oversized 📦';
      default:   return 'Try On 👕';
    }
  }

  Color _fitColor(String? size) {
    switch (size?.toUpperCase()) {
      case 'XS':
      case 'S':  return Colors.redAccent;
      case 'M':
      case 'L':  return Colors.green;
      case 'XL':
      case 'XXL':
      case 'XXXL': return Colors.orangeAccent;
      default:   return Colors.blueAccent;
    }
  }

  double _smoothValue(double? previous, double next, double alpha) {
    if (previous == null) return next;
    return previous + (next - previous) * alpha;
  }

  /// Build InputImage for ML Kit from CameraImage.
  /// On Android: use NV21 (requested via imageFormatGroup).
  /// Fallback: manual YUV420→NV21 conversion.
  InputImage? _buildInputImage(CameraImage image) {
    // Determine rotation from sensor orientation
    final sensorOrientation = _cameraController.description.sensorOrientation;
    InputImageRotation rotation;
    if (_isFrontCamera) {
      // Front camera: mirror the rotation
      switch (sensorOrientation) {
        case 90:  rotation = InputImageRotation.rotation270deg; break;
        case 270: rotation = InputImageRotation.rotation90deg;  break;
        default:  rotation = InputImageRotation.rotation0deg;
      }
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation)
          ?? InputImageRotation.rotation0deg;
    }

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    _imageSize    = imageSize;
    _imageRotation = rotation;

    // If the camera already provides NV21 bytes (imageFormatGroup.nv21)
    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    // Manual YUV420→NV21 conversion (3-plane)
    if (image.planes.length == 3) {
      final nv21 = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    debugPrint('⚠️ Unexpected plane count: ${image.planes.length}');
    return null;
  }

  /// Correct YUV420 → NV21 conversion respecting row/pixel strides.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final w = image.width;
    final h = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(w * h + (w * h ~/ 2));
    int idx = 0;

    // Copy Y plane row by row (respecting row stride)
    for (int row = 0; row < h; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      for (int col = 0; col < w; col++) {
        nv21[idx++] = yPlane.bytes[rowStart + col];
      }
    }

    // Interleave VU for NV21 (V first, then U)
    final uvHeight = h ~/ 2;
    final uvWidth  = w ~/ 2;
    final vStride  = vPlane.bytesPerRow;
    final uStride  = uPlane.bytesPerRow;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        nv21[idx++] = vPlane.bytes[row * vStride + col * vPixelStride];
        nv21[idx++] = uPlane.bytes[row * uStride + col * uPixelStride];
      }
    }

    return nv21;
  }

  /// Normalise ML Kit landmark to [0,1] screen coordinates.
  /// ML Kit returns pixel coords in the original image space.
  /// We just divide by image size; ML Kit already handles rotation internally.
  Offset? _normalizeLandmark(PoseLandmark landmark) {
    final imgSize = _imageSize;
    if (imgSize == null) return null;

    // ML Kit landmark x/y are in camera-image pixel space.
    // After rotation by ML Kit, width/height may swap.
    double nx, ny;
    final rot = _imageRotation ?? InputImageRotation.rotation0deg;
    if (rot == InputImageRotation.rotation90deg ||
        rot == InputImageRotation.rotation270deg) {
      // Rotated: x maps to height axis, y maps to width axis
      nx = landmark.y / imgSize.height;
      ny = landmark.x / imgSize.width;
    } else {
      nx = landmark.x / imgSize.width;
      ny = landmark.y / imgSize.height;
    }

    // Front camera: mirror horizontally
    if (_isFrontCamera) nx = 1.0 - nx;

    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
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
        selectedSize: widget.selectedSize ??
          (widget.product.sizes.isNotEmpty ? widget.product.sizes.first : null),
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


  /// Show the full camera image — no zoom, full body visible.
  Widget _buildFullscreenCamera() {
    final previewSize = _cameraController.value.previewSize;
    if (previewSize == null) return const SizedBox.expand(child: ColoredBox(color: Colors.black));

    // previewSize is in landscape; for portrait we swap width/height
    final double camW = previewSize.height; // portrait width
    final double camH = previewSize.width;  // portrait height

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain, // show full image — no crop, no zoom
        alignment: Alignment.center,
        child: SizedBox(
          width: camW,
          height: camH,
          child: CameraPreview(_cameraController),
        ),
      ),
    );
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Try AR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isPoseDetected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildStatusChip(),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: !_isCameraInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                // ── Fullscreen camera preview ──────────────────────────
                _buildFullscreenCamera(),

                // ── Real-time articulated garment painter ──────────────
                if (_currentPose != null &&
                    _imageSize != null &&
                    _imageRotation != null &&
                    _isPoseDetected)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GarmentPainter(
                        pose: _currentPose!,
                        imageSize: _imageSize!,
                        rotation: _imageRotation!,
                        isFrontCamera: _isFrontCamera,
                        selectedSize: widget.selectedSize,
                        isSideView: _isSideView,
                      ),
                    ),
                  ),

                // ── Body position guide (shown before overlay appears) ──
                if (_overlayRect == null)
                  Positioned.fill(
                    child: CustomPaint(painter: _BodyGuidePainter()),
                  ),
                if (_overlayRect == null)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.18,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Icon(Icons.person_outline, color: Colors.white70,
                            size: MediaQuery.of(context).size.width * 0.09),
                        const SizedBox(height: 8),
                        const Text(
                          'Stand 1–2m away\nAlign torso with the outline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Draggable 3D clothing overlay ──────────────────────
                if (_overlayRect != null)
                  Positioned(
                    left:   _overlayRect!.left,
                    top:    _overlayRect!.top,
                    width:  _overlayRect!.width,
                    height: _overlayRect!.height,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _lastDragTime = DateTime.now();
                        setState(() => _userIsDragging = true);
                      },
                      onPanUpdate: (details) {
                        _lastDragTime = DateTime.now();
                        setState(() {
                          final r = _overlayRect!;
                          _overlayRect = Rect.fromLTWH(
                            r.left  + details.delta.dx,
                            r.top   + details.delta.dy,
                            r.width,
                            r.height,
                          );
                        });
                      },
                      onPanEnd: (_) {
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _userIsDragging = false);
                        });
                      },
                      child: Stack(
                        children: [
                          if ((widget.product.arModelUrl ?? '').isNotEmpty)
                            Flutter3DViewer(
                              controller: _modelController,
                              src: widget.product.arModelUrl!,
                              activeGestureInterceptor: false,
                              onLoad: (_) {
                                debugPrint('✅ 3D model loaded — setting camera');
                                setState(() => _modelLoaded = true);
                                // Slight delay so WebView finishes rendering
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  _setupModelCamera,
                                );
                              },
                              onProgress: (p) =>
                                  debugPrint('⏳ Model loading: $p%'),
                              onError: (e) =>
                                  debugPrint('❌ Model error: $e'),
                            )
                          else
                            const Center(
                              child: Text(
                                '3D model URL not available',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          // Loading indicator while model downloads
                          if (!_modelLoaded &&
                              (widget.product.arModelUrl ?? '').isNotEmpty)
                            const Positioned.fill(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white70),
                                    SizedBox(height: 8),
                                    Text('Loading 3D model...',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          // Drag hint
                          Positioned(
                            top: 4, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _userIsDragging
                                          ? Icons.lock_outline
                                          : Icons.open_with,
                                      color: Colors.white70,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _userIsDragging
                                          ? 'Locked — auto-track paused'
                                          : 'Drag to reposition',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isPoseDetected && _overlayRect == null)

                  // Still calculating position — show subtle scanning indicator
                  const Positioned(
                    top: 0, left: 0, right: 0, bottom: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Positioning clothing...',
                            style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                // Pose landmarks visualization overlay (debug only)
                if (_showDebugOverlay &&
                    _currentPose != null &&
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

                // ── Size Fit Indicator + Body Match Badge ─────────────
                if (widget.selectedSize != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected size + fit label
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _fitColor(widget.selectedSize)
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Size ${widget.selectedSize}  •  ${_fitLabel(widget.selectedSize)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Body measurement match badge
                        if (_measuredSizeRecommendation != null)
                          _buildSizeMatchBadge(),
                      ],
                    ),
                  ),

                // ── Front / Side View Indicator ───────────────────────
                if (_isPoseDetected)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSideView
                                ? Icons.rotate_90_degrees_ccw
                                : Icons.face,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isSideView ? 'Side View' : 'Front View',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_showDebugOverlay)
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Frames: $_frameCount\n'
                        'Poses: $_poseDetectedCount\n'
                        'Angle: ${_bodyRotationAngle.toStringAsFixed(2)}\n'
                        'Shoulder: ${(_lastShoulderPct != null ? (_lastShoulderPct! * 100).toStringAsFixed(1) : "-")}%\n'
                        'Measured: ${_measuredSizeRecommendation ?? "-"}\n'
                        'Model: ${_modelLoaded ? "✅" : "⏳"}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 10,
                          fontFamily: 'Courier',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _isCameraInitialized ? _buildBottomBar() : null,
    );
  }

  /// Badge showing how selected size matches measured body size
  Widget _buildSizeMatchBadge() {
    final selected = widget.selectedSize?.toUpperCase();
    final measured = _measuredSizeRecommendation?.toUpperCase();
    if (selected == null || measured == null) return const SizedBox.shrink();

    const sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final selIdx  = sizes.indexOf(selected);
    final measIdx = sizes.indexOf(measured);
    if (selIdx < 0 || measIdx < 0) return const SizedBox.shrink();
    final diff = (selIdx - measIdx).abs();

    final String label;
    final Color  color;
    if (diff == 0) {
      label = 'Perfect match for your body ✅';
      color = Colors.green;
    } else if (diff == 1) {
      label = selIdx > measIdx
          ? 'Slightly loose on you 📦'
          : 'Slightly tight on you ⚠️';
      color = Colors.orangeAccent;
    } else {
      label = selIdx > measIdx
          ? 'Too loose — try $measured ↓'
          : 'Too tight — try $measured ↑';
      color = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.accessibility_new, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            'Your body → $measured  •  $label',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Body Detected', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LKR ${widget.product.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _addToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Cart: ${widget.cartItems.length}',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
/// Draws a body-fitted garment silhouette (torso + sleeves) mapped to
/// ML Kit pose landmarks in real-time.
// ─────────────────────────────────────────────────────────────────────────
class GarmentPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;
  final String? selectedSize;
  final bool isSideView;

  const GarmentPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
    this.selectedSize,
    this.isSideView = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ls = _screenPos(PoseLandmarkType.leftShoulder, size);
    final rs = _screenPos(PoseLandmarkType.rightShoulder, size);
    final le = _screenPos(PoseLandmarkType.leftElbow, size);
    final re = _screenPos(PoseLandmarkType.rightElbow, size);
    final lh = _screenPos(PoseLandmarkType.leftHip, size);
    final rh = _screenPos(PoseLandmarkType.rightHip, size);
    final nose = _screenPos(PoseLandmarkType.nose, size);

    if (ls == null || rs == null) return;

    final scale = _sizeScale(selectedSize);
    final sw = (rs.dx - ls.dx).abs(); // shoulder width px
    // Sleeve clamp is relative to canvas size so it scales on all screen densities
    final minSleeve = size.width * 0.03;
    final maxSleeve = size.width * 0.10;
    final sleeveW = (sw * 0.22 * scale).clamp(minSleeve, maxSleeve);

    // Neck position (between nose and shoulder midpoint)
    final midShoulderY = (ls.dy + rs.dy) / 2;
    final midShoulderX = (ls.dx + rs.dx) / 2;
    final neckPos = nose != null
        ? Offset(midShoulderX, nose.dy + (midShoulderY - nose.dy) * 0.65)
        : Offset(midShoulderX, midShoulderY - sw * 0.18);

    // Hip fallback: estimate from shoulder position
    final hipL = lh ?? Offset(ls.dx - sw * 0.05, ls.dy + sw * 1.75 * scale);
    final hipR = rh ?? Offset(rs.dx + sw * 0.05, rs.dy + sw * 1.75 * scale);

    // Expand torso slightly beyond shoulders
    final exp = sw * 0.11 * scale;
    final tLS = Offset(ls.dx - exp, ls.dy);
    final tRS = Offset(rs.dx + exp, rs.dy);
    final tLH = Offset(hipL.dx - exp * 0.4, hipL.dy);
    final tRH = Offset(hipR.dx + exp * 0.4, hipR.dy);

    // ── Paints ────────────────────────────────────────────────────
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.18);

    // strokeWidth scales with screen density so lines look the same on all phones
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.005).clamp(1.5, 3.5)
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final collarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.004).clamp(1.5, 3.0)
      ..color = Colors.white.withValues(alpha: 0.90);

    // ── Torso path ────────────────────────────────────────────────
    final torso = Path()
      ..moveTo(neckPos.dx - sw * 0.09, neckPos.dy)
      ..lineTo(tLS.dx, tLS.dy)
      ..lineTo(tLH.dx, tLH.dy)
      ..lineTo(tRH.dx, tRH.dy)
      ..lineTo(tRS.dx, tRS.dy)
      ..lineTo(neckPos.dx + sw * 0.09, neckPos.dy)
      ..close();

    canvas.drawPath(torso, fillPaint);
    canvas.drawPath(torso, strokePaint);

    // ── Left sleeve ───────────────────────────────────────────────
    final leftElbow = le ??
        Offset(ls.dx - sw * 0.55, ls.dy + sw * 0.55);
    _drawSleeve(canvas, fillPaint, strokePaint, tLS, leftElbow, sleeveW);

    // ── Right sleeve ──────────────────────────────────────────────
    final rightElbow = re ??
        Offset(rs.dx + sw * 0.55, rs.dy + sw * 0.55);
    _drawSleeve(canvas, fillPaint, strokePaint, tRS, rightElbow, sleeveW);

    // ── Collar (neckline oval) ────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: neckPos,
        width: sw * 0.22,
        height: sw * 0.13,
      ),
      collarPaint,
    );

    // ── Centre seam line (stitching detail) ───────────────────────
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.30);
    canvas.drawLine(
      Offset(midShoulderX, neckPos.dy + sw * 0.05),
      Offset(midShoulderX, (tLH.dy + tRH.dy) / 2),
      seamPaint,
    );
  }

  void _drawSleeve(
    Canvas canvas,
    Paint fill,
    Paint stroke,
    Offset shoulder,
    Offset elbow,
    double width,
  ) {
    final dir = elbow - shoulder;
    final len = dir.distance;
    if (len < 1) return;
    final norm = Offset(dir.dx / len, dir.dy / len);
    final perp = Offset(-norm.dy, norm.dx);

    // Tapered sleeve (slightly narrower at elbow)
    final path = Path()
      ..moveTo(shoulder.dx + perp.dx * width,      shoulder.dy + perp.dy * width)
      ..lineTo(shoulder.dx - perp.dx * width,      shoulder.dy - perp.dy * width)
      ..lineTo(elbow.dx   - perp.dx * width * 0.6, elbow.dy   - perp.dy * width * 0.6)
      ..lineTo(elbow.dx   + perp.dx * width * 0.6, elbow.dy   + perp.dy * width * 0.6)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  double _sizeScale(String? s) {
    switch (s?.toUpperCase()) {
      case 'XS':   return 0.72;
      case 'S':    return 0.82;
      case 'M':    return 1.00;
      case 'L':    return 1.18;
      case 'XL':   return 1.36;
      case 'XXL':  return 1.55;
      case 'XXXL': return 1.75;
      default:     return 1.00;
    }
  }

  Offset? _screenPos(PoseLandmarkType type, Size size) {
    final lm = pose.landmarks[type];
    if (lm == null || lm.likelihood < 0.30) return null;
    double nx, ny;
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      nx = lm.y / imageSize.height;
      ny = lm.x / imageSize.width;
    } else {
      nx = lm.x / imageSize.width;
      ny = lm.y / imageSize.height;
    }
    if (isFrontCamera) nx = 1.0 - nx;
    return Offset(
      nx.clamp(0.0, 1.0) * size.width,
      ny.clamp(0.0, 1.0) * size.height,
    );
  }

  @override
  bool shouldRepaint(GarmentPainter old) => true;
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

/// Draws a dashed body silhouette guide so user knows where to stand
class _BodyGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    // Head oval
    final headR = size.width * 0.09;
    final headTop = size.height * 0.08;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headTop + headR), width: headR * 2, height: headR * 2.2),
      paint,
    );

    // Torso rectangle (shoulders to hips)
    final torsoTop    = headTop + headR * 2.4;
    final torsoBottom = size.height * 0.68;
    final torsoLeft   = cx - size.width * 0.22;
    final torsoRight  = cx + size.width * 0.22;

    _drawDashedRect(
      canvas, paint,
      Rect.fromLTRB(torsoLeft, torsoTop, torsoRight, torsoBottom),
      dashLen: 10, gapLen: 6,
    );

    // Shoulder line
    canvas.drawLine(
      Offset(torsoLeft - size.width * 0.04, torsoTop + 10),
      Offset(torsoRight + size.width * 0.04, torsoTop + 10),
      paint,
    );
  }

  void _drawDashedRect(Canvas canvas, Paint paint, Rect rect,
      {double dashLen = 8, double gapLen = 4}) {
    final path = Path()..addRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(dist, dist + len),
            paint,
          );
        }
        dist += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_BodyGuidePainter oldDelegate) => false;
}