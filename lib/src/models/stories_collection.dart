import 'package:equatable/equatable.dart';

import 'story.dart';

class StoriesCollection {
  final StoryOwner owner;
  final DateTime lastUpdate;
  final List<Story> stories;

  StoriesCollection({
    this.owner,
    this.lastUpdate,
    this.stories,
  });
}

class StoryOwner extends Equatable {
  final String id;
  final String coverImg;
  final Map<String, dynamic> title;

  StoryOwner({
    this.id,
    this.title,
    this.coverImg,
  });

  factory StoryOwner.fromJson(dynamic json) {
    if (json == null || json.isEmpty) return null;
    return StoryOwner(
      id: json['id'],
      coverImg: json['cover_img'],
      title: json['title'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': this.id,
      'title': this.title,
      'cover_img': this.coverImg,
    };
  }

  @override
  List<Object> get props => [
        this.id,
        this.title,
        this.coverImg,
      ];
}
