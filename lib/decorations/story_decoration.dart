import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:stories_lib/components/attachment_widget.dart';
import 'package:stories_lib/views/story_publisher.dart';

import '../views/story_view.dart';

typedef CoverImageBuilder = Widget Function(ImageProvider);

typedef TitleBuilder = Widget Function(String);

typedef PublishmentDateBuilder = Widget Function(DateTime);

typedef ProgressBarBuilder = Widget Function(List<PageData>, int, Animation<double>);

typedef ViewersBuilder = Widget Function(List<Map<String, dynamic>>);

typedef StoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef ExternalMediaCallback = Future<ExternalMediaStatus> Function(File, StoryType);

typedef ExternalMediaBuilder = Widget Function(BuildContext, ExternalMediaCallback);

typedef MyStoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, bool, bool);

typedef MakeStoryBuilder = Widget Function(StoryType, Animation<double>);

typedef ChangeStoryTypeBuilder = Widget Function(StoryType, Function(StoryType));

typedef ChangeCameraBuilder = Widget Function(CameraLensDirection, Function(CameraLensDirection));

typedef PublishBuilder = Widget Function(BuildContext, Function({List<dynamic> selectedReleases}));

typedef AddAttachmentsBuilder = Widget Function(BuildContext, Function(List<AttachmentWidget>));

/// A set of widgets, builders and styles to decorate story's view.
///
/// These widgets will be put on [Stack] with the story media view.
/// So, use [Align] or [Positioned] to set the widgets in right place.
class StoryDecoration {
  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  /// Widget displayed when media fails to load.
  final Widget mediaError;

  /// Widget displayed while media load.
  final Widget mediaPlaceholder;

  final Color backgroundBetweenStories;

  /// Widget that shows [StorySettings.coverImg] on [StoryView].
  final CoverImageBuilder avatarBuilder;

  /// Widget that shows [StorySettings.title] on [StoryView].
  final TitleBuilder titleBuilder;

  /// Widget of the publishment [DateTime] on [StoryView].
  final PublishmentDateBuilder publishmentDateBuilder;

  /// A progressbar of the current [StoryView]
  final ProgressBarBuilder progressBar;

  /// Show the stories preview.
  final StoriesPreviewBuilder previewBuilder;

  /// Widget displayed while loading stories previews.
  final Widget previewPlaceholder;

  final EdgeInsets previewListPadding;

  /// Build the button to publish stories.
  ///
  /// Provide the [StoryType] selected and [Animation] on video record.
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  ///
  /// If you want implements your own behavior, set the [defaultBehavior] to false and
  /// use [PublisherController].
  final MakeStoryBuilder makeStoryBuilder;

  /// Button to change the [StoryType].
  final ChangeStoryTypeBuilder typeBuilder;

  /// Button to change the device's camera.
  final ChangeCameraBuilder lensBuilder;

  /// A button to take external media.
  ///
  /// Pass a valid [File] (image or video) in the callback.
  ///
  /// You can use [ImagePicker] plugin to take the file media.
  final ExternalMediaBuilder externalMediaButtonBuilder;

  /// enable/disable the default behavior of the widget built by [makeStoryBuilder].
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  final bool defaultBehavior;

  /// A button that will save the current story in the directory specified by [StoryController.pathToSave].
  ///
  /// If the path is null, the tap will be ignored.
  final Widget saveStoryButton;

  /// A button to send the [Story] to Firebase.
  ///
  /// Provides the function to send story where you can put the selected releases list
  final PublishBuilder publishBuilder;

  /// A widget to insert attachments to story like text and stickers
  ///
  /// The attachments are wrapped by [MultiGestureWidget] and can be translated, scaled and rotated
  ///
  /// To delete a specific attachment, pass a list of attachments without the [AttachmentWidget]
  /// you want to delete.
  final AddAttachmentsBuilder addAttachments;

  StoryDecoration({
    this.mediaError,
    this.typeBuilder,
    this.lensBuilder,
    this.closeButton,
    this.progressBar,
    this.titleBuilder,
    this.avatarBuilder,
    this.addAttachments,
    this.previewBuilder,
    this.publishBuilder,
    this.saveStoryButton,
    this.defaultBehavior,
    this.makeStoryBuilder,
    this.mediaPlaceholder,
    this.previewListPadding,
    this.previewPlaceholder,
    this.publishmentDateBuilder,
    this.backgroundBetweenStories,
    this.externalMediaButtonBuilder,
  });
}
