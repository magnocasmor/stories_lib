import 'package:flutter/material.dart';

class StoryWidget extends StatelessWidget {
  final Widget story;
  final String caption;
  final TextStyle captionStyle;

  const StoryWidget({
    Key key,
    @required this.story,
    this.caption,
    this.captionStyle = const TextStyle(fontSize: 15, color: Colors.white),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: story),
        if (caption is String && caption.isNotEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
              color: Colors.black54,
              child: Text(
                caption,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
            ),
          )
      ],
    );
  }
}
