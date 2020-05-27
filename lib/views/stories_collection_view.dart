import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stories_lib/utils/story_types.dart';
import 'package:stories_lib/views/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_helpers.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/configs/story_controller.dart';

enum _StoriesDirection { next, previous }

class StoriesCollectionView extends StatefulWidget {
  final StoriesSettings settings;
  final Widget closeButton;
  final Alignment closeButtonPosition;
  final Widget mediaError;
  final Widget mediaPlaceholder;
  final Color backgroundBetweenStories;
  final InfoLayerBuilder infoLayerBuilder;
  final RouteTransitionsBuilder navigationTransition;
  final StoryController storyController;
  final String selectedStoryId;
  final List<String> storiesIds;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;

  StoriesCollectionView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.settings,
    this.storyController,
    this.closeButton,
    this.closeButtonPosition,
    this.mediaError,
    this.mediaPlaceholder,
    this.backgroundBetweenStories,
    this.infoLayerBuilder,
    this.navigationTransition,
  });

  @override
  _StoriesCollectionViewState createState() => _StoriesCollectionViewState();
}

class _StoriesCollectionViewState extends State<StoriesCollectionView> {
  final _firestore = Firestore.instance;
  PageController _pageController;
  StoryController _storyController;

  @override
  void initState() {
    super.initState();
    widget.onStoryCollectionOpenned?.call();
    _storyController = widget.storyController ?? StoryController();

    _pageController = PageController(initialPage: indexOfStory(widget.selectedStoryId));
  }

  @override
  void dispose() {
    _storyController?.dispose();
    widget.onStoryCollectionClosed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        _storyController?.stop();
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: widget.backgroundBetweenStories,
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
                    future: getStories(widget.settings, widget.storiesIds[index]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return widget.mediaPlaceholder ??
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
                        _storyController,
                        widget.settings,
                        widget.mediaError,
                        widget.mediaPlaceholder,
                      );

                      return GestureDetector(
                        child: StoryView(
                          storyItems: stories,
                          closeButton: widget.closeButton,
                          closeButtonPosition: widget.closeButtonPosition,
                          infoLayerBuilder: widget.infoLayerBuilder,
                          repeat: widget.settings.repeat,
                          inline: widget.settings.inline,
                          controller: _storyController,
                          onStoryShow: (StoryItem item) {
                            storyData.reference.get().then(
                              (ds) async {
                                if (ds.documentID == widget.settings.userId) return;

                                final doc = ds.data;
                                final story =
                                    doc["stories"].singleWhere((s) => s['id'] == item.storyId);
                                final views = story["views"];
                                final currentView = {
                                  "user_id": widget.settings.userId,
                                  "user_name": widget.settings.username,
                                  "cover_img": widget.settings.coverImg,
                                  "date": DateTime.now(),
                                };

                                if (views is List) {
                                  final hasView =
                                      views.any((v) => v["user_id"] == widget.settings.userId);

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

  Future<DocumentSnapshot> getStories(StoriesSettings settings, String storyId) => _firestore
          .collection(settings.collectionDbName)
          .where(
            'last_update',
            isGreaterThanOrEqualTo: DateTime.now().subtract(settings.storyTimeValidaty),
          )
          .getDocuments()
          .then(
        (doc) {
          return doc.documents.singleWhere(
            (d) => d.documentID == storyId,
            orElse: () => null,
          );
        },
      );

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
    _storyController.stop();

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
    _storyController?.stop();
    return Navigator.maybePop(context);
  }

  int indexOfStory(String storyId) => widget.storiesIds.indexOf(storyId);
}
