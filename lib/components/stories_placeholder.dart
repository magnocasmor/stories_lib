import 'package:flutter/material.dart';
import 'package:skeleton_text/skeleton_text.dart';

// class StoriesListSkeleton extends StatelessWidget {
//   double width;
//   double height;

//   StoriesListSkeleton({
//     this.width = 140.0,
//     this.height = 178.0,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(left: 20),
//       child: Container(
//         height: height,
//         width: width,
//         child: SkeletonAnimation(
//           child: Container(
//             width: width,
//             height: height,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(10),
//               color: Colors.grey[300],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

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
