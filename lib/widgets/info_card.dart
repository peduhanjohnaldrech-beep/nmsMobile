import 'package:flutter/material.dart';

/// A section card with a title and slot for children.
class InfoCard extends StatelessWidget {
  final String        title;
  final IconData?     icon;
  final List<Widget>  children;
  final Color?        iconColor;
  final EdgeInsetsGeometry padding;

  const InfoCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.iconColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin:      const EdgeInsets.only(bottom: 12),
      elevation:   2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor ?? theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      theme.colorScheme.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A single labeled row inside an InfoCard.
class InfoRow extends StatelessWidget {
  final String  label;
  final String  value;
  final Widget? trailing;
  final bool    bold;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color:    Color(0xFF8FA8BF),
              ),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color:      const Color(0xFFE8F4FD),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Stat card used in the dashboard stats row
class StatCard extends StatelessWidget {
  final String    label;
  final String    value;
  final IconData  icon;
  final Color     color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1527),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: const Color(0xFF1A3050), width: 1),
              right: BorderSide(color: const Color(0xFF1A3050), width: 1),
              bottom: BorderSide(color: const Color(0xFF1A3050), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color:  color.withValues(alpha: 0.1),
                  shape:  BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w800,
                  color:      color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF7B8FA6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
