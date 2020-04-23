import 'package:flutter/material.dart';

class StoryWidget extends StatelessWidget {
  final Widget story;
  final String caption;

  const StoryWidget({
    Key key,
    @required this.story,
    this.caption,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        story,
        if (caption is String && caption.isNotEmpty)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(
                  bottom: 24,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                color: Colors.black54,
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
      ],
    );
  }
}
