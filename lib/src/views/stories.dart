import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../stories.dart';
import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../models/stories_collection.dart';
import '../utils/stories_helpers.dart';
import '../utils/story_types.dart';
import '../views/stories_collection_view.dart';
import '../views/story_publisher.dart';

typedef _ItemBuilder = Widget Function(BuildContext, int);

class Stories extends StatefulWidget {
  final StoriesSettings settings;

  final MyStories myStoriesPreview;

  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  final Alignment closeButtonPosition;

  /// Widget displayed when media fails to load.
  final Widget errorWidget;

  /// Widget displayed while media load.
  final Widget loadingWidget;

  final Color backgroundBetweenStories;

  /// A overlay above the [StoryView] that shows information about the current story.
  final InfoLayerBuilder infoLayerBuilder;

  /// Show the stories preview.
  final StoriesPreviewBuilder previewBuilder;

  /// Widget displayed while loading stories previews.
  final Widget previewPlaceholder;

  final EdgeInsets previewListPadding;

  /// A navigation transition when preview is tapped.
  final RouteTransitionsBuilder navigationTransition;

  final StoryController storyController;

  /// Calling when the view of all stories of the all [StoriesCollection]s is completed.
  final VoidCallback onAllStoriesComplete;

  /// Calling when the stories collection is popped.
  final VoidCallback onStoriesClosed;

  /// Calling when the stories collection is openned.
  final VoidCallback onStoriesOpenned;

  /// If should set [SafeArea] with top padding on [StoriesCollection].
  ///
  /// Default is true.
  final bool topSafeArea;

  /// If should set [SafeArea] with bottom padding on [StoriesCollection].
  ///
  /// Default is false.
  final bool bottomSafeArea;

  Stories({
    @required this.settings,
    this.errorWidget,
    this.closeButton,
    this.previewBuilder,
    this.storyController,
    this.loadingWidget,
    this.infoLayerBuilder,
    this.previewPlaceholder,
    this.previewListPadding,
    this.onAllStoriesComplete,
    this.navigationTransition,
    this.onStoriesClosed,
    this.onStoriesOpenned,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
    this.backgroundBetweenStories = Colors.black,
    this.closeButtonPosition = Alignment.topRight,
  }) : myStoriesPreview = null;

  /// Build a stories preview list with [MyStories] and same shared widgets.
  Stories.withMyStories({
    @required this.settings,
    this.errorWidget,
    this.closeButton,
    this.previewBuilder,
    this.storyController,
    this.loadingWidget,
    this.infoLayerBuilder,
    this.previewPlaceholder,
    this.previewListPadding,
    this.onAllStoriesComplete,
    this.navigationTransition,
    this.onStoriesClosed,
    this.onStoriesOpenned,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
    this.backgroundBetweenStories = Colors.black,
    this.closeButtonPosition = Alignment.topRight,
    VoidCallback onStoryPosted,
    Widget myPreviewPlaceholder,
    TakeStoryBuilder takeStoryBuilder,
    ResultLayerBuilder resultInfoBuilder,
    MyInfoLayerBuilder myInfoLayerBuilder,
    PublisherController publisherController,
    MyStoriesPreviewBuilder myPreviewBuilder,
    PublishLayerBuilder publisherLayerBuilder,
    Future<Color> Function(Color) changeBackgroundColor,
  }) : myStoriesPreview = myPreviewBuilder != null
            ? MyStories(
                settings: settings,
                errorWidget: errorWidget,
                topSafeArea: topSafeArea,
                closeButton: closeButton,
                loadingWidget: loadingWidget,
                onStoryPosted: onStoryPosted,
                bottomSafeArea: bottomSafeArea,
                storyController: storyController,
                onStoriesClosed: onStoriesClosed,
                myPreviewBuilder: myPreviewBuilder,
                takeStoryBuilder: takeStoryBuilder,
                onStoriesOpenned: onStoriesOpenned,
                infoLayerBuilder: myInfoLayerBuilder,
                resultInfoBuilder: resultInfoBuilder,
                publisherController: publisherController,
                closeButtonPosition: closeButtonPosition,
                previewPlaceholder: myPreviewPlaceholder,
                navigationTransition: navigationTransition,
                publisherLayerBuilder: publisherLayerBuilder,
                changeBackgroundColor: changeBackgroundColor,
                backgroundBetweenStories: backgroundBetweenStories,
              )
            : null;

  @override
  _StoriesState createState() => _StoriesState();
}

class _StoriesState extends State<Stories> {
  Stream<QuerySnapshot> stream;
  List<DocumentSnapshot> documents;

