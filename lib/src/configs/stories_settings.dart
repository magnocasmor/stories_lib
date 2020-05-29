import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../views/story_publisher.dart';

class StoriesSettings {
  final bool repeat;

  final bool inline;

  final String userId;

  final String coverImg;

  final String username;

  final StoryType initialType;

  final String languageCode;

  final bool sortByDescUpdate;

  final List<dynamic> releases;

  final Duration storyDuration;

  final Duration videoDuration;

  final String collectionDbName;

  final Duration storyTimeValidaty;

  final CameraLensDirection initialCamera;

  StoriesSettings({
    @required this.userId,
    @required this.collectionDbName,
    this.coverImg,
    this.username,
    this.releases,
    this.repeat = false,
    this.inline = false,
    this.languageCode = 'pt',
    this.sortByDescUpdate = true,
    this.initialType = StoryType.image,
    this.initialCamera = CameraLensDirection.front,
    this.storyDuration = const Duration(seconds: 3),
    this.videoDuration = const Duration(seconds: 10),
    this.storyTimeValidaty = const Duration(hours: 12),
  });
}
