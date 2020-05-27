import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stories_lib/views/story_publisher.dart';
import 'package:stories_lib/components/attachment_widget.dart';

import '../views/story_view.dart';

typedef StoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef ExternalMediaCallback = Future<ExternalMediaStatus> Function(File, StoryType);

typedef MyStoriesPreviewBuilder = Widget Function(BuildContext, ImageProvider, bool, bool);

typedef TakeStoryBuilder = Widget Function(StoryType, Animation<double>, void Function(StoryType));

typedef PublishLayerBuilder = Widget Function(BuildContext, StoryType, ExternalMediaCallback);

typedef ResultLayerBuilder = Widget Function(BuildContext, File,
    void Function(List<AttachmentWidget>), void Function({List<dynamic> selectedReleases}));

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

typedef AddAttachment = void Function(List<AttachmentWidget>);

typedef PublishStory = void Function({List<dynamic> selectedReleases});