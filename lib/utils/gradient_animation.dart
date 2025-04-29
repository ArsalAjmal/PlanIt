import 'package:flutter/material.dart';

class CreamNavyGradient extends StatefulWidget {
  final Widget child;
  
  const CreamNavyGradient({
    super.key,
    required this.child,
  });
  
  @override
  State<CreamNavyGradient> createState() => _CreamNavyGradientState();
}

class _CreamNavyGradientState extends State<CreamNavyGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFFDD0), // Cream
                Color.lerp(
                  const Color(0xFFFFFDD0),
                  const Color(0xFF9D9DCC), // Updated color
                  _animation.value,
                )!,
                const Color(0xFF9D9DCC), // Updated color
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}