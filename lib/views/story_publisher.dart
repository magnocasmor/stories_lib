import 'dart:io';
import 'dart:async';
import 'package:stories_lib/configs/story_controller.dart';
import 'package:stories_lib/utils/fix_image_orientation.dart';
import 'package:stories_lib/views/story_view.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' show join, basename;
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:video_compress/video_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stories_lib/components/story_error.dart';
import 'package:stories_lib/components/story_widget.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/components/story_loading.dart';
import 'package:stories_lib/components/fitted_container.dart';
import 'package:stories_lib/configs/publisher_controller.dart';
import 'package:stories_lib/views/stories_collection_view.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

enum StoryType { text, image, video, gif }

typedef StoryPublisherToolsBuilder = Widget Function(
  BuildContext,
  StoryType,
  CameraLensDirection,
  void Function(StoryType),
  void Function(CameraLensDirection),
  void Function(String, StoryType),
);

typedef StoryPublisherPreviewToolsBuilder = Widget Function(
  BuildContext,
  File,
  void Function({List selectedReleases}),
);

typedef StoryPublisherButtonBuilder = Widget Function(
  BuildContext,
  StoryType,
  Animation<double>,
  void Function(StoryType),
);

class StoryPublisher extends StatefulWidget {
  final bool hasPublish;
  final Widget closeButton;
  final Widget errorWidget;
  final Widget loadingWidget;
  final Duration videoDuration;
  final StoriesSettings settings;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final StoryController storyController;
  final StoryOverlayInfoBuilder overlayInfoBuilder;
  final StoryPublisherToolsBuilder toolsBuilder;
  final PublisherController publisherController;
  final StoryPublisherButtonBuilder publishBuilder;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  const StoryPublisher({
    Key key,
    @required this.settings,
    this.errorWidget,
    this.closeButton,
    this.toolsBuilder,
    this.loadingWidget,
    this.publishBuilder,
    this.onStoryPosted,
    this.storyController,
    this.resultToolsBuilder,
    this.overlayInfoBuilder,
    this.publisherController,
    this.hasPublish = false,
    this.backgroundBetweenStories,
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
  Animation<double> animation;
  Future cameraInitialization;
  PageController pageController;
  CameraLensDirection direction;
  CameraController cameraController;
  AnimationController animationController;
  bool showPublishes = true;

  @override
  void initState() {
    cameraInitialization = initializeController(direction: CameraLensDirection.front);

    type = StoryType.image;

    animationController = AnimationController(vsync: this, duration: widget.videoDuration);

    animation = animationController.drive(Tween(begin: 0.0, end: 1.0));

    pageController = PageController();

    super.initState();
  }

  @override
  void dispose() {
    videoTimer?.cancel();
    cameraController?.dispose();
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        PageView(
          pageSnapping: true,
          controller: pageController,
          children: <Widget>[
            if (widget.hasPublish) myStories(),
            publishStory(),
          ],
        ),
        Align(
          alignment: widget.closeButtonPosition,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: widget.closeButton,
          ),
        ),
      ],
    );
  }

  Widget publishStory() {
    return Scaffold(
      backgroundColor: widget.backgroundBetweenStories,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(
              child: FutureBuilder<void>(
                future: cameraInitialization,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return widget.errorWidget ??
                        StoryError(
                          info: "Open camera failed.",
                        );
                  switch (snapshot.connectionState) {
                    case ConnectionState.done:
                      return FittedContainer(
                        fit: BoxFit.cover,
                        width: cameraController.value.previewSize?.height ?? 0,
                        height: cameraController.value.previewSize?.width ?? 0,
                        child: AspectRatio(
                          aspectRatio: cameraController.value.aspectRatio,
                          child: CameraPreview(cameraController),
                        ),
                      );
                      break;
                    default:
                      return widget.loadingWidget ?? StoryLoading();
                  }
                },
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: FutureBuilder<void>(
                    future: cameraInitialization,
                    builder: (context, snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.done:
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              if (widget.publishBuilder != null)
                                widget.publishBuilder(context, type, animation, _processStory),
                              if (widget.toolsBuilder != null)
                                Flexible(
                                  child: IgnorePointer(
                                    ignoring: cameraController.value.isRecordingVideo,
                                    child: widget.toolsBuilder(
                                      context,
                                      type,
                                      cameraController.description.lensDirection,
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
      ),
    );
  }

  Widget myStories() {
    return WillPopScope(
      onWillPop: () {
        showPublishes = false;
        pageController?.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.ease);
        return Future.value(false);
      },
      child: StoriesCollectionView(
        repeat: false,
        inline: false,
        settings: widget.settings,
        storiesIds: [widget.settings.userId],
        storyController: widget.storyController,
        selectedStoryId: widget.settings.userId,
        overlayInfoBuilder: widget.overlayInfoBuilder,
        // sortingOrderDesc: true,
        backgroundBetweenStories: widget.backgroundBetweenStories,
      ),
    );
  }

  Future<void> initializeController({CameraLensDirection direction}) async {
    final cameras = await availableCameras();

    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => cameras.first,
    );

    cameraController = CameraController(selectedCamera, ResolutionPreset.high);

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
    videoTimer = Timer(widget.videoDuration, _stopVideoRecording);

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

  void _sendExternalMedia(String path, StoryType type) async {
    storyPath = path;
    this.type = type;

    _goToStoryResult();
  }

  void _goToStoryResult() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, anim2) {
          return _StoryPublisherResult(
            type: type,
            filePath: storyPath,
            settings: widget.settings,
            closeButton: widget.closeButton,
            onStoryPosted: widget.onStoryPosted,
            resultToolsBuilder: widget.resultToolsBuilder,
            closeButtonPosition: widget.closeButtonPosition,
            publisherController: widget.publisherController,
            backgroundBetweenStories: widget.backgroundBetweenStories,
          );
        },
      ),
    );
  }
}

