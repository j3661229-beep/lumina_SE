import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final bool glass;
  final double? width;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.glass = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final decoration = BoxDecoration(
      color: color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: glass || isDark ? Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)) : null,
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withOpacity(isDark ? 0.05 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );

    final card = Container(
      width: width,
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return card;
  }
}
