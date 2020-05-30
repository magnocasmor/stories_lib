import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/story_controller.dart';
import '../utils/color_parser.dart';
import '../utils/progress_bar_data.dart';
import '../views/story_image.dart';
import '../views/story_video.dart';
import '../widgets/story_widget.dart';

part '../utils/story_wrap.dart';

enum LoadState { loading, success, failure }

/// Widget to display stories just like Whatsapp and Instagram. Can also be used
/// inline/inside [ListView] or [Column] just like Google News app. Comes with
/// gestures to pause, forward and go to previous page.
class StoryView extends StatefulWidget {
  /// The pages to displayed.
  final List<StoryWrap> stories;

  /// Callback for when a full cycle of story is shown. This will be called
  /// each time the full story completes when [repeat] is set to `true`.
  final VoidCallback onComplete;

  /// Calling when user tapped story left area on first story of collection.
  final VoidCallback onPreviousFirstStory;

  /// Callback for when a story is currently being shown.
  final ValueChanged<int> onShowing;

  /// Should the story be repeated forever?
  final bool repeat;

  /// If you would like to display the story as full-page, then set this to
  /// `false`. But in case you would display this as part of a page (eg. in
  /// a [ListView] or [Column]) then set this to `true`.
  final bool inline;

  final StoryController controller;

  final Widget Function(List<PageData>, int, Animation<double>) infoLayerBuilder;

  final Widget closeButton;

  final Alignment closeButtonPosition;

  StoryView({
    @required this.stories,
    this.controller,
    this.onComplete,
    this.onShowing,
    this.onPreviousFirstStory,
    this.repeat = false,
    this.inline = false,
    this.infoLayerBuilder,
    this.closeButton,
    this.closeButtonPosition,
  })  : assert(stories != null && stories.length > 0, "[storyItems] should not be null or empty"),
        assert(repeat != null),
        assert(inline != null);

  @override
  State<StatefulWidget> createState() {
    return _StoryViewState();
  }
}

class _StoryViewState extends State<StoryView> with TickerProviderStateMixin {
  Timer debouncer;

  Animation<double> animation;

  AnimationController animationController;

  StreamSubscription<PlaybackState> subscription;

  @override
  void initState() {
    widget.stories.forEach((story) {
      story.addListener(() => beginPlay());
    });

    final firstStory = currentStory;

    if (firstStory != null) {
      final currentPosition = widget.stories.indexOf(firstStory);

      widget.stories.sublist(currentPosition).forEach((s) => s.shown = false);
    } else {
      for (var s in widget.stories) s.shown = false;
    }

    play();

    if (widget.controller != null) {
      widget.controller.addListener(
        (playbackStatus) {
          if (playbackStatus == PlaybackState.play) {
            unpause();
          } else if (playbackStatus == PlaybackState.pause) {
            pause();
          }
        },
      ).then((subs) => subscription = subs);
    }

    super.initState();
  }

  @override
  void dispose() {
    debouncer?.cancel();
    animationController?.dispose();
    subscription?.cancel();
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

        /// Divide screen horizontally in 3 sections (left area, center area, right area).
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
        debouncer?.cancel();
        debouncer = null;

        controlUnpause();
      },
      child: Stack(
        children: <Widget>[
          currentView,
          if (widget.infoLayerBuilder != null)
            AnimatedOpacity(
              curve: Curves.easeInOutCubic,
              opacity: (animationController?.isAnimating ?? true) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: widget.infoLayerBuilder(
                widget.stories.map((it) => PageData(it.duration, it.shown)).toList(),
                widget.stories.indexOf(currentStory),
                animation,
              ),
            ),
          if (widget.closeButton != null)
            Align(
              alignment: widget.closeButtonPosition,
              child: widget.closeButton,
            ),
        ],
      ),
    );
  }

  Widget get currentView {
    return ChangeNotifierProvider.value(
      value: currentStory ?? widget.stories.last,
      child: currentStory?.view ?? widget.stories.last.view,
    );
  }

  StoryWrap get currentStory => widget.stories.firstWhere((s) => !s.shown, orElse: () => null);

  void play() {
    animationController?.dispose();

    final storyWrap = currentStory;

    if (widget.onShowing != null) {
      widget.onShowing(widget.stories.indexOf(storyWrap));
    }

    animationController = AnimationController(duration: storyWrap.duration, vsync: this);

    animationController.addStatusListener(
      (status) {
        if (status == AnimationStatus.completed) {
          storyWrap.shown = true;
          if (widget.stories.last != storyWrap) {
            beginPlay();
          } else {
            onComplete();
          }
        }
      },
    );

    animation = Tween(begin: 0.0, end: 1.0).animate(animationController);

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
      widget.stories.forEach((it) => it.shown = false);

      return beginPlay();
    } else {
      widget.onComplete?.call();
    }
  }

  void goBack() {
    animationController.stop();

    if (currentStory == null) {
      widget.stories.last.shown = false;
    }

    if (currentStory == widget.stories.first) {
      widget.onPreviousFirstStory?.call();

      widget.controller?.play();
    } else {
      widget.controller?.stop();

      currentStory.shown = false;

      int lastPos = widget.stories.indexOf(currentStory);

      final previous = widget.stories[lastPos - 1];

      previous.shown = false;

      beginPlay();
    }
  }

  void goForward() {
    final _current = this.currentStory;

    widget.controller?.stop();

    animationController.stop();

    if (_current != widget.stories.last) {
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
    animationController?.stop(canceled: false);
  }

  void unpause() {
    animationController?.forward();
  }

  void controlPause() {
    if (widget.controller != null) {
      widget.controller.pause();
    } else {
      pause();
    }

    setState(() {});
  }

  void controlUnpause() {
    if (widget.controller != null) {
      widget.controller.play();
    } else {
      unpause();
    }
    setState(() {});
  }
}
