import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/subjects.dart';
import 'package:video_player/video_player.dart';

import '../configs/story_controller.dart';
import '../views/story_view.dart';
import '../widgets/fitted_container.dart';
import '../widgets/story_error.dart';
import '../widgets/story_loading.dart';

class VideoLoader {
  final String url;

  final Map<String, dynamic> requestHeaders;

  final _state = BehaviorSubject<LoadState>()..add(LoadState.loading);

  File _file;

  VideoLoader(this.url, {this.requestHeaders});

  /// Load image from cache and/or download, depending on availability and age.
  Future<File> loadVideo() async {
    try {
      if (_file == null) {
        final file = await DefaultCacheManager().getSingleFile(
          url,
          headers: requestHeaders,
        );

        _file = file;
      }

      _state.add(LoadState.success);

      return _file;
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());

      _state.add(LoadState.failure);

      rethrow;
    }
  }
}

class StoryVideo extends StatefulWidget {
  final BoxFit fit;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Color backgroundColor;
  final VideoLoader videoLoader;
  final StoryController controller;

  StoryVideo({
    Key key,
    @required this.videoLoader,
    this.controller,
    this.errorWidget,
    this.loadingWidget,
    this.fit = BoxFit.cover,
    this.backgroundColor = Colors.black,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo url({
    Key key,
    String url,
    Widget errorWidget,
    Widget loadingWidget,
    Color backgroundColor,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    BoxFit fit = BoxFit.cover,
  }) {
    return StoryVideo(
      key: key,
      fit: fit,
      controller: controller,
      errorWidget: errorWidget,
      loadingWidget: loadingWidget,
      backgroundColor: backgroundColor,
      videoLoader: VideoLoader(url, requestHeaders: requestHeaders),
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _StoryVideoState();
  }
}

class _StoryVideoState extends State<StoryVideo> {
  StreamSubscription subscription;

  VideoPlayerController playerController;

  @override
  void dispose() {
    playerController?.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializeController(),
      builder: (context, snapshot) {
        if (!snapshot.hasError) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              final ratio = playerController.value.aspectRatio;
              return DecoratedBox(
                decoration: BoxDecoration(color: widget.backgroundColor),
                child: FittedContainer(
                  fit: ratio <= 0.7
                      ? BoxFit.fitHeight
                      : (ratio >= 1.4 ? BoxFit.fitWidth : BoxFit.contain),
                  width: playerController.value.size.width,
                  height: playerController.value.size.height,
                  child: VideoPlayer(playerController),
                ),
              );
              break;
            default:
              return widget.loadingWidget ?? StoryLoading();
              break;
          }
        } else {
          widget.controller.play();
          return widget.errorWidget ?? StoryError();
        }
      },
    );
  }

  Future<void> initializeController() async {
    try {
      if (playerController is VideoPlayerController && playerController.value.isInitialized) return;

      widget.controller?.pause();

      final videoFile = await widget.videoLoader.loadVideo();

      this.playerController = VideoPlayerController.file(videoFile);

      await playerController.initialize();

      Provider.of<StoryWrap>(context, listen: false).duration = playerController.value.duration;

      widget.controller.play();

      if (widget.controller != null) {
        playerController.addListener(checkIfVideoFinished);

        widget.controller.addListener((playbackState) {
          if (playbackState == PlaybackState.play) {
            playerController.play();
          } else if (playbackState == PlaybackState.pause) {
            playerController.pause();
          } else if (playbackState == PlaybackState.stop) {
            playerController.pause();
            subscription.cancel();
          }
        }).then((subs) => subscription = subs);
      }
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }
  }

  void checkIfVideoFinished() {
    final position = playerController.value.position;
    final total = playerController.value.duration;

    if (position.compareTo(total) == 0) {
      playerController.removeListener(checkIfVideoFinished);
    }
  }
}
