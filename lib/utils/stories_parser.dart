
import 'package:flutter/material.dart';
import 'package:stories_lib/story_view.dart';
import 'package:stories_lib/models/stories.dart';
import 'package:stories_lib/models/story_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

List<String> storyIds(List<DocumentSnapshot> stories) {
  return stories
      .where((story) => _storiesFromDocument(story).file != null)
      .map((story) => story.documentID)
      .toList();
}

List<Stories> parseStoriesPreview(String languageCode, List<DocumentSnapshot> stories) {
  final _cacheDepth = 4;

  return stories.map((story) {
    final Stories storyData = _storiesFromDocument(story);

    if (storyData.file != null) {
      var i = 0;
      for (var file in storyData.file) {
        if (file.filetype == 'image' && i < _cacheDepth) {
          DefaultCacheManager().getSingleFile(file.data[languageCode]);
          i += 1;
        }
      }
    }
    return storyData;
  }).toList();
}

List<StoryItem> parseStories(
  String languageCode,
  DocumentSnapshot data,
  int storyDuration,
) {
  final stories = _storiesFromDocument(data);

  final storyItems = <StoryItem>[];

  final storyController = StoryController();

  stories.file.asMap().forEach(
    (index, storyData) {
      switch (storyData.filetype) {
        case 'text':
          storyItems.add(
            StoryItem.text(
              storyData.data[languageCode],
              Colors.purple,
              duration: Duration(seconds: storyDuration),
            ),
          );
          break;
        case 'image':
          final storyImage = CachedNetworkImageProvider(storyData.data[languageCode]);
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
              storyData.data[languageCode],
              controller: storyController,
              duration: Duration(seconds: storyDuration),
            ),
          );
          break;
        case 'video':
          storyItems.add(
            StoryItem.pageVideo(
              storyData.data[languageCode],
              controller: storyController,
            ),
          );
          break;
        default:
      }

      // cache images inside story
      if (index < stories.file.length - 1) {
        DefaultCacheManager().getSingleFile(stories.file[index + 1].data[languageCode]);
      }
    },
  );
  return storyItems;
}

Stories _storiesFromDocument(DocumentSnapshot document) => Stories(
      storyId: document.documentID,
      date: DateTime.fromMillisecondsSinceEpoch(document.data['date'].seconds),
      file: document.data['file']?.map<StoryData>((e) => StoryData.fromJson(e))?.toList(),
      previewImage: document.data['previewImage'],
      previewTitle: (document.data['previewTitle'] as Map<String, dynamic>)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );
