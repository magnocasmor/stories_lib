import 'package:flutter/foundation.dart';

class StoriesSettings {
  final String userId;
  final String coverImg;
  final String username;
  final String languageCode;
  final bool sortByDescUpdate;
  final Duration storyDuration;
  final String collectionDbName;
  final Duration storyTimeValidaty;
  final List<Map<String, dynamic>> releases;

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
