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
  final void Function(int) onStoryViewed;
  final VoidCallback onStoriesClosed;
  final VoidCallback onStoriesOpenned;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final InfoLayerBuilder infoLayerBuilder;
  final List<StoriesCollectionV2> collections;
  final RouteTransitionsBuilder navigationTransition;

  StoriesCollectionView({
    this.settings,
    this.errorWidget,
    this.closeButton,
    this.collections,
    this.onStoryViewed,
    this.loadingWidget,
    this.storyController,
    this.onStoriesClosed,
    this.infoLayerBuilder,
    this.onStoriesOpenned,
    this.closeButtonPosition,
    this.navigationTransition,
    this.backgroundBetweenStories,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
    this.initialIndex = 0,
  });

  @override
  StoriesCollectionViewState createState() => StoriesCollectionViewState();
}

class StoriesCollectionViewState extends State<StoriesCollectionView> {
  final firestore = Firestore.instance;

  PageController pageController;

  StoryController storyController;

  String currentStoryId;

  @override
  void initState() {
    widget.onStoriesOpenned?.call();

    storyController = widget.storyController ?? StoryController();

    pageController = PageController(initialPage: widget.initialIndex);

    storyController.addCollectionState(this);

    super.initState();
  }

  @override
  void dispose() {
    storyController?.removeCollectionState();

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
            itemCount: widget.collections.length,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final collection = widget.collections[index];

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
                        closeButton: widget.closeButton,
                        onComplete: _nextGroupedStories,
                        infoLayerBuilder: (bars, currentIndex, animation) {
                          if (currentIndex < 0) return Container();

                          currentStoryId = stories[currentIndex].storyId;

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
                        onShowing: widget.onStoryViewed,
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
                    )
                  else
                    widget.loadingWidget ?? Center(child: StoryLoading()),
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
