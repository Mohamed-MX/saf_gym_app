import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
  });

  static IconData getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'abs':
        return Icons.sports_martial_arts;
      case 'arms':
        return Icons.sports_gymnastics;
      case 'back':
        return Icons.accessibility_new;
      case 'calves':
        return Icons.directions_walk;
      case 'cardio':
        return Icons.favorite;
      case 'chest':
        return Icons.fitness_center;
      case 'legs':
        return Icons.directions_run;
      case 'shoulders':
        return Icons.person;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            splashColor: AppTheme.white.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
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
