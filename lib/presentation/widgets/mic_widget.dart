import 'package:flutter/material.dart';

class MicWidget extends StatefulWidget {
  final bool isListening;
  final bool isError;
  final VoidCallback onTap;

  const MicWidget({
    super.key, 
    required this.isListening, 
    required this.onTap,
    this.isError = false,
  });

  @override
  State<MicWidget> createState() => _MicWidgetState();
}

class _MicWidgetState extends State<MicWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pro Colors
    final Color activeColor = widget.isError ? Colors.redAccent : Colors.cyanAccent;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow Ring (Only when listening or error)
          if (widget.isListening || widget.isError)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: (1.5 - _pulseAnimation.value) * 0.6,
                  child: Container(
                    width: 70 * _pulseAnimation.value,
                    height: 70 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: activeColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Main Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isError 
                    ? [Colors.red, Colors.redAccent]
                    : widget.isListening
                        ? [Colors.cyan, Colors.blue]
                        : [Colors.grey[800]!, Colors.grey[900]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isError 
                          ? Colors.red 
                          : widget.isListening ? Colors.cyan : Colors.black)
                      .withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              widget.isError ? Icons.error_outline :
              widget.isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 36,
            ),
          ),

          // Rotating Border Detail
          if (widget.isListening)
            RotationTransition(
              turns: _rotateController,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
