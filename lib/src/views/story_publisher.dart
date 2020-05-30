import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart' show join, basename, extension;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../configs/stories_settings.dart';
import '../configs/story_controller.dart';
import '../utils/exceptions.dart';
import '../utils/fix_image_orientation.dart';
import '../utils/story_types.dart';
import '../widgets/attachment_widget.dart';
import '../widgets/fitted_container.dart';
import '../widgets/story_error.dart';
import '../widgets/story_loading.dart';
import '../widgets/story_widget.dart';

part '../configs/publisher_controller.dart';

enum StoryType { text, image, video, gif }

enum ExternalMediaStatus { valid, does_not_exist, duration_exceeded }

enum PublisherStatus { none, compressing, sending, failure }

class StoryPublisher extends StatefulWidget {
  final Widget errorWidget;
  final Widget closeButton;
  final bool enableSafeArea;
  final Widget loadingWidget;
  final StoriesSettings settings;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final TakeStoryBuilder takeStoryBuilder;
  final ResultLayerBuilder resultInfoBuilder;
  final VoidCallback onStoryCollectionClosed;
  final VoidCallback onStoryCollectionOpenned;
  final PublisherController publisherController;
  final PublishLayerBuilder publisherLayerBuilder;

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
    this.errorWidget,
    this.loadingWidget,
    this.takeStoryBuilder,
    this.publisherLayerBuilder,
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

    cameraInitialization =
        initializeController(direction: widget.publisherController.initialCamera);

    type = widget.publisherController.initialType;

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
                    return widget.errorWidget ?? StoryError(info: "Open camera failed.");
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
                          if (widget.closeButton != null)
                            Align(
                              alignment: widget.closeButtonPosition,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: widget.closeButton,
                              ),
                            ),
                          if (widget.takeStoryBuilder != null)
                            widget.takeStoryBuilder(type, animation, _processStory),
                          if (widget.publisherLayerBuilder != null)
                            widget.publisherLayerBuilder(context, type),
                        ],
                      );
                      break;
                    default:
                      return widget.loadingWidget ?? StoryLoading();
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

  bool get isCameraReady =>
      cameraController.value.isInitialized &&
      !cameraController.value.isTakingPicture &&
      !cameraController.value.isRecordingVideo;

  void _takePicture() async {
    if (!isCameraReady) return;

    storyPath = await _pathToNewFile('jpg');

    await cameraController.takePicture(storyPath);

    try {
      storyPath = await fixExifRotation(storyPath, isFront: direction == CameraLensDirection.front);
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
    }

    setState(() => type = StoryType.image);

    _goToStoryResult();
  }

  void _startVideoRecording() async {
    if (!isCameraReady) return;

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

  Future<void> _sendExternalMedia(File file, StoryType type) async {
    if (file == null || !file.existsSync()) {
      throw FileSystemException("The [File] is null or doesn't exists", file.path);
    }

    storyPath = file.path;

    this.type = type;

    if (type == StoryType.video) {
      final videoCtrl = VideoPlayerController.file(file);

      await videoCtrl.initialize();

      if (videoCtrl.value.initialized) {
        if (videoCtrl.value.duration.inSeconds > videoDuration.inSeconds) {
          ExceededDurationException();
        }
      }
    }

    _goToStoryResult();
  }

  void _goToStoryResult() async {
    widget.publisherController?._detachPublisher();
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, anim2) {
          return _StoryPublisherResult(
            type: type,
            filePath: storyPath,
            settings: widget.settings,
            closeButton: widget.closeButton,
            onStoryPosted: widget.onStoryPosted,
            enableSafeArea: widget.enableSafeArea,
            storyController: widget.storyController,
            resultInfoBuilder: widget.resultInfoBuilder,
            publisherController: widget.publisherController,
            closeButtonPosition: widget.closeButtonPosition,
            backgroundBetweenStories: widget.backgroundBetweenStories,
          );
        },
      ),
    );
    widget.publisherController?._attachPublisher(this);
  }
}

class _StoryPublisherResult extends StatefulWidget {
  final StoryType type;
  final String filePath;
  final Widget closeButton;
  final bool enableSafeArea;
  final StoriesSettings settings;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final ResultLayerBuilder resultInfoBuilder;
  final PublisherController publisherController;

