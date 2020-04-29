import 'package:flutter/material.dart';

class StoryError extends StatelessWidget {
  const StoryError({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      "Media failed to load.",
      style: TextStyle(
        color: Colors.white,
      ),
    );
  }
}
