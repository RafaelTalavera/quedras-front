import 'package:flutter/material.dart';

class CostaNorteLogo extends StatelessWidget {
  const CostaNorteLogo({
    this.width = 190,
    this.semanticLabel = 'Costa Norte',
    super.key,
  });

  final double width;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        'assets/branding/costanorte_logo.png',
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
