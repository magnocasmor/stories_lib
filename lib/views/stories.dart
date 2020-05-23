import 'package:flutter/material.dart';
import 'package:stories_lib/views/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/views/story_publisher.dart';
import 'package:stories_lib/utils/stories_helpers.dart';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/models/stories_collection.dart';
import 'package:stories_lib/configs/publisher_controller.dart';
import 'package:stories_lib/views/stories_collection_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

typedef _ItemBuilder = Widget Function(BuildContext, int);

typedef StoryPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef StoryPublisherPreviewBuilder = Widget Function(
  BuildContext context,
  ImageProvider coverImg,
  bool hasStories,
  bool hasNewStories,
);

class Stories extends StatefulWidget {
  final StoriesSettings settings;
  final MyStories myStoriesPreview;
  final Widget closeButton;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Widget previewPlaceholder;
  final EdgeInsets previewListPadding;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  // final _ItemBuilder placeholderBuilder;
  final StoryController storyController;
  final VoidCallback onAllStoriesComplete;
  final StoryPreviewBuilder previewBuilder;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;
  final StoryOverlayInfoBuilder overlayInfoBuilder;
  final RouteTransitionsBuilder storyOpenTransition;

  Stories({
    @required this.settings,
    this.closeButton,
    this.previewBuilder,
    this.storyController,
    this.myStoriesPreview,
    this.errorWidget,
    this.previewListPadding,
    this.previewPlaceholder,
    this.overlayInfoBuilder,
    this.loadingWidget,
    this.storyOpenTransition,
    this.onAllStoriesComplete,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.backgroundBetweenStories = Colors.black,
    this.closeButtonPosition = Alignment.topRight,
  });

  @override
  _StoriesState createState() => _StoriesState();
}

class _StoriesState extends State<Stories> {
  final _firestore = Firestore.instance;

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

              return _storyItem(context, preview, storyIds(stories));
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

