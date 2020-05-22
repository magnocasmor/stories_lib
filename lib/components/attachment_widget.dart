import 'package:flutter/material.dart';

import '../components/multi_gesture_widget.dart';

class AttachmentWidget extends StatelessWidget {
  final Widget child;

  const AttachmentWidget({
    @required Key key,
    @required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: MultiGestureWidget(child: child),
    );
  }
}
