import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stories_lib/src/models/stories_collection.dart';

import '../../stories.dart';
import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../utils/stories_helpers.dart';
import '../utils/story_types.dart';
import 'story_view.dart';

enum _StoriesDirection { next, previous }

class StoriesCollectionView extends StatefulWidget {
  final bool topSafeArea;
  final int initialIndex;
  final Widget errorWidget;
  final Widget closeButton;
  final bool bottomSafeArea;
  final Widget loadingWidget;
  final StoriesSettings settings;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final StoryEventCallback onStoryViewed;
  final StoryEventCallback onStoryClosed;
  final StoryEventCallback onStoryPaused;
  final InfoLayerBuilder infoLayerBuilder;
  final StoryEventCallback onStoryResumed;
  final List<StoriesCollection> collections;
  final void Function(String) onCollectionOpenned;
  final RouteTransitionsBuilder navigationTransition;
  final void Function(String, bool) onCollectionClosed;

  StoriesCollectionView({
    this.settings,
    this.errorWidget,
    this.closeButton,
    this.collections,
    this.loadingWidget,
    this.onStoryClosed,
    this.onStoryViewed,
    this.onStoryPaused,
    this.onStoryResumed,
    this.storyController,
    this.infoLayerBuilder,
    this.onCollectionClosed,
    this.onCollectionOpenned,
    this.closeButtonPosition,
    this.navigationTransition,
    this.backgroundBetweenStories,
    this.initialIndex = 0,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
  });

  @override
  StoriesCollectionViewState createState() => StoriesCollectionViewState();
}

class StoriesCollectionViewState extends State<StoriesCollectionView> {
  final firestore = Firestore.instance;

  PageController pageController;

  StoryController storyController;

  @override
  void initState() {
    storyController = widget.storyController ?? StoryController();

    pageController = PageController(initialPage: widget.initialIndex);

    super.initState();
  }

  @override
  void dispose() {
    storyController?.dispose();

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
            itemCount: widget.collections.length,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, collectionIndex) {
              final collection = widget.collections[collectionIndex];

              final stories = parseStories(
                collection,
                storyController,
                widget.settings,
                widget.errorWidget,
                widget.loadingWidget,
              );

              return Stack(
                children: <Widget>[
                  if (stories != null)
                    GestureDetector(
                      child: StoryView(
                        key: UniqueKey(),
                        stories: stories,
                        controller: storyController,
                        repeat: widget.settings.repeat,
                        inline: widget.settings.inline,
                        onPaused: widget.onStoryPaused,
                        onResumed: widget.onStoryResumed,
                        closeButton: widget.closeButton,
                        onInit: () {
                          widget.onCollectionOpenned?.call(collection.owner.id);
                        },
                        onComplete: () {
                          widget.onCollectionClosed
                              ?.call(collection.owner.id, stories.every((s) => s.shown));
                          _nextGroupedStories();
                        },
                        infoLayerBuilder: (bars, currentIndex, animation) {
                          if (currentIndex < 0) return Container();

                          final currentStoryId = stories[currentIndex].storyId;

                          final currentStory = collection.stories
                              .singleWhere((s) => s.id == currentStoryId, orElse: () => null);

                          return widget.infoLayerBuilder(
                            context,
                            CachedNetworkImageProvider(collection.owner.coverImg ?? ""),
                            collection.owner.title[widget.settings.languageCode],
                            currentStory.date,
                            bars,
                            currentIndex,
                            animation,
                            currentStory?.views?.where((v) {
                                  return v["user_id"] != widget.settings.userId;
                                })?.toList() ??
                                [],
                          );
                        },
                        onPreviousFirstStory: _previousGroupedStories,
                        closeButtonPosition: widget.closeButtonPosition,
                        onStoryViewing: (int storyIndex) {
                          widget.onStoryViewed(collection.stories[storyIndex].id);
                        },
                        onStoryClosed: widget.onStoryClosed,
                      ),
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy > 0) {
                          widget.onCollectionClosed
                              ?.call(collection.owner.id, stories.every((s) => s.shown));
                          _finishStoriesView();
                        }
                      },
                      onHorizontalDragUpdate: (details) {
                        if (details.delta.dx > 0) {
                          _previousGroupedStories();
                        } else {
                          _nextGroupedStories();
                          if (pageController.page.toInt() == widget.collections.length - 1)
                            widget.onCollectionClosed
                                ?.call(collection.owner.id, stories.every((s) => s.shown));
                        }
                      },
                    )
                  else
                    widget.loadingWidget ?? Center(child: StoryLoading()),
                  if (widget.closeButton != null)
                    Align(
                      alignment: widget.closeButtonPosition,
                      child: GestureDetector(
                        onTap: () {
                          _finishStoriesView();
                          widget.onCollectionClosed
                              ?.call(collection.owner.id, stories.every((s) => s.shown));
                        },
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

  void _nextGroupedStories() {
    if (pageController.page.toInt() != widget.collections.length - 1) {
      _navigateToStories(_StoriesDirection.next);
    } else {
      _finishStoriesView();
    }
  }

  void _previousGroupedStories() {
    if (pageController.page.toInt() != 0) {
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
}
