import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stories_lib/components/attachment_widget.dart';
import 'package:stories_lib/utils/story_types.dart';
import 'package:stories_lib/views/story_publisher.dart';
import 'package:stories_lib/utils/stories_helpers.dart';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/models/stories_collection.dart';
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

  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  final Alignment closeButtonPosition;

  /// Widget displayed when media fails to load.
  final Widget mediaError;

  /// Widget displayed while media load.
  final Widget mediaPlaceholder;

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
  final VoidCallback onAllStoriesComplete;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;

  Stories({
    @required this.settings,
    this.storyController,
    this.myStoriesPreview,
    this.onAllStoriesComplete,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.closeButton,
    this.closeButtonPosition = Alignment.topRight,
    this.mediaError,
    this.mediaPlaceholder,
    this.backgroundBetweenStories = Colors.black,
    this.infoLayerBuilder,
    this.previewBuilder,
    this.previewPlaceholder,
    this.previewListPadding,
    this.navigationTransition,
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
            transitionsBuilder: widget.navigationTransition,
            pageBuilder: (context, anim, anim2) {
              return StoriesCollectionView(
                settings: widget.settings,
                backgroundBetweenStories: widget.backgroundBetweenStories,
                closeButton: widget.closeButton,
                closeButtonPosition: widget.closeButtonPosition,
                infoLayerBuilder: widget.infoLayerBuilder,
                mediaError: widget.mediaError,
                mediaPlaceholder: widget.mediaPlaceholder,
                navigationTransition: widget.navigationTransition,
                storyController: widget.storyController,
                storiesIds: storyIds,
                selectedStoryId: story.storyId,
                onStoryCollectionClosed: widget.onStoryCollectionClosed,
                onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
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
  final StoriesSettings settings;
  final VoidCallback onStoryPosted;

  /// The button that close the layers of the Stories with [Navigator.pop()].
  final Widget closeButton;

  final Alignment closeButtonPosition;

  /// Widget displayed when media fails to load.
  final Widget mediaError;

  /// Widget displayed while media load.
  final Widget mediaPlaceholder;

  final Color backgroundBetweenStories;

  /// A overlay above the [StoryView] that shows information about the current story.
  final MyInfoLayerBuilder infoLayerBuilder;

  /// Show the stories preview.
  final MyStoriesPreviewBuilder myPreviewBuilder;

  /// Widget displayed while loading stories previews.
  final Widget previewPlaceholder;

  /// Build the button to publish stories.
  ///
  /// Provide the [StoryType] selected and [Animation] on video record.
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  ///
  /// If you want implements your own behavior, set the [defaultBehavior] to false and
  /// use [PublisherController].
  final TakeStoryBuilder takeStoryBuilder;

  /// A overlay above [StoryPublisher] where can put some interactions to manipulate the story.
  ///
  /// [StoryType] indicates the current selected type. When change type by calling [PublisherController.changeType]
  /// this widget will rebuild.
  ///
  /// The builder pass a [ExternalMediaCallback] to call when the user want send a external media.
  /// You can use [ImagePicker] plugin to take the file media.
  final PublishLayerBuilder publisherLayerBuilder;

  /// enable/disable the default behavior of the widget built by [takeStoryBuilder].
  ///
  /// By default, on tap this widget a story with the selected [StoryType] will be
  /// taked/record. In [StoryType.video] case, a second tap will be stop the record.
  final bool defaultBehavior;

  /// A overlay above the result of story taked in [_StoryPublisherResult].
  ///
  /// The [File] is a copy of the current story result. This can be used to save story in the device's storage.
  ///
  /// Provides a callback to insert [AttachmentWidget]. This widget is wrapped by [MultiGestureWidget]
  /// above the result and can be draggable, scalable and rotated.
  ///
  /// To delete a specific attachment, pass a list of attachments without the [AttachmentWidget]
  /// you want to delete.
  final ResultLayerBuilder resultInfoBuilder;

  /// A navigation transition when preview is tapped.
  final RouteTransitionsBuilder navigationTransition;
  final StoryController storyController;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;
  final PublisherController publisherController;

  MyStories({
    @required this.settings,
    this.onStoryPosted,
    this.storyController,
    this.publisherController,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.closeButton,
    this.closeButtonPosition = Alignment.topRight,
    this.mediaError,
    this.mediaPlaceholder,
    this.backgroundBetweenStories = Colors.black,
    this.infoLayerBuilder,
    this.myPreviewBuilder,
    this.previewPlaceholder,
    this.takeStoryBuilder,
    this.publisherLayerBuilder,
    this.defaultBehavior = true,
    this.resultInfoBuilder,
    this.navigationTransition,
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
                return widget.myPreviewBuilder?.call(context, image, hasPublish, hasNewPublish);
              },
              errorWidget: (context, url, error) {
                debugPrint(error.toString());
                return widget.myPreviewBuilder?.call(context, null, hasPublish, hasNewPublish);
              },
            )
          : widget.myPreviewBuilder?.call(context, null, hasPublish, hasNewPublish),
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

  Widget get publisher => StoryPublisher(
        settings: widget.settings,
        mediaError: widget.mediaError,
        closeButton: widget.closeButton,
        onStoryPosted: widget.onStoryPosted,
        storyController: widget.storyController,
        defaultBehavior: widget.defaultBehavior,
        mediaPlaceholder: widget.mediaPlaceholder,
        takeStoryBuilder: widget.takeStoryBuilder,
        resultInfoBuilder: widget.resultInfoBuilder,
        publisherController: widget.publisherController,
        closeButtonPosition: widget.closeButtonPosition,
        publisherLayerBuilder: widget.publisherLayerBuilder,
        onStoryCollectionClosed: widget.onStoryCollectionClosed,
        onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
        backgroundBetweenStories: widget.backgroundBetweenStories,
      );

  Widget get myStories => StoriesCollectionView(
        settings: widget.settings,
        mediaError: widget.mediaError,
        closeButton: widget.closeButton,
        storiesIds: [widget.settings.userId],
        storyController: widget.storyController,
        selectedStoryId: widget.settings.userId,
        mediaPlaceholder: widget.mediaPlaceholder,
        infoLayerBuilder: (i, t, d, b, c, a, v) =>
            widget.infoLayerBuilder(i, t, d, b, c, a, v, goToPublisher),
        closeButtonPosition: widget.closeButtonPosition,
        navigationTransition: widget.navigationTransition,
        onStoryCollectionClosed: widget.onStoryCollectionClosed,
        backgroundBetweenStories: widget.backgroundBetweenStories,
        onStoryCollectionOpenned: widget.onStoryCollectionOpenned,
      );

  Stream<DocumentSnapshot> get _storiesStream => _firestore
      .collection(widget.settings.collectionDbName)
      .document(widget.settings.userId)
      .snapshots();
}
