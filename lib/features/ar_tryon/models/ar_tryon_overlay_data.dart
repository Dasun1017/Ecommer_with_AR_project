import 'package:flutter/widgets.dart';

class ArTryOnOverlayData {
  const ArTryOnOverlayData({
    required this.frame,
    required this.rotation,
    required this.confidence,
  });

  final Rect frame;
  final double rotation;
  final double confidence;
}
