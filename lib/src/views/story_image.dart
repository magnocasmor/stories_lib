import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:rxdart/subjects.dart';
import 'package:stories_lib/src/views/story_view.dart';

import '../configs/story_controller.dart';
import '../widgets/story_error.dart';
import '../widgets/story_loading.dart';

/// Utitlity to load image (gif, png, jpg, etc) media just once. Resource is
/// cached to disk with default configurations of [DefaultCacheManager].
class ImageLoader {
  final String url;

  final Map<String, dynamic> requestHeaders;

  final _state = BehaviorSubject<LoadState>()..add(LoadState.loading);

  ui.Codec _frames;

  ImageLoader(this.url, {this.requestHeaders});

  Future<ui.FrameInfo> get nextFrame async => await this._frames.getNextFrame();

  /// Load image from cache and/or download, depending on availability and age.
  Future<void> loadImage() async {
    try {
      this._state.add(LoadState.loading);

      final file =
          await DefaultCacheManager().getSingleFile(this.url, headers: this.requestHeaders);

      final imageBytes = file.readAsBytesSync();

      final codec = await PaintingBinding.instance.instantiateImageCodec(imageBytes);

      this._frames = codec;

      this._state.add(LoadState.success);
    } catch (e) {
      this._state.add(LoadState.failure);

      rethrow;
    }
  }
}

/// Widget to display animated gifs or still images. Shows a loader while image is being loaded.
///
/// Listens to playback states from [controller] to pause andforward animated media.
class StoryImage extends StatefulWidget {
  final BoxFit fit;
  final Widget errorWidget;
  final Widget loadingWidget;
  final ImageLoader imageLoader;
  final StoryController controller;

  StoryImage({
    Key key,
    @required this.imageLoader,
    this.controller,
    this.errorWidget,
    this.loadingWidget,
    this.fit = BoxFit.cover,
  }) : super(key: key ?? UniqueKey());

  /// Use this shorthand to fetch images/gifs from the provided [url]
  factory StoryImage.url({
    Key key,
    @required String url,
    Widget errorWidget,
    Widget loadingWidget,
    StoryController controller,
    BoxFit fit = BoxFit.cover,
    Map<String, dynamic> requestHeaders,
  }) {
    return StoryImage(
      key: key,
      fit: fit,
      controller: controller,
      errorWidget: errorWidget,
      loadingWidget: loadingWidget,
      imageLoader: ImageLoader(url, requestHeaders: requestHeaders),
    );
  }

  @override
  State<StatefulWidget> createState() => _StoryImageState();
}

class _StoryImageState extends State<StoryImage> {
  final frame = BehaviorSubject<ui.Image>();

  Timer timer;

  StreamSubscription<PlaybackState> subscription;

  @override
  void initState() {
    if (widget.controller != null) {
      this.subscription = widget.controller.playbackNotifier.listen(
        (playbackState) {
          // for the case of gifs we need to pause/play
          if (widget.imageLoader._frames == null) {
            return;
          }

          if (playbackState == PlaybackState.pause) {
            this.timer?.cancel();
          } else {
            forward();
          }
        },
      );
    }

    initializeImage();

    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    frame.close();
    subscription?.cancel();
    // widget.imageLoader.state.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
      stream: frame.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SizedBox.expand(
            child: RawImage(
              fit: widget.fit,
              image: snapshot.data,
              filterQuality: FilterQuality.high,
            ),
          );
        } else if (snapshot.hasError) {
          return widget.errorWidget ?? StoryError();
        } else {
          return widget.loadingWidget ?? StoryLoading();
        }
      },
    );
  }

  Future<void> initializeImage() async {
    widget.controller?.pause();

    await widget.imageLoader.loadImage().catchError(
      (e, s) {
        debugPrint(e);
        debugPrint(s);

        frame.addError(e);
      },
    );

    widget.controller?.play();

    forward();
  }

  void forward() async {
    this.timer?.cancel();

    if (widget.controller != null &&
        widget.controller.playbackNotifier.value == PlaybackState.pause) {
      return;
    }

    final nextFrame = await widget.imageLoader.nextFrame;

    frame.add(nextFrame.image);

    if (nextFrame.duration > Duration(milliseconds: 0)) {
      timer = Timer(nextFrame.duration, forward);
    }
  }
}
