import 'story_data.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'stories.g.dart';

@JsonSerializable(explicitToJson: true)
class Stories {
  final DateTime date;
  final String storyId;
  final String previewImage;
  final List<StoryData> file;
  final Map<String, String> previewTitle;

  Stories({
    @required this.storyId,
    this.date,
    this.file,
    this.previewImage,
    this.previewTitle,
  });

  factory Stories.fromJson(Map<String, dynamic> json) => _$StoriesFromJson(json);
  
  Map<String, dynamic> toJson() => _$StoriesToJson(this);
}
