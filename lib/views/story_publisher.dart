import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/utils/fix_image_orientation.dart';
import 'package:stories_lib/utils/story_types.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' show join, basename, extension;
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:video_compress/video_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stories_lib/components/story_error.dart';
import 'package:stories_lib/components/story_widget.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/components/story_loading.dart';
import 'package:stories_lib/components/fitted_container.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

enum StoryType { text, image, video, gif }

enum ExternalMediaStatus { valid, does_not_exist, duration_exceeded }

enum PublisherStatus { none, showingResult, compressing, sending, complete, failure }

class PublisherController {
  final _uploadStatus = StreamController<PublisherStatus>()..add(PublisherStatus.none);

  Stream _stream;

  _StoryPublisherState _publisherState;

  _StoryPublisherResultState _resultState;

  PublisherController() {
    _stream = _uploadStatus.stream.asBroadcastStream();
  }

  Stream<PublisherStatus> get stream => _stream;

  void addStatus(PublisherStatus status) {
    _uploadStatus?.add(status);
  }

  void _attachPublisher(_StoryPublisherState p) {
    _publisherState = p;
  }

  void _detachPublisher() {
    _publisherState = null;
  }

  void _attachResult(_StoryPublisherResultState r) {
    _resultState = r;
  }

  void _detachResult() {
    _resultState = null;
  }

  void switchCamera() {
    assert(_publisherState != null, "No [StoryPublisher] attached to controller");

    var direction;
    switch (_publisherState.direction) {
      case CameraLensDirection.front:
        direction = CameraLensDirection.back;
        break;
      default:
        direction = CameraLensDirection.front;
        break;
    }
    _publisherState._changeLens(direction);
  }

  void changeType(StoryType type) {
    assert(_publisherState != null, "No [StoryPublisher] attached to controller");
    _publisherState._changeType(type);
  }

  Future<ExternalMediaStatus> sendExternal(File file, StoryType type) {
   return _publisherState._sendExternalMedia(file, type);
  }

  void dispose() {
    _uploadStatus?.close();
  }
}

class StoryPublisher extends StatefulWidget {
  final bool enableSafeArea;
  final StoriesSettings settings;
  final StoryController storyController;
  final PublisherController publisherController;
  final Widget closeButton;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final Widget mediaError;
  final Widget mediaPlaceholder;
  final TakeStoryBuilder takeStoryBuilder;
  final PublishLayerBuilder publisherLayerBuilder;
  final bool defaultBehavior;
  final ResultLayerBuilder resultInfoBuilder;
  final VoidCallback onStoryPosted;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;

  const StoryPublisher({
    Key key,
    this.settings,
    this.onStoryPosted,
    this.storyController,
    this.publisherController,
    this.onStoryCollectionClosed,
    this.onStoryCollectionOpenned,
    this.closeButton,
    this.closeButtonPosition,
    this.backgroundBetweenStories,
    this.mediaError,
    this.mediaPlaceholder,
    this.takeStoryBuilder,
    this.publisherLayerBuilder,
    this.defaultBehavior,
    this.resultInfoBuilder,
    this.enableSafeArea = true,
  }) : super(key: key);

  @override
  _StoryPublisherState createState() => _StoryPublisherState();
}

class _StoryPublisherState extends State<StoryPublisher> with SingleTickerProviderStateMixin {
  StoryType type;
  String storyPath;
  Timer videoTimer;
  Animation<double> animation;
  Future cameraInitialization;
  CameraLensDirection direction;
  CameraController cameraController;
  AnimationController animationController;
  Duration videoDuration = const Duration(seconds: 10);

  @override
  void initState() {
    widget.publisherController?._attachPublisher(this);

    widget.onStoryCollectionOpenned?.call();

    cameraInitialization = initializeController(direction: CameraLensDirection.front);

    type = StoryType.image;

    videoDuration = widget.settings.videoDuration;

    animationController = AnimationController(vsync: this, duration: videoDuration);

    animation = animationController.drive(Tween(begin: 0.0, end: 1.0));

    super.initState();
  }

  @override
  void dispose() {
    videoTimer?.cancel();
    cameraController?.dispose();
    animationController?.dispose();
    widget.publisherController?._detachPublisher();
    widget.onStoryCollectionClosed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return publishStory();
  }

