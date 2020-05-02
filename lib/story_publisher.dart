import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' show join, basename;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stories_lib/components/story_error.dart';
import 'package:stories_lib/components/story_loading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

enum StoryType { text, image, video, gif }

enum StoryUploadStatus { waiting, compressing, sending, complete, failure }

typedef StoryPublisherToolsBuilder = Widget Function(
  BuildContext,
  StoryType,
  CameraLensDirection,
  void Function(StoryType),
  void Function(CameraLensDirection),
  void Function(String, StoryType),
);

typedef StoryPublisherPreviewToolsBuilder = Widget Function(
    BuildContext, File, Stream<StoryUploadStatus>, VoidCallback);

typedef StoryPublisherButtonBuilder = Widget Function(BuildContext, StoryType, Animation<double>);

class StoryPublisher extends StatefulWidget {
  final String userId;
  final Widget closeButton;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Duration videoDuration;
  final String collectionDbName;
  final Alignment closeButtonPosition;
  final StoryPublisherToolsBuilder toolsBuilder;
  final StoryPublisherButtonBuilder publishBuilder;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  const StoryPublisher({
    Key key,
    @required this.collectionDbName,
    this.userId,
    this.errorWidget,
    this.closeButton,
    this.toolsBuilder,
    this.loadingWidget,
    this.publishBuilder,
    this.resultToolsBuilder,
    this.closeButtonPosition = Alignment.topRight,
    this.videoDuration = const Duration(seconds: 10),
  }) : super(key: key);

  @override
  _StoryPublisherState createState() => _StoryPublisherState();
}

class _StoryPublisherState extends State<StoryPublisher> with SingleTickerProviderStateMixin {
  StoryType type;
  String storyPath;
  Timer videoTimer;
  CameraController controller;
  Animation<double> animation;
  Future _cameraInitialization;
  CameraLensDirection direction;
  AnimationController animationController;

  @override
  void initState() {
    _cameraInitialization = initializeController(direction: CameraLensDirection.front);

    type = StoryType.image;

    animationController = AnimationController(vsync: this, duration: widget.videoDuration);

    animation = animationController.drive(Tween(begin: 0.0, end: 1.0));

    super.initState();
  }

  @override
  void dispose() {
    videoTimer?.cancel();
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
    final tempDir = await getTemporaryDirectory();

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
    await HapticFeedback.vibrate();
    await controller.startVideoRecording(storyPath);

    videoTimer?.cancel();
    videoTimer = Timer(widget.videoDuration, _stopVideoRecording);

    setState(() => type = StoryType.video);
    animationController.forward();
  }

  void _stopVideoRecording() async {
    videoTimer?.cancel();
    animationController.stop();
    await controller.stopVideoRecording();
    animationController.reset();

    _goToStoryResult();
  }

  void _sendExternalMedia(String path, StoryType type) async {
    storyPath = path;
    this.type = type;

    _goToStoryResult();
  }

  void _goToStoryResult() {
    Navigator.push(
      context,
      PageRouteBuilder(pageBuilder: (context, anim, anim2) {
        return StoryPublisherPreview(
          type: type,
          filePath: storyPath,
          userId: widget.userId,
          closeButton: widget.closeButton,
          collectionDbName: widget.collectionDbName,
          resultToolsBuilder: widget.resultToolsBuilder,
          closeButtonPosition: widget.closeButtonPosition,
        );
      }),
    );
  }
}

class StoryPublisherPreview extends StatefulWidget {
  final String userId;
  final StoryType type;
  final String filePath;
  final Widget closeButton;
  final String collectionDbName;
  final Alignment closeButtonPosition;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  StoryPublisherPreview({
    Key key,
    @required this.type,
    @required this.filePath,
    this.userId,
    this.closeButton,
    this.resultToolsBuilder,
    this.closeButtonPosition,
    @required this.collectionDbName,
  })  : assert(filePath != null, "The [filePath] can't be null"),
        assert(type != null, "The [type] can't be null"),
        super(key: key);

  @override
  _StoryPublisherPreviewState createState() => _StoryPublisherPreviewState();
}

class _StoryPublisherPreviewState extends State<StoryPublisherPreview> {
  File storyFile;
  String compressedPath;
  Future compressFuture;
  VideoPlayerController controller;
  final _uploadStatus = StreamController<StoryUploadStatus>()..add(StoryUploadStatus.waiting);

