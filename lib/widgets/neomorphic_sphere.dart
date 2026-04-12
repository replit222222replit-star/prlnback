import 'dart:math';
import 'package:flutter/material.dart';

class NeomorphicSphere extends StatefulWidget {
  final bool active;
  final String label;
  const NeomorphicSphere({super.key, required this.active, required this.label});

  @override
  State<NeomorphicSphere> createState() => _NeomorphicSphereState();
}

class _NeomorphicSphereState extends State<NeomorphicSphere> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
        final progress = _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: widget.active
                  ? [const Color(0xFF57BBF6), const Color(0xFF08101F)]
                  : [const Color(0xFF2A3140), const Color(0xFF09141E)],
              stops: [0.1 + sin(progress * pi) * 0.05, 0.9],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.active ? const Color(0xFF4FB3F6).withOpacity(0.24) : Colors.black26,
                blurRadius: 32,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _SphereShaderPainter(progress, widget.active),
            child: Center(
              child: Text(widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        );
      },
    );
  }
}

class _SphereShaderPainter extends CustomPainter {
  final double progress;
  final bool active;
  _SphereShaderPainter(this.progress, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: active
            ? [const Color(0xFF8AE4FF).withOpacity(0.8), const Color(0xFF0B1521).withOpacity(0.3)]
            : [const Color(0xFF4A5568).withOpacity(0.55), const Color(0xFF09141E).withOpacity(0.25)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path();
    final distortion = sin(progress * 2 * pi) * 12;
    path.addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 0.44));
    canvas.drawPath(path, paint);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.35, Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.04));
    canvas.drawCircle(size.center(Offset.zero).translate(distortion / 3, -distortion / 2), size.width * 0.08,
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.18));
  }

  @override
  bool shouldRepaint(covariant _SphereShaderPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.active != active;
}
