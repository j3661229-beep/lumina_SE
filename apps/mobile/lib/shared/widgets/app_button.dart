import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) _ctrl.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) _ctrl.reverse();
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = cs.primary;
        fg = Colors.white;
        break;
      case AppButtonVariant.secondary:
        bg = cs.primary.withOpacity(0.1);
        fg = cs.primary;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = cs.primary;
        border = Border.all(color: cs.primary.withOpacity(0.3));
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = cs.onSurface;
        break;
    }

    if (widget.onPressed == null) {
      bg = theme.disabledColor.withOpacity(0.1);
      fg = theme.disabledColor;
      border = null;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );

    if (widget.fullWidth) {
      content = Center(child: content);
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: content,
        ),
      ),
    );
  }
}
