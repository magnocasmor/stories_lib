import 'dart:ui';
import 'settings.dart';
import 'story_view.dart';
import 'story_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_parser.dart';

export 'settings.dart';
export 'story_view.dart';
export 'story_image.dart';
export 'story_video.dart';
export 'story_controller.dart';

class GroupedStoriesView extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final String languageCode;
  final Icon closeButtonIcon;
  final bool sortingOrderDesc;
  final String selectedStoryId;
  final int imageStoryDuration;
  final List<String> storiesIds;
  final String collectionDbName;
  final Color closeButtonBackgroundColor;
  final ProgressPosition progressPosition;
  final Color backgroundColorBetweenStories;

  GroupedStoriesView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    @required this.collectionDbName,
    this.inline,
    this.languageCode,
    this.closeButtonIcon,
    this.sortingOrderDesc,
    this.progressPosition,
    this.closeButtonBackgroundColor,
    this.backgroundColorBetweenStories,
    this.repeat = false,
    this.imageStoryDuration = 3,
  });

  @override
  _GroupedStoriesViewState createState() => _GroupedStoriesViewState();
}

class _GroupedStoriesViewState extends State<GroupedStoriesView> {
  final _firestore = Firestore.instance;
  final storyController = StoryController();

  Stream<DocumentSnapshot> get streamStories =>
      _firestore.collection(widget.collectionDbName).document(widget.selectedStoryId).snapshots();

  String _nextStoriesId(String currentStoryId, List<String> storyIds) {
    var position = storyIds.indexWhere((id) => id.startsWith(currentStoryId));

    if (position == -1 || storyIds[position] == storyIds.last) {
      return null;
    }

    return storyIds[++position];
  }

  String _previousStoriesId(String currentStoryId, List<String> storyIds) {
    var position = storyIds.indexWhere((id) => id.startsWith(currentStoryId));

    if (position == -1 || storyIds[position] == storyIds.first) {
      return null;
    }

    return storyIds[--position];
  }

  void _nextGroupedStories() {
    String storyId = _nextStoriesId(
      widget.selectedStoryId,
      widget.storiesIds,
    );
    if (storyId == null) {
      _finishStoriesView();
    } else {
      _navigateToStories(storyId);
    }
  }

  void _previousGroupedStories() {
    String storyId = _previousStoriesId(
      widget.selectedStoryId,
      widget.storiesIds,
    );
    if (storyId == null) {
      _finishStoriesView();
    } else {
      _navigateToStories(storyId);
    }
  }

  Future _navigateToStories(String storyId) {
    return Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _groupedStoriesView(
          storyId,
          widget.storiesIds,
        ),
      ),
    );
  }

  Future _finishStoriesView() {
    return Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (_) => false,
      arguments: 'back_from_stories_view',
    );
  }

  void _onStoryShow(StoryItem s) {}

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        _finishStoriesView();
        return Future.value(false);
      },
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: streamStories,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final stories = parseStories(
              storyController,
              widget.languageCode,
              snapshot.data,
              widget.imageStoryDuration,
            );

            return Dismissible(
                resizeDuration: Duration(milliseconds: 200),
                key: UniqueKey(),
                onDismissed: (DismissDirection direction) {
                  if (direction == DismissDirection.endToStart) {
                    _nextGroupedStories();
                  } else {
                    _previousGroupedStories();
                  }
                },
                child: GestureDetector(
                  child: StoryView(
                    widget.sortingOrderDesc ? stories.reversed.toList() : stories,
                    controller: storyController,
                    progressPosition: widget.progressPosition,
                    repeat: widget.repeat,
                    inline: widget.inline,
                    onStoryShow: (StoryItem s) {
                      _onStoryShow(s);
                    },
                    previousOnFirstStory: _previousGroupedStories,
                    onComplete: _nextGroupedStories,
                  ),
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy > 0) {
                      _finishStoriesView();
                    }
                  },
                ));
          },
        ),
        floatingActionButton: Align(
          alignment: Alignment(1.0, -0.84),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: FloatingActionButton(
              onPressed: () {
                _finishStoriesView();
              },
              child: widget.closeButtonIcon,
              backgroundColor: widget.closeButtonBackgroundColor,
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  GroupedStoriesView _groupedStoriesView(String storyId, List<String> storyIds) {
    return GroupedStoriesView(
      storiesIds: storyIds,
      selectedStoryId: storyId,
      collectionDbName: widget.collectionDbName,
      languageCode: widget.languageCode,
      imageStoryDuration: widget.imageStoryDuration,
      progressPosition: widget.progressPosition,
      repeat: widget.repeat,
      inline: widget.inline,
      backgroundColorBetweenStories: widget.backgroundColorBetweenStories,
      closeButtonIcon: widget.closeButtonIcon,
      closeButtonBackgroundColor: widget.closeButtonBackgroundColor,
      sortingOrderDesc: widget.sortingOrderDesc,
    );
  }
}
