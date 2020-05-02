import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:stories_lib/components/story_error.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:stories_lib/components/story_loading.dart';

enum StoryType { text, image, video, gif }

typedef StoryPublisherToolsBuilder = Widget Function(
  BuildContext,
  StoryType,
  CameraLensDirection,
  void Function(StoryType),
  void Function(CameraLensDirection),
  void Function(String, StoryType),
);

typedef StoryPublisherButtonBuilder = Widget Function(BuildContext, StoryType);

class StoryPublisher extends StatefulWidget {
  final Widget closeButton;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Alignment closeButtonPosition;
  final StoryPublisherButtonBuilder publishBuilder;
  final StoryPublisherToolsBuilder tools;

  const StoryPublisher({
    Key key,
    this.errorWidget,
    this.closeButton,
    this.tools,
    this.loadingWidget,
    this.publishBuilder,
    this.closeButtonPosition = Alignment.topRight,
  }) : super(key: key);

  @override
  _StoryPublisherState createState() => _StoryPublisherState();
}

class _StoryPublisherState extends State<StoryPublisher> {
  StoryType type;
  CameraController controller;
  CameraLensDirection direction;
  List<CameraDescription> cameras;
  Future _cameraInitialization;

  @override
  void initState() {
    super.initState();

    _cameraInitialization = initializeController(direction: CameraLensDirection.front);

    type = StoryType.image;
  }

  @override
  void dispose() {
    controller?.dispose();
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
                              InkWell(
                                onTap: _takeStory,
                                // onLongPress: _takeVideo,
                                child: widget.publishBuilder(
                                  context,
                                  type,
                                ),
                              ),
                            if (widget.tools != null)
                              Flexible(
                                child: widget.tools(
                                  context,
                                  type,
                                  controller.description.lensDirection,
                                  _changeType,
                                  _changeLens,
                                  _sendExternalMedia,
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
    // if (controller is CameraController) return;

    final cameras = await availableCameras();

    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => cameras.first,
    );

    controller = CameraController(selectedCamera, ResolutionPreset.max);

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

  void _takeStory() async {
    final tempDir = await path.getTemporaryDirectory();

    final picturePath = join(tempDir.path, "${DateTime.now()}.png");

    await controller.takePicture(picturePath);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Image.file(
          File(picturePath),
          fit: BoxFit.fitHeight,
        ),
      ),
    );
  }

  void _sendExternalMedia(String path, StoryType type) {
    if (type == StoryType.image)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Image.file(
            File(path),
            fit: BoxFit.fitHeight,
          ),
        ),
      );
  }
}
