import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stories_lib/utils/stories_parser.dart';
import 'story_controller.dart';
import 'story_view.dart';
import 'models/stories_list_with_pressed.dart';
import 'settings.dart';

export 'story_image.dart';
export 'story_video.dart';
export 'story_controller.dart';
export 'story_view.dart';
export 'settings.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupedStoriesView extends StatefulWidget {
  String collectionDbName;
  String languageCode;
  int imageStoryDuration;
  ProgressPosition progressPosition;
  bool repeat;
  bool inline;
  Icon closeButtonIcon;
  Color closeButtonBackgroundColor;
  Color backgroundColorBetweenStories;
  bool sortingOrderDesc;

  GroupedStoriesView(
      {this.collectionDbName,
      this.languageCode,
      this.imageStoryDuration = 3,
      this.progressPosition,
      this.repeat,
      this.inline,
      this.backgroundColorBetweenStories,
      this.closeButtonIcon,
      this.closeButtonBackgroundColor,
      this.sortingOrderDesc});

  @override
  _GroupedStoriesViewState createState() => _GroupedStoriesViewState();
}

class _GroupedStoriesViewState extends State<GroupedStoriesView> {
  final _firestore = Firestore.instance;
  final storyController = StoryController();
  List<List<StoryItem>> storyItemList = [];

  StoriesListWithPressed get storiesListWithPressed => ModalRoute.of(context).settings.arguments;

  Stream<DocumentSnapshot> get streamStories => _firestore
      .collection(widget.collectionDbName)
      .document(storiesListWithPressed.pressedStoryId)
      .snapshots();

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        _navigateBack();
        return Future.value(false);
      },
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: streamStories,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            storyItemList.add(
              parseStories(
                widget.languageCode,
                snapshot.data,
                widget.imageStoryDuration,
              ),
            );

            return Dismissible(
                resizeDuration: Duration(milliseconds: 200),
                key: UniqueKey(),
                onDismissed: (DismissDirection direction) {
                  if (direction == DismissDirection.endToStart) {
                    String nextStoryId = storiesListWithPressed.nextElementStoryId();
                    if (nextStoryId == null) {
                      _navigateBack();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _groupedStoriesView(),
                          settings: RouteSettings(
                            arguments: StoriesListWithPressed(
                                pressedStoryId: nextStoryId,
                                storiesIdsList: storiesListWithPressed.storiesIdsList),
                          ),
                        ),
                      );
                    }
                  } else {
                    String previousStoryId = storiesListWithPressed.previousElementStoryId();
                    if (previousStoryId == null) {
                      _navigateBack();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _groupedStoriesView(),
                          settings: RouteSettings(
                            arguments: StoriesListWithPressed(
                                pressedStoryId: previousStoryId,
                                storiesIdsList: storiesListWithPressed.storiesIdsList),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: GestureDetector(
                  child: StoryView(
                    widget.sortingOrderDesc ? storyItemList[0].reversed.toList() : storyItemList[0],
                    controller: storyController,
                    progressPosition: widget.progressPosition,
                    repeat: widget.repeat,
                    inline: widget.inline,
                    onStoryShow: (StoryItem s) {
                      _onStoryShow(s);
                    },
                    goForward: () {},
                    onComplete: () {
                      String nextStoryId = storiesListWithPressed.nextElementStoryId();

                      if (nextStoryId == null) {
                        _navigateBack();
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _groupedStoriesView(),
                            settings: RouteSettings(
                              arguments: StoriesListWithPressed(
                                pressedStoryId: nextStoryId,
                                storiesIdsList: storiesListWithPressed.storiesIdsList,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy > 0) {
                      _navigateBack();
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
                _navigateBack();
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

  GroupedStoriesView _groupedStoriesView() {
    return GroupedStoriesView(
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

  _navigateBack() {
    return Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (_) => false,
      arguments: 'back_from_stories_view',
    );
  }

  void _onStoryShow(StoryItem s) {}
}
