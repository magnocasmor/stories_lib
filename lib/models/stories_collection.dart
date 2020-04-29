import 'story.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable(explicitToJson: true)
class StoriesCollection {
  final String storyId;
  final String coverImg;
  final List<Story> stories;
  final DateTime lastUpdate;
  final Map<String, String> title;

  StoriesCollection({
    @required this.storyId,
    this.lastUpdate,
    this.stories,
    this.coverImg,
    this.title,
  });

  factory StoriesCollection.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;
    return StoriesCollection(
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
      'cover_img': this.coverImg,
      'last_update': this.lastUpdate.toIso8601String(),
      'stories': this.stories.map((story) => story.toJson()),
    };
  }
}
