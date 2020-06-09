import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../utils/color_parser.dart';

class Story {
  final String id;
  final String type;
  final DateTime date;
  final DateTime deletedAt;
  final Color backgroundColor;
  final List<dynamic> releases;
  final Map<String, String> media;
  final Map<String, String> caption;
  final List<Map<String, dynamic>> views;

  Story({
    @required this.id,
    this.type,
    this.date,
    this.media,
    this.views,
    this.caption,
    this.releases,
    this.deletedAt,
    this.backgroundColor,
  });

  factory Story.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;

    List<Map<String, dynamic>> views;

    if (json['views'] is List) views = List<Map<String, dynamic>>.from(json['views']);

    List<dynamic> releases;
    if (json['releases'] is List) releases = List.from(json['releases']);

    return Story(
      views: views,
      id: json['id'],
      type: json['type'],
      releases: releases,
      date: (json['date'] as Timestamp).toDate(),
      deletedAt: (json['deleted_at'] as Timestamp)?.toDate(),
      backgroundColor: stringToColor(json['background_color']),
      media: json['media'] != null ? Map<String, String>.from(json['media']) : null,
      caption: json['caption'] != null ? Map<String, String>.from(json['caption']) : null,
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
      'date': this.date.toIso8601String(),
      'background_color': this.backgroundColor,
      'deleted_at': this.deletedAt?.toIso8601String(),
    };
  }
}
