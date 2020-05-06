import 'dart:ui';
import 'dart:async';
import 'settings.dart';
import 'story_video.dart';
import 'story_image.dart';
import 'story_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stories_lib/stories.dart';
import 'package:stories_lib/utils/color_parser.dart';
import 'package:stories_lib/components/story_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

export 'story_image.dart';
export 'story_video.dart';
export 'story_controller.dart';

typedef StoryHeaderBuilder = Widget Function(
  BuildContext context,
  int currentIndex,
  ImageProvider image,
  String title,
  DateTime postDate,
  List<PageData> pageData,
  Animation animation,
);

/// This is a representation of a story item (or page).
class StoryItem extends ChangeNotifier {
  final String storyId;

  final String storyPreviewImg;

  final String storyTitle;

  final DateTime postDate;

  /// Specifies how long the page should be displayed. It should be a reasonable
  /// amount of time greater than 0 milliseconds.
  Duration _duration;

  /// Has this page been shown already? This is used to indicate that the page
  /// has been displayed. If some pages are supposed to be skipped in a story,
  /// mark them as shown `shown = true`.
  ///
  /// However, during initialization of the story view, all pages after the
  /// last unshown page will have their `shown` attribute altered to false. This
  /// is because the next item to be displayed is taken by the last unshown
  /// story item.
  bool shown;

  /// The page content
  final Widget view;

  StoryItem({
    @required this.view,
    @required this.storyId,
    @required this.postDate,
    this.storyTitle,
    this.storyPreviewImg,
    Duration duration = const Duration(seconds: 3),
    this.shown = false,
  })  : assert(duration != null, "[duration] should not be null"),
        _duration = duration;

