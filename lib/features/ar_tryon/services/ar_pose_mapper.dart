import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/ar_tryon_overlay_data.dart';

class ArPoseMapper {
  static ArTryOnOverlayData? mapPoseToOverlay({
    required Pose pose,
    required Size sourceSize,
    required Size viewportSize,
    required bool mirrorHorizontally,
    required double fitScale,
    required double verticalOffset,
  }) {
    if (sourceSize.isEmpty || viewportSize.isEmpty) {
      return null;
    }

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    final viewRect = _calculateFittedRect(
      sourceSize: sourceSize,
      viewportSize: viewportSize,
    );

    final leftShoulderPoint = _mapPoint(
      x: leftShoulder.x,
      y: leftShoulder.y,
      sourceSize: sourceSize,
      fittedRect: viewRect,
      mirrorHorizontally: mirrorHorizontally,
    );
    final rightShoulderPoint = _mapPoint(
      x: rightShoulder.x,
      y: rightShoulder.y,
      sourceSize: sourceSize,
      fittedRect: viewRect,
      mirrorHorizontally: mirrorHorizontally,
    );
    final leftHipPoint = _mapPoint(
      x: leftHip.x,
      y: leftHip.y,
      sourceSize: sourceSize,
      fittedRect: viewRect,
      mirrorHorizontally: mirrorHorizontally,
    );
    final rightHipPoint = _mapPoint(
      x: rightHip.x,
      y: rightHip.y,
      sourceSize: sourceSize,
      fittedRect: viewRect,
      mirrorHorizontally: mirrorHorizontally,
    );

    final shoulderCenter = Offset.lerp(
      leftShoulderPoint,
      rightShoulderPoint,
      0.5,
    )!;
    final hipCenter = Offset.lerp(leftHipPoint, rightHipPoint, 0.5)!;
    final torsoCenter = Offset.lerp(shoulderCenter, hipCenter, 0.45)!;

    final shoulderWidth = (rightShoulderPoint - leftShoulderPoint).distance;
    final torsoHeight = (hipCenter - shoulderCenter).distance;
    if (shoulderWidth < 24 || torsoHeight < 24) {
      return null;
    }

    final width = shoulderWidth * 1.45 * fitScale;
    final height = math.max(width * 1.18, torsoHeight * 1.9 * fitScale);
    final rotation = math.atan2(
      rightShoulderPoint.dy - leftShoulderPoint.dy,
      rightShoulderPoint.dx - leftShoulderPoint.dx,
    );

    final center = torsoCenter.translate(0, verticalOffset);
    final unclampedFrame = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    final frame = Rect.fromLTWH(
      unclampedFrame.left.clamp(-width * 0.25, viewportSize.width - width * 0.75),
      unclampedFrame.top.clamp(0.0, viewportSize.height - height * 0.2),
      width,
      height,
    );

    final confidence = [
      leftShoulder.likelihood,
      rightShoulder.likelihood,
      leftHip.likelihood,
      rightHip.likelihood,
    ].reduce((a, b) => a + b) / 4;

    return ArTryOnOverlayData(
      frame: frame,
      rotation: rotation,
      confidence: confidence,
    );
  }

  static Rect _calculateFittedRect({
    required Size sourceSize,
    required Size viewportSize,
  }) {
    final fittedSizes = applyBoxFit(BoxFit.cover, sourceSize, viewportSize);
    final inputSubrect = Alignment.center.inscribe(
      fittedSizes.source,
      Offset.zero & sourceSize,
    );
    final outputSubrect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & viewportSize,
    );

    final scaleX = outputSubrect.width / inputSubrect.width;
    final scaleY = outputSubrect.height / inputSubrect.height;

    return Rect.fromLTWH(
      outputSubrect.left - inputSubrect.left * scaleX,
      outputSubrect.top - inputSubrect.top * scaleY,
      sourceSize.width * scaleX,
      sourceSize.height * scaleY,
    );
  }

  static Offset _mapPoint({
    required double x,
    required double y,
    required Size sourceSize,
    required Rect fittedRect,
    required bool mirrorHorizontally,
  }) {
    final normalizedX = (x / sourceSize.width).clamp(0.0, 1.0);
    final normalizedY = (y / sourceSize.height).clamp(0.0, 1.0);
    final adjustedX = mirrorHorizontally ? (1 - normalizedX) : normalizedX;

    return Offset(
      fittedRect.left + adjustedX * fittedRect.width,
      fittedRect.top + normalizedY * fittedRect.height,
    );
  }
}
