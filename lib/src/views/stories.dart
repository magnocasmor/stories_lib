import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  }) : myStoriesPreview = MyStories(
          settings: settings,
          errorWidget: errorWidget,
          topSafeArea: topSafeArea,
          closeButton: closeButton,
          onStoryPosted: onStoryPosted,
          bottomSafeArea: bottomSafeArea,
          storyController: storyController,
          myPreviewBuilder: myPreviewBuilder,
          loadingWidget: loadingWidget,
          takeStoryBuilder: takeStoryBuilder,
          infoLayerBuilder: myInfoLayerBuilder,
          resultInfoBuilder: resultInfoBuilder,
          publisherController: publisherController,
          closeButtonPosition: closeButtonPosition,
          previewPlaceholder: myPreviewPlaceholder,
          navigationTransition: navigationTransition,
          publisherLayerBuilder: publisherLayerBuilder,
          onStoriesClosed: onStoriesClosed,
          backgroundBetweenStories: backgroundBetweenStories,
          onStoriesOpenned: onStoriesOpenned,
        );

  @override
  _StoriesState createState() => _StoriesState();
}

class _StoriesState extends State<Stories> {
  final firestore = Firestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stories = snapshot.data.documents;

          stories.removeWhere((s) => s.documentID == widget.settings.userId);

          stories.removeWhere(
              (prev) => !prev.data["stories"].every((story) => allowToSee(story, widget.settings)));

          final storyPreviews = parseStoriesPreview(widget.settings.languageCode, stories);

          return _storiesList(
            itemCount: storyPreviews.length,
            builder: (context, index) {
              final preview = storyPreviews[index];

              return _storyItem(preview, storyIds(stories));
            },
          );
        } else if (snapshot.hasError) {
          print(snapshot.error);
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
            itemCount: 4,
            builder: (context, index) {
              return widget.previewPlaceholder ?? LimitedBox();
            },
          );
        }
      },
    );
  }

  Widget _storyItem(StoriesCollection story, List<String> storyIds) {
    return GestureDetector(
      child: CachedNetworkImage(
        imageUrl: story.coverImg ?? "",
        placeholder: (context, url) => widget.previewPlaceholder,
        imageBuilder: (context, image) {
          return widget.previewBuilder(
            context,
            image,
            story.title[widget.settings.languageCode],
            hasNewStories(
              widget.settings.userId,
              story,
              widget.settings.storyTimeValidaty,
            ),
          );
        },
        errorWidget: (context, url, error) {
          debugPrint(error.toString());
          return widget.previewBuilder(
            context,
            null,
            story.title[widget.settings.languageCode],
            hasNewStories(
              widget.settings.userId,
              story,
              widget.settings.storyTimeValidaty,
            ),
          );
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
                storiesIds: storyIds,
                settings: widget.settings,
                errorWidget: widget.errorWidget,
                selectedStoryId: story.storyId,
                topSafeArea: widget.topSafeArea,
                closeButton: widget.closeButton,
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
    var query = firestore.collection(widget.settings.collectionDbPath).where(
          'last_update',
          isGreaterThanOrEqualTo: DateTime.now().subtract(widget.settings.storyTimeValidaty),
        );

    // if (widget.settings.releases is List && widget.settings.releases.isNotEmpty) {
    //   query = query.where('releases', arrayContainsAny: widget.settings.releases);
    // }

    return query.orderBy('last_update', descending: widget.settings.sortByDesc).snapshots();
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
    this.topSafeArea = true,
    this.bottomSafeArea = false,
    this.backgroundBetweenStories = Colors.black,
    this.closeButtonPosition = Alignment.topRight,
  });

  @override
  _MyStoriesState createState() => _MyStoriesState();
}

class _MyStoriesState extends State<MyStories> {
  final firestore = Firestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stories = snapshot.data;

          if (stories.data?.isNotEmpty ?? false) {
            final interval =
                DateTime.now().difference((stories.data["last_update"] as Timestamp).toDate());

            final isInValidaty = interval.compareTo(widget.settings.storyTimeValidaty) <= 0;

            if (stories.exists && isInValidaty) {
              final storyPreviews = parseStoriesPreview(widget.settings.languageCode, [stories]);

              final myPreview = storyPreviews.firstWhere(
                (preview) => preview.storyId == widget.settings.userId,
                orElse: () => null,
              );

              final hasPublish = myPreview != null && (myPreview.stories?.isNotEmpty ?? false);

              storyPreviews.remove(myPreview);

              final hasNewPublish = hasPublish
                  ? hasNewStories(
                      widget.settings.userId, myPreview, widget.settings.storyTimeValidaty)
                  : false;

              return _storyItem(myPreview.coverImg, hasPublish, hasNewPublish);
            }
          }
        }
        return _storyItem(widget.settings.coverImg, false, false);
      },
    );
  }

  Widget _storyItem(String coverImg, bool hasPublish, bool hasNewPublish) {
    return GestureDetector(
      child: CachedNetworkImage(
        imageUrl: coverImg ?? "",
        // placeholder: (context, url) => widget.previewPlaceholder,
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
                return myStories;
              else
                return publisher;
            },
          ),
        );
      },
    );
  }

  void goToPublisher() => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: widget.navigationTransition,
          pageBuilder: (context, anim, anim2) => publisher,
        ),
      );

  Widget get publisher {
    return StoryPublisher(
      settings: widget.settings,
      errorWidget: widget.errorWidget,
      closeButton: widget.closeButton,
      onStoryPosted: widget.onStoryPosted,
      loadingWidget: widget.loadingWidget,
      storyController: widget.storyController,
      takeStoryBuilder: widget.takeStoryBuilder,
      resultInfoBuilder: widget.resultInfoBuilder,
      publisherController: widget.publisherController,
      closeButtonPosition: widget.closeButtonPosition,
      onStoryCollectionClosed: widget.onStoriesClosed,
      onStoryCollectionOpenned: widget.onStoriesOpenned,
      publisherLayerBuilder: widget.publisherLayerBuilder,
      backgroundBetweenStories: widget.backgroundBetweenStories,
    );
  }

  Widget get myStories {
    return StoriesCollectionView(
      settings: widget.settings,
      errorWidget: widget.errorWidget,
      closeButton: widget.closeButton,
      loadingWidget: widget.loadingWidget,
      storiesIds: [widget.settings.userId],
      storyController: widget.storyController,
      selectedStoryId: widget.settings.userId,
      onStoriesClosed: widget.onStoriesClosed,
      onStoriesOpenned: widget.onStoriesOpenned,
      closeButtonPosition: widget.closeButtonPosition,
      navigationTransition: widget.navigationTransition,
      backgroundBetweenStories: widget.backgroundBetweenStories,
      infoLayerBuilder: (i, t, d, b, c, a, v) =>
          widget.infoLayerBuilder(i, t, d, b, c, a, v, goToPublisher),
    );
  }

  Stream<DocumentSnapshot> get _storiesStream {
    return firestore
        .collection(widget.settings.collectionDbPath)
        .document(widget.settings.userId)
        .snapshots();
  }
}
