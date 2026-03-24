import 'package:flutter/material.dart';

import '../theme/costa_norte_brand.dart';

class BrandSectionHero extends StatelessWidget {
  const BrandSectionHero({
    required this.eyebrow,
    required this.title,
    required this.icon,
    this.description,
    this.action,
    this.photoAlignment = Alignment.centerRight,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;
  final Alignment photoAlignment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasDescription =
        description != null && description!.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                'assets/branding/costanorte_hero.jpg',
                fit: BoxFit.cover,
                alignment: photoAlignment,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: CostaNorteBrand.sectionOverlay,
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: CostaNorteBrand.goldAccentGradient,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x29000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: CostaNorteBrand.charcoal),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      eyebrow,
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (hasDescription) ...<Widget>[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Text(
                        description!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                    ),
                  ],
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 18),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
