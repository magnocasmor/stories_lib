import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

class MultiGestureWidget extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;

  MultiGestureWidget({
    @required this.child,
    this.minScale = 0.8,
    this.maxScale = 2.5,
  }) : assert(minScale != null && maxScale != null);

  @override
  _MultiGestureWidgetState createState() => _MultiGestureWidgetState();
}

class _MultiGestureWidgetState extends State<MultiGestureWidget> {
  Offset offset = Offset.zero;
  Offset lastOffset;

  double scale = 1.0;
  double lastScale;

  double angle = 0.0;
  double lastAngle;

  @override
  void initState() {
    super.initState();
    lastOffset = offset;
    lastScale = scale;
    lastAngle = angle;
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: _MultiGestureDetector(
        onPanStart: (initial) {
          lastOffset = this.offset;
        },
        onScaleStart: (offset) {
          lastScale = scale;
          lastAngle = angle;
        },
        onPanUpdate: (initial, delta) {
          setState(() {
            offset = lastOffset + delta;
          });
        },
        onScaleUpdate: (focus, scale, rotate) {
          setState(() {
            angle = lastAngle + rotate;
            this.scale = (lastScale * scale).clamp(widget.minScale, widget.maxScale);
          });
        },
        child: widget.child,
      ),
    );
  }

  Matrix4 get matrix {
    return Matrix4.translationValues(offset.dx, offset.dy, 0.0)
      ..setRotationZ(angle)
      ..scale(scale, scale, 1.0);
  }
}

class _MultiGestureDetector extends StatefulWidget {
  final Widget child;
  final void Function(Offset initialPoint) onPanStart;
  final void Function(Offset initialPoint, Offset delta) onPanUpdate;
  final void Function() onPanEnd;

  final void Function(Offset initialFocusPoint) onScaleStart;
  final void Function(Offset changedFocusPoint, double scale, double rotate) onScaleUpdate;
  final void Function() onScaleEnd;

  final void Function(double dx) onHorizontalDragUpdate;
  final void Function(double dy) onVerticalDragUpdate;

  _MultiGestureDetector({
    this.child,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onHorizontalDragUpdate,
    this.onVerticalDragUpdate,
  });

  @override
  __MultiGestureDetectorState createState() => __MultiGestureDetectorState();
}

class __MultiGestureDetectorState extends State<_MultiGestureDetector> {
  final List<Touch> _touches = [];
  double _initialScalingDistance;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      child: widget.child,
      behavior: HitTestBehavior.translucent,
      gestures: {
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(),
          (ImmediateMultiDragGestureRecognizer instance) {
            instance.onStart = (Offset offset) {
              final touch = Touch(
                offset,
                (drag, details) => _onTouchUpdate(drag, details),
                (drag, details) => _onTouchEnd(drag, details),
              );
              _onTouchStart(touch);
              return touch;
            };
          },
        ),
      },
    );
  }

  void _onTouchStart(Touch touch) {
    _touches.add(touch);
    if (_touches.length == 1) {
      if (widget.onPanStart != null) widget.onPanStart(touch._startOffset);
    } else if (_touches.length == 2) {
      _initialScalingDistance = (_touches[0]._currentOffset - _touches[1]._currentOffset).distance;
      if (widget.onScaleStart != null)
        widget.onScaleStart((_touches[0]._currentOffset + _touches[1]._currentOffset) / 2);
    } else {
      // Do nothing/ ignore
    }
  }

  final _dxy = 10;

  double _computeRotationFactor(Touch t1, Touch t2) {
    if (t1 == null || t2 == null) {
      return 0.0;
    }

    final initialLine = t2._startOffset - t1._startOffset;

    final currentLine = t2._currentOffset - t1._currentOffset;

    return math.atan2(initialLine.dx, initialLine.dy) - math.atan2(currentLine.dx, currentLine.dy);

    // return (vB.direction <= math.pi / 2 ? -1 : 1) *
    //     math.acos((vA.dx * vB.dx + vA.dy * vB.dy) / (vA.distance * vB.distance));
  }

  void _onTouchUpdate(Touch touch, DragUpdateDetails details) {
    assert(_touches.isNotEmpty);
    touch._currentOffset = details.localPosition;

    if (_touches.length == 1) {
      if (widget.onPanUpdate != null)
        widget.onPanUpdate(touch._startOffset, details.localPosition - touch._startOffset);

      if (widget.onHorizontalDragUpdate != null) {
        final dx = (details.localPosition.dx - touch._startOffset.dx).abs();
        if (dx > _dxy)
          widget.onHorizontalDragUpdate(
              (details.localPosition.dx - touch._startOffset.dx).clamp(-2.0, 2.0));
      }

      if (widget.onVerticalDragUpdate != null) {
        final dy = (details.localPosition.dy - touch._startOffset.dy).abs();
        if (dy > _dxy)
          widget.onVerticalDragUpdate(
              (details.localPosition.dy - touch._startOffset.dy).clamp(-2.0, 2.0));
      }
    } else {
      // TODO average of ALL offsets, not only 2 first
      var newDistance = (_touches[0]._currentOffset - _touches[1]._currentOffset).distance;

      if (widget.onScaleUpdate != null)
        widget.onScaleUpdate(
            (_touches[0]._currentOffset + _touches[1]._currentOffset) / 2,
            newDistance / _initialScalingDistance,
            _computeRotationFactor(_touches[0], _touches[1]));
    }
  }

  void _onTouchEnd(Touch touch, DragEndDetails details) {
    _touches.remove(touch);
    if (_touches.length == 0) {
      if (widget.onPanEnd != null) widget.onPanEnd();
    } else if (_touches.length == 1) {
      if (widget.onScaleEnd != null) widget.onScaleEnd();

      // Restart pan
      _touches[0]._startOffset = _touches[0]._currentOffset;
      if (widget.onPanStart != null) widget.onPanStart(_touches[0]._startOffset);
    }
  }
}

class Touch extends Drag {
  Offset _startOffset;
  Offset _currentOffset;

  final void Function(Drag drag, DragUpdateDetails details) onUpdate;
  final void Function(Drag drag, DragEndDetails details) onEnd;

  Touch(this._startOffset, this.onUpdate, this.onEnd) {
    _currentOffset = _startOffset;
  }

  @override
  void update(DragUpdateDetails details) {
    super.update(details);
    onUpdate(this, details);
  }

  @override
  void end(DragEndDetails details) {
    super.end(details);
    onEnd(this, details);
  }
}