  Widget _storyItem(
    BuildContext context,
    StoriesCollection story,
    List<String> storyIds,
  ) {
    return GestureDetector(
      child: story.coverImg != null
          ? CachedNetworkImage(
              imageUrl: story.coverImg,
              // placeholder: (context, url) => widget.previewPlaceholder,
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
            )
          : widget.previewBuilder(
              context,
              null,
              story.title[widget.settings.languageCode],
              hasNewStories(
                widget.settings.userId,
                story,
                widget.settings.storyTimeValidaty,
              ),
            ),
      onTap: () async {
        widget.onStoryCollectionOpenned?.call();
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: widget.storyOpenTransition,
            pageBuilder: (context, anim, anim2) {
              return StoriesCollectionView(
                storiesIds: storyIds,
                settings: widget.settings,
                selectedStoryId: story.storyId,
                closeButton: widget.closeButton,
                storyController: widget.storyController,
                mediaErrorWidget: widget.errorWidget,
                mediaLoadingWidget: widget.loadingWidget,
                overlayInfoBuilder: widget.overlayInfoBuilder,
                closeButtonPosition: widget.closeButtonPosition,
                onStoryCollectionClosed: widget.onStoryCollectionClosed,
                onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
                backgroundBetweenStories: widget.backgroundBetweenStories,
              );
            },
          ),
        );
        widget.onStoryCollectionClosed?.call();
      },
    );
  }

  Widget _storiesList({
    int itemCount,
    _ItemBuilder builder,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      padding: widget.previewListPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.myStoriesPreview ?? Container(),
          for (int i = 0; i < itemCount; i++) builder(context, i),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> get _storiesStream {
    var query = _firestore.collection(widget.settings.collectionDbName).where(
          'last_update',
          isGreaterThanOrEqualTo: DateTime.now().subtract(widget.settings.storyTimeValidaty),
        );

    // if (widget.settings.releases is List && widget.settings.releases.isNotEmpty) {
    //   query = query.where('releases', arrayContainsAny: widget.settings.releases);
    // }

    return query.orderBy('last_update', descending: widget.settings.sortByDescUpdate).snapshots();
  }
}

class MyStories extends StatefulWidget {
  final Widget closeButton;
  final Widget mediaErrorWidget;
  final StoriesSettings settings;
  final Widget mediaLoadingWidget;
  final Widget previewPlaceholder;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;
  final PublisherController publisherController;
  final StoryPublisherToolsBuilder toolsBuilder;
  final StoryPublisherButtonBuilder publishBuilder;
  final RouteTransitionsBuilder storyOpenTransition;
  final MyStoryOverlayInfoBuilder overlayInfoBuilder;
  final StoryPublisherPreviewBuilder previewStoryBuilder;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  MyStories({
    @required this.settings,
    this.closeButton,
    this.toolsBuilder,
    this.onStoryPosted,
    this.publishBuilder,
    this.storyController,
    this.mediaErrorWidget,
    this.overlayInfoBuilder,
    this.resultToolsBuilder,
    this.previewPlaceholder,
    this.mediaLoadingWidget,
    this.storyOpenTransition,
    this.previewStoryBuilder,
    this.publisherController,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.closeButtonPosition = Alignment.topRight,
    this.backgroundBetweenStories = Colors.black,
  });

  @override
  _MyStoriesState createState() => _MyStoriesState();
}

class _MyStoriesState extends State<MyStories> {
  final _firestore = Firestore.instance;

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

  Widget _storyItem(
    String coverImg,
    bool hasPublish,
    bool hasNewPublish,
  ) {
    return GestureDetector(
      child: coverImg is String
          ? CachedNetworkImage(
              imageUrl: coverImg,
              // placeholder: (context, url) => widget.previewPlaceholder,
              imageBuilder: (context, image) {
                return widget.previewStoryBuilder?.call(context, image, hasPublish, hasNewPublish);
              },
              errorWidget: (context, url, error) {
                debugPrint(error.toString());
                return widget.previewStoryBuilder?.call(context, null, hasPublish, hasNewPublish);
              },
            )
          : widget.previewStoryBuilder?.call(context, null, hasPublish, hasNewPublish),
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: widget.storyOpenTransition,
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
          transitionsBuilder: widget.storyOpenTransition,
          pageBuilder: (context, anim, anim2) => publisher,
        ),
      );

  Widget get publisher => StoryPublisher(
        settings: widget.settings,
        closeButton: widget.closeButton,
        toolsBuilder: widget.toolsBuilder,
        onStoryPosted: widget.onStoryPosted,
        errorWidget: widget.mediaErrorWidget,
        publisherBuilder: widget.publishBuilder,
        storyController: widget.storyController,
        loadingWidget: widget.mediaLoadingWidget,
        resultToolsBuilder: widget.resultToolsBuilder,
        publisherController: widget.publisherController,
        closeButtonPosition: widget.closeButtonPosition,
        onStoryCollectionClosed: widget.onStoryCollectionClosed,
        onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
        backgroundBetweenStories: widget.backgroundBetweenStories,
      );

  Widget get myStories => StoriesCollectionView(
        settings: widget.settings,
        closeButton: widget.closeButton,
        storiesIds: [widget.settings.userId],
        overlayInfoBuilder: overlayInfoBuilder,
        storyController: widget.storyController,
        selectedStoryId: widget.settings.userId,
        closeButtonPosition: widget.closeButtonPosition,
        onStoryCollectionClosed: widget.onStoryCollectionClosed,
        onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
        // sortingOrderDesc: true,
        backgroundBetweenStories: widget.backgroundBetweenStories,
      );

  Stream<DocumentSnapshot> get _storiesStream => _firestore
      .collection(widget.settings.collectionDbName)
      .document(widget.settings.userId)
      .snapshots();

  Widget overlayInfoBuilder(
    BuildContext context,
    int index,
    ImageProvider image,
    String title,
    List viewers,
    DateTime date,
    List<PageData> pages,
    Animation<double> animation,
  ) {
    return widget.overlayInfoBuilder(
      context,
      index,
      image,
      viewers,
      date,
      pages,
      animation,
      goToPublisher,
    );
  }
}
