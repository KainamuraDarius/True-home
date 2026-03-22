
import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback onFinish;
  const AnimatedSplashScreen({
    super.key,
    required this.duration,
    required this.onFinish,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    Future.delayed(widget.duration, () {
      _controller.reverse().then((_) => widget.onFinish());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.62,
              height: MediaQuery.of(context).size.width * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1976D2), // Brand blue or your preferred color
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.38,
                  height: MediaQuery.of(context).size.width * 0.38,
                  child: Image.asset(
                    'assets/images/launcher icon.jpeg',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
