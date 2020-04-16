import 'package:flutter/painting.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:stories_lib/utils/color_parser.dart';

@JsonSerializable(explicitToJson: true)
class Story {
  final String type;
  final List<String> views;
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
    return Story(
      type: json['type'],
      views: json['views'],
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
