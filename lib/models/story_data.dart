import 'package:json_annotation/json_annotation.dart';

part 'story_data.g.dart';

@JsonSerializable(explicitToJson: true)
class StoryData {
  final String filetype;
  final Map<String, String> data;
  final Map<String, String> fileTitle;

  StoryData({
    this.data,
    this.filetype,
    this.fileTitle,
  });

  factory StoryData.fromJson(Map<String, dynamic> json) => _$StoryDataFromJson(json);
  
  Map<String, dynamic> toJson() => _$StoryDataToJson(this);
}