  /// Short hand to create text-only page.
  ///
  /// [text] is the text to be displayed on [backgroundColor]. The text color
  /// alternates between [Colors.black] and [Colors.white] depending on the
  /// calculated contrast. This is to ensure readability of text.
  ///
  /// Works for inline and full-page stories. See [StoryView.inline] for more on
  /// what inline/full-page means.
  static StoryItem text({
    @required String text,
    @required String storyId,
    @required Color backgroundColor,
    TextStyle style,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    bool shown = false,
    bool roundedTop = false,
    bool roundedBottom = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    assert(text is String, "[title] should not be null");
    if (backgroundColor == null) backgroundColor = Colors.black;

    final _contrast = contrast([
      backgroundColor.red,
      backgroundColor.green,
      backgroundColor.blue,
    ], [
      255,
      255,
      255
    ] /** white text */);

    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundedTop ? 8 : 0),
            bottom: Radius.circular(roundedBottom ? 8 : 0),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Center(
          child: Text(
            text,
            style: (style ?? TextStyle())
                .copyWith(color: _contrast > 1.8 ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        //color: backgroundColor,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for a full-page image content.
  ///
  /// You can provide any image provider for [image].
  static StoryItem pageImage({
    @required String storyId,
    @required ImageProvider image,
    String caption,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    bool shown = false,
    BoxFit imageFit = BoxFit.fitHeight,
    Duration duration = const Duration(seconds: 3),
  }) {
    assert(imageFit != null, "[imageFit] should not be null");
    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: StoryWidget(
        story: Image(
          image: image,
          fit: imageFit,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for creating inline image page.
  static StoryItem inlineImage({
    @required String storyId,
    @required ImageProvider image,
    Text caption,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    bool shown = false,
    bool roundedTop = true,
    bool roundedBottom = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: Container(
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(roundedTop ? 8 : 0),
              bottom: Radius.circular(roundedBottom ? 8 : 0),
            ),
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
            )),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 16,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 8,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              child: caption == null ? SizedBox() : caption,
              width: double.infinity,
            ),
          ),
        ),
      ),
      shown: shown,
      duration: duration,
    );
  }

  static StoryItem pageGif({
    @required String url,
    @required String storyId,
    String caption,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    bool shown = false,
    BoxFit imageFit = BoxFit.fitHeight,
    Duration duration = const Duration(seconds: 3),
  }) {
    assert(imageFit != null, "[imageFit] should not be null");
    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: StoryWidget(
        story: StoryImage.url(
          url: url,
          fit: imageFit,
          controller: controller,
          requestHeaders: requestHeaders,
          mediaErrorWidget: mediaErrorWidget,
          mediaLoadingWidget: mediaLoadingWidget,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for creating inline image page.
  static StoryItem inlineGif({
    @required String url,
    @required String storyId,
    Text caption,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    bool shown = false,
    bool roundedTop = true,
    bool roundedBottom = false,
    BoxFit imageFit = BoxFit.cover,
    Duration duration = const Duration(seconds: 3),
  }) {
    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundedTop ? 8 : 0),
            bottom: Radius.circular(roundedBottom ? 8 : 0),
          ),
        ),
        child: Container(
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              StoryImage.url(
                url: url,
                controller: controller,
                fit: imageFit,
                mediaErrorWidget: mediaErrorWidget,
                mediaLoadingWidget: mediaLoadingWidget,
                requestHeaders: requestHeaders,
              ),
              caption.data != null && caption.data.length > 0
                  ? Container(
                      margin: EdgeInsets.only(
                        bottom: 16,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          child: caption == null ? SizedBox() : caption,
                          width: double.infinity,
                        ),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
      shown: shown,
      duration: duration,
    );
  }

  static StoryItem pageVideo({
    @required String url,
    @required String storyId,
    String caption,
    String storyTitle,
    DateTime postDate,
    String storyPreviewImg,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    StoryController controller,
    bool shown = false,
    BoxFit videoFit = BoxFit.fitHeight,
    Map<String, dynamic> requestHeaders,
    Duration duration = const Duration(seconds: 10),
  }) {
    assert(videoFit != null, "[videoFit] should not be null");
    return StoryItem(
      storyId: storyId,
      postDate: postDate,
      storyTitle: storyTitle,
      storyPreviewImg: storyPreviewImg,
      view: StoryWidget(
        story: StoryVideo.url(
          url: url,
          videoFit: videoFit,
          controller: controller,
          requestHeaders: requestHeaders,
          mediaErrorWidget: mediaErrorWidget,
          mediaLoadingWidget: mediaLoadingWidget,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  Duration get duration => _duration;

  /// Whatever duration changes, notify listeners
  set duration(Duration d) {
    _duration = d;
    notifyListeners();
  }
}

/// Widget to display stories just like Whatsapp and Instagram. Can also be used
/// inline/inside [ListView] or [Column] just like Google News app. Comes with
/// gestures to pause, forward and go to previous page.
class StoryView extends StatefulWidget {
  /// The pages to displayed.
  final List<StoryItem> storyItems;

  /// Callback for when a full cycle of story is shown. This will be called
  /// each time the full story completes when [repeat] is set to `true`.
  final VoidCallback onComplete;

  final VoidCallback previousOnFirstStory;

  final StoryHeaderBuilder headerBuilder;

  /// Callback for when a story is currently being shown.
  final ValueChanged<StoryItem> onStoryShow;

  /// Where the progress indicator should be placed.
  final StoryHeaderPosition headerPosition;

  /// Should the story be repeated forever?
  final bool repeat;

  /// If you would like to display the story as full-page, then set this to
  /// `false`. But in case you would display this as part of a page (eg. in
  /// a [ListView] or [Column]) then set this to `true`.
  final bool inline;

  final StoryController controller;

  StoryView({
    @required this.storyItems,
    this.controller,
    this.onComplete,
    this.onStoryShow,
    this.headerBuilder,
    this.previousOnFirstStory,
    this.repeat = false,
    this.inline = false,
    this.headerPosition = StoryHeaderPosition.top,
  })  : assert(storyItems != null && storyItems.length > 0,
            "[storyItems] should not be null or empty"),
        assert(headerPosition != null, "[progressPosition] cannot be null"),
        assert(repeat != null, "[repeat] cannot be null"),
        assert(inline != null, "[inline] cannot be null");

  @override
  State<StatefulWidget> createState() {
    return _StoryViewState();
  }
}

class _StoryViewState extends State<StoryView> with TickerProviderStateMixin {
  Timer debouncer;
  Animation<double> currentAnimation;
  AnimationController animationController;
  StreamSubscription<PlaybackState> playbackSubscription;

  @override
  void initState() {
    widget.storyItems.forEach((story) {
      story.addListener(() {
        beginPlay();
      });
    });

    final firstStory = currentStory;

    if (firstStory == null) {
      widget.storyItems.forEach((it) {
        it.shown = false;
      });
    } else {
      final currentPosition = widget.storyItems.indexOf(firstStory);
      widget.storyItems.sublist(currentPosition).forEach((it) {
        it.shown = false;
      });
    }

    play();

    if (widget.controller != null) {
      playbackSubscription = widget.controller.playbackNotifier.listen(
        (playbackStatus) {
          if (playbackStatus == PlaybackState.play) {
            unpause();
          } else if (playbackStatus == PlaybackState.pause) {
            pause();
          }
        },
      );
    }

    super.initState();
  }

  @override
  void dispose() {
    debouncer?.cancel();
    animationController?.dispose();
    playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        controlPause();
      },
      onTapUp: (details) {
        final displayWidth = MediaQuery.of(context).size.width;
        final displaySection = displayWidth / 3;

        final touchDx = details.globalPosition.dx;
        if (touchDx <= displaySection) {
          goBack();
        } else if (touchDx >= displaySection * 2) {
          goForward();
        } else {
          controlUnpause();
          // nothing
        }
      },
      onLongPressStart: (details) {
        controlPause();
        debouncer?.cancel();
        debouncer = Timer(Duration(milliseconds: 500), () {});
      },
      onLongPressEnd: (details) {
        if (debouncer?.isActive == true) {
          debouncer.cancel();
          debouncer = null;

          controlUnpause();
        } else {
          debouncer.cancel();
          debouncer = null;

          controlUnpause();
        }
      },
      child: Stack(
        children: <Widget>[
          currentView,
          Align(
            alignment: widget.headerPosition == StoryHeaderPosition.top
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: widget.headerBuilder?.call(
                    context,
                    widget.storyItems.indexOf(currentStory),
                    CachedNetworkImageProvider(currentStory.storyPreviewImg),
                    currentStory.storyTitle,
                    currentStory.postDate,
                    widget.storyItems.map((it) => PageData(it.duration, it.shown)).toList(),
                    this.currentAnimation,
                  ) ??
                  PageBar(
                    widget.storyItems.map((it) => PageData(it.duration, it.shown)).toList(),
                    this.currentAnimation,
                    key: UniqueKey(),
                    indicatorHeight: widget.inline ? IndicatorHeight.small : IndicatorHeight.large,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  StoryItem get currentStory => widget.storyItems.firstWhere((it) => !it.shown, orElse: () => null);

  void play() {
    animationController?.dispose();

    final storyItem = currentStory;

    if (widget.onStoryShow != null) {
      widget.onStoryShow(storyItem);
    }

    animationController = AnimationController(duration: storyItem.duration, vsync: this);

    animationController.addStatusListener(
      (status) {
        if (status == AnimationStatus.completed) {
          storyItem.shown = true;
          if (widget.storyItems.last != storyItem) {
            beginPlay();
          } else {
            // done playing
            onComplete();
          }
        }
      },
    );

    currentAnimation = Tween(begin: 0.0, end: 1.0).animate(animationController);
    animationController.forward();
    widget.controller.play();
  }

  void beginPlay() {
    setState(() {});
    play();
  }

  void onComplete() {
    widget.controller?.stop();
    if (widget.repeat) {
      widget.storyItems.forEach((it) {
        it.shown = false;
      });

      return beginPlay();
    } else {
      if (widget.onComplete != null) {
        widget.onComplete();
      } else {
        print("Done");
      }
    }
  }

  void goBack() {
    animationController.stop();

    if (this.currentStory == null) {
      widget.storyItems.last.shown = false;
    }

    if (this.currentStory == widget.storyItems.first) {
      widget.previousOnFirstStory?.call();
      widget.controller?.play();
      // beginPlay();
    } else {
      widget.controller?.stop();

      this.currentStory.shown = false;
      int lastPos = widget.storyItems.indexOf(this.currentStory);
      final previous = widget.storyItems[lastPos - 1];

      previous.shown = false;

      beginPlay();
    }
  }

  void goForward() {
    final _current = this.currentStory;

    widget.controller?.stop();

    animationController.stop();
    if (_current != widget.storyItems.last) {
      if (_current != null) {
        _current.shown = true;
        beginPlay();
      }
    } else {
      // this is the last page, progress animation should skip to end
      animationController.forward(from: 1.0);
    }
  }

  void pause() {
    this.animationController?.stop(canceled: false);
  }

  void unpause() {
    this.animationController?.forward();
  }

  void controlPause() {
    if (widget.controller != null) {
      widget.controller.pause();
    } else {
      pause();
    }
  }

  void controlUnpause() {
    if (widget.controller != null) {
      widget.controller.play();
    } else {
      unpause();
    }
  }

  Widget get currentView => ChangeNotifierProvider.value(
        value: currentStory ?? widget.storyItems.last,
        child: currentStory?.view ?? widget.storyItems.last.view,
      );
}

/// Capsule holding the duration and shown property of each story. Passed down
/// to the pages bar to render the page indicators.
class PageData {
  final bool shown;
  final Duration duration;

  PageData(this.duration, this.shown);
}

/// Horizontal bar displaying a row of [StoryProgressIndicator] based on the
/// [pages] provided.
class PageBar extends StatefulWidget {
  final List<PageData> pages;
  final Animation<double> animation;
  final IndicatorHeight indicatorHeight;

  PageBar(
    this.pages,
    this.animation, {
    this.indicatorHeight = IndicatorHeight.large,
    Key key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PageBarState();
  }
}

class PageBarState extends State<PageBar> {
  double spacing = 4;

  @override
  void initState() {
    super.initState();

    int count = widget.pages.length;
    spacing = count > 15 ? 1 : count > 10 ? 2 : 4;
  }

  bool isPlaying(PageData page) {
    return widget.pages.firstWhere((it) => !it.shown, orElse: () => null) == page;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: widget.pages.map(
        (it) {
          return Expanded(
            child: Container(
              padding: EdgeInsets.only(right: widget.pages.last == it ? 0 : this.spacing),
              child: AnimatedBuilder(
                  animation: widget.animation,
                  builder: (context, snapshot) {
                    return StoryProgressIndicator(
                      isPlaying(it) ? widget.animation.value : it.shown ? 1 : 0,
                      indicatorHeight: widget.indicatorHeight == IndicatorHeight.large ? 5 : 3,
                    );
                  }),
            ),
          );
        },
      ).toList(),
    );
  }
}

/// Custom progress bar. Supposed to be lighter than the
/// original [ProgressIndicator], and rounded at the sides.
class StoryProgressIndicator extends StatelessWidget {
  /// From `0.0` to `1.0`, determines the progress of the indicator
  final double value;
  final double indicatorHeight;

  StoryProgressIndicator(
    this.value, {
    this.indicatorHeight = 5,
  }) : assert(indicatorHeight != null && indicatorHeight > 0,
            "[indicatorHeight] should not be null or less than 1");

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.fromHeight(
        this.indicatorHeight,
      ),
      foregroundPainter: IndicatorOval(
        Colors.grey.withOpacity(0.8),
        this.value,
      ),
      painter: IndicatorOval(
        Colors.white.withOpacity(0.4),
        1.0,
      ),
    );
  }
}

class IndicatorOval extends CustomPainter {
  final Color color;
  final double widthFactor;

  IndicatorOval(this.color, this.widthFactor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = this.color;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * this.widthFactor, size.height), Radius.circular(3)),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
