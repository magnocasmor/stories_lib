import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../views/story_publisher.dart';

/// A set of configurations that will configure the library operation.
class StoriesSettings {
  /// Indicates if repeat all stories collection.
  ///
  /// Default is false.
  final bool repeat;

  /// Indicate if the stories is fullscreen or inline inside a list.
  ///
  /// Default is false (fullscreen).
  final bool inline;

  /// The user id to set story document, set view etc.
  ///
  /// Can't be null or empty.
  final String userId;

  /// The user cover image.
  final String coverImg;

  /// The name set in document "title".
  final String username;

  /// Media, caption and title can be separated according to the language.
  final String languageCode;

  /// Sort the [StoryView]s in descrescent order.
  final bool sortByDesc;

  /// A release array that will filter the permission to see stories and
  /// list the possible target audience to user publishment.
  ///
  /// If this is empty, then all user can see the user's publishments.
  final List<dynamic> releases;

  /// Story view [Duration].
  ///
  /// This [Duration] is set to all [StoryType] except [StoryType.video].
  /// To set [Duration] for [StoryType.video], see [videoDuration].
  ///
  /// Default is 5 seconds.
  final Duration storyDuration;

  /// Story view [Duration] to type [StoryType.video].
  ///
  /// To set [Duration] for other [StoryType]s, see [storyDuration].
  ///
  /// Default is 10 seconds.
  final Duration videoDuration;

  /// Max file size (in MB) to publish story.
  ///
  /// When this limit is exceeded, will throw [ExceededSizeException].
  ///
  /// Default is 5 MB.
  final int maxFileSize;

  /// The image quality to compress in [FlutterImageCompress].
  ///
  /// Default is 80.
  final int storyQuality;

  /// The stories database path.
  ///
  /// This can't be null or empty
  final String collectionDbPath;

  /// The validaty to see the stories.
  ///
  /// If the difference between the [DateTime.now()] and [StoriesCollection.lastUpdate]
  /// is less than [storyTimeValidaty], then user can see the stories.
  final Duration storyTimeValidaty;

  StoriesSettings({
    @required this.userId,
    @required this.collectionDbPath,
    this.coverImg,
    this.username,
    this.repeat = false,
    this.inline = false,
    this.maxFileSize = 5,
    this.storyQuality = 80,
    this.sortByDesc = true,
    this.languageCode = 'pt',
    this.releases = const [],
    this.storyDuration = const Duration(seconds: 5),
    this.videoDuration = const Duration(seconds: 10),
    this.storyTimeValidaty = const Duration(hours: 12),
  })  : assert(userId != null),
        assert(releases != null),
        assert(languageCode != null),
        assert(storyDuration != null),
        assert(videoDuration != null),
        assert(collectionDbPath != null),
        assert(storyTimeValidaty != null);
}