  @override
  void initState() {
    _compress();

    storyFile = File(widget.filePath);
    if (widget.type == StoryType.video) controller = VideoPlayerController.file(storyFile);
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    _uploadStatus?.close();
    VideoCompress.cancelCompression();
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
              child: widget.resultToolsBuilder
                      ?.call(context, storyFile, _uploadStatus.stream, _sendStory) ??
                  LimitedBox(),
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

  void _compress() {
    switch (widget.type) {
      case StoryType.video:
        compressFuture = _compressVideo().then((path) => compressedPath = path);
        break;
      case StoryType.image:
        compressFuture = _compressImage().then((path) => compressedPath = path);
        break;
      default:
    }
  }

  Future<void> _sendStory() async {
    try {
      _uploadStatus.add(StoryUploadStatus.compressing);
      await compressFuture;

      if (compressedPath is! String) throw Exception("Fail to compress story");

      _uploadStatus.add(StoryUploadStatus.sending);
      final url = await _uploadFile(compressedPath);

      if (url is! String) throw Exception("Fail to upload story");

      await _sendToFirestore(url);

      _uploadStatus.add(StoryUploadStatus.complete);
    } catch (e) {
      _uploadStatus.add(StoryUploadStatus.failure);
    }
  }

  Future<String> _compressImage() async {
    debugPrint('image before = ${File(widget.filePath).lengthSync() / 1000} kB');

    final temp = await getTemporaryDirectory();
    final newPath = join(temp.path, '${DateTime.now().millisecondsSinceEpoch}.jpeg');

    final compressed = await FlutterImageCompress.compressAndGetFile(
      widget.filePath,
      newPath,
      quality: 90,
      keepExif: true,
    );

    debugPrint('image after = ${compressed.lengthSync() / 1000} kB');

    return compressed.path;
  }

  Future<String> _compressVideo() async {
    debugPrint('video before = ${File(widget.filePath).lengthSync() / 1000} kB');

    final mediaInfo = await VideoCompress.compressVideo(
      widget.filePath,
      includeAudio: true,
      deleteOrigin: true,
      quality: VideoQuality.DefaultQuality,
    );

    debugPrint('video after = ${File(mediaInfo.path).lengthSync() / 1000} kB');

    return mediaInfo.path;
  }

  Future<String> _uploadFile(String path) async {
    try {
      final fileName = basename(path);

      final storageReference =
          FirebaseStorage.instance.ref().child("stories").child(widget.userId).child(fileName);

      final StorageUploadTask uploadTask = storageReference.putFile(File(path));

      var subs;
      subs = uploadTask.events.listen((event) {
        print((event.snapshot.bytesTransferred / event.snapshot.totalByteCount) * 100);
        if (event.type == StorageTaskEventType.success ||
            event.type == StorageTaskEventType.success) subs.cancel();
      });

      final StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
      final String url = (await downloadUrl.ref.getDownloadURL());

      return url;
    } catch (e, s) {
      print(e);
      print(s);

      return null;
    }
  }

  Future<void> _sendToFirestore(String url) async {
    try {
      final firestore = Firestore.instance;

      final collectionInfo = {
        "cover_img":
            "https://images.unsplash.com/photo-1570158268183-d296b2892211?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=634&q=80",
        "last_update": DateTime.now(),
        "title": {"pt": "sou"},
        "releases": [
          {"group": "dev"}
        ]
      };

      final storyInfo = {
        "id": Uuid().v4(),
        "date": DateTime.now(),
        "media": {"pt": url},
        "type": _extractType,
      };

      final userDoc =
          await firestore.collection(widget.collectionDbName).document(widget.userId).get();

      if (userDoc.exists) {
        final stories = userDoc.data["stories"] ?? List();
        if (stories is List) {
          stories.add(storyInfo);
          await userDoc.reference.updateData(
            {"last_update": DateTime.now(), "stories": stories},
          );
        }
      } else {
        await userDoc.reference.setData(collectionInfo
          ..addAll({
            "stories": [storyInfo]
          }));
      }
    } catch (e, s) {
      debugPrint(e);
      debugPrint(s.toString());
    }
  }

  String get _extractType => widget.type.toString().split('.')[1];
}
