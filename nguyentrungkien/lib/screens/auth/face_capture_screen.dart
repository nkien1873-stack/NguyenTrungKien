import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/face_features.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../router.dart';

enum FaceMode { login, enroll }

/// Vừa đăng nhập bằng mật khẩu mà tài khoản chưa có khuôn mặt -> mời đăng ký ngay
/// (mỗi tài khoản chỉ hỏi 1 lần trên máy này).
Future<void> offerFaceEnroll(BuildContext context, Session session) async {
  if (session.hasFace || session.role == Roles.child) return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'faceOffered_${session.username}';
  if (prefs.getBool(key) == true || !context.mounted) return;
  await prefs.setBool(key, true);
  if (!context.mounted) return;
  final ok = await confirm(context, 'Đăng nhập bằng khuôn mặt',
      'Đăng ký khuôn mặt để lần sau chỉ cần nhìn vào camera là vào được app (không cần mật khẩu)?',
      ok: 'Đăng ký ngay');
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceCaptureScreen.enroll()));
}

/// Chức năng a – Đăng nhập bằng khuôn mặt (và đăng ký khuôn mặt).
///
/// Chỉ 1 bước: nhìn thẳng và bấm "Chụp" một lần.
/// Mỗi lần bấm, app tự chụp vài ảnh liên tiếp và dùng các ảnh thấy rõ mặt
/// (camera kém hoặc ảnh mờ thì không phải bấm lại nhiều lần).
/// Đăng ký: tối đa 3 ảnh tốt -> server lấy mẫu trung bình. Đăng nhập: 1 ảnh tốt.
class FaceCaptureScreen extends StatefulWidget {
  final FaceMode mode;
  final String? username;

  const FaceCaptureScreen.login({super.key, required this.username}) : mode = FaceMode.login;
  const FaceCaptureScreen.enroll({super.key})
      : mode = FaceMode.enroll,
        username = null;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cam;
  String? _camError;
  bool _busy = false;
  String? _hint;

  static const _maxShots = 5; // số ảnh chụp thử tối đa cho 1 lần bấm
  int get _needed => widget.mode == FaceMode.enroll ? 3 : 1; // số ảnh tốt muốn có
  int _good = 0; // số ảnh tốt của lần bấm hiện tại (hiện tiến trình)

  String get _instruction => 'Nhìn thẳng vào camera, giữ nét mặt tự nhiên rồi bấm Chụp';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('Không tìm thấy camera');
      final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      final ctrl = CameraController(front, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _cam = ctrl);
    } catch (e) {
      if (mounted) setState(() => _camError = 'Không mở được camera: $e');
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  /// 1 lần bấm: chụp liên tiếp tới khi đủ ảnh tốt (hoặc hết số lần thử), rồi gửi luôn.
  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() {
      _busy = true;
      _hint = null;
      _good = 0;
    });
    final samples = <List<double>>[];
    String? lastProblem;
    try {
      for (var shot = 0; shot < _maxShots && samples.length < _needed; shot++) {
        final file = await cam.takePicture();
        final result = await FaceFeatures.analyzeFile(file.path);
        try {
          await File(file.path).delete();
        } catch (_) {}
        if (result.features == null) {
          lastProblem = result.problem;
          continue;
        }
        samples.add(result.features!);
        if (mounted) setState(() => _good = samples.length);
      }

      if (samples.isEmpty) {
        setState(() => _hint = lastProblem ?? 'Không nhận được khuôn mặt, hãy thử lại.');
        return;
      }
      if (widget.mode == FaceMode.enroll) {
        await _submitEnroll(samples);
      } else {
        await _submitLogin(samples.first);
      }
    } catch (e) {
      if (mounted) setState(() => _hint = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEnroll(List<List<double>> samples) async {
    try {
      final res = await Api.I.post('/api/auth/face/enroll', {'samples': samples});
      if (!mounted) return;
      await context.read<Session>().setHasFace(true);
      if (!mounted) return;
      showMsg(context, res['message'] ?? 'Đã đăng ký khuôn mặt');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _hint = e.message);
    }
  }

  Future<void> _submitLogin(List<double> features) async {
    final session = context.read<Session>();
    try {
      final res = await Api.I.post('/api/auth/face-login', {
        'username': widget.username,
        'features': features,
      });
      await session.saveUser(Map<String, dynamic>.from(res));
      if (!mounted) return;
      showMsg(context, 'Xin chào ${session.fullName}!');
      goHome(context, session.role);
    } on ApiException catch (e) {
      if (mounted) setState(() => _hint = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.mode == FaceMode.enroll ? 'Đăng ký khuôn mặt' : 'Đăng nhập khuôn mặt',
            style: const TextStyle(color: Colors.white)),
      ),
      body: _camError != null
          ? Center(child: Text(_camError!, style: const TextStyle(color: Colors.white)))
          : cam == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: cam.value.previewSize?.height ?? 300,
                                height: cam.value.previewSize?.width ?? 400,
                                child: CameraPreview(cam),
                              ),
                            ),
                          ),
                          // Khung oval hướng dẫn
                          IgnorePointer(
                            child: Container(
                              width: 250,
                              height: 330,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(Radius.elliptical(125, 165)),
                                border: Border.all(color: _hint == null ? Colors.white : AppColors.warning, width: 4),
                              ),
                            ),
                          ),
                          if (_busy) const CircularProgressIndicator(color: Colors.white),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_busy) ...[
                            LinearProgressIndicator(
                              value: _good / _needed,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(_instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          if (_hint != null) ...[
                            const SizedBox(height: 8),
                            Text(_hint!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                          ],
                          if (widget.mode == FaceMode.login) ...[
                            const SizedBox(height: 6),
                            Text(
                                widget.username == null
                                    ? 'Tự nhận ra tài khoản theo khuôn mặt'
                                    : 'Tài khoản: ${widget.username}',
                                style: const TextStyle(color: AppColors.muted)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _capture,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(_busy ? 'Đang chụp, giữ yên...' : 'Chụp'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
