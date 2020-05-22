import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../views/story_publisher.dart';

typedef _ExternalPublish = Future<ExternalMediaStatus> Function(File, StoryType);

/// A set of widgets, builders and style to decorate the screen
/// when the user publish stories.
///
/// These widgets will be put on [Stack] with the story media view.
/// So, use [Align] or [Positioned] to set the widgets in right place.
class PublishDecoration {
  /// Build the button to publish stories.
  ///
  /// Provide the [StoryType] selected and [Animation] on video record.
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  ///
  /// If you want implements your own behavior, set the [defaultBehavior] to false and
  /// use [PublisherController].
  final Widget Function(StoryType type, Animation<double> anim) publisherBuilder;

  /// Build a widget to change the [StoryType] by calling the [changeType] function.
  final Widget Function(StoryType type, Function(StoryType) changeType) typeBuilder;

  /// Build a widget to change the [CameraLensDirection] by calling the [changeLens] function.
  final Widget Function(
    CameraLensDirection lens,
    Function(CameraLensDirection) changeLens,
  ) lensBuilder;

  /// Build a widget to [sendExternalMedia] by pass a [File] of the media and your [StoryType].
  ///
  /// You can use [ImagePicker] to get the file media and call [sendExternalMedia].
  final Widget Function(
    BuildContext context,
    _ExternalPublish sendExternalMedia,
  ) externalMediaButtonBuilder;

  /// enable/disable the default behavior of the widget built by [publisherBuilder].
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  final bool defaultBehavior;

  PublishDecoration({
    this.publisherBuilder,
    this.typeBuilder,
    this.lensBuilder,
    this.externalMediaButtonBuilder,
    this.defaultBehavior = true,
  }) : assert(defaultBehavior != null);
}
