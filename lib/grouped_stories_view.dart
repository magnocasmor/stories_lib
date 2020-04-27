import 'dart:ui';
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

enum _StoriesDirection { next, previous }

class GroupedStoriesView extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final String userId;
  final String languageCode;
  final bool sortingOrderDesc;
  final String selectedStoryId;
  final int imageStoryDuration;
  final List<String> storiesIds;
  final String collectionDbName;
  final Widget closeButtonWidget;
  final Alignment progressPosition;
  final Alignment closeButtonPosition;
  final ProgressBuilder progressBuilder;
  final Color backgroundColorBetweenStories;

  GroupedStoriesView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    @required this.collectionDbName,
    this.userId,
    this.inline,
    this.languageCode,
    this.progressBuilder,
    this.sortingOrderDesc,
    this.progressPosition,
    this.closeButtonWidget,
    this.closeButtonPosition,
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
        backgroundColor: Colors.black,
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
                        storyController,
                        widget.languageCode,
                        storyData,
                        widget.imageStoryDuration,
                      );
                      return GestureDetector(
                        child: StoryView(
                          storyItems: widget.sortingOrderDesc ? stories.reversed.toList() : stories,
                          controller: storyController,
                          repeat: widget.repeat,
                          inline: widget.inline,
                          progressBuilder: widget.progressBuilder,
                          progressPosition: widget.progressPosition,
                          onStoryShow: (StoryItem s) {
                            storyData.reference.get().then(
                              (ds) async {
                                final doc = ds.data;
                                final index = stories.indexOf(s);
                                final views = doc["stories"][index]["views"];
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
                                  doc["stories"][index]["views"] = [currentView];
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
                      child: widget.closeButtonWidget,
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

  Future<DocumentSnapshot> streamStories(String storyId) =>
      _firestore.collection(widget.collectionDbName).document(storyId).get();

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
