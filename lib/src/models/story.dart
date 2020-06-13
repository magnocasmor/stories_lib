import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart';
import 'package:stories_lib/src/models/stories_collection.dart';

class Story {
  final String id;
  final String type;
  final DateTime date;
  final StoryOwner owner;
  final DateTime deletedAt;
  final Color backgroundColor;
  final List<dynamic> releases;
  final Map<String, String> media;
  final Map<String, String> caption;
  final List<Map<String, dynamic>> views;

  Story({
    this.id,
    this.type,
    this.date,
    this.deletedAt,
    this.backgroundColor,
    this.releases,
    this.media,
    this.owner,
    this.caption,
    this.views,
  });

  factory Story.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;
    return Story(
      id: json['id'],
      type: json['type'],
      releases: json['releases'] as List,
      owner: StoryOwner.fromJson(json["owner"]),
      backgroundColor: json['background_color'],
      date: (json['date'] as Timestamp).toDate(),
      media: Map<String, String>.from(json['media']),
      deletedAt: (json['deleted_at'] as Timestamp)?.toDate(),
      caption: json['caption'] != null ? Map<String, String>.from(json['caption']) : null,
      views: json['views'] != null ? List<Map<String, dynamic>>.from(json['views']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': this.id,
      'type': this.type,
      'views': this.views,
      'media': this.media,
      'caption': this.caption,
      'releases': this.releases,
      'owner': this.owner.toJson(),
      'date': this.date.toIso8601String(),
      'background_color': this.backgroundColor,
      'deleted_at': this.deletedAt?.toIso8601String(),
    };
  }
}
