import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stories_lib/stories.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as provider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StoriesSettings settings;
  final publisherController = PublisherController();
  final storyController = StoryController();

  @override
  void initState() {
    super.initState();

    settings = StoriesSettings(
      userId: "00000000000",
      languageCode: 'pt',
      username: "Jubscleiton",
      storyTimeValidaty: const Duration(hours: 12),
      coverImg:
          "https://images.unsplash.com/photo-1468218457742-ee484fe2fe4c?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1053&q=80",
      sortByDesc: true,
      collectionDbPath: "stories",
      storyDuration: const Duration(seconds: 5),
      releases: [
        {"release": 1},
      ],
    );
  }

  @override
  void dispose() {
    publisherController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Stories")),
      body: Stories.withMyStories(
        settings: settings,
        closeButton: closeButton(),
        myPreviewBuilder: myPreview,
        previewBuilder: storyPreview,
        storyController: storyController,
        infoLayerBuilder: storyInfoLayer,
        takeStoryBuilder: takeStoryButton,
        resultInfoBuilder: resultInfoBuilder,
        myInfoLayerBuilder: myStoryInfoLayer,
        publisherLayerBuilder: publisherLayer,
        previewListPadding: EdgeInsets.all(8.0),
        backgroundBetweenStories: Colors.black,
        closeButtonPosition: Alignment.topRight,
        publisherController: publisherController,
        navigationTransition: storyScreenTransition,
      ),
    );
  }

  Widget storyPreview(
    BuildContext context,
    ImageProvider image,
    String title,
    bool hasPublish,
  ) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 65.0,
          width: 65.0,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: hasPublish ? 1.0 : 0.0,
                  backgroundColor: Colors.white,
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(3.0),
                child: CircleAvatar(
                  backgroundImage: image,
                  radius: 30.0,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title),
        ),
      ],
    );
  }

  Widget storyInfoLayer(
    ImageProvider image,
    String title,
    DateTime date,
    List<PageData> bars,
    int current,
    Animation<double> anim,
    List _,
  ) {
    return Positioned(
      top: 16.0,
      right: 16.0,
      left: 16.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: progressBar(bars: bars, current: current, anim: anim),
          ),
          storyHeader(image: image, title: title, date: date),
        ],
      ),
    );
  }

  Widget storyHeader({
    ImageProvider image,
    Widget imageOverlay,
    String title,
    DateTime date,
    VoidCallback onImagePressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: onImagePressed,
            child: CircleAvatar(
              radius: 16.0,
              backgroundImage: image,
              child: imageOverlay,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                    ),
                  ),
                  Text(
                    "${date.second.toString()}s",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10.0,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget progressBar({List<PageData> bars, int current, Animation<double> anim}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: bars.map<Widget>((bar) {
        final isShwon = bars.indexOf(bar) == current;
        final isShowed = bars.indexOf(bar) < current;
        return Flexible(
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white38,
                  value: isShwon ? anim.value : (isShowed ? 1.0 : 0.0),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget closeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Icon(
        Icons.close,
        color: Colors.white,
      ),
    );
  }

  Widget storyScreenTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final begin = Offset(0.0, 1.0);
    final end = Offset.zero;
    final curve = Curves.ease;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }

  Widget resultInfoBuilder(BuildContext context, PublishStory publishStory) {
    return Positioned(
      top: 80.0,
      right: 16.0,
      left: 16.0,
      bottom: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            child: Icon(Icons.text_fields, color: Colors.white),
            onTap: () {
              publisherController.addAttachment(
                AttachmentWidget(
                  key: UniqueKey(),
                  child: FlutterLogo(
                    size: 100.0,
                  ),
                ),
              );
            },
          ),
          Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.file_download),
                color: Colors.white,
                onPressed: () async {
                  final directory = await provider.getApplicationDocumentsDirectory();
                  await publisherController.saveStory(directory.path);
                },
              ),
              FloatingActionButton(
                child: Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  publishStory();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget takeStoryButton(
    StoryType type,
    Animation<double> anim,
    void Function(StoryType) takeStory,
  ) {
    return Positioned(
      left: 0.0,
      right: 0.0,
      bottom: 72.0,
      child: GestureDetector(
        onTap: () => takeStory(type),
        child: Center(
          child: SizedBox(
            height: 72.0,
            width: 72.0,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                return CircularProgressIndicator(
                  value: anim.value,
                  backgroundColor: Colors.white,
                  strokeWidth: 4.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget myPreview(context, image, hasPublish, hasNewPublish) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 65.0,
          width: 65.0,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: StreamBuilder<PublisherStatus>(
                  initialData: PublisherStatus.none,
                  stream: publisherController.stream,
                  builder: (context, snapshot) {
                    final sending = snapshot.data == PublisherStatus.compressing ||
                        snapshot.data == PublisherStatus.sending;
                    return CircularProgressIndicator(
                      value: sending ? null : 1.0,
                      backgroundColor: Colors.white,
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasNewPublish
                            ? Colors.purpleAccent
                            : (hasPublish ? Colors.grey : Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(3.0),
                child: CircleAvatar(
                  backgroundImage: image,
                  radius: 30.0,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("Você"),
        ),
      ],
    );
  }

  Widget publisherLayer(
    BuildContext context,
    StoryType type,
  ) {
    return Positioned(
      bottom: 16.0,
      right: 16.0,
      left: 16.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.file_upload),
            color: Colors.white,
            onPressed: () async {
              await showDialog(
                context: context,
                barrierDismissible: true,
                child: AlertDialog(
                  title: Text("Escolha o tipo da mídia"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        leading: Icon(Icons.image),
                        title: Text("Foto"),
                        onTap: () async {
                          final file = await ImagePicker.pickImage(source: ImageSource.gallery);
                          Navigator.pop(context);
                          publisherController.sendExternal(file, StoryType.image);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.play_circle_outline),
                        title: Text("Vídeo"),
                        onTap: () async {
                          final file = await ImagePicker.pickVideo(source: ImageSource.gallery);
                          Navigator.pop(context);
                          publisherController.sendExternal(file, StoryType.video);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: SingleChildScrollView(
              child: Row(
                children: StoryType.values
                    .map<Widget>(
                      (t) => RawMaterialButton(
                        constraints: BoxConstraints(
                          maxHeight: 40.0,
                          minHeight: 30.0,
                          maxWidth: 70.0,
                          minWidth: 60.0,
                        ),
                        padding: const EdgeInsets.all(0.0),
                        visualDensity: VisualDensity.standard,
                        onPressed: () {
                          publisherController.changeType(t);
                        },
                        child: Text(
                          t.toString().split(".")[1],
                          style: TextStyle(
                            color: type == t ? Colors.white : Colors.white54,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.switch_camera),
            color: Colors.white,
            onPressed: publisherController.switchCamera,
          ),
        ],
      ),
    );
  }

  Widget myStoryInfoLayer(
    ImageProvider image,
    String title,
    DateTime date,
    List<PageData> bars,
    int current,
    Animation<double> anim,
    List viewers,
    VoidCallback goToPublisher,
  ) {
    return Positioned(
      top: 16.0,
      right: 16.0,
      left: 16.0,
      bottom: 16.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: progressBar(bars: bars, current: current, anim: anim),
          ),
          storyHeader(
            image: image,
            title: "Você",
            date: date,
            onImagePressed: goToPublisher,
          ),
        ],
      ),
    );
  }
}
