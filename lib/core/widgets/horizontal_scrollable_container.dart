import 'package:flutter/material.dart';

class HorizontalScrollableContainer extends StatefulWidget {
  const HorizontalScrollableContainer({
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 6),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<HorizontalScrollableContainer> createState() =>
      _HorizontalScrollableContainerState();
}

class _HorizontalScrollableContainerState
    extends State<HorizontalScrollableContainer> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
