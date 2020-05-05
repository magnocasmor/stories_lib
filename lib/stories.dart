import 'package:flutter/material.dart';
import 'package:stories_lib/stories_settings.dart';
import 'models/stories_collection.dart';
import 'package:stories_lib/settings.dart';
import 'package:stories_lib/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_helpers.dart';
import 'package:stories_lib/stories_collection_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

export 'stories_collection_view.dart';

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
  final EdgeInsets previewListPadding;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final _ItemBuilder placeholderBuilder;
  final VoidCallback onAllStoriesComplete;
  final StoryHeaderPosition headerPosition;
  final StoryPreviewBuilder previewBuilder;
  final StoryHeaderBuilder storyHeaderBuilder;
  final RouteTransitionsBuilder storyOpenTransition;
  final StoryPublisherPreviewBuilder publishStoryBuilder;

  Stories({
    @required this.settings,
    this.closeButton,
    this.publishStoryBuilder,
    this.previewBuilder,
    this.mediaErrorWidget,
    this.placeholderBuilder,
    this.previewListPadding,
    this.previewPlaceholder,
    this.storyHeaderBuilder,
    this.mediaLoadingWidget,
    this.storyOpenTransition,
    this.onAllStoriesComplete,
    this.repeat = false,
    this.inline = false,
    this.backgroundBetweenStories = Colors.black,
    this.headerPosition = StoryHeaderPosition.top,
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

          final storyPreviews = parseStoriesPreview(widget.settings.languageCode, stories);

          final myPreview = storyPreviews.firstWhere(
            (preview) => preview.storyId == widget.settings.userId,
            orElse: () => null,
          );

          final hasPublish = myPreview != null && myPreview.stories.isNotEmpty;

          storyPreviews.remove(myPreview);

          final hasNewPublish = hasPublish ? _hasNewStories(myPreview) : false;

          final myCoverImg =
              myPreview != null ? CachedNetworkImageProvider(myPreview.coverImg) : null;

          return _storiesList(
            itemCount: storyPreviews.length,
            myPreview:
                widget.publishStoryBuilder?.call(context, myCoverImg, hasPublish, hasNewPublish),
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
      child: CachedNetworkImage(
        imageUrl: story.coverImg,
        placeholder: (context, url) => widget.previewPlaceholder,
        imageBuilder: (context, image) {
          return widget.previewBuilder(
            context,
            image,
            story.title[widget.settings.languageCode],
            _hasNewStories(story),
          );
        },
        errorWidget: (context, url, error) => Icon(Icons.error),
      ),
      onTap: () async {
        Navigator.push(
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
                mediaErrorWidget: widget.mediaErrorWidget,
                mediaLoadingWidget: widget.mediaLoadingWidget,
                headerPosition: widget.headerPosition,
                progressBuilder: widget.storyHeaderBuilder,
                closeButton: widget.closeButton,
                closeButtonPosition: widget.closeButtonPosition,
                backgroundColorBetweenStories: widget.backgroundBetweenStories,
              );
            },
          ),
        );
      },
    );
  }

  Widget _storiesList({
    int itemCount,
    Widget myPreview,
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
          if (myPreview != null) myPreview,
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

    if (widget.settings.releases is List && widget.settings.releases.isNotEmpty)
      query = query.where('releases', arrayContainsAny: widget.settings.releases);

    return query.orderBy('last_update', descending: widget.settings.sortByDescUpdate).snapshots();
  }

  bool _hasNewStories(StoriesCollection collection) {
    return collection.stories.any(
      (s) =>
          isInIntervalToShow(s) &&
          (s.views?.every((v) => v["user_info"] != widget.settings.userId) ?? true),
    );
  }
}
