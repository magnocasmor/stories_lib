import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:stories_lib/models/story.dart';
import 'package:stories_lib/views/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/models/stories_collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

List<String> storyIds(List<DocumentSnapshot> stories) {
  return stories
      .where((story) => storiesCollectionFromDocument(story).stories != null)
      .map((story) => story.documentID)
      .toList();
}

List<StoriesCollection> parseStoriesPreview(String languageCode, List<DocumentSnapshot> stories) {
  final _cacheDepth = 4;

  return stories.map((story) {
    final StoriesCollection storyData = storiesCollectionFromDocument(story);

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
  StoriesSettings settings,
  Widget mediaErrorWidget,
  Widget mediaLoadingWidget,
) {
  final storiesCollection = storiesCollectionFromDocument(data);

  final storyItems = <StoryItem>[];

  storiesCollection.stories.asMap().forEach(
    (index, storyData) {
      if (!isInIntervalToShow(storyData, settings.storyTimeValidaty)) return;

      if (settings.userId != storiesCollection.storyId &&
          !checkRelease(storyData.toJson(), settings)) return;

      final storyId = storyData.id;
      final storyPreviewImg = storiesCollection.coverImg;
      final storyTitle = storiesCollection.title[settings.languageCode];
      final duration = settings.storyDuration;
      final media = storyData.media != null ? storyData.media[settings.languageCode] : null;
      final caption = storyData.caption != null ? storyData.caption[settings.languageCode] : null;

      final _shown = isViewed(storyData, settings.userId);

      switch (storyData.type) {
        case 'text':
          storyItems.add(
            StoryItem.text(
              text: caption,
              shown: _shown,
              storyId: storyId,
              duration: duration,
              storyTitle: storyTitle,
              postDate: storyData.date,
              storyPreviewImg: storyPreviewImg,
              backgroundColor: storyData.backgroundColor,
            ),
          );
          break;
        case 'image':
          final storyImage = CachedNetworkImageProvider(media);
          storyItems.add(
            StoryItem.pageImage(
              shown: _shown,
              storyId: storyId,
              caption: caption,
              image: storyImage,
              duration: duration,
              storyTitle: storyTitle,
              postDate: storyData.date,
              storyPreviewImg: storyPreviewImg,
            ),
          );
          break;
        case 'gif':
          storyItems.add(
            StoryItem.pageGif(
              url: media,
              shown: _shown,
              storyId: storyId,
              caption: caption,
              duration: duration,
              storyTitle: storyTitle,
              postDate: storyData.date,
              controller: storyController,
              storyPreviewImg: storyPreviewImg,
              mediaErrorWidget: mediaErrorWidget,
              mediaLoadingWidget: mediaLoadingWidget,
            ),
          );
          break;
        case 'video':
          storyItems.add(
            StoryItem.pageVideo(
              url: media,
              shown: _shown,
              storyId: storyId,
              caption: caption,
              storyTitle: storyTitle,
              postDate: storyData.date,
              controller: storyController,
              storyPreviewImg: storyPreviewImg,
              mediaErrorWidget: mediaErrorWidget,
              mediaLoadingWidget: mediaLoadingWidget,
            ),
          );
          break;
        default:
      }

      if (index < storiesCollection.stories.length - 1 &&
          storiesCollection.stories[index + 1].media != null) {
        DefaultCacheManager()
            .getSingleFile(storiesCollection.stories[index + 1].media[settings.languageCode]);
      }
    },
  );
  return storyItems;
}

bool checkRelease(Map storyData, StoriesSettings settings) {
  return storyData["releases"] != null &&
      storyData["releases"].any((release) {
        if (release is Map)
          return settings.releases.any((release2) => mapEquals(release, release2));
        else if (release is List)
          return settings.releases.any((release2) => listEquals(release, release2));
        else
          return settings.releases.contains(release);
      });
}

bool hasNewStories(String userId, StoriesCollection collection, Duration storyValidaty) {
  return collection.stories.any(
    (s) =>
        isInIntervalToShow(s, storyValidaty) &&
        (s.views?.every((v) => v["user_info"] != userId) ?? true),
  );
}

bool isViewed(Story story, String userId) {
  return story.views?.any((v) => v["user_info"] == userId) ?? false;
}

bool isInIntervalToShow(Story story, Duration storyValidaty) {
  return story.date.isAfter(DateTime.now().subtract(storyValidaty));
}

StoriesCollection storiesCollectionFromDocument(DocumentSnapshot document) =>
    StoriesCollection.fromJson(document.data..addAll({"story_id": document.documentID}));
