import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/progress_bar_data.dart';
import '../views/story_publisher.dart';

typedef PublishStory = void Function({String caption, List<dynamic> selectedReleases});

typedef ExternalMediaCallback = Future<ExternalMediaStatus> Function(File, StoryType);

typedef StoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef MyStoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, bool, bool);

typedef TakeStoryBuilder = Widget Function(
    BuildContext, StoryType, Animation<double>, Future<void> Function(TakeStory));

typedef PublishLayerBuilder = Widget Function(BuildContext, StoryType);

typedef ResultLayerBuilder = Widget Function(BuildContext, StoryType, PublishStory);

typedef InfoLayerBuilder = Widget Function(
  BuildContext,
  ImageProvider,
  String,
  DateTime,
  List<PageData>,
  int,
  Animation<double>,
  List<Map<String, dynamic>>,
);

typedef MyInfoLayerBuilder = Widget Function(
  BuildContext,
  ImageProvider,
  String,
  DateTime,
  List<PageData>,
  int,
  Animation<double>,
  List<Map<String, dynamic>>,
  VoidCallback,
);

typedef StoryEventCallback = void Function(String);