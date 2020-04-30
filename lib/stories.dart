import 'package:flutter/material.dart';
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

class Stories extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final String userId;
  final Widget closeButton;
  final String languageCode;
  final bool sortingOrderDesc;
  final List<String> releases;
  final Duration storyDuration;
  final Widget mediaErrorWidget;
  final String collectionDbName;
  final Widget mediaLoadingWidget;
  final Widget previewPlaceholder;
  final Duration storyTimeValidaty;
  final EdgeInsets previewListPadding;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final _ItemBuilder placeholderBuilder;
  final VoidCallback onAllStoriesComplete;
  final StoryHeaderPosition headerPosition;
  final StoryPreviewBuilder previewBuilder;
  final StoryHeaderBuilder storyHeaderBuilder;
  final RouteTransitionsBuilder storyOpenTransition;

  Stories({
    @required this.collectionDbName,
    this.userId,
    this.releases,
    this.closeButton,
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
    this.languageCode = 'pt',
    this.sortingOrderDesc = true,
    this.backgroundBetweenStories = Colors.black,
    this.headerPosition = StoryHeaderPosition.top,
    this.closeButtonPosition = Alignment.topRight,
    this.storyDuration = const Duration(seconds: 3),
    this.storyTimeValidaty = const Duration(hours: 12),
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

          final storyWidgets = parseStoriesPreview(widget.languageCode, stories);

          if (storyWidgets.isNotEmpty)
            return _storiesList(
              itemCount: stories.length,
              builder: (context, index) {
                final story = storyWidgets[index];

                return _storyItem(context, story, storyIds(stories));
              },
            );
          else
            return LimitedBox();
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
              return Padding(
                padding: widget.previewListPadding,
                child: widget.placeholderBuilder?.call(context, index) ?? LimitedBox(),
              );
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
            story.title[widget.languageCode],
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
                userId: widget.userId,
                selectedStoryId: story.storyId,
                languageCode: widget.languageCode,
                mediaErrorWidget: widget.mediaErrorWidget,
                mediaLoadingWidget: widget.mediaLoadingWidget,
                headerPosition: widget.headerPosition,
                progressBuilder: widget.storyHeaderBuilder,
                // sortingOrderDesc: widget.sortingOrderDesc,
                collectionDbName: widget.collectionDbName,
                closeButton: widget.closeButton,
                storyDuration: widget.storyDuration,
                closeButtonPosition: widget.closeButtonPosition,
                backgroundColorBetweenStories: widget.backgroundBetweenStories,
              );
            },
            settings: RouteSettings(
              arguments: story.storyId,
            ),
          ),
        );
      },
    );
  }

  ListView _storiesList({
    int itemCount,
    _ItemBuilder builder,
  }) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      primary: false,
      padding: widget.previewListPadding,
      itemCount: itemCount,
      itemBuilder: builder,
    );
  }

  Stream<QuerySnapshot> get _storiesStream {
    var query = _firestore.collection(widget.collectionDbName).where(
          'last_update',
          isGreaterThanOrEqualTo: DateTime.now().subtract(widget.storyTimeValidaty),
        );

    if (widget.releases is List && widget.releases.isNotEmpty)
      query = query.where('releases', arrayContainsAny: widget.releases);

    return query
        .orderBy('last_update', descending: widget.sortingOrderDesc)
        // .getDocuments()
        // .asStream();
        .snapshots();
  }

  bool _hasNewStories(StoriesCollection collection) {
    return collection.stories.any(
      (s) =>
          isInIntervalToShow(s) && (s.views?.every((v) => v["user_info"] != widget.userId) ?? true),
    );
  }
}
