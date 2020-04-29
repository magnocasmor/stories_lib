import 'dart:ui';
import 'story_view.dart';
import 'story_controller.dart';
import 'package:flutter/material.dart';
import 'package:stories_lib/stories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_parser.dart';

export 'settings.dart';
export 'story_view.dart';
export 'story_image.dart';
export 'story_video.dart';
export 'story_controller.dart';

enum _StoriesDirection { next, previous }

class StoriesCollectionView extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final String userId;
  final Widget closeButton;
  final String languageCode;
  final bool sortingOrderDesc;
  final String selectedStoryId;
  final Duration storyDuration;
  final List<String> storiesIds;
  final String collectionDbName;
  final Alignment closeButtonPosition;
  final StoryHeaderBuilder progressBuilder;
  final StoryHeaderPosition headerPosition;
  final Color backgroundColorBetweenStories;

  StoriesCollectionView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    @required this.collectionDbName,
    this.userId,
    this.inline,
    this.closeButton,
    this.languageCode,
    this.progressBuilder,
    this.headerPosition,
    this.closeButtonPosition,
    this.backgroundColorBetweenStories,
    this.repeat = false,
    this.sortingOrderDesc = false,
    this.storyDuration = const Duration(seconds: 3),
  });

  @override
  _StoriesCollectionViewState createState() => _StoriesCollectionViewState();
}

class _StoriesCollectionViewState extends State<StoriesCollectionView> {
  final _firestore = Firestore.instance;
  final storyController = StoryController();
  PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: indexOfStory(widget.selectedStoryId));
  }

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
        backgroundColor: widget.backgroundColorBetweenStories,
        body: SafeArea(
          bottom: false,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.storiesIds.length,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Stack(
                children: <Widget>[
                  FutureBuilder<DocumentSnapshot>(
                    future: streamStories(widget.storiesIds[index]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final storyData = snapshot.data;

                      final stories = parseStories(
                        storyData,
                        storyController,
                        widget.userId,
                        widget.languageCode,
                        widget.storyDuration,
                      );

                      return GestureDetector(
                        child: StoryView(
                          storyItems: widget.sortingOrderDesc ? stories.reversed.toList() : stories,
                          controller: storyController,
                          repeat: widget.repeat,
                          inline: widget.inline,
                          headerBuilder: widget.progressBuilder,
                          headerPosition: widget.headerPosition,
                          onStoryShow: (StoryItem item) {
                            storyData.reference.get().then(
                              (ds) async {
                                final doc = ds.data;
                                final story =
                                    doc["stories"].singleWhere((s) => s['id'] == item.storyId);
                                final views = story["views"];
                                final currentView = {
                                  "user_info": widget.userId,
                                  "date": DateTime.now(),
                                };

                                if (views is List) {
                                  final hasView = views.any(
                                    (v) => v["user_info"] == widget.userId,
                                  );

                                  if (!hasView) {
                                    views.add(currentView);
                                  }
                                } else {
                                  story["views"] = [currentView];
                                }

                                ds.reference.updateData(doc);
                              },
                            );
                          },
                          previousOnFirstStory: _previousGroupedStories,
                          onComplete: _nextGroupedStories,
                        ),
                        onVerticalDragUpdate: (details) {
                          if (details.delta.dy > 0) {
                            _finishStoriesView();
                          }
                        },
                        onHorizontalDragUpdate: (details) {
                          if (details.delta.dx > 0) {
                            _previousGroupedStories();
                          } else {
                            _nextGroupedStories();
                          }
                        },
                      );
                    },
                  ),
                  Align(
                    alignment: widget.closeButtonPosition,
                    child: GestureDetector(
                      onTap: _finishStoriesView,
                      child: widget.closeButton,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<DocumentSnapshot> streamStories(String storyId) => _firestore
      .collection(widget.collectionDbName)
      .orderBy('last_update', descending: widget.sortingOrderDesc)
      .reference()
      .document(storyId)
      .get();

  void _nextGroupedStories() {
    if (_pageController.page.toInt() != indexOfStory(widget.storiesIds.last)) {
      _navigateToStories(_StoriesDirection.next);
    } else {
      _finishStoriesView();
    }
  }

  void _previousGroupedStories() {
    if (_pageController.page.toInt() != indexOfStory(widget.storiesIds.first)) {
      _navigateToStories(_StoriesDirection.previous);
    }
  }

  Future _navigateToStories(_StoriesDirection direction) {
    storyController.stop();

    if (direction == _StoriesDirection.next)
      return _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
    else {
      return _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
    }
  }

  bool _finishStoriesView() {
    storyController?.stop();
    return Navigator.pop(context);
  }

  int indexOfStory(String storyId) => widget.storiesIds.indexOf(storyId);
}
