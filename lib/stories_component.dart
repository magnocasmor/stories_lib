import 'settings.dart';
import 'models/stories.dart';
import 'models/stories_data.dart';
import 'grouped_stories_view.dart';
import 'package:flutter/material.dart';
import 'models/stories_list_with_pressed.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final Icon closeButtonIcon;
  final bool sortingOrderDesc;
  final int imageStoryDuration;
  final EdgeInsets listPadding;
  final String collectionDbName;
  final Widget previewPlaceholder;
  final EdgeInsets storyItemPadding;
  final VoidCallback onStoriesFinish;
  final Color backgroundBetweenStories;
  final ItemBuilder placeholderBuilder;
  final Color closeButtonBackgroundColor;
  final ProgressPosition progressPosition;
  final StoryPreviewBuilder storyPreviewBuilder;

  StoriesComponent({
    @required this.collectionDbName,
    this.listPadding,
    this.closeButtonIcon,
    this.onStoriesFinish,
    this.placeholderBuilder,
    this.previewPlaceholder,
    this.imageStoryDuration,
    this.storyPreviewBuilder,
    this.closeButtonBackgroundColor,
    this.repeat = false,
    this.inline = false,
    this.recentHighlight = false,
    this.sortingOrderDesc = true,
    this.storyItemPadding = EdgeInsets.zero,
    this.progressPosition = ProgressPosition.top,
    this.backgroundBetweenStories = Colors.black,
    this.languageCode = 'en',
  }) : assert(listPadding is EdgeInsets);

  @override
  _StoriesComponentState createState() => _StoriesComponentState();
}

class _StoriesComponentState extends State<StoriesComponent> {
  StoriesData _storiesData;
  final _firestore = Firestore.instance;
  bool _backStateAdditional = false;

  @override
  void initState() {
    _storiesData = StoriesData(languageCode: widget.languageCode);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stories = snapshot.data.documents;

          final storyIds = _storiesData.storiesIdsList;

          final storyWidgets = _storiesData.parseStoriesPreview(stories);

          _buildFuture(ModalRoute.of(context).settings.arguments);

          if (storyWidgets.isNotEmpty)
            return _storiesList(
              itemCount: stories.length,
              builder: (context, index) {
                final story = storyWidgets[index];

                return _storyItem(story, context, storyIds);
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

  Widget _storyItem(Stories story, BuildContext context, List<String> storiesIds) {
    return Padding(
      padding: widget.storyItemPadding,
      child: GestureDetector(
        child: CachedNetworkImage(
          imageUrl: story.previewImage,
          placeholder: (context, url) => widget.previewPlaceholder,
          imageBuilder: (context, image) {
            return widget.storyPreviewBuilder(
              context,
              image,
              story.previewTitle[widget.languageCode],
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
                collectionDbName: widget.collectionDbName,
                languageCode: widget.languageCode,
                imageStoryDuration: widget.imageStoryDuration,
                progressPosition: widget.progressPosition,
                repeat: widget.repeat,
                inline: widget.inline,
                backgroundColorBetweenStories: widget.backgroundBetweenStories,
                closeButtonIcon: widget.closeButtonIcon,
                closeButtonBackgroundColor: widget.closeButtonBackgroundColor,
                sortingOrderDesc: widget.sortingOrderDesc,
              ),
              settings: RouteSettings(
                arguments: StoriesListWithPressed(
                  pressedStoryId: story.storyId,
                  storiesIdsList: storiesIds,
                ),
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

  Future<void> _buildFuture(String res) async {
    await Future.delayed(const Duration(seconds: 1));
    if (res == 'back_from_stories_view' && !_backStateAdditional) {
      widget.onStoriesFinish();
    }
  }
}
