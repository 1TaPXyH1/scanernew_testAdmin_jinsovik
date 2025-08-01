import 'package:flutter/material.dart';

class ShimmerLoadingWidget extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoadingWidget({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 1000),
      
      builder: (context, value, _) {
        return Opacity(
          opacity: isLoading ? value : 1.0,
          child: child,
        );
      },
    );
  }
}