  Widget publishStory() {
    return Scaffold(
      backgroundColor: widget.backgroundBetweenStories,
      body: SafeArea(
        top: widget.enableSafeArea,
        bottom: widget.enableSafeArea,
        child: Stack(
          children: <Widget>[
            Center(
              child: FutureBuilder<void>(
                future: cameraInitialization,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return widget.mediaError ??
                        StoryError(
                          info: "Open camera failed.",
                        );
                  switch (snapshot.connectionState) {
                    case ConnectionState.done:
                      return Stack(
                        children: <Widget>[
                          FittedContainer(
                            fit: BoxFit.cover,
                            width: cameraController.value.previewSize?.height ?? 0,
                            height: cameraController.value.previewSize?.width ?? 0,
                            child: AspectRatio(
                              aspectRatio: cameraController.value.aspectRatio,
                              child: CameraPreview(cameraController),
                            ),
                          ),
                          Align(
                            alignment: widget.closeButtonPosition,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: widget.closeButton,
                            ),
                          ),
                          if (widget.takeStoryBuilder != null)
                            widget.takeStoryBuilder(type, animation, _processStory),
                          widget.publisherLayerBuilder(context, type),
                        ],
                      );
                      break;
                    default:
                      return widget.mediaPlaceholder ?? StoryLoading();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> initializeController({CameraLensDirection direction}) async {
    final cameras = await availableCameras();

    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => cameras.first,
    );

    cameraController = CameraController(selectedCamera, ResolutionPreset.medium);

    storyPath = null;

    this.direction = direction;

    await cameraController.initialize();
  }

  void _changeLens(CameraLensDirection mode) {
    setState(() {
      cameraInitialization = initializeController(direction: mode);
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

  void _processStory(StoryType type) {
    switch (type) {
      case StoryType.image:
        _takePicture();
        break;
      case StoryType.video:
        if (cameraController.value.isRecordingVideo)
          _stopVideoRecording();
        else
          _startVideoRecording();
        break;
      default:
    }
  }

  void _takePicture() async {
    if (cameraController.value.isRecordingVideo) return;

    storyPath = await _pathToNewFile('jpg');
    await cameraController.takePicture(storyPath);
    try {
      storyPath = await fixExifRotation(storyPath, isFront: direction == CameraLensDirection.front);
    } catch (e, s) {
      print(e);
      print(s);
    }
    setState(() => type = StoryType.image);

    _goToStoryResult();
  }

  void _startVideoRecording() async {
    if (cameraController.value.isTakingPicture) return;
    storyPath = await _pathToNewFile('mp4');
    await cameraController.prepareForVideoRecording();
    await HapticFeedback.vibrate();
    await cameraController.startVideoRecording(storyPath);

    videoTimer?.cancel();
    videoTimer = Timer(videoDuration, _stopVideoRecording);

    setState(() => type = StoryType.video);
    animationController.forward();
  }

  void _stopVideoRecording() async {
    if (cameraController.value.isTakingPicture) return;

    videoTimer?.cancel();
    animationController.stop();
    await cameraController.stopVideoRecording();
    animationController.reset();

    _goToStoryResult();
  }

  Future<ExternalMediaStatus> _sendExternalMedia(File file, StoryType type) async {
    if (file == null || !file.existsSync()) {
      return ExternalMediaStatus.does_not_exist;
    }

    storyPath = file.path;
    this.type = type;

    if (type == StoryType.video) {
      final videoCtrl = VideoPlayerController.file(file);

      await videoCtrl.initialize();

      if (videoCtrl.value.initialized) {
        if (videoCtrl.value.duration.inSeconds > videoDuration.inSeconds)
          return ExternalMediaStatus.duration_exceeded;
      }
    }

    _goToStoryResult();

    return ExternalMediaStatus.valid;
  }

  void _goToStoryResult() async {
    widget.publisherController?._detachPublisher();
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, anim2) {
          return _StoryPublisherResult(
            settings: widget.settings,
            publisherController: widget.publisherController,
            storyController: widget.storyController,
            type: type,
            filePath: storyPath,
            onStoryPosted: widget.onStoryPosted,
            onMyStoriesClosed: widget.onStoryCollectionClosed,
            backgroundBetweenStories: widget.backgroundBetweenStories,
            closeButton: widget.closeButton,
            closeButtonPosition: widget.closeButtonPosition,
            resultInfoBuilder: widget.resultInfoBuilder,
          );
        },
      ),
    );
    widget.publisherController?._attachPublisher(this);
  }
}

class _StoryPublisherResult extends StatefulWidget {
  final bool enableSafeArea;
  final StoriesSettings settings;
  final StoryController storyController;
  final PublisherController publisherController;
  final StoryType type;
  final String filePath;
  final VoidCallback onStoryPosted;
  final VoidCallback onMyStoriesClosed;
  final Widget closeButton;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final ResultLayerBuilder resultInfoBuilder;

  _StoryPublisherResult({
    Key key,
    @required this.type,
    @required this.filePath,
    this.onStoryPosted,
    this.onMyStoriesClosed,
    this.settings,
    this.storyController,
    this.publisherController,
    this.closeButton,
    this.closeButtonPosition,
    this.backgroundBetweenStories,
    this.resultInfoBuilder,
    this.enableSafeArea = true,
  })  : assert(filePath != null, "The [filePath] can't be null"),
        assert(type != null, "The [type] can't be null"),
        super(key: key);

  @override
  _StoryPublisherResultState createState() => _StoryPublisherResultState();
}

class _StoryPublisherResultState extends State<_StoryPublisherResult> {
  File storyFile;

  String compressedPath;

  Future compressFuture;

  VideoPlayerController controller;

  Future controllerFuture;

  StreamSubscription playbackSubscription;

  List<Widget> mediaAttachments = <Widget>[];

  final _globalKey = GlobalKey();

  PublisherController publisherController;

  StoryController storyController;

  @override
  void initState() {
    _compress();

    publisherController = widget.publisherController;
    storyController = widget.storyController;

    publisherController?._attachResult(this);

    publisherController.addStatus(PublisherStatus.showingResult);

    storyFile = File(widget.filePath);
    if (widget.type == StoryType.video) {
      controller = VideoPlayerController.file(storyFile);
      controller.setLooping(true);
      controllerFuture = controller.initialize();
    }

    playbackSubscription = storyController?.playbackNotifier?.listen(
      (playbackStatus) {
        if (playbackStatus == PlaybackState.play) {
          controller?.play();
        } else if (playbackStatus == PlaybackState.pause) {
          controller?.pause();
        }
      },
    );

    super.initState();
  }

  @override
  void dispose() {
    controller?.pause();
    controller?.dispose();
    playbackSubscription?.cancel();
    publisherController?._detachResult();
    // widget.onMyStoriesClosed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundBetweenStories,
      resizeToAvoidBottomPadding: false,
      body: SafeArea(
        top: widget.enableSafeArea,
        bottom: widget.enableSafeArea,
        child: Stack(
          children: <Widget>[
            StoryWidget(story: _buildPreview()),
            widget.resultInfoBuilder(context, storyFile, insertAttachment, _sendStory),
            Align(
              alignment: widget.closeButtonPosition,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: widget.closeButton,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void insertAttachment(List<Widget> attachments) {
    setState(() => mediaAttachments = attachments);
  }

  Future<void> _capturePng() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext.findRenderObject();
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData.buffer.asUint8List();
      final temp = await getTemporaryDirectory();
      final newPath = join(temp.path, '${DateTime.now().millisecondsSinceEpoch}.png');

      final file = await File(newPath).writeAsBytes(pngBytes);

      compressedPath = file.path;
    } catch (e) {
      print(e);
    }
  }

  Widget _buildPreview() {
    switch (widget.type) {
      case StoryType.image:
        return RepaintBoundary(
          key: _globalKey,
          child: Stack(
            fit: StackFit.loose,
            children: <Widget>[
              Positioned.fill(
                child: Image.file(
                  storyFile,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              for (var render in mediaAttachments) render,
            ],
          ),
        );
        break;
      case StoryType.video:

        /// A way to listen Navigation without RouteObservers
        if (ModalRoute.of(context).isCurrent) {
          controller.play();
        } else {
          controller.pause();
        }
        return FutureBuilder<void>(
          future: controllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return FittedContainer(
                fit: BoxFit.cover,
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              );
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

  Future<void> _sendStory({
    File newStoryFile,
    String caption,
    List<dynamic> selectedReleases,
    bool needCompress = false,
  }) async {
    try {
      publisherController.addStatus(PublisherStatus.compressing);

      if (newStoryFile is File && newStoryFile.existsSync()) {
        if (needCompress)
          _compress();
        else
          compressedPath = newStoryFile.path;
      }
      await compressFuture;
      await _capturePng();

      if (compressedPath is! String) throw Exception("Fail to compress story");

      publisherController.addStatus(PublisherStatus.sending);
      final url = await _uploadFile(compressedPath);

      if (url is! String) throw Exception("Fail to upload story");

      await _sendToFirestore(url, caption: caption, selectedReleases: selectedReleases);

      publisherController.addStatus(PublisherStatus.complete);

      widget.onStoryPosted?.call();
    } catch (e) {
      publisherController.addStatus(PublisherStatus.failure);
    }
  }

  Future<String> _compressImage() async {
    // debugPrint('image before = ${File(widget.filePath).lengthSync() / 1000} kB');

    final temp = await getTemporaryDirectory();
    final newPath = join(temp.path, '${DateTime.now().millisecondsSinceEpoch}.jpeg');

    final compressed = await FlutterImageCompress.compressAndGetFile(
      widget.filePath,
      newPath,
      quality: 90,
      keepExif: true,
    );

    // debugPrint('image after = ${compressed.lengthSync() / 1000} kB');

    return compressed.path;
  }

  Future<String> _compressVideo() async {
    try {
      debugPrint('video before = ${File(widget.filePath).lengthSync() / 1000} kB');

      // final mediaInfo = await VideoCompress.compressVideo(
      //   widget.filePath,
      //   deleteOrigin: true,
      //   quality: VideoQuality.MediumQuality,
      // );

      // compressedPath = mediaInfo.path;

      // debugPrint('video after = ${mediaInfo.file.lengthSync() / 1000} kB');

      compressedPath = widget.filePath;

      return compressedPath;
    } catch (e, s) {
      print(e);
      print(s);

      return null;
    }
  }

  Future<String> _uploadFile(String path) async {
    try {
      final fileName = basename(path);

      final fileExt = extension(path);

      final storageReference = FirebaseStorage.instance
          .ref()
          .child("stories")
          .child(widget.settings.userId)
          .child(fileName);

      final StorageUploadTask uploadTask = storageReference.putFile(
        File(path),
        StorageMetadata(
          contentType: widget.type == StoryType.video ? "video/mp4" : "image/$fileExt",
        ),
      );

      var subs;
      subs = uploadTask.events.listen((event) {
        debugPrint(
            ((event.snapshot.bytesTransferred / event.snapshot.totalByteCount) * 100).toString());
        if (event.type == StorageTaskEventType.success ||
            event.type == StorageTaskEventType.success) subs.cancel();
      });

      final StorageTaskSnapshot downloadUrl = await uploadTask.onComplete;
      final String url = await downloadUrl.ref.getDownloadURL();

      return url;
    } catch (e, s) {
      print(e);
      print(s);

      return null;
    }
  }

  Future<void> _sendToFirestore(
    String url, {
    String caption,
    List<dynamic> selectedReleases,
  }) async {
    final settings = widget.settings;
    try {
      final firestore = Firestore.instance;

      final collectionInfo = {
        "cover_img": settings.coverImg,
        "last_update": DateTime.now(),
        "title": {settings.languageCode: settings.username},
        "releases": settings.releases,
      };

      final storyInfo = {
        "id": Uuid().v4(),
        "date": DateTime.now(),
        "media": {settings.languageCode: url},
        "caption": {settings.languageCode: caption},
        "releases": selectedReleases,
        "type": _extractType,
      };

      final userDoc =
          await firestore.collection(settings.collectionDbName).document(settings.userId).get();

      if (userDoc.exists) {
        final stories = userDoc.data["stories"] ?? List();
        if (stories is List) {
          stories.add(storyInfo);
          await userDoc.reference.updateData(collectionInfo
            ..addAll({
              "stories": stories,
            }));
        }
      } else {
        await userDoc.reference.setData(collectionInfo
          ..addAll({
            "stories": [storyInfo]
          }));
      }
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
    }
  }

  String get _extractType => widget.type.toString().split('.')[1];
}
