import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:stories_lib/components/story_error.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:stories_lib/components/story_loading.dart';
import 'package:video_player/video_player.dart';

enum StoryType { text, image, video, gif }

typedef StoryPublisherToolsBuilder = Widget Function(
  BuildContext,
  StoryType,
  CameraLensDirection,
  void Function(StoryType),
  void Function(CameraLensDirection),
  void Function(String, StoryType),
);

typedef StoryPublisherPreviewToolsBuilder = Widget Function(BuildContext, File, VoidCallback);

typedef StoryPublisherButtonBuilder = Widget Function(BuildContext, StoryType, Animation<double>);

class StoryPublisher extends StatefulWidget {
  final Widget closeButton;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Alignment closeButtonPosition;
  final StoryPublisherToolsBuilder toolsBuilder;
  final StoryPublisherButtonBuilder publishBuilder;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  const StoryPublisher({
    Key key,
    this.errorWidget,
    this.closeButton,
    this.toolsBuilder,
    this.loadingWidget,
    this.publishBuilder,
    this.resultToolsBuilder,
    this.closeButtonPosition = Alignment.topRight,
  }) : super(key: key);

  @override
  _StoryPublisherState createState() => _StoryPublisherState();
}

class _StoryPublisherState extends State<StoryPublisher> with SingleTickerProviderStateMixin {
  StoryType type;
  String storyPath;
  CameraController controller;
  Animation<double> animation;
  Future _cameraInitialization;
  CameraLensDirection direction;
  List<CameraDescription> cameras;
  AnimationController animationController;

  @override
  void initState() {
    _cameraInitialization = initializeController(direction: CameraLensDirection.front);

    type = StoryType.image;

    animationController = AnimationController(vsync: this, duration: const Duration(seconds: 10));

    animation = animationController.drive(Tween(begin: 0.0, end: 1.0));

    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          FutureBuilder<void>(
            future: _cameraInitialization,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: widget.errorWidget ??
                      StoryError(
                        info: "Open camera failed.",
                      ),
                );

              switch (snapshot.connectionState) {
                case ConnectionState.done:
                  return AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  );
                  break;
                default:
                  return Center(
                    child: widget.loadingWidget ?? StoryLoading(),
                  );
              }
            },
          ),
          Align(
            alignment: widget.closeButtonPosition,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: widget.closeButton,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FutureBuilder<void>(
                  future: _cameraInitialization,
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.done:
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            if (widget.publishBuilder != null)
                              GestureDetector(
                                onTap: _takeStory,
                                onLongPressStart: (details) => _startVideoRecording(),
                                onLongPressEnd: (details) => _stopVideoRecording(),
                                child: widget.publishBuilder(context, type, animation),
                              ),
                            if (widget.toolsBuilder != null)
                              Flexible(
                                child: IgnorePointer(
                                  ignoring: controller.value.isRecordingVideo,
                                  child: widget.toolsBuilder(
                                    context,
                                    type,
                                    controller.description.lensDirection,
                                    _changeType,
                                    _changeLens,
                                    _sendExternalMedia,
                                  ),
                                ),
                              ),
                          ],
                        );
                        break;
                      default:
                        return LimitedBox();
                    }
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> initializeController({CameraLensDirection direction}) async {
    final cameras = await availableCameras();

    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => cameras.first,
    );

    controller = CameraController(selectedCamera, ResolutionPreset.max);

    storyPath = null;

    await controller.initialize();
  }

  void _changeLens(CameraLensDirection mode) {
    setState(() {
      _cameraInitialization = initializeController(direction: mode);
    });
  }

  void _changeType(StoryType type) {
    setState(() {
      this.type = type;
    });
  }

  Future<String> _pathToNewFile(String format) async {
    final tempDir = await path.getTemporaryDirectory();

    return join(tempDir.path, "${DateTime.now().millisecondsSinceEpoch}.$format");
  }

  void _takeStory() async {
    storyPath = await _pathToNewFile('png');
    await controller.takePicture(storyPath);

    _goToStoryResult();
  }

  void _startVideoRecording() async {
    storyPath = await _pathToNewFile('mp4');
    await controller.prepareForVideoRecording();
    await controller.startVideoRecording(storyPath);
    setState(() => type = StoryType.video);
    animationController.forward();
  }

  void _stopVideoRecording() async {
    animationController.stop();
    await controller.stopVideoRecording();
    animationController.reset();
    _goToStoryResult();
  }

  void _sendExternalMedia(String path, StoryType type) {
    storyPath = path;
    this.type = type;
    _goToStoryResult();
  }

  void _goToStoryResult() {
    Navigator.push(
      context,
      PageRouteBuilder(pageBuilder: (context, anim, anim2) {
        return StoryPublisherPreview(
          filePath: storyPath,
          type: type,
          closeButton: widget.closeButton,
          resultToolsBuilder: widget.resultToolsBuilder,
          closeButtonPosition: widget.closeButtonPosition,
        );
      }),
    );
  }
}

class StoryPublisherPreview extends StatefulWidget {
  final StoryType type;
  final String filePath;
  final Widget closeButton;
  final Alignment closeButtonPosition;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  StoryPublisherPreview({
    Key key,
    @required this.type,
    @required this.filePath,
    this.closeButton,
    this.closeButtonPosition,
    this.resultToolsBuilder,
  })  : assert(filePath != null, "The [filePath] can't be null"),
        assert(type != null, "The [type] can't be null"),
        super(key: key);

  @override
  _StoryPublisherPreviewState createState() => _StoryPublisherPreviewState();
}

class _StoryPublisherPreviewState extends State<StoryPublisherPreview> {
  File storyFile;
  VideoPlayerController controller;

  @override
  void initState() {
    storyFile = File(widget.filePath);
    if (widget.type == StoryType.video) controller = VideoPlayerController.file(storyFile);
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _buildPreview(),
          Align(
            alignment: widget.closeButtonPosition,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: widget.closeButton,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child:
                  widget.resultToolsBuilder?.call(context, storyFile, _sendStory) ?? LimitedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    switch (widget.type) {
      case StoryType.image:
        return Image.file(
          storyFile,
          fit: BoxFit.fitHeight,
        );
        break;
      case StoryType.video:
        return FutureBuilder<void>(
          future: controller.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              controller.setLooping(true);
              controller.play();
              return VideoPlayer(controller);
            } else {
              return Center(child: StoryLoading());
            }
          },
        );
      default:
        return Container();
    }
  }

  void _sendStory() {}
}
