import 'dart:io';
import 'dart:async';
import 'story_view.dart';
import 'package:rxdart/subjects.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stories_lib/settings.dart';
import 'package:video_player/video_player.dart';
import 'package:stories_lib/story_controller.dart';
import 'package:stories_lib/components/story_error.dart';
import 'package:stories_lib/components/story_loading.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
      print(e);
      print(s);

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
            return widget.mediaErrorWidget ?? StoryError();
          }

          final state = snapshot.connectionState;

          switch (state) {
            case ConnectionState.done:
              return SafeArea(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: playerController.value.size?.width ?? 0,
                      height: playerController.value.size?.height ?? 0,
                      child: VideoPlayer(playerController),
                    ),
                  ),
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
  }

  void checkIfVideoFinished() {
    try {
      if (playerController.value.position.inSeconds == playerController.value.duration.inSeconds) {
        playerController.removeListener(checkIfVideoFinished);
      }
    } catch (e) {}
  }
}
