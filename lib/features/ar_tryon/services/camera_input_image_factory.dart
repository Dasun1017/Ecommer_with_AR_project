import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/processed_camera_frame.dart';

class CameraInputImageFactory {
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static ProcessedCameraFrame? fromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required CameraController controller,
  }) {
    final rotation = _getRotation(
      camera: camera,
      controller: controller,
    );
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    final inputImage = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );

    final isQuarterTurn = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    return ProcessedCameraFrame(
      inputImage: inputImage,
      imageSize: isQuarterTurn
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble()),
    );
  }

  static InputImageRotation? _getRotation({
    required CameraDescription camera,
    required CameraController controller,
  }) {
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (!Platform.isAndroid) {
      return null;
    }

    var rotationCompensation = _orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) {
      return null;
    }

    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }

    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }
}
