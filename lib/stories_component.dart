import 'grouped_stories_view.dart';
import 'package:flutter/material.dart';
import 'models/stories_collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/utils/stories_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';

export 'grouped_stories_view.dart';

typedef ItemBuilder = Widget Function(BuildContext, int);

typedef StoryPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef HighlightBuilder = Widget Function(BuildContext, Widget);

class StoriesComponent extends StatefulWidget {
  final bool repeat;
  final bool inline;
  final String languageCode;
  final bool recentHighlight;
  final Widget closeButtonWidget;
  final bool sortingOrderDesc;
  final int imageStoryDuration;
  final EdgeInsets listPadding;
  final String collectionDbName;
  final Widget previewPlaceholder;
  final Alignment progressPosition;
  final EdgeInsets storyItemPadding;
  final VoidCallback onStoriesFinish;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final ItemBuilder placeholderBuilder;
  final ProgressBuilder progressBuilder;
  final StoryPreviewBuilder storyPreviewBuilder;

  StoriesComponent({
    @required this.collectionDbName,
    this.listPadding,
    this.progressBuilder,
    this.onStoriesFinish,
    this.closeButtonWidget,
    this.placeholderBuilder,
    this.previewPlaceholder,
    this.imageStoryDuration,
    this.storyPreviewBuilder,
    this.repeat = false,
    this.inline = false,
    this.languageCode = 'en',
    this.recentHighlight = false,
    this.sortingOrderDesc = true,
    this.storyItemPadding = EdgeInsets.zero,
    this.progressPosition = Alignment.topCenter,
    this.closeButtonPosition = Alignment.topRight,
    this.backgroundBetweenStories = Colors.black,
  });

  @override
  _StoriesComponentState createState() => _StoriesComponentState();
}

class _StoriesComponentState extends State<StoriesComponent> {
  bool _backStateAdditional = false;
  final _firestore = Firestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stories = snapshot.data.documents;

          final storyWidgets = parseStoriesPreview(widget.languageCode, stories);

          _buildFuture();

          if (storyWidgets.isNotEmpty)
            return _storiesList(
              itemCount: stories.length,
              builder: (context, index) {
                final story = storyWidgets[index];

                return _storyItem(context, story, storyIds(stories));
              },
            );
          else
            return Container();
        } else {
          return _storiesList(
            itemCount: 4,
            builder: (context, index) {
              return Container(
                margin: widget.storyItemPadding,
                child: widget.placeholderBuilder?.call(context, index),
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
    return Padding(
      padding: widget.storyItemPadding,
      child: GestureDetector(
        child: CachedNetworkImage(
          imageUrl: story.coverImg,
          placeholder: (context, url) => widget.previewPlaceholder,
          imageBuilder: (context, image) {
            return widget.storyPreviewBuilder(
              context,
              image,
              story.title[widget.languageCode],
              widget.recentHighlight,
            );
          },
          errorWidget: (context, url, error) => Icon(Icons.error),
        ),
        onTap: () async {
          _backStateAdditional = true;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => GroupedStoriesView(
                storiesIds: storyIds,
                repeat: widget.repeat,
                inline: widget.inline,
                selectedStoryId: story.storyId,
                languageCode: widget.languageCode,
                progressBuilder: widget.progressBuilder,
                progressPosition: widget.progressPosition,
                sortingOrderDesc: widget.sortingOrderDesc,
                collectionDbName: widget.collectionDbName,
                closeButtonWidget: widget.closeButtonWidget,
                imageStoryDuration: widget.imageStoryDuration,
                closeButtonPosition: widget.closeButtonPosition,
                backgroundColorBetweenStories: widget.backgroundBetweenStories,
              ),
              settings: RouteSettings(
                arguments: story.storyId,
              ),
            ),
            ModalRoute.withName('/'),
          );
        },
      ),
    );
  }

  ListView _storiesList({
    int itemCount,
    ItemBuilder builder,
  }) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      primary: false,
      padding: widget.listPadding,
      itemCount: itemCount,
      itemBuilder: builder,
    );
  }

  Stream<QuerySnapshot> get _storiesStream => _firestore
      .collection(widget.collectionDbName)
      .orderBy('date', descending: widget.sortingOrderDesc)
      .snapshots();

  Future<void> _buildFuture() async {
    final res = ModalRoute.of(context).settings.arguments;
    await Future.delayed(const Duration(seconds: 1));
    if (res == 'back_from_stories_view' && !_backStateAdditional) {
      widget.onStoriesFinish?.call();
    }
  }
}
