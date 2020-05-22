import 'package:flutter/material.dart';

import '../views/story_view.dart';

typedef PublisherBuilder = Widget Function(ImageProvider, String);

typedef PostDateBuilder = Widget Function(DateTime);

typedef ProgressBarBuilder = Widget Function(List<PageData>, int, Animation<double>);

typedef ViewersBuilder = Widget Function(List<Map<String, dynamic>> viewers);

/// A set of widgets, builders and styles to decorate story's view.
///
/// These widgets will be put on [Stack] with the story media view.
/// So, use [Align] or [Positioned] to set the widgets in right place.
class StoryDecoration {
  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  /// Widget to place on media error.
  final Widget mediaErrorWidget;

  /// Widget to place while media load.
  final Widget mediaLoadingWidget;

  final Color backgroundBetweenStories;

  /// Build the [StorySettings.coverImg] and [StorySettings.title] of who published.
  final PublisherBuilder publisherBuilder;

  final PostDateBuilder postDateBuilder;

  /// A builder to construct a progressbar by provide the current story index and the animation
  /// used to animate [StoryCollection]
  final ProgressBarBuilder progressBar;

  StoryDecoration({
    this.closeButton,
    this.progressBar,
    this.postDateBuilder,
    this.mediaErrorWidget,
    this.publisherBuilder,
    this.mediaLoadingWidget,
    this.backgroundBetweenStories,
  });
}

/// A set of widgets, builders and styles to decorate user's story.
///
/// These widgets will be put on [Stack] with the story media view.
/// So, use [Align] or [Positioned] to set the widgets in right place.
class MyStoryDecoration extends StoryDecoration {
  /// Provide the viewers of the story showed
  final ViewersBuilder viewersBuilder;

  MyStoryDecoration({
    Widget closeButton,
    this.viewersBuilder,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    Color backgroundBetweenStories,
    ProgressBarBuilder progressBar,
    PostDateBuilder postDateBuilder,
    PublisherBuilder publisherBuilder,
  }) : super(
          closeButton: closeButton,
          progressBar: progressBar,
          postDateBuilder: postDateBuilder,
          mediaErrorWidget: mediaErrorWidget,
          publisherBuilder: publisherBuilder,
          mediaLoadingWidget: mediaLoadingWidget,
          backgroundBetweenStories: backgroundBetweenStories,
        );

  factory MyStoryDecoration.from({
    StoryDecoration decoration,
    ViewersBuilder viewersBuilder,
  }) {
    assert(decoration != null);

    return MyStoryDecoration(
      viewersBuilder: viewersBuilder,
      closeButton: decoration.closeButton,
      progressBar: decoration.progressBar,
      postDateBuilder: decoration.postDateBuilder,
      mediaErrorWidget: decoration.mediaErrorWidget,
      publisherBuilder: decoration.publisherBuilder,
      mediaLoadingWidget: decoration.mediaLoadingWidget,
      backgroundBetweenStories: decoration.backgroundBetweenStories,
    );
  }
}
