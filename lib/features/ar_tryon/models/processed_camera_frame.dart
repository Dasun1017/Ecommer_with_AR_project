import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ProcessedCameraFrame {
  const ProcessedCameraFrame({
    required this.inputImage,
    required this.imageSize,
  });

  final InputImage inputImage;
  final Size imageSize;
}
