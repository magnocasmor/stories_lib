import 'story.dart';

class StoriesCollectionV2 {
  final StoryOwner owner;
  final DateTime lastUpdate;
  final List<StoryV2> stories;

  StoriesCollectionV2({
    this.owner,
    this.lastUpdate,
    this.stories,
  });
}

class StoryOwner {
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
}
