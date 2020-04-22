import 'dart:io';
import 'dart:async';
import 'story_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:stories_lib/story_controller.dart';
import 'package:stories_lib/utils/load_state.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoLoader {
  String url;

  File videoFile;

  Map<String, dynamic> requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      // this.state = LoadState.loading;
      onComplete();
    }

    final fileStream = DefaultCacheManager().getFile(this.url, headers: this.requestHeaders);

    fileStream.listen((fileInfo) {
      if (this.videoFile == null) {
        this.state = LoadState.success;
        this.videoFile = fileInfo.file;
        onComplete();
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final BoxFit videoFit;

  final VideoLoader videoLoader;

  final StoryController storyController;

  StoryVideo(
    this.videoLoader, {
    this.videoFit,
    this.storyController,
    Key key,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo url(
    String url, {
    Key key,
    BoxFit videoFit,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    VoidCallback adjustDuration,
  }) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      key: key,
      videoFit: videoFit,
      storyController: controller,
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
  void initState() {
    super.initState();
    widget.videoLoader.loadVideo(
      () {
        if (widget.videoLoader.state == LoadState.success) {
          this.playerController = VideoPlayerController.file(widget.videoLoader.videoFile);

          playerController.initialize().then((v) {
            Provider.of<StoryItem>(context, listen: false)
                .updateDuration(playerController.value.duration);
            setState(() {});
            widget.storyController.play();
          });

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
        } else {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
      child: getContentView(),
    );
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success && playerController.value.initialized) {
      return SafeArea(
        child: SizedBox.expand(
          child: FittedBox(
            // If your background video doesn't look right, try changing the BoxFit property.
            // BoxFit.fill created the look I was going for.
            fit: widget.videoFit,
            child: SizedBox(
              width: playerController.value.size?.width ?? 0,
              height: playerController.value.size?.height ?? 0,
              child: VideoPlayer(playerController),
            ),
          ),
        ),
      );
    }
    return widget.videoLoader.state == LoadState.loading
        ? Center(
            child: Container(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          )
        : Center(
            child: Text(
            "Media failed to load.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ));
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void checkIfVideoFinished() {
    // print('~~~~~~~~~~~~~~ -- ${playerController.value.duration?.inSeconds} ');
    try {
      if (playerController.value.position.inSeconds == playerController.value.duration.inSeconds) {
        playerController.removeListener(checkIfVideoFinished);
      }
    } catch (e) {}
  }
}
