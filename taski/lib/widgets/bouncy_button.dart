import 'package:flutter/material.dart';

/// An icon button that gives a quick scale "bounce" when tapped.
class BouncyIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? borderColor;
  final VoidCallback onPressed;

  const BouncyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 32,
    this.color,
    this.borderColor,
  });

  @override
  State<BouncyIconButton> createState() => _BouncyIconButtonState();
}

class _BouncyIconButtonState extends State<BouncyIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Shrink then spring back.
    _controller.forward().then((_) => _controller.reverse());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = Icon(widget.icon);
    // Wrap with a circular ring border (slightly larger than the glyph) so the
    // button picks up the banner's darker shade.
    if (widget.borderColor != null) {
      icon = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.borderColor!, width: 2),
        ),
        child: icon,
      );
    }
    return IconButton(
      iconSize: widget.size,
      color: widget.color,
      onPressed: _handleTap,
      icon: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.7).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: icon,
      ),
    );
  }
}
