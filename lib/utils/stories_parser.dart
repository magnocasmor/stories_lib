import 'package:flutter/material.dart';
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
  StoryController storyController,
  String languageCode,
  DocumentSnapshot data,
  int storyDuration,
) {
  final storiesCollection = _storiesCollectionFromDocument(data);

  final storyItems = <StoryItem>[];

  storiesCollection.stories.asMap().forEach(
    (index, storyData) {
      switch (storyData.type) {
        case 'text':
          storyItems.add(
            StoryItem.text(
              storyData.caption[languageCode],
              storyData.backgroundColor ?? Colors.black,
              duration: Duration(seconds: storyDuration),
            ),
          );
          break;
        case 'image':
          final storyImage = CachedNetworkImageProvider(storyData.media[languageCode]);
          storyItems.add(
            StoryItem.pageImage(
              storyImage,
              duration: Duration(seconds: storyDuration),
            ),
          );
          break;
        case 'gif':
          storyItems.add(
            StoryItem.pageGif(
              storyData.media[languageCode],
              controller: storyController,
              duration: Duration(seconds: storyDuration),
            ),
          );
          break;
        case 'video':
          storyItems.add(
            StoryItem.pageVideo(
              storyData.media[languageCode],
              controller: storyController,
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

StoriesCollection _storiesCollectionFromDocument(DocumentSnapshot document) =>
    StoriesCollection.fromJson(document.data..addAll({"story_id": document.documentID}));
