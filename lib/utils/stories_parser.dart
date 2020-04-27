import 'package:stories_lib/models/story.dart';
import 'package:stories_lib/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/models/stories_collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

List<String> storyIds(List<DocumentSnapshot> stories) {
  return stories
      .where((story) => _storiesCollectionFromDocument(story).stories != null)
      .map((story) => story.documentID)
      .toList();
}

List<StoriesCollection> parseStoriesPreview(String languageCode, List<DocumentSnapshot> stories) {
  final _cacheDepth = 4;

  return stories.map((story) {
    final StoriesCollection storyData = _storiesCollectionFromDocument(story);

    if (storyData.stories != null) {
      var i = 0;
      for (var file in storyData.stories) {
        if (file.type == 'image' && i < _cacheDepth) {
          DefaultCacheManager().getSingleFile(file.media[languageCode]);
          i += 1;
        }
      }
    }
    return storyData;
  }).toList();
}

List<StoryItem> parseStories(
  DocumentSnapshot data,
  StoryController storyController,
  String userId,
  String languageCode,
  int storyDuration,
) {
  final storiesCollection = _storiesCollectionFromDocument(data);

  final storyItems = <StoryItem>[];

  storiesCollection.stories.asMap().forEach(
    (index, storyData) {
      final duration = Duration(seconds: storyDuration);
      final media = storyData.media != null ? storyData.media[languageCode] : null;
      final caption = storyData.caption != null ? storyData.caption[languageCode] : null;

      final _shown = isViewed(storyData, userId);

      switch (storyData.type) {
        case 'text':
          storyItems.add(
            StoryItem.text(
              text: caption,
              duration: duration,
              backgroundColor: storyData.backgroundColor,
              shown: _shown,
            ),
          );
          break;
        case 'image':
          final storyImage = CachedNetworkImageProvider(media);
          storyItems.add(
            StoryItem.pageImage(
              caption: caption,
              image: storyImage,
              duration: duration,
              shown: _shown,
            ),
          );
          break;
        case 'gif':
          storyItems.add(
            StoryItem.pageGif(
              url: media,
              caption: caption,
              duration: duration,
              controller: storyController,
              shown: _shown,
            ),
          );
          break;
        case 'video':
          storyItems.add(
            StoryItem.pageVideo(
              url: media,
              caption: caption,
              controller: storyController,
              shown: _shown,
            ),
          );
          break;
        default:
      }

      if (index < storiesCollection.stories.length - 1 &&
          storiesCollection.stories[index + 1].media != null) {
        DefaultCacheManager()
            .getSingleFile(storiesCollection.stories[index + 1].media[languageCode]);
      }
    },
  );
  return storyItems;
}

bool isViewed(Story story, String userId) {
  return story.views?.any((v) => v["user_info"] == userId) ?? false;
}

StoriesCollection _storiesCollectionFromDocument(DocumentSnapshot document) =>
    StoriesCollection.fromJson(document.data..addAll({"story_id": document.documentID}));
