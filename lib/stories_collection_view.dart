import 'dart:ui';
import 'package:stories_lib/stories_settings.dart';
import 'story_view.dart';
import 'story_controller.dart';
import 'package:flutter/material.dart';
import 'package:stories_lib/stories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_helpers.dart';

export 'settings.dart';
export 'story_view.dart';
export 'story_image.dart';
export 'story_video.dart';
export 'story_controller.dart';

enum _StoriesDirection { next, previous }

class StoriesCollectionView extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final Widget closeButton;
  final String selectedStoryId;
  final List<String> storiesIds;
  final Widget mediaErrorWidget;
  final StoriesSettings settings;
  final Widget mediaLoadingWidget;
  final Alignment closeButtonPosition;
  final StoryHeaderBuilder progressBuilder;
  final StoryHeaderPosition headerPosition;
  final Color backgroundColorBetweenStories;

  StoriesCollectionView({
    @required this.settings,
    @required this.storiesIds,
    @required this.selectedStoryId,
    this.inline,
    this.closeButton,
    this.headerPosition,
    this.progressBuilder,
    this.mediaErrorWidget,
    this.mediaLoadingWidget,
    this.closeButtonPosition,
    this.backgroundColorBetweenStories,
    this.repeat = false,
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
        storyController?.stop();
        return Future.value(true);
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
                    future: getStories(widget.storiesIds[index]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return widget.mediaLoadingWidget ??
                            Center(
                              child: SizedBox(
                                width: 70,
                                height: 70,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 3,
                                ),
                              ),
                            );
                      }

                      final storyData = snapshot.data;

                      final stories = parseStories(
                        storyData,
                        storyController,
                        widget.settings,
                        widget.mediaErrorWidget,
                        widget.mediaLoadingWidget,
                      );

                      return GestureDetector(
                        child: StoryView(
                          storyItems: stories,
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
                                  "user_info": widget.settings.userId,
                                  "date": DateTime.now(),
                                };

                                if (views is List) {
                                  final hasView = views.any(
                                    (v) => v["user_info"] == widget.settings.userId,
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
                  if (widget.closeButton != null)
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

  Future<DocumentSnapshot> getStories(String storyId) =>
      _firestore.collection(widget.settings.collectionDbName).document(storyId).get();

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

  Future<bool> _finishStoriesView() {
    storyController?.stop();
    return Navigator.maybePop(context);
  }

  int indexOfStory(String storyId) => widget.storiesIds.indexOf(storyId);
}
