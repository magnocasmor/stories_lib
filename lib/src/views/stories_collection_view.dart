import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../stories.dart';
import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../utils/stories_helpers.dart';
import '../utils/story_types.dart';
import 'story_view.dart';

enum _StoriesDirection { next, previous }

class StoriesCollectionView extends StatefulWidget {
  final bool topSafeArea;
  final Widget mediaError;
  final bool bottomSafeArea;
  final Widget closeButton;
  final String selectedStoryId;
  final Widget mediaPlaceholder;
  final List<String> storiesIds;
  final StoriesSettings settings;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final InfoLayerBuilder infoLayerBuilder;
  final VoidCallback onStoriesClosed;
  final VoidCallback onStoriesOpenned;
  final RouteTransitionsBuilder navigationTransition;

  StoriesCollectionView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    this.settings,
    this.mediaError,
    this.closeButton,
    this.storyController,
    this.mediaPlaceholder,
    this.infoLayerBuilder,
    this.closeButtonPosition,
    this.onStoriesOpenned,
    this.navigationTransition,
    this.onStoriesClosed,
    this.backgroundBetweenStories,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
  });

  @override
  _StoriesCollectionViewState createState() => _StoriesCollectionViewState();
}

class _StoriesCollectionViewState extends State<StoriesCollectionView> {
  final firestore = Firestore.instance;
  PageController pageController;
  StoryController storyController;

  @override
  void initState() {
    widget.onStoriesOpenned?.call();
    storyController = widget.storyController ?? StoryController();
    pageController = PageController(initialPage: indexOfStory(widget.selectedStoryId));
    super.initState();
  }

  @override
  void dispose() {
    storyController?.dispose();
    widget.onStoriesClosed?.call();
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
        backgroundColor: widget.backgroundBetweenStories,
        body: SafeArea(
          top: widget.topSafeArea,
          bottom: widget.bottomSafeArea,
          child: PageView.builder(
            controller: pageController,
            itemCount: widget.storiesIds.length,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Stack(
                children: <Widget>[
                  FutureBuilder<DocumentSnapshot>(
                    future: getStories(widget.settings, widget.storiesIds[index]),
                    builder: (context, snapshot) {
                      final stories = parseItems(snapshot.data);
                      if (stories != null) {
                        return GestureDetector(
                          child: StoryView(
                            storyItems: stories,
                            controller: storyController,
                            repeat: widget.settings.repeat,
                            inline: widget.settings.inline,
                            closeButton: widget.closeButton,
                            onComplete: _nextGroupedStories,
                            infoLayerBuilder: widget.infoLayerBuilder,
                            previousOnFirstStory: _previousGroupedStories,
                            closeButtonPosition: widget.closeButtonPosition,
                            onStoryShow: (item) => setViewed(snapshot.data, item),
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
                      } else {
                        return widget.mediaPlaceholder ?? Center(child: StoryLoading());
                      }
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

  void setViewed(DocumentSnapshot data, StoryItem item) {
    data.reference.get().then(
      (ds) async {
        if (ds.documentID == widget.settings.userId) return;

        final doc = ds.data;
        final story = doc["stories"].singleWhere((s) => s['id'] == item.storyId);
        final views = story["views"];
        final currentView = {
          "user_id": widget.settings.userId,
          "user_name": widget.settings.username,
          "cover_img": widget.settings.coverImg,
          "date": DateTime.now(),
        };

        if (views is List) {
          final hasView = views.any((v) => v["user_id"] == widget.settings.userId);

          if (!hasView) {
            views.add(currentView);
          }
        } else {
          story["views"] = [currentView];
        }

        ds.reference.updateData(doc);
      },
    );
  }

  List<StoryItem> parseItems(DocumentSnapshot data) {
    if (data == null) return null;

    return parseStories(
      data,
      storyController,
      widget.settings,
      widget.mediaError,
      widget.mediaPlaceholder,
    );
  }

  Future<DocumentSnapshot> getStories(StoriesSettings settings, String storyId) {
    final validaty = DateTime.now().subtract(settings.storyTimeValidaty);
    return firestore
        .collection(settings.collectionDbPath)
        .where('last_update', isGreaterThanOrEqualTo: validaty)
        .getDocuments()
        .then(
          (doc) => doc.documents.singleWhere((d) => d.documentID == storyId, orElse: () => null),
        );
  }

  void _nextGroupedStories() {
    if (pageController.page.toInt() != indexOfStory(widget.storiesIds.last)) {
      _navigateToStories(_StoriesDirection.next);
    } else {
      _finishStoriesView();
    }
  }

  void _previousGroupedStories() {
    if (pageController.page.toInt() != indexOfStory(widget.storiesIds.first)) {
      _navigateToStories(_StoriesDirection.previous);
    }
  }

  Future _navigateToStories(_StoriesDirection direction) {
    storyController.stop();

    if (direction == _StoriesDirection.next)
      return pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
    else {
      return pageController.previousPage(
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
