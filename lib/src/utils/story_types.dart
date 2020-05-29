import 'dart:io';
import 'package:flutter/material.dart';

import '../views/story_publisher.dart';
import '../views/story_view.dart';

typedef PublishStory = void Function({String caption, List<dynamic> selectedReleases});

typedef ExternalMediaCallback = Future<ExternalMediaStatus> Function(File, StoryType);

typedef StoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef MyStoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, bool, bool);

typedef TakeStoryBuilder = Widget Function(StoryType, Animation<double>, void Function(StoryType));

typedef PublishLayerBuilder = Widget Function(BuildContext, StoryType);

typedef ResultLayerBuilder = Widget Function(BuildContext, PublishStory);

typedef InfoLayerBuilder = Widget Function(
  ImageProvider,
  String,
  DateTime,
  List<PageData>,
  int,
  Animation<double>,
  List<Map<String, dynamic>>,
);

typedef MyInfoLayerBuilder = Widget Function(
  ImageProvider,
  String,
  DateTime,
  List<PageData>,
  int,
  Animation<double>,
  List<Map<String, dynamic>>,
  VoidCallback,
);
