import 'package:flutter/material.dart';
import 'package:skeleton_text/skeleton_text.dart';

class StoriesPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  StoriesPlaceholder({
    this.width = 140.0,
    this.height = 178.0,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimation(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
        ),
      ),
    );
  }
}