  @override
  void initState() {
    super.initState();
    stream = _storiesStream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          documents = snapshot.data.documents;

          documents.removeWhere((s) => s["owner"]["id"] == widget.settings.userId);

          documents.removeWhere((prev) => !allowToSee(prev.data, widget.settings));

          final collections = parseStoriesPreview(widget.settings.languageCode, documents);

          return _storiesList(
            itemCount: collections.length,
            builder: (context, collectionIndex) {
              final collection = collections[collectionIndex];
              final ownerTitle = collection.owner.title[widget.settings.languageCode];
              final ownerCoverImg = collection.owner.coverImg ?? "";
              final hasNsewStories = hasNewStories(
                widget.settings.userId,
                collection,
                widget.settings.storyTimeValidaty,
              );

              return GestureDetector(
                child: CachedNetworkImage(
                  imageUrl: ownerCoverImg,
                  placeholder: (context, url) {
                    return widget.previewPlaceholder;
                  },
                  imageBuilder: (context, image) {
                    return widget.previewBuilder(context, image, ownerTitle, hasNsewStories);
                  },
                  errorWidget: (context, url, error) {
                    debugPrint(error.toString());

                    return widget.previewBuilder(context, null, ownerTitle, hasNsewStories);
                  },
                ),
                onTap: () async {
                  widget.onStoriesOpenned?.call();

                  await Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 250),
                      transitionsBuilder: widget.navigationTransition,
                      pageBuilder: (context, anim, anim2) {
                        return StoriesCollectionView(
                          collections: collections,
                          settings: widget.settings,
                          onStoryViewed: _setViewed,
                          initialIndex: collectionIndex,
                          closeButton: widget.closeButton,
                          errorWidget: widget.errorWidget,
                          topSafeArea: widget.topSafeArea,
                          loadingWidget: widget.loadingWidget,
                          bottomSafeArea: widget.bottomSafeArea,
                          storyController: widget.storyController,
                          onStoriesClosed: widget.onStoriesClosed,
                          onStoriesOpenned: widget.onStoriesOpenned,
                          infoLayerBuilder: widget.infoLayerBuilder,
                          closeButtonPosition: widget.closeButtonPosition,
                          navigationTransition: widget.navigationTransition,
                          backgroundBetweenStories: widget.backgroundBetweenStories,
                        );
                      },
                    ),
                  );

                  widget.onStoriesClosed?.call();
                },
              );
            },
          );
        } else if (snapshot.hasError) {
          debugPrint(snapshot.error);

          return Center(
            child: Column(
              children: <Widget>[
                Icon(Icons.error),
                Text("Can't get stories"),
              ],
            ),
          );
        } else {
          return _storiesList(
            itemCount: 6,
            builder: (context, index) {
              return widget.previewPlaceholder ?? LimitedBox();
            },
          );
        }
      },
    );
  }

  Widget _storiesList({int itemCount, _ItemBuilder builder}) {
    return SingleChildScrollView(
      primary: false,
      scrollDirection: Axis.horizontal,
      padding: widget.previewListPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.myStoriesPreview != null) widget.myStoriesPreview,
          for (int i = 0; i < itemCount; i++) builder(context, i),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> get _storiesStream {
    var query = Firestore.instance
        .collection(widget.settings.collectionDbPath)
        .where('deleted_at', isNull: true)
        .where(
          'date',
          isGreaterThanOrEqualTo: DateTime.now().subtract(widget.settings.storyTimeValidaty),
        );

    if (widget.settings.releases is List && widget.settings.releases.isNotEmpty) {
      query = query.where('releases', arrayContainsAny: widget.settings.releases);
    }

    return query.orderBy('date', descending: widget.settings.sortByDesc).snapshots();
  }

  Future<void> _setViewed(String storyId) async {
    if (documents == null || documents.isEmpty) return;

    final document = documents.singleWhere((document) => document.documentID == storyId);

    final data = document.data;

    final views = data["views"];

    final currentView = {
      "user_id": widget.settings.userId,
      "user_name": widget.settings.username,
      "cover_img": widget.settings.coverImg,
      "date": DateTime.now(),
    };

    if (views is List) {
      final hasView = views.any((view) => view["user_id"] == widget.settings.userId);

      if (!hasView) {
        views.add(currentView);
      }
    } else {
      data["views"] = [currentView];
    }

    document.reference.updateData(data);
  }
}

class MyStories extends StatefulWidget {
  final StoriesSettings settings;

  /// Calling when a publishment is completed with success.
  final VoidCallback onStoryPosted;

