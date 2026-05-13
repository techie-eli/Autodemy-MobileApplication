import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/attendance_service.dart';

class StudentQRCodeScreen extends StatefulWidget {
  final String studentName;
  final String subject;
  final String section;
  final String sessionCode;

  const StudentQRCodeScreen({
    super.key,
    required this.studentName,
    required this.subject,
    required this.section,
    required this.sessionCode,
  });

  @override
  State<StudentQRCodeScreen> createState() => _StudentQRCodeScreenState();
}

class _StudentQRCodeScreenState extends State<StudentQRCodeScreen> with TickerProviderStateMixin {
  late Timer _timer;
  late int _timestamp;
  int _secondsRemaining = 15;
  StreamSubscription? _statusSub;
  bool _marked = false;

  // Liveness animation controllers
  late AnimationController _bgController;
  late AnimationController _particleController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _refreshQR();
    _startTimer();
    _listenForStatus();

    // Background gradient animation — proves the app is LIVE
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    // Particle animation
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  void _refreshQR() {
    setState(() {
      _timestamp = DateTime.now().millisecondsSinceEpoch;
      _secondsRemaining = 15;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _refreshQR();
      }
    });
  }

  void _listenForStatus() {
    _statusSub = AttendanceService.streamSessionRecords(widget.subject, widget.section).listen((records) {
      final myRecord = records.where((r) => r.name == widget.studentName).firstOrNull;
      if (myRecord != null && myRecord.status != 'pending' && !_marked) {
        setState(() => _marked = true);
        _timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _statusSub?.cancel();
    _bgController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String qrData = "${widget.studentName}|${widget.subject}|${widget.section}|$_timestamp|${widget.sessionCode}";

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // ── Animated Gradient Background ──
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFF0D47A1), const Color(0xFF1A237E), _bgAnimation.value)!,
                      Color.lerp(const Color(0xFF001529), const Color(0xFF0D1B2A), _bgAnimation.value)!,
                      Color.lerp(const Color(0xFF001529), const Color(0xFF162447), _bgAnimation.value * 0.5)!,
                    ],
                    stops: [0.0, 0.6 + _bgAnimation.value * 0.1, 1.0],
                  ),
                ),
              ),

              // ── Floating Particles (Liveness Proof) ──
              ...List.generate(12, (i) => _FloatingParticle(
                controller: _particleController,
                index: i,
              )),

              // ── Scanning Lines Animation ──
              _ScanLineEffect(controller: _bgController),

              // ── Main Content ──
              SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _marked ? Colors.green : const Color(0xFFFFD700),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_marked ? Colors.green : const Color(0xFFFFD700)).withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _marked ? 'VERIFIED' : 'LIVE SESSION',
                                style: TextStyle(
                                  color: _marked ? Colors.green.shade300 : const Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Main QR Card
                    _buildMainCard(qrData),

                    const Spacer(),

                    // Student Identity
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Text(
                            widget.studentName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${widget.subject} • ${widget.section}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Status Indicator
                    _buildStatusIndicator(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainCard(String qrData) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_marked) _buildSuccessView() else _buildQRView(qrData),
          ],
        ),
      ),
    );
  }

  Widget _buildQRView(String qrData) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _PulsingRing(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF001529)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF001529)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'PRESENCE VALIDATION',
          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        // Animated countdown bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _secondsRemaining / 15.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsRemaining <= 3 ? Colors.red : const Color(0xFFFFD700),
              ),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFFFD700)),
            const SizedBox(width: 6),
            Text(
              'Dynamic Update in $_secondsRemaining s',
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(Icons.done_all_rounded, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 24),
          const Text('VERIFIED!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Attendance logged successfully.', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_marked) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(
          width: 40, height: 40,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            strokeWidth: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AWAITING TEACHER VERIFICATION',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ── PULSING RING AROUND QR ──
class _PulsingRing extends StatefulWidget {
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity((1 - _controller.value) * 0.3),
              width: _controller.value * 20,
            ),
          ),
        );
      },
    );
  }
}

// ── FLOATING PARTICLES (LIVENESS INDICATOR) ──
class _FloatingParticle extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _FloatingParticle({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final random = Random(index * 42);
    final size = 3.0 + random.nextDouble() * 5;
    final startX = random.nextDouble();
    final startY = random.nextDouble();
    final speed = 0.3 + random.nextDouble() * 0.7;
    final opacity = 0.1 + random.nextDouble() * 0.2;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = (controller.value * speed + startY) % 1.0;
        final xOffset = sin((controller.value + startX) * pi * 2) * 30;

        return Positioned(
          left: MediaQuery.of(context).size.width * startX + xOffset,
          top: MediaQuery.of(context).size.height * (1.0 - progress),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(opacity * 0.5),
                  blurRadius: size * 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── SCAN LINE EFFECT (HORIZONTAL LINE SWEEPING DOWN) ──
class _ScanLineEffect extends StatelessWidget {
  final AnimationController controller;
  const _ScanLineEffect({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * controller.value,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.05),
                  Colors.cyan.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
