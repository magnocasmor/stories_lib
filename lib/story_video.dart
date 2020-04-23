import 'dart:io';
import 'dart:async';
import 'story_view.dart';
import 'package:rxdart/subjects.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:stories_lib/story_controller.dart';
import 'package:stories_lib/utils/load_state.dart';
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
  final BoxFit videoFit;
  final Widget mediaErrorWidget;
  final VideoLoader videoLoader;
  final Widget mediaLoadingWidget;
  final StoryController storyController;

  StoryVideo({
    Key key,
    @required this.videoLoader,
    this.storyController,
    this.mediaErrorWidget,
    this.mediaLoadingWidget,
    this.videoFit = BoxFit.cover,
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
      videoFit: videoFit,
      storyController: controller,
      mediaErrorWidget: mediaErrorWidget,
      mediaLoadingWidget: mediaLoadingWidget,
      videoLoader: VideoLoader(url, requestHeaders: requestHeaders),
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void> playerLoader;

  StreamSubscription _streamSubscription;

  VideoPlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Center(child: contentView());
  }

  Widget contentView() {
    return FutureBuilder<void>(
      future: initializeController(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.mediaErrorWidget ??
              Text(
                "Media failed to load.",
                style: TextStyle(
                  color: Colors.white,
                ),
              );
        }

        final state = snapshot.connectionState;

        switch (state) {
          case ConnectionState.done:
            return SafeArea(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: widget.videoFit,
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
            return widget.mediaLoadingWidget ??
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                );
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> initializeController() async {
    if (playerController is VideoPlayerController && playerController.value.initialized) return;

    widget.storyController?.pause();

    final videoFile = await widget.videoLoader.loadVideo();

    this.playerController = VideoPlayerController.file(videoFile);

    await playerController.initialize();

    Provider.of<StoryItem>(context, listen: false).duration = playerController.value.duration;

    widget.storyController.play();

    if (widget.storyController != null) {
      playerController.addListener(checkIfVideoFinished);
      _streamSubscription = widget.storyController.playbackNotifier.listen((playbackState) {
        if (playbackState == PlaybackState.pause) {
          playerController.pause();
        } else {
          playerController.play();
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
