import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Kết quả phân tích 1 ảnh khuôn mặt.
class FaceAnalysis {
  final List<double>? features;
  final double smile;
  final String? problem;
  FaceAnalysis({this.features, this.smile = 0, this.problem});
}

/// Chức năng a – Trích xuất đặc trưng khuôn mặt từ ML Kit.
///
/// Ý tưởng: lấy 7 điểm mốc (2 mắt, mũi, 2 khóe miệng, môi dưới, 2 má),
/// tính khoảng cách giữa mọi cặp điểm rồi chia cho khoảng cách 2 mắt
/// -> vector không phụ thuộc kích thước ảnh. Server so sánh vector này với mẫu đã đăng ký.
class FaceFeatures {
  static final FaceDetector detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  static const _types = [
    FaceLandmarkType.leftEye,
    FaceLandmarkType.rightEye,
    FaceLandmarkType.noseBase,
    FaceLandmarkType.leftMouth,
    FaceLandmarkType.rightMouth,
    FaceLandmarkType.bottomMouth,
    FaceLandmarkType.leftCheek,
    FaceLandmarkType.rightCheek,
  ];

  static Future<FaceAnalysis> analyzeFile(String path, {bool requireFrontal = true}) async {
    final faces = await detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) return FaceAnalysis(problem: 'Không thấy khuôn mặt. Hãy đưa mặt vào khung.');
    if (faces.length > 1) return FaceAnalysis(problem: 'Chỉ được có 1 khuôn mặt trong khung.');
    final face = faces.first;
    final smile = face.smilingProbability ?? 0;

    if (requireFrontal) {
      final y = (face.headEulerAngleY ?? 0).abs();
      final z = (face.headEulerAngleZ ?? 0).abs();
      if (y > 20 || z > 15) return FaceAnalysis(smile: smile, problem: 'Hãy nhìn thẳng vào camera, không nghiêng đầu.');
    }

    final pts = <Point<double>>[];
    for (final t in _types) {
      final lm = face.landmarks[t];
      if (lm == null) {
        return FaceAnalysis(smile: smile, problem: 'Không nhận đủ điểm trên khuôn mặt. Hãy chụp nơi đủ sáng.');
      }
      pts.add(Point(lm.position.x.toDouble(), lm.position.y.toDouble()));
    }

    final eyeDist = pts[0].distanceTo(pts[1]);
    if (eyeDist < 20) return FaceAnalysis(smile: smile, problem: 'Khuôn mặt quá nhỏ, hãy đưa máy lại gần hơn.');

    final features = <double>[];
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        if (i == 0 && j == 1) continue; // = 1 sau khi chuẩn hóa
        features.add(pts[i].distanceTo(pts[j]) / eyeDist);
      }
    }

    // Tỉ lệ khung mặt (đường viền khuôn mặt)
    final contour = face.contours[FaceContourType.face]?.points ?? [];
    if (contour.length >= 10) {
      final xs = contour.map((p) => p.x.toDouble());
      final ys = contour.map((p) => p.y.toDouble());
      features.add((xs.reduce(max) - xs.reduce(min)) / eyeDist);
      features.add((ys.reduce(max) - ys.reduce(min)) / eyeDist);
    } else {
      features.add(face.boundingBox.width / eyeDist);
      features.add(face.boundingBox.height / eyeDist);
    }

    return FaceAnalysis(features: features, smile: smile);
  }
}
