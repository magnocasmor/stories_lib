import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class StoriesSettings {
  final String userId;

  final String coverImg;

  final String username;

  final String languageCode;

  final bool sortByDescUpdate;

  final List<dynamic> releases;

  final Duration storyDuration;

  final Duration videoDuration;

  final String collectionDbName;

  final Duration storyTimeValidaty;

  final bool repeat;

  final bool inline;

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
    this.storyDuration = const Duration(seconds: 3),
    this.videoDuration = const Duration(seconds: 10),
    this.storyTimeValidaty = const Duration(hours: 12),
  });
}
