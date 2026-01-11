import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  final Future<Widget> Function() resolveNextPage;
  final Duration duration;

  const SplashPage({
    super.key,
    required this.resolveNextPage,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeInAnimation;
  // ignore: unused_field
  late final Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3333, 1.0, curve: Curves.easeInOut),
      ),
    );

    _start();
  }

  Future<void> _start() async {
    try {
      final minDisplayDuration = widget.duration;
      final fadeOutDuration = const Duration(milliseconds: 400);
      // ignore: unused_local_variable
      final fadeInDuration = _controller.duration ?? const Duration(milliseconds: 600);

      // Start fade in animation
      await _controller.forward();

      // Start both minimum display duration minus fade out duration and resolveNextPage
      final results = await Future.wait([
        Future.delayed(minDisplayDuration - fadeOutDuration),
        widget.resolveNextPage(),
      ]);
      final next = results[1] as Widget;

      // Start fade out animation
      await _controller.animateBack(0.0, duration: fadeOutDuration);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final next = await widget.resolveNextPage();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeInAnimation.drive(
          Tween<double>(begin: 0.0, end: 1.0),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
                    final size = constraints.maxWidth * (isTablet ? 0.6 : 0.48);

                    return Container(
                      width: size,
                      height: size,
                      child: ClipRRect(
                        child: Image.asset(
                          'assets/icon-sp.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  "あなたの野球をもう一段楽しく。",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}