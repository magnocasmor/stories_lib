import 'package:flutter/material.dart';

import 'stories.dart';
import 'package:stories_lib/story_view.dart';
import 'package:stories_lib/models/story_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class StoriesData {
  final _cacheDepth = 4;
  final String languageCode;
  final storyItems = <StoryItem>[];
  final _storiesIdsList = <String>[];
  final storyController = StoryController();

  StoriesData({this.languageCode});

  List<String> get storiesIdsList => _storiesIdsList;

  List<Stories> parseStoriesPreview(List<DocumentSnapshot> stories) {
    return stories.map((story) {
      final Stories storyData = _storiesFromDocument(story);

      if (storyData.file != null) {
        _storiesIdsList.add(story.documentID);

        var i = 0;
        for (var file in storyData.file) {
          if (file.filetype == 'image' && i < _cacheDepth) {
            DefaultCacheManager().getSingleFile(file.url[languageCode]);
            i += 1;
          }
        }
      }
      return storyData;
    }).toList();
  }

  void parseStories(
    DocumentSnapshot data,
    String pressedStoryId,
    int imageStoryDuration,
  ) {
    assert(pressedStoryId == data.documentID);

    final stories = _storiesFromDocument(data);

    var storyImage;

    stories.file.asMap().forEach(
      (index, storyData) {
        switch (storyData.filetype) {
          case 'text':
            storyItems.add(
              StoryItem.text(
                storyData.url[languageCode],
                Colors.purple,
                duration: Duration(seconds: imageStoryDuration),
              ),
            );
            break;
          case 'image':
            storyImage = CachedNetworkImageProvider(storyData.url[languageCode]);
            storyItems.add(
              StoryItem.pageGif(
                storyData.url[languageCode],
                controller: storyController,
                duration: Duration(seconds: imageStoryDuration),
              ),
            );
            break;
          case 'video':
            storyItems.add(
              StoryItem.pageVideo(
                storyData.url[languageCode],
                controller: storyController,
              ),
            );
            break;
          default:
        }

        // cache images inside story
        if (index < stories.file.length - 1) {
          DefaultCacheManager().getSingleFile(stories.file[index + 1].url[languageCode]);
        }
      },
    );
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
}
