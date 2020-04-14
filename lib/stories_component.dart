import 'settings.dart';
import 'models/stories.dart';
import 'models/stories_data.dart';
import 'grouped_stories_view.dart';
import 'package:flutter/material.dart';
import 'models/stories_list_with_pressed.dart';
import 'components//stories_list_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

export 'grouped_stories_view.dart';

typedef ItemBuilder = Widget Function(BuildContext, int);

typedef StoryPreviewBuilder = Widget Function(BuildContext, ImageProvider, String, bool);

typedef HighlightBuilder = Widget Function(BuildContext, Widget);

class StoriesComponent extends StatefulWidget {
  /// the name of collection in Firestore
  String collectionDbName;

  /// the language of the stories
  String languageCode;

  /// highlight the most recent story user (story image preview)
  bool recentHighlight;
  Color recentHighlightColor;
  Radius recentHighlightRadius;

  /// preview images settings
  double iconWidth;
  double iconHeight;
  bool showTitleOnIcon = true;
  TextStyle iconTextStyle;
  EdgeInsets textInIconPadding;

  /// how long story lasts
  int imageStoryDuration;

  /// background color between stories
  Color backgroundColorBetweenStories;

  /// stories close button style
  Icon closeButtonIcon;
  Color closeButtonBackgroundColor;

  /// stories sorting order Descending
  bool sortingOrderDesc;

  /// callback to get data that stories screen was opened
  VoidCallback backFromStories;

  ProgressPosition progressPosition;
  bool repeat;
  bool inline;

  final EdgeInsets listPadding;
  final ItemBuilder placeholderBuilder;
  final EdgeInsets storyItemPadding;
  final StoryPreviewBuilder storyPreviewBuilder;
  final Alignment textInIconAlignment;

  StoriesComponent(
      {@required this.collectionDbName,
      this.listPadding,
      this.storyItemPadding,
      this.placeholderBuilder,
      this.storyPreviewBuilder,
      this.textInIconAlignment,
      this.recentHighlight = false,
      this.recentHighlightColor = Colors.deepOrange,
      this.recentHighlightRadius = const Radius.circular(15.0),
      this.iconWidth,
      this.iconHeight,
      this.showTitleOnIcon,
      this.iconTextStyle,
      this.textInIconPadding = const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      this.imageStoryDuration,
      this.backgroundColorBetweenStories,
      this.closeButtonIcon,
      this.closeButtonBackgroundColor,
      this.sortingOrderDesc = true,
      this.backFromStories,
      this.progressPosition = ProgressPosition.top,
      this.repeat = true,
      this.inline = false,
      this.languageCode = 'en'});

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
    return _storiesComponent(context);
  }

  Widget _storiesComponent(BuildContext context) {
    return Padding(
      padding: widget.listPadding ?? EdgeInsets.zero,
      child: StreamBuilder<QuerySnapshot>(
        stream: _storiesStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final stories = snapshot.data.documents;

            final List<Stories> storyWidgets = _storiesData.parseStoriesPreview(stories);

            _buildFuture(ModalRoute.of(context).settings.arguments);

            if (storyWidgets.isNotEmpty)
              return _storiesList(
                itemCount: stories.length,
                builder: (context, index) {
                  Stories story = storyWidgets[index];

                  return _storyItem(story, context, _storiesData.storiesIdsList);
                },
              );
            else
              return Container();
          } else {
            return _storiesList(
              itemCount: 4,
              builder: widget.placeholderBuilder ??
                  (context, index) {
                    return Container(
                      margin: widget.storyItemPadding,
                      child: StoriesListSkeletonAlone(),
                    );
                  },
            );
          }
        },
      ),
    );
  }

  Widget _storyItem(Stories story, BuildContext context, List<String> storiesIds) {
    return Padding(
      padding: widget.storyItemPadding ?? EdgeInsets.zero,
      child: GestureDetector(
        child: CachedNetworkImage(
          imageUrl: story.previewImage,
          placeholder: (context, url) => StoriesListSkeletonAlone(
            width: widget.iconWidth,
            height: widget.iconHeight,
          ),
          imageBuilder: (context, image) {
            if (widget.storyPreviewBuilder != null)
              return widget.storyPreviewBuilder(
                  context, image, story.previewTitle[widget.languageCode], widget.recentHighlight);
            else
              return Stack(
                children: <Widget>[
                  Container(
                    height: double.infinity,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0),
                      image: DecorationImage(
                        image: image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Align(
                    alignment: widget.textInIconAlignment ?? Alignment.bottomLeft,
                    child: Padding(
                      padding: widget.textInIconPadding ?? EdgeInsets.zero,
                      child: Text(
                        story.previewTitle[widget.languageCode],
                        style: widget.iconTextStyle,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ],
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
                backgroundColorBetweenStories: widget.backgroundColorBetweenStories,
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
      widget.backFromStories();
    }
  }
}