  _StoryPublisherResult({
    Key key,
    @required this.type,
    @required this.filePath,
    this.onStoryPosted,
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
  String filePath;

  Future future;

  VideoPlayerController controller;

  Future controllerFuture;

  StreamSubscription playbackSubscription;

  List<Widget> mediaAttachments = <AttachmentWidget>[];

  final _globalKey = GlobalKey();

  @override
  void initState() {
    widget.publisherController?._attachResult(this);

    _compress();

    if (widget.type == StoryType.video) {
      controller = VideoPlayerController.file(File(widget.filePath));
      controller.setLooping(true);
      controllerFuture = controller.initialize();
    }

    playbackSubscription = widget.storyController?.playbackNotifier?.listen(
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
    widget.publisherController?._detachResult();
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
            widget.resultInfoBuilder(context, _sendStory),
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

  Future<String> _capturePng() async {
    RenderRepaintBoundary boundary = _globalKey.currentContext.findRenderObject();
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    var pngBytes = byteData.buffer.asUint8List();
    final temp = await getTemporaryDirectory();
    final newPath = join(temp.path, '${DateTime.now().millisecondsSinceEpoch}.png');

    final file = await File(newPath).writeAsBytes(pngBytes);

    return file.path;
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
                  File(widget.filePath),
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
        future = _compressVideo().then((path) => filePath = path);
        break;
      case StoryType.image:
        future = _compressImage().then((path) => filePath = path);
        break;
      default:
    }
  }

  Future<void> _sendStory({
    String caption,
    List<dynamic> selectedReleases = const [],
  }) async {
    try {
      widget.publisherController.addStatus(PublisherStatus.compressing);

      if (widget.type == StoryType.image) {
        filePath = await _capturePng();
      } else {
        await future;
      }

      if (filePath is! String) throw Exception("Fail to compress story");

      widget.publisherController.addStatus(PublisherStatus.sending);

      final url = await _uploadFile(filePath);

      if (url is! String) throw Exception("Fail to upload story");

      await _dbInput(url, caption: caption, selectedReleases: selectedReleases);

      widget.publisherController.addStatus(PublisherStatus.none);

      widget.onStoryPosted?.call();
    } catch (e) {
      widget.publisherController.addStatus(PublisherStatus.failure);
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

    /// TODO: Search a way to compress video sucessfully
    // final mediaInfo = await VideoCompress.compressVideo(
    //   widget.filePath,
    //   deleteOrigin: true,
    //   quality: VideoQuality.MediumQuality,
    // );

    // compressedPath = mediaInfo.path;

    // debugPrint('video after = ${mediaInfo.file.lengthSync() / 1000} kB');

    filePath = widget.filePath;

    return filePath;
  }

  void addAttachment(AttachmentWidget attachment) {
    setState(() => mediaAttachments.add(attachment));
  }

  void removeAttachment(AttachmentWidget attachment) {
    setState(() => mediaAttachments.remove(attachment));
  }

  Future<String> _uploadFile(String path) async {
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

    final StorageTaskSnapshot downloadUrl = await uploadTask.onComplete;

    final String url = await downloadUrl.ref.getDownloadURL();

    return url;
  }

  Future<void> _dbInput(
    String url, {
    String caption,
    List<dynamic> selectedReleases,
  }) async {
    final firestore = Firestore.instance;

    final publishDate = DateTime.now();

    final collectionInfo = {
      "cover_img": widget.settings.coverImg,
      "last_update": publishDate,
      "title": {widget.settings.languageCode: widget.settings.username},
      "releases": widget.settings.releases,
    };

    final storyInfo = {
      "id": Uuid().v4(),
      "date": publishDate,
      "media": {widget.settings.languageCode: url},
      "caption": {widget.settings.languageCode: caption},
      "releases": selectedReleases,
      "type": _extractType,
    };

    final doc = await firestore
        .collection(widget.settings.collectionDbPath)
        .document(widget.settings.userId)
        .get();

    if (doc.exists) {
      final stories = doc.data["stories"] ?? List();

      assert(
          stories is List,
          "The field [stories] in ${widget.settings.collectionDbPath}/"
          "${widget.settings.userId} need be a List");

      stories.add(storyInfo);

      collectionInfo.addAll({"stories": stories});

      await doc.reference.updateData(collectionInfo);
    } else {
      collectionInfo.addAll({
        "stories": [storyInfo]
      });
      await doc.reference.setData(collectionInfo);
    }
  }

  String get _extractType => widget.type.toString().split('.')[1];
}
