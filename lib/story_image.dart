import 'dart:async';
import 'dart:ui' as ui;
import 'story_controller.dart';
import 'package:rxdart/subjects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:stories_lib/settings.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Utitlity to load image (gif, png, jpg, etc) media just once. Resource is
/// cached to disk with default configurations of [DefaultCacheManager].
class ImageLoader {
  final String url;

  final Map<String, dynamic> requestHeaders;

  final _state = BehaviorSubject<LoadState>()..add(LoadState.loading); // by default

  ui.Codec _frames;

  ImageLoader(this.url, {this.requestHeaders});

  /// Load image from disk cache first, if not found then load from network.
  /// `onComplete` is called when [imageBytes] become available.
  Future<void> loadImage() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(this.url, headers: this.requestHeaders);

      final imageBytes = file.readAsBytesSync();

      this._state.add(LoadState.success);

      final codec = await PaintingBinding.instance.instantiateImageCodec(imageBytes);

      this._frames = codec;

      this._state.add(LoadState.success);
    } catch (e) {
      this._state.add(LoadState.failure);

      rethrow;
    }
  }

  Future<ui.FrameInfo> get nextFrame => this._frames.getNextFrame();
}

/// Widget to display animated gifs or still images. Shows a loader while image
/// is being loaded. Listens to playback states from [controller] to pause and
/// forward animated media.
class StoryImage extends StatefulWidget {
  final BoxFit fit;
  final ImageLoader imageLoader;
  final Widget mediaErrorWidget;
  final Widget mediaLoadingWidget;
  final StoryController controller;

  StoryImage({
    Key key,
    @required this.imageLoader,
    this.fit,
    this.controller,
    this.mediaErrorWidget,
    this.mediaLoadingWidget,
  }) : super(key: key ?? UniqueKey());

  /// Use this shorthand to fetch images/gifs from the provided [url]
  factory StoryImage.url({
    Key key,
    String url,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    StoryController controller,
    BoxFit fit = BoxFit.fitWidth,
    Map<String, dynamic> requestHeaders,
  }) {
    return StoryImage(
      key: key,
      fit: fit,
      controller: controller,
      mediaErrorWidget: mediaErrorWidget,
      mediaLoadingWidget: mediaLoadingWidget,
      imageLoader: ImageLoader(url, requestHeaders: requestHeaders),
    );
  }

  @override
  State<StatefulWidget> createState() => _StoryImageState();
}

class _StoryImageState extends State<StoryImage> {
  final streamFrame = BehaviorSubject<ui.Image>();

  Timer timer;

  StreamSubscription<PlaybackState> streamSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      this.streamSubscription = widget.controller.playbackNotifier.listen(
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
  }

  @override
  void dispose() {
    timer?.cancel();
    streamFrame.close();
    streamSubscription?.cancel();
    // widget.imageLoader.state.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
      stream: streamFrame.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.mediaErrorWidget ??
              Text(
                "Image failed to load.",
                style: TextStyle(
                  color: Colors.white,
                ),
              );
        } else if (snapshot.hasData) {
          return SizedBox.expand(
            child: RawImage(
              image: snapshot.data,
              fit: widget.fit,
            ),
          );
        } else {
          return widget.mediaLoadingWidget ??
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              );
        }
      },
    );
  }

  Future<void> initializeImage() async {
    widget.controller?.pause();

    await widget.imageLoader.loadImage().catchError((e, s) {
      print(e);
      print(s);

      streamFrame.addError(e);
    });

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

    this.streamFrame.add(nextFrame.image);

    if (nextFrame.duration > Duration(milliseconds: 0)) {
      this.timer = Timer(nextFrame.duration, forward);
    }
  }
}
