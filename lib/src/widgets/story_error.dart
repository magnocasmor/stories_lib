import 'package:flutter/material.dart';

class StoryError extends StatelessWidget {
  final String info;

  const StoryError({Key key, this.info = "Media failed to load."}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
      child: Center(
        child: Text(
          info,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
