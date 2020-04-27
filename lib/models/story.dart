import 'package:flutter/painting.dart';
import 'package:stories_lib/utils/color_parser.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable(explicitToJson: true)
class Story {
  final String type;
  final List<Map> views;
  final Color backgroundColor;
  final Map<String, String> media;
  final Map<String, String> caption;

  Story({
    this.type,
    this.media,
    this.views,
    this.caption,
    this.backgroundColor,
  });

  factory Story.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;

    List<Map> views;

    if (json['views'] is List) views = List<Map>.from(json['views']);

    return Story(
      type: json['type'],
      views: views,
      backgroundColor: stringToColor(json['background_color']),
      media: json['media'] != null ? Map<String, String>.from(json['media']) : null,
      caption: json['caption'] != null ? Map<String, String>.from(json['caption']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.type,
      'views': this.views,
      'media': this.media,
      'caption': this.caption,
      'background_color': this.backgroundColor,
    };
  }
}
