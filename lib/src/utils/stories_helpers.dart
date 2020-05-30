import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../models/stories_collection.dart';
import '../models/story.dart';
import '../views/story_view.dart';

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

List<StoryWrap> parseStories(
  DocumentSnapshot document,
  StoryController controller,
  StoriesSettings settings,
  Widget errorWidget,
  Widget loadingWidget,
) {
  final storiesCollection = storiesCollectionFromDocument(document);

  final wraps = <StoryWrap>[];

  for (Story story in storiesCollection.stories) {
    final index = storiesCollection.stories.indexOf(story);

    if (!isInIntervalToShow(story, settings.storyTimeValidaty)) {
      continue;
    }

    if (settings.userId != storiesCollection.storyId && !allowToSee(story.toJson(), settings)) {
      continue;
    }

    final duration = settings.storyDuration;
    final shown = isViewed(story, settings.userId);
    final media = story.media != null ? story.media[settings.languageCode] : null;
    final caption = story.caption != null ? story.caption[settings.languageCode] : null;

    switch (story.type) {
      case 'text':
        wraps.add(
          StoryWrap.text(
            text: caption,
            shown: shown,
            duration: duration,
            backgroundColor: story.backgroundColor,
          ),
        );
        break;
      case 'image':
        // final storyImage = CachedNetworkImageProvider(media);
        wraps.add(
          StoryWrap.pageGif(
            shown: shown,
            caption: caption,
            url: media,
            duration: duration,
            // image: storyImage,
            errorWidget: errorWidget,
            loadingWidget: loadingWidget,
          ),
        );
        break;
      case 'gif':
        wraps.add(
          StoryWrap.pageGif(
            url: media,
            shown: shown,
            caption: caption,
            duration: duration,
            controller: controller,
            errorWidget: errorWidget,
            loadingWidget: loadingWidget,
          ),
        );
        break;
      case 'video':
        wraps.add(
          StoryWrap.pageVideo(
            url: media,
            shown: shown,
            caption: caption,
            controller: controller,
            errorWidget: errorWidget,
            loadingWidget: loadingWidget,
          ),
        );
        break;
      default:
    }

    if (index < storiesCollection.stories.length - 1 &&
        storiesCollection.stories[index + 1].media != null) {
      final next = storiesCollection.stories[index + 1];

      DefaultCacheManager().getSingleFile(next.media[settings.languageCode]);
    }
  }

  return wraps;
}

bool allowToSee(Map storyData, StoriesSettings settings) {
  return storyData["releases"] == null ||
      storyData["releases"].isEmpty ||
      storyData["releases"].any(
        (release) {
          if (release is Map)
            return settings.releases.any((myRelease) => mapEquals(release, myRelease));
          else if (release is List)
            return settings.releases.any((myRelease) => listEquals(release, myRelease));
          else
            return settings.releases.contains(release);
        },
      );
}

bool hasNewStories(String userId, StoriesCollection collection, Duration storyValidaty) {
  return collection.stories.any(
    (s) =>
        isInIntervalToShow(s, storyValidaty) &&
        (s.views?.every((v) => v["user_id"] != userId) ?? true),
  );
}

bool isViewed(Story story, String userId) {
  return story.views?.any((v) => v["user_id"] == userId) ?? false;
}

bool isInIntervalToShow(Story story, Duration storyValidaty) {
  return story.date.isAfter(DateTime.now().subtract(storyValidaty));
}

StoriesCollection storiesCollectionFromDocument(DocumentSnapshot document) {
  return StoriesCollection.fromJson(document.data..addAll({"story_id": document.documentID}));
}
