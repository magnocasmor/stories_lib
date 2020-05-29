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

  File _videoFile;

  VideoLoader(this.url, {this.requestHeaders});

  Future<File> loadVideo() async {
    try {
      if (this._videoFile == null) {
        final file = await DefaultCacheManager().getSingleFile(
          this.url,
          headers: this.requestHeaders,
        );
        this._videoFile = file;
      }

      _state.add(LoadState.success);

      return _videoFile;
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
  final Widget mediaErrorWidget;
  final VideoLoader videoLoader;
  final Widget mediaLoadingWidget;
  final StoryController controller;

  StoryVideo({
    Key key,
    @required this.videoLoader,
    this.controller,
    this.mediaErrorWidget,
    this.mediaLoadingWidget,
    this.fit = BoxFit.cover,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo url({
    Key key,
    String url,
    BoxFit videoFit,
    Widget mediaErrorWidget,
    Widget mediaLoadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
  }) {
    return StoryVideo(
      key: key,
      fit: videoFit,
      controller: controller,
      mediaErrorWidget: mediaErrorWidget,
      mediaLoadingWidget: mediaLoadingWidget,
      videoLoader: VideoLoader(url, requestHeaders: requestHeaders),
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _StoryVideoState();
  }
}

class _StoryVideoState extends State<StoryVideo> {
  StreamSubscription streamSubscription;

  VideoPlayerController playerController;

  @override
  void dispose() {
    playerController?.dispose();
    streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<void>(
        future: initializeController(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            widget.controller.play();
            return widget.mediaErrorWidget ?? StoryError();
          }

          final state = snapshot.connectionState;

          switch (state) {
            case ConnectionState.done:
              return SafeArea(
                child: FittedContainer(
                  fit: widget.fit,
                  width: playerController.value.size?.width ?? 0,
                  height: playerController.value.size?.height ?? 0,
                  child: VideoPlayer(playerController),
                ),
              );
              break;
            default:
              return widget.mediaLoadingWidget ?? StoryLoading();
              break;
          }
        },
      ),
    );
  }

  Future<void> initializeController() async {
    try {
      if (playerController is VideoPlayerController && playerController.value.initialized) return;

      widget.controller?.pause();

      final videoFile = await widget.videoLoader.loadVideo();

      this.playerController = VideoPlayerController.file(videoFile);

      await playerController.initialize();

      Provider.of<StoryItem>(context, listen: false).duration = playerController.value.duration;

      widget.controller.play();

      if (widget.controller != null) {
        playerController.addListener(checkIfVideoFinished);
        streamSubscription = widget.controller.playbackNotifier.listen((playbackState) {
          if (playbackState == PlaybackState.play) {
            playerController.play();
          } else {
            playerController.pause();
            if (playbackState == PlaybackState.stop) streamSubscription.cancel();
          }
        });
      }
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }
  }

  void checkIfVideoFinished() {
    try {
      if (playerController.value.position.inSeconds == playerController.value.duration.inSeconds) {
        playerController.removeListener(checkIfVideoFinished);
      }
    } catch (e) {}
  }
}
