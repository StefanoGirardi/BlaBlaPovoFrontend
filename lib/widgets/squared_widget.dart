import 'package:flutter/material.dart';

/// A square tile with rounded corners, an icon and a label inside.
/// Tappable with ripple (via InkWell).
class IconTextTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size; // width == height
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry contentPadding;
  final double elevation;

  const IconTextTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 100,
    this.borderRadius = 16,
    this.backgroundColor,
    this.iconColor,
    this.labelStyle,
    this.contentPadding = const EdgeInsets.all(12),
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final icColor = iconColor ?? Theme.of(context).iconTheme.color;
    final txtStyle = labelStyle ??
        Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600);

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        elevation: elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: elevation > 0
                  ? [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: elevation,
                        offset: Offset(0, elevation / 2),
                      )
                    ]
                  : null,
            ),
            child: Padding(
              padding: contentPadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: size * 0.36, color: icColor),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: txtStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