class _StoryPublisherResult extends StatefulWidget {
  final StoryType type;
  final String filePath;
  final Widget closeButton;
  final StoriesSettings settings;
  final VoidCallback onStoryPosted;
  final Alignment closeButtonPosition;
  final Color backgroundBetweenStories;
  final PublisherController publisherController;
  final StoryPublisherPreviewToolsBuilder resultToolsBuilder;

  _StoryPublisherResult({
    Key key,
    @required this.type,
    @required this.settings,
    @required this.filePath,
    @required this.publisherController,
    this.closeButton,
    this.onStoryPosted,
    this.resultToolsBuilder,
    this.closeButtonPosition,
    this.backgroundBetweenStories,
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
  TextEditingController captionController;

  @override
  void initState() {
    _compress();
    widget.publisherController.addStatus(PublisherStatus.showingResult);
    storyFile = File(widget.filePath);
    if (widget.type == StoryType.video) {
      controller = VideoPlayerController.file(storyFile);
      controller.setLooping(true);
      controllerFuture = controller.initialize();
    }

    captionController = TextEditingController();

    super.initState();
  }

  @override
  void dispose() {
    controller?.pause();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundBetweenStories,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            StoryWidget(story: _buildPreview()),
            Align(
              alignment: widget.closeButtonPosition,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: widget.closeButton,
              ),
            ),
            Align(
              alignment: widget.closeButtonPosition,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 56.0),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.text_fields,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // SafeArea(
            //   child: Align(
            //     alignment: Alignment.bottomCenter,
            //     child: Container(
            //       width: double.infinity,
            //       margin: EdgeInsets.only(
            //         bottom: 24,
            //       ),
            //       padding: EdgeInsets.symmetric(
            //         horizontal: 56,
            //         vertical: 8,
            //       ),
            //       color: Colors.black54,
            //       child: TextField(
            //         controller: captionController,
            //         decoration: InputDecoration(
            //           border: InputBorder.none,
            //           contentPadding: const EdgeInsets.all(0.0),
            //           isDense: true,
            //           hintText: "Adicione uma legenda",
            //           hintStyle: TextStyle(
            //             fontSize: 15,
            //             color: Colors.white.withOpacity(0.5),
            //           ),
            //         ),
            //         style: TextStyle(
            //           fontSize: 15,
            //           color: Colors.white,
            //         ),
            //         textAlign: TextAlign.center,
            //         minLines: 1,
            //         maxLines: 4,
            //         keyboardType: TextInputType.multiline,
            //       ),
            //     ),
            //   ),
            // ),
            if (widget.resultToolsBuilder != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: widget.resultToolsBuilder(context, storyFile, _sendStory),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    switch (widget.type) {
      case StoryType.image:
        return Image.file(
          storyFile,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
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

  Future<void> _sendStory({List<dynamic> selectedReleases}) async {
    try {
      widget.publisherController.addStatus(PublisherStatus.compressing);
      await compressFuture;

      if (compressedPath is! String) throw Exception("Fail to compress story");

      widget.publisherController.addStatus(PublisherStatus.sending);
      final url = await _uploadFile(compressedPath);

      if (url is! String) throw Exception("Fail to upload story");

      await _sendToFirestore(url, selectedReleases: selectedReleases);

      widget.publisherController.addStatus(PublisherStatus.complete);

      widget.onStoryPosted?.call();
    } catch (e) {
      widget.publisherController.addStatus(PublisherStatus.failure);
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

      final storageReference = FirebaseStorage.instance
          .ref()
          .child("stories")
          .child(widget.settings.userId)
          .child(fileName);

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

  Future<void> _sendToFirestore(String url, {List<dynamic> selectedReleases}) async {
    try {
      final firestore = Firestore.instance;

      final collectionInfo = {
        "cover_img": widget.settings.coverImg,
        "last_update": DateTime.now(),
        "title": {widget.settings.languageCode: widget.settings.username},
        "releases": widget.settings.releases,
      };

      final storyInfo = {
        "id": Uuid().v4(),
        "date": DateTime.now(),
        "media": {widget.settings.languageCode: url},
        "caption": {widget.settings.languageCode: captionController.text},
        "releases": selectedReleases,
        "type": _extractType,
      };

      final userDoc = await firestore
          .collection(widget.settings.collectionDbName)
          .document(widget.settings.userId)
          .get();

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
      debugPrint(e);
      debugPrint(s.toString());
    }
  }

  String get _extractType => widget.type.toString().split('.')[1];
}
