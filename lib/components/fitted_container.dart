import 'package:flutter/material.dart';

class FittedContainer extends StatelessWidget {
  final BoxFit fit;
  final Widget child;
  final double width;
  final double height;

  const FittedContainer({
    Key key,
    @required this.fit,
    @required this.child,
    this.width,
    this.height,
  })  : assert(fit != null, "[fit] can't be null"),
        assert(child != null, "[child] can't be null"),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          child: child,
          width: width ?? size.width,
          height: height ?? size.height,
        ),
      ),
    );
  }
}
