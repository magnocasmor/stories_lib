import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:stories_lib/utils/color_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String type;
  final DateTime date;
  final List<Map> views;
  final Color backgroundColor;
  final Map<String, String> media;
  final Map<String, String> caption;
  final List<dynamic> releases;

  Story({
    @required this.id,
    this.type,
    this.date,
    this.media,
    this.views,
    this.caption,
    this.releases,
    this.backgroundColor,
  });

  factory Story.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;

    List<Map> views;

    if (json['views'] is List) views = List<Map>.from(json['views']);

    List<dynamic> releases;
    if (json['releases'] is List) releases = List.from(json['releases']);

    return Story(
      views: views,
      id: json['id'],
      type: json['type'],
      releases: releases,
      date: (json['date'] as Timestamp).toDate(),
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
    };
  }
}
