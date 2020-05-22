import 'package:flutter/material.dart';

typedef StoryPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef StoryPublisherPreviewBuilder = Widget Function(
  BuildContext context,
  ImageProvider coverImg,
  bool hasStories,
  bool hasNewStories,
);

class PreviewDecoration {
  /// Build a preview of a particular stories collection.
  final StoryPreviewBuilder storiesPreview;

  /// Build the preview of the user stories collection.
  final StoryPublisherPreviewBuilder myStoriesPreview;

  /// Build a placeholder while loading stories previews.
  final Widget previewPlaceholder;

  /// Indicate if [previewPlaceholder] must be set to [myStoriesPreview] too.
  final bool setPlaceholderToMyStories;

  final EdgeInsets previewListPadding;

  PreviewDecoration({
    @required this.storiesPreview,
    this.myStoriesPreview,
    this.previewPlaceholder,
    this.setPlaceholderToMyStories = false,
    this.previewListPadding = const EdgeInsets.all(8.0),
  });
}