  /// If should set [SafeArea] with top padding on [StoriesCollection] and [StoryPublisher].
  ///
  /// Default is true.
  final bool topSafeArea;

  /// If should set [SafeArea] with bottom padding on [StoriesCollection] and [StoryPublisher].
  ///
  /// Default is false.
  final bool bottomSafeArea;

  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  final Alignment closeButtonPosition;

  /// Widget displayed when media fails to load.
  final Widget errorWidget;

  /// Widget displayed while media load.
  final Widget loadingWidget;

  final Color backgroundBetweenStories;

  /// A overlay above the [StoryView] that shows information about the current story.
  final MyInfoLayerBuilder infoLayerBuilder;

  /// Show the stories preview.
  final MyStoriesPreviewBuilder myPreviewBuilder;

  /// Widget displayed while loading story preview.
  final Widget previewPlaceholder;

  /// Build the button to publish stories.
  ///
  /// Provide the [Animation] on video record and a function to take story.
  final TakeStoryBuilder takeStoryBuilder;

  /// A overlay above [StoryPublisher] where can put some interactions to manipulate the story.
  ///
  /// [StoryType] indicates the current selected type. When change type by calling [PublisherController.changeType]
  /// this widget will rebuild.
  final PublishLayerBuilder publisherLayerBuilder;

  /// A overlay above the [_StoryPublisherResult] of story taked.
  ///
  /// Provide a function to add a caption to the story and the releases list allowed to see this story.
  final ResultLayerBuilder resultInfoBuilder;

  /// A navigation transition when preview is tapped.
  final RouteTransitionsBuilder navigationTransition;

  final StoryController storyController;

  /// Calling when the stories collection is popped.
  final VoidCallback onStoriesClosed;

  /// Calling when the stories collection is openned.
  final VoidCallback onStoriesOpenned;

  final PublisherController publisherController;

  final Future<Color> Function(Color) changeBackgroundColor;

  MyStories({
    @required this.settings,
    this.errorWidget,
    this.closeButton,
    this.loadingWidget,
    this.onStoryPosted,
    this.storyController,
    this.onStoriesClosed,
    this.onStoriesOpenned,
    this.infoLayerBuilder,
    this.myPreviewBuilder,
    this.takeStoryBuilder,
    this.resultInfoBuilder,
    this.previewPlaceholder,
    this.publisherController,
    this.navigationTransition,
    this.publisherLayerBuilder,
    this.changeBackgroundColor,
    this.topSafeArea = true,
    this.bottomSafeArea = false,
    this.backgroundBetweenStories = Colors.black,
    this.closeButtonPosition = Alignment.topRight,
  });

  @override
  _MyStoriesState createState() => _MyStoriesState();
}

class _MyStoriesState extends State<MyStories> {
  final collectionStream = StreamController<StoriesCollection>.broadcast();
  bool isMyStoriesFinished = true;
  Stream<QuerySnapshot> stream;
  List<DocumentSnapshot> documents;

  @override
  void initState() {
    super.initState();
    stream = _storiesStream;

    widget.storyController.attachMyStories(this);
  }

