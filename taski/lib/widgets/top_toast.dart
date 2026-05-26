import 'package:flutter/material.dart';

/// Shows a notification that slides down from the top, stays for 3 seconds,
/// then slides back up and removes itself.
void showTopToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;
  const _TopToast({required this.message, required this.onDismissed});

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.celebration,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
