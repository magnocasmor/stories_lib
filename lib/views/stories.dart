import 'package:flutter/material.dart';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/views/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/views/story_publisher.dart';
import 'package:stories_lib/utils/stories_helpers.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/models/stories_collection.dart';
import 'package:stories_lib/configs/publisher_controller.dart';
import 'package:stories_lib/views/stories_collection_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

typedef _ItemBuilder = Widget Function(BuildContext, int);

typedef StoryPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef StoryPublisherPreviewBuilder = Widget Function(BuildContext, ImageProvider, bool, bool);

class Stories extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final Widget closeButton;
  final Widget mediaErrorWidget;
  final StoriesSettings settings;
  final Widget mediaLoadingWidget;
  final Widget previewPlaceholder;
  final MyStories myStoriesPreview;
  final EdgeInsets previewListPadding;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final _ItemBuilder placeholderBuilder;
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
    this.mediaErrorWidget,
    this.placeholderBuilder,
    this.previewListPadding,
    this.previewPlaceholder,
    this.overlayInfoBuilder,
    this.mediaLoadingWidget,
    this.storyOpenTransition,
    this.onAllStoriesComplete,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.repeat = false,
    this.inline = false,
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
              return widget.placeholderBuilder?.call(context, index) ?? LimitedBox();
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
              errorWidget: (context, url, error) => Icon(Icons.error),
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
                repeat: widget.repeat,
                inline: widget.inline,
                settings: widget.settings,
                selectedStoryId: story.storyId,
                closeButton: widget.closeButton,
                storyController: widget.storyController,
                mediaErrorWidget: widget.mediaErrorWidget,
                overlayInfoBuilder: widget.overlayInfoBuilder,
                mediaLoadingWidget: widget.mediaLoadingWidget,
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
  final bool repeat;
  final bool inline;
  final Widget closeButton;
  final Widget mediaErrorWidget;
  final StoriesSettings settings;
  final Widget mediaLoadingWidget;
  final Widget previewPlaceholder;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final _ItemBuilder placeholderBuilder;
  final StoryController storyController;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;
  final StoryOverlayInfoBuilder overlayInfoBuilder;
  final PublisherController publisherController;
  final StoryPublisherToolsBuilder toolsBuilder;
  final StoryPublisherButtonBuilder publishBuilder;
  final RouteTransitionsBuilder storyOpenTransition;
  final StoryPublisherPreviewBuilder publishStoryBuilder;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  MyStories({
    @required this.settings,
    this.closeButton,
    this.publishStoryBuilder,
    this.mediaErrorWidget,
    this.placeholderBuilder,
    this.previewPlaceholder,
    this.mediaLoadingWidget,
    this.storyOpenTransition,
    this.toolsBuilder,
    this.onStoryPosted,
    this.publishBuilder,
    this.storyController,
    this.overlayInfoBuilder,
    this.resultToolsBuilder,
    this.publisherController,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.repeat = false,
    this.inline = false,
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

              final hasPublish = myPreview != null && myPreview.stories.isNotEmpty;

              storyPreviews.remove(myPreview);

              final hasNewPublish = hasPublish
                  ? hasNewStories(
                      widget.settings.userId, myPreview, widget.settings.storyTimeValidaty)
                  : false;

              return _storyItem(myPreview.coverImg, hasPublish, hasNewPublish);
            }
          }
          return _storyItem(widget.settings.coverImg, false, false);
        } else {
          return widget.placeholderBuilder?.call(context, 0) ?? LimitedBox();
        }
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
              placeholder: (context, url) => widget.previewPlaceholder,
              imageBuilder: (context, image) {
                return widget.publishStoryBuilder?.call(context, image, hasPublish, hasNewPublish);
              },
              errorWidget: (context, url, error) => Icon(Icons.error),
            )
          : widget.publishStoryBuilder?.call(context, null, hasPublish, hasNewPublish),
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: widget.storyOpenTransition,
            pageBuilder: (context, anim, anim2) {
              return StoryPublisher(
                hasPublish: hasPublish,
                settings: widget.settings,
                closeButton: widget.closeButton,
                toolsBuilder: widget.toolsBuilder,
                onStoryPosted: widget.onStoryPosted,
                errorWidget: widget.mediaErrorWidget,
                publishBuilder: widget.publishBuilder,
                storyController: widget.storyController,
                loadingWidget: widget.mediaLoadingWidget,
                overlayInfoBuilder: widget.overlayInfoBuilder,
                resultToolsBuilder: widget.resultToolsBuilder,
                publisherController: widget.publisherController,
                closeButtonPosition: widget.closeButtonPosition,
                onStoryCollectionClosed: widget.onStoryCollectionClosed,
                onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
                backgroundBetweenStories: widget.backgroundBetweenStories,
              );
            },
          ),
        );
      },
    );
  }

  Stream<DocumentSnapshot> get _storiesStream => _firestore
      .collection(widget.settings.collectionDbName)
      .document(widget.settings.userId)
      .snapshots();
}
