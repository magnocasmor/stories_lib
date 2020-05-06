import 'package:flutter/foundation.dart';

class StoriesSettings {
  final String userId;
  final String coverImg;
  final String username;
  final String languageCode;
  final bool sortByDescUpdate;
  final List<dynamic> releases;
  final Duration storyDuration;
  final String collectionDbName;
  final Duration storyTimeValidaty;

  StoriesSettings({
    @required this.userId,
    @required this.collectionDbName,
    this.coverImg,
    this.username,
    this.releases,
    this.languageCode = 'pt',
    this.sortByDescUpdate = true,
    this.storyDuration = const Duration(seconds: 3),
    this.storyTimeValidaty = const Duration(hours: 12),
  });
}
