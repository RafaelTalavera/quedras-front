import 'package:flutter/material.dart';

final class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.child,
    required this.maxWidth,
    this.maxHeight,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
