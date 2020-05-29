import 'story.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoriesCollection {
  final String storyId;
  final String coverImg;
  final List<Story> stories;
  final DateTime lastUpdate;
  final Map<String, String> title;
  // final List<Map<String, dynamic>> releases;

  StoriesCollection({
    @required this.storyId,
    this.title,
    this.stories,
    // this.releases,
    this.coverImg,
    this.lastUpdate,
  });

  factory StoriesCollection.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;

    // List<Map<String, dynamic>> releases;
    // if (json['releases'] is List) releases = List<Map<String, dynamic>>.from(json['releases']);

    return StoriesCollection(
      // releases: releases,
      storyId: json['story_id'],
      coverImg: json['cover_img'],
      title: Map<String, String>.from(json['title']),
      lastUpdate: (json['last_update'] as Timestamp).toDate(),
      stories: (json['stories'] as List)?.map((story) => Story.fromJson(story))?.toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': this.title,
      'story_id': this.storyId,
      // 'releases': this.releases,
      'cover_img': this.coverImg,
      'last_update': this.lastUpdate.toIso8601String(),
      'stories': this.stories.map((story) => story.toJson()),
    };
  }
}
