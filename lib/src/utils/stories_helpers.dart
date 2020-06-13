import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../models/stories_collection.dart';
import '../models/story.dart';
import '../views/story_view.dart';

List<StoriesCollection> parseStoriesPreview(
    String languageCode, List<DocumentSnapshot> documents) {
  final _cacheDepth = 10;
  var i = 0;

  final owners = documents.map<StoryOwner>(
    (document) {
      return StoryOwner.fromJson(document.data["owner"]);
    },
  ).fold<List<StoryOwner>>(
    <StoryOwner>[],
    (list, owner) {
      if (!list.contains(owner)) list.add(owner);
      return list;
    },
  );

  return owners.map<StoriesCollection>((owner) {
    return ownerCollection(documents.map((document) => document.data).toList(), owner)
      ..stories.forEach(
        (story) {
          if (story.type == 'image' && i < _cacheDepth) {
            DefaultCacheManager().getSingleFile(story.media[languageCode]);
            i += 1;
          }
        },
      );
  }).toList();
}

List<StoryWrap> parseStories(
  StoriesCollection collection,
  StoryController controller,
  StoriesSettings settings,
  Widget errorWidget,
  Widget loadingWidget,
) {
  final wraps = <StoryWrap>[];

  for (Story story in collection.stories) {
    if (story.deletedAt != null) continue;

    final index = collection.stories.indexOf(story);

    if (!isInIntervalToShow(story, settings.storyTimeValidaty)) {
      continue;
    }

    if (settings.userId != collection.owner.id && !allowToSee(story.toJson(), settings)) {
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
            shown: shown,
            text: caption,
            storyId: story.id,
            duration: duration,
            backgroundColor: story.backgroundColor,
          ),
        );
        break;
      case 'image':
        // final storyImage = CachedNetworkImageProvider(media);
        wraps.add(
          StoryWrap.pageGif(
            url: media,
            shown: shown,
            caption: caption,
            storyId: story.id,
            duration: duration,
            // image: storyImage,
            controller: controller,
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
            storyId: story.id,
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
            storyId: story.id,
            controller: controller,
            errorWidget: errorWidget,
            loadingWidget: loadingWidget,
          ),
        );
        break;
      default:
    }

    if (index < collection.stories.length - 1 && collection.stories[index + 1].media != null) {
      final next = collection.stories[index + 1];

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
        s.deletedAt == null &&
        (s.views?.every((v) => v["user_id"] != userId) ?? true),
  );
}

bool isViewed(Story story, String userId) {
  return story.views?.any((v) => v["user_id"] == userId) ?? false;
}

bool isInIntervalToShow(Story story, Duration storyValidaty) {
  return story.date.isAfter(DateTime.now().subtract(storyValidaty));
}

StoriesCollection ownerCollection(List<Map<String, dynamic>> datas, StoryOwner owner) {
  final stories = datas
      .where((data) => data["owner"]["id"] == owner.id)
      .map<Story>((story) => Story.fromJson(story))
      .toList();

  return StoriesCollection(
    owner: owner,
    stories: stories,
    lastUpdate: stories.first.date,
  );
}
