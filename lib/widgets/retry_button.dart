import 'package:flutter/material.dart';

class RetryButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  const RetryButton({super.key, required this.onPressed});

  @override
  State<RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<RetryButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {}),
      onTapUp: (_) => setState(() {}),
      onTapCancel: () => setState(() {}),
      onTap: _isLoading
          ? null
          : () async {
              setState(() {
                _isLoading = true;
              });
              _controller.repeat();

              // Run minimum delay and task in parallel
              // This ensures we see the animation for at least 1s
              // but also wait for the actual network request if it takes longer.
              final minDelay = Future.delayed(
                const Duration(milliseconds: 1000),
              );
              final task = widget.onPressed();

              await Future.wait([minDelay, task]);

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                _controller.stop();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF714FDC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF714FDC).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isLoading
            ? RotationTransition(
                turns: _controller,
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              )
            : const Text(
                "Retry",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
