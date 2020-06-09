import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
  final Widget errorWidget;
  final Widget closeButton;
  final bool bottomSafeArea;
  final Widget loadingWidget;
  final String selectedStoryId;
  final List<String> storiesIds;
  final StoriesSettings settings;
  final VoidCallback onStoriesClosed;
  final VoidCallback onStoriesOpenned;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final InfoLayerBuilder infoLayerBuilder;
  final RouteTransitionsBuilder navigationTransition;

  StoriesCollectionView({
    @required this.storiesIds,
    @required this.selectedStoryId,
    this.settings,
    this.errorWidget,
    this.closeButton,
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
  });

  @override
  StoriesCollectionViewState createState() => StoriesCollectionViewState();
}

class StoriesCollectionViewState extends State<StoriesCollectionView> {
  final firestore = Firestore.instance;

  PageController pageController;

  StoryController storyController;

  Future<List<DocumentSnapshot>> storiesDoc;

  String currentStoryId;

  @override
  void initState() {
    storiesDoc = storiesFromIds();

    widget.onStoriesOpenned?.call();

    storyController = widget.storyController ?? StoryController();

    pageController = PageController(initialPage: indexOfStory(widget.selectedStoryId));

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
          child: FutureBuilder<List<DocumentSnapshot>>(
              future: storiesDoc,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return PageView.builder(
                    controller: pageController,
                    itemCount: widget.storiesIds.length,
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final data = snapshot.data[index];

                      final stories = parseItems(data);

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

                                  final collection = storiesCollectionFromDocument(data);

                                  final currentStory = collection.stories.singleWhere(
                                      (s) => s.id == currentStoryId,
                                      orElse: () => null);

                                  return widget.infoLayerBuilder(
                                    context,
                                    CachedNetworkImageProvider(collection.coverImg ?? ""),
                                    collection.title[widget.settings.languageCode],
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
                                onShowing: (i) {
                                  currentStoryId = stories[i].storyId;

                                  setViewed();
                                },
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
                  );
                } else {
                  return widget.loadingWidget ?? StoryLoading();
                }
              }),
        ),
      ),
    );
  }

  Future<void> deleteCurrentStory() async {
    if (storiesDoc != null && currentStoryId != null) {
      int index;

      try {
        index = pageController.page.toInt();
      } catch (e) {
        index = indexOfStory(widget.selectedStoryId);
      }

      final ds = (await storiesDoc)[index];

      final doc = ds.data;

      final story =
          doc["stories"].singleWhere((s) => s["id"] == currentStoryId, orElse: () => null);

      if (story == null) return;

      story["deleted"] = true;
      story["deleted_at"] = DateTime.now();

      await ds.reference.updateData(doc);

      storiesDoc = storiesFromIds();

      final newDS = await storiesDoc;

      final noStoryRemains =
          newDS[index].data["stories"].every((d) => d["deleted"] as bool ?? false);

      if (noStoryRemains) {
        storyController?.stop();

        Navigator.pop(context);
      } else {
        setState(() {});
      }
    }
  }

  void setViewed() async {
    if (storiesDoc != null && currentStoryId != null) {
      int index;

      try {
        index = pageController.page.toInt();
      } catch (e) {
        index = indexOfStory(widget.selectedStoryId);
      }

      storiesDoc = storiesFromIds();

      final ds = (await storiesDoc)[index];

      final doc = ds.data;
      final story =
          doc["stories"].singleWhere((s) => s["id"] == currentStoryId, orElse: () => null);

      final views = story["views"];
      final currentView = {
        "user_id": widget.settings.userId,
        "user_name": widget.settings.username,
        "cover_img": widget.settings.coverImg,
        "date": DateTime.now(),
      };

      if (views is List) {
        final hasView = views.any((v) => v["user_id"] == widget.settings.userId);

        if (!hasView) views.add(currentView);
      } else {
        story["views"] = [currentView];
      }

      ds.reference.updateData(doc);
    }
  }

  List<StoryWrap> parseItems(DocumentSnapshot data) {
    if (data == null) return null;

    return parseStories(
      data,
      storyController,
      widget.settings,
      widget.errorWidget,
      widget.loadingWidget,
    );
  }

  Future<List<DocumentSnapshot>> storiesFromIds() {
    final validaty = DateTime.now().subtract(widget.settings.storyTimeValidaty);

    return firestore
        .collection(widget.settings.collectionDbPath)
        .where('last_update', isGreaterThanOrEqualTo: validaty)
        .orderBy('last_update', descending: widget.settings.sortByDesc)
        .getDocuments()
        .then(
          (doc) => doc.documents.where((d) => widget.storiesIds.contains(d.documentID)).toList(),
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