  @override
  void dispose() {
    collectionStream?.close();
    widget.storyController?.dettachMyStories();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          documents = snapshot.data.documents;

          if (documents.isNotEmpty) {
            final myCollection = parseStoriesPreview(widget.settings.languageCode, documents).first;

            final interval = DateTime.now().difference(myCollection.lastUpdate);

            final isInValidaty = interval.compareTo(widget.settings.storyTimeValidaty) <= 0;

            final noStories = myCollection.stories.every((story) => story.deletedAt != null);

            if (!noStories && isInValidaty) {
              final hasPublish = myCollection.stories?.isNotEmpty ?? false;

              final hasNewPublish = hasPublish
                  ? hasNewStories(
                      widget.settings.userId, myCollection, widget.settings.storyTimeValidaty)
                  : false;

              return _storyItem(
                collection: myCollection,
                hasPublish: hasPublish,
                hasNewPublish: hasNewPublish,
              );
            }
          }
        }
        return _storyItem();
      },
    );
  }

  Widget _storyItem({
    StoriesCollection collection,
    bool hasPublish = false,
    bool hasNewPublish = false,
  }) {
    return GestureDetector(
      child: CachedNetworkImage(
        imageUrl: collection?.owner?.coverImg ?? widget.settings.coverImg ?? "",
        imageBuilder: (context, image) {
          return widget.myPreviewBuilder?.call(context, image, hasPublish, hasNewPublish);
        },
        errorWidget: (context, url, error) {
          debugPrint(error.toString());
          return widget.myPreviewBuilder?.call(context, null, hasPublish, hasNewPublish);
        },
      ),
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: widget.navigationTransition,
            pageBuilder: (context, anim, anim2) {
              if (hasPublish)
                return myStories(collection);
              else
                return publisher;
            },
          ),
        );
      },
    );
  }

  void goToPublisher() async {
    isMyStoriesFinished = false;
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: widget.navigationTransition,
        pageBuilder: (context, anim, anim2) => publisher,
      ),
    );
    isMyStoriesFinished = true;
  }

  Widget get publisher => StoryPublisher(
        settings: widget.settings,
        errorWidget: widget.errorWidget,
        closeButton: widget.closeButton,
        topSafeArea: widget.topSafeArea,
        onStoryPosted: widget.onStoryPosted,
        loadingWidget: widget.loadingWidget,
        bottomSafeArea: widget.bottomSafeArea,
        storyController: widget.storyController,
        takeStoryBuilder: widget.takeStoryBuilder,
        resultInfoBuilder: widget.resultInfoBuilder,
        publisherController: widget.publisherController,
        closeButtonPosition: widget.closeButtonPosition,
        onStoryCollectionClosed: widget.onStoriesClosed,
        onStoryCollectionOpenned: widget.onStoriesOpenned,
        changeBackgroundColor: widget.changeBackgroundColor,
        publisherLayerBuilder: widget.publisherLayerBuilder,
        backgroundBetweenStories: widget.backgroundBetweenStories,
      );

  Widget myStories(StoriesCollection collection) {
    return StreamBuilder<StoriesCollection>(
        initialData: collection,
        stream: collectionStream.stream,
        builder: (context, snapshot) {
          return StoriesCollectionView(
            initialIndex: 0,
            collections: [snapshot.data],
            onStoryViewed: _setViewed,
            settings: widget.settings,
            errorWidget: widget.errorWidget,
            closeButton: widget.closeButton,
            loadingWidget: widget.loadingWidget,
            storyController: widget.storyController,
            onStoriesClosed: () {
              if (isMyStoriesFinished) widget.onStoriesClosed?.call();
            },
            onStoriesOpenned: widget.onStoriesOpenned,
            closeButtonPosition: widget.closeButtonPosition,
            navigationTransition: widget.navigationTransition,
            backgroundBetweenStories: widget.backgroundBetweenStories,
            infoLayerBuilder: (ctx, i, t, d, b, c, a, v) {
              return widget.infoLayerBuilder(ctx, i, t, d, b, c, a, v, goToPublisher);
            },
          );
        });
  }

  Stream<QuerySnapshot> get _storiesStream {
    return Firestore.instance
        .collection(widget.settings.collectionDbPath)
        .where(
          'date',
          isGreaterThanOrEqualTo: DateTime.now().subtract(widget.settings.storyTimeValidaty),
        )
        .where('owner.id', isEqualTo: widget.settings.userId)
        .where('deleted_at', isNull: true)
        .orderBy('date', descending: widget.settings.sortByDesc)
        .snapshots();
  }

  Future<void> deleteStory(int index) async {
    final collection = parseStoriesPreview(widget.settings.languageCode, documents).first;

    if (collection.owner.id != widget.settings.userId) {
      throw NotAllowedException();
    }
    final story = collection.stories[index];

    final document = documents.singleWhere((doc) => doc.documentID == story.id);

    widget.storyController.pause();

    final newData = document.data;

    newData["deleted_at"] = DateTime.now();

    await document.reference.updateData(newData);

    collection.stories.removeWhere((s) => s.id == newData["id"]);

    final noStories = collection.stories.every((s) => s.deletedAt != null);

    if (noStories) {
      widget.storyController?.stop();

      Navigator.pop(context);
    } else {
      collectionStream.sink.add(collection);
    }
  }

  Future<void> _setViewed(String storyId) async {
    if (documents == null || documents.isEmpty) return;

    final document = documents.singleWhere((document) => document.documentID == storyId);

    final data = document.data;

    final views = data["views"];

    final currentView = {
      "user_id": widget.settings.userId,
      "user_name": widget.settings.username,
      "cover_img": widget.settings.coverImg,
      "date": DateTime.now(),
    };

    if (views is List) {
      final hasView = views.any((view) => view["user_id"] == widget.settings.userId);

      if (!hasView) {
        views.add(currentView);
      }
    } else {
      data["views"] = [currentView];
    }

    document.reference.updateData(data);
  }
}
