import 'package:flutter/material.dart';
import 'app_card.dart';

class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (progress != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
