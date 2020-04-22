import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:rxdart/subjects.dart';
import 'package:stories_lib/utils/load_state.dart';

import 'story_controller.dart';

/// Utitlity to load image (gif, png, jpg, etc) media just once. Resource is
/// cached to disk with default configurations of [DefaultCacheManager].
class ImageLoader {
  ui.Codec _frames;

  String url;

  Map<String, dynamic> requestHeaders;

  final state = BehaviorSubject<LoadState>()..add(LoadState.loading); // by default

  ImageLoader(this.url, {this.requestHeaders});

  /// Load image from disk cache first, if not found then load from network.
  /// `onComplete` is called when [imageBytes] become available.
  Future<void> loadImage() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(this.url, headers: this.requestHeaders);

      if (_frames == null) {
        final imageBytes = file.readAsBytesSync();

        this.state.add(LoadState.success);

        final codec = await PaintingBinding.instance.instantiateImageCodec(imageBytes);

        this._frames = codec;
      }

      this.state.add(LoadState.success);
    } catch (e) {
      this.state.add(LoadState.failure);

      rethrow;
    }
  }

  Future<ui.FrameInfo> get nextFrame => this._frames.getNextFrame();
}

/// Widget to display animated gifs or still images. Shows a loader while image
/// is being loaded. Listens to playback states from [controller] to pause and
/// forward animated media.
class StoryImage extends StatefulWidget {
  final ImageLoader imageLoader;

  final BoxFit fit;

  final StoryController controller;

  StoryImage(
    this.imageLoader, {
    Key key,
    this.controller,
    this.fit,
  }) : super(key: key ?? UniqueKey());

  /// Use this shorthand to fetch images/gifs from the provided [url]
  static StoryImage url(
    String url, {
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    BoxFit fit = BoxFit.fitWidth,
    Key key,
  }) {
    return StoryImage(
        ImageLoader(
          url,
          requestHeaders: requestHeaders,
        ),
        controller: controller,
        fit: fit,
        key: key);
  }

  @override
  State<StatefulWidget> createState() => StoryImageState();
}

class StoryImageState extends State<StoryImage> {
  final streamFrame = BehaviorSubject<ui.Image>();

  Timer _timer;

  StreamSubscription<PlaybackState> _streamSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      this._streamSubscription = widget.controller.playbackNotifier.listen((playbackState) {
        // for the case of gifs we need to pause/play
        if (widget.imageLoader._frames == null) {
          return;
        }

        if (playbackState == PlaybackState.pause) {
          this._timer?.cancel();
        } else {
          forward();
        }
      });
    }

    initializeImage();
  }

  @override
  void dispose() {
    _timer?.cancel();
    streamFrame.close();
    _streamSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: contentView());
  }

  Widget contentView() {
    return StreamBuilder<Object>(
      stream: streamFrame.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
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
          return SizedBox(
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
    this._timer?.cancel();

    if (widget.controller != null &&
        widget.controller.playbackNotifier.value == PlaybackState.pause) {
      return;
    }

    final nextFrame = await widget.imageLoader.nextFrame;

    this.streamFrame.add(nextFrame.image);

    if (nextFrame.duration > Duration(milliseconds: 0)) {
      this._timer = Timer(nextFrame.duration, forward);
    }
  }
}
