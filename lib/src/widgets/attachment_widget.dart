import 'package:flutter/material.dart';
import 'package:multi_gesture_widget/multi_gesture_widget.dart';

/// A wrap to insert the [child] in the attachments array on [_StoryPublisherResult]
/// 
/// This widget can de draggable, scalable and rotated
class AttachmentWidget extends StatelessWidget {
  final Widget child;

  const AttachmentWidget({
    @required Key key,
    @required this.child,
  }) : 
  assert(key != null, "[key] is needed to remove the widget from attachment's array"),
  assert(child != null),
  super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: MultiGestureWidget(child: child),
    );
  }
}
