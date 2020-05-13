import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:stories_lib/components/stories_placeholder.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:stories_lib/configs/publisher_controller.dart';
import 'package:stories_lib/configs/stories_settings.dart';
import 'package:stories_lib/views/stories.dart';
import 'package:stories_lib/views/story_publisher.dart';

void main() async {
  // timeDilation = 5.0;
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
        theme: Themes.darkTheme,
        darkTheme: Themes.darkTheme,
        home: Home());
  }
}

class Home extends StatefulWidget {

  const Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StoriesSettings settings;
  final controller = PublisherController();

  @override
  void initState() {
    super.initState();

    settings = StoriesSettings(
      userId: "user_uid",
      languageCode: 'pt',
      username: "Jubscleiton",
      storyTimeValidaty: const Duration(hours: 12),
      coverImg: "https://images.unsplash.com/photo-1468218457742-ee484fe2fe4c?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1053&q=80",
      sortByDescUpdate: true,
      collectionDbName: 'stories_db',
      storyDuration: const Duration(seconds: 5),
      releases: [
        {"group": "dev"},
        {"campaign": 1},
        {"group": "admin"},
      ],
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Stories")),
      body: stories(),
    );
  }

  Widget stories() {
    return Stories(
      settings: settings,
      previewListPadding: const EdgeInsets.all(8.0),
      myStoriesPreview: myStories(),
      previewBuilder: previewBuilder,
      placeholderBuilder: placeholderBuilder,
      overlayInfoBuilder:
          (context, currentIndex, previewImage, title, views, postDate, datas, animation) {
        return Column(
          children: <Widget>[
            Row(
              children: datas.map(
                (it) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: datas.last == it ? 0 : 8.0),
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return SizedBox(
                            height: 3.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1.5),
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.black26,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                value: datas.indexOf(it) == currentIndex
                                    ? animation.value
                                    : it.shown ? 1 : 0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  position: DecorationPosition.foreground,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Hero(
                      tag: title,
                      transitionOnUserGestures: true,
                      child: CircleAvatar(
                        backgroundImage: previewImage,
                        // backgroundColor: Colors.purple,
                        radius: 20.0,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title),
                      Text(DateTime.now().difference(postDate).inHours.toString() + " horas"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
      storyOpenTransition: transition,
      inline: false,
      repeat: false,
      closeButton: closeButton(),
      closeButtonPosition: Alignment.topRight,
    );
  }

  Widget previewBuilder(context, image, title, hasNew) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: hasNew ? Colors.red : Colors.transparent,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(40.0),
            ),
            position: DecorationPosition.foreground,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Hero(
                tag: title,
                transitionOnUserGestures: true,
                child: CircleAvatar(
                  backgroundImage: image,
                  radius: 32.0,
                ),
              ),
            ),
          ),
          Text(title ?? ''),
        ],
      ),
    );
  }

  MyStories myStories() {
    return MyStories(
      settings: settings,
      publisherController: controller,
      closeButton: closeButton(),
      placeholderBuilder: placeholderBuilder,
      storyOpenTransition: transition,
      previewStoryBuilder: (context, image, hasPublish, hasNewPublish) {
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          hasNewPublish ? Colors.orange : (hasPublish ? Colors.blue : Colors.grey),
                      width: 2.0,
                    ),
                    image: image != null ? DecorationImage(image: image) : null,
                    borderRadius: BorderRadius.circular(40.0),
                  ),
                  position: DecorationPosition.background,
                  child: SizedBox(
                    height: 64.0,
                    width: 64.0,
                    child: Center(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Icon(
                            Icons.add,
                            size: 32.0,
                          ),
                          StreamBuilder<PublisherStatus>(
                            stream: controller.stream,
                            builder: (context, snapshot) {
                              switch (snapshot.data) {
                                case PublisherStatus.compressing:
                                case PublisherStatus.sending:
                                  return CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  );
                                  break;
                                default:
                                  return Container();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text("Você"),
            ],
          ),
        );
      },
      publishBuilder: (context, type, animation, processStory) {
        return GestureDetector(
          onTap: () => processStory(StoryType.image),
          onLongPressStart: (details) => processStory(StoryType.video),
          onLongPressEnd: (details) => processStory(StoryType.video),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 80.0,
              width: 80.0,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    backgroundColor: Colors.white,
                    strokeWidth: 4.0,
                    value: animation.value,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  );
                },
              ),
            ),
          ),
        );
      },
      toolsBuilder: (
        context,
        currentType,
        currentLens,
        changeType,
        changeLens,
        sendExternalMedia,
      ) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 42.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  child: Icon(
                    Icons.insert_photo,
                    size: 32.0,
                  ),
                  onTap: () async {
                    var file;
                    if (currentType == StoryType.video) {
                      file = await ImagePicker.pickVideo(source: ImageSource.gallery);
                      sendExternalMedia(file.path, StoryType.video);
                    } else {
                      file = await ImagePicker.pickImage(source: ImageSource.gallery);
                      sendExternalMedia(file.path, StoryType.image);
                    }
                  },
                ),
                Expanded(
                  child: Center(
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: StoryType.values.length,
                      itemBuilder: (context, index) {
                        final type = StoryType.values[index];
                        return Center(
                          child: GestureDetector(
                            onTap: () => changeType(type),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                type.toString().split('StoryType.')[1].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18.0,
                                  color: type == currentType ? Colors.white : Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(currentLens == CameraLensDirection.back
                      ? Icons.camera_front
                      : Icons.camera_rear),
                  onPressed: () => changeLens(
                    CameraLensDirection.values.take(2).firstWhere(
                          (lens) => lens != currentLens,
                          orElse: () => currentLens,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      resultToolsBuilder: (context, storyFile, type, sendStory) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.save_alt),
                onPressed: () {},
              ),
              StreamBuilder<PublisherStatus>(
                stream: controller.stream,
                builder: (context, snapshot) {
                  Widget icon;
                  switch (snapshot.data) {
                    case PublisherStatus.none:
                    case PublisherStatus.showingResult:
                    case PublisherStatus.failure:
                      icon = Icon(Icons.send);
                      break;
                    case PublisherStatus.compressing:
                    case PublisherStatus.sending:
                      icon = CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      );
                      break;
                    case PublisherStatus.complete:
                      icon = Icon(Icons.check);
                      break;
                  }
                  return FloatingActionButton(
                    child: icon,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) {
                        final selecteds = [];
                        return StatefulBuilder(builder: (context, setState) {
                          return Scaffold(
                            appBar: AppBar(
                              title: Text("Select releases"),
                            ),
                            body: ListView.builder(
                              itemCount: settings.releases.length,
                              itemBuilder: (context, index) {
                                final release = settings.releases[index] as Map;

                                final key = release.keys.toList()[0].toString();
                                final value = release.values.toList()[0].toString();
                                return CheckboxListTile(
                                  title: Text('$key - $value'),
                                  value: selecteds.contains(release),
                                  onChanged: (change) {
                                    if (change)
                                      selecteds.add(release);
                                    else
                                      selecteds.remove(release);
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                            floatingActionButton: StreamBuilder<Object>(
                                stream: controller.stream,
                                builder: (context, snapshot) {
                                  return FloatingActionButton(
                                    child: snapshot.data == PublisherStatus.sending ||
                                            snapshot.data == PublisherStatus.compressing
                                        ? CircularProgressIndicator()
                                        : Icon(Icons.check),
                                    onPressed: selecteds.isNotEmpty
                                        ? () {
                                            sendStory(selectedReleases: selecteds);
                                            Navigator.popUntil(context, ModalRoute.withName('/'));
                                          }
                                        : null,
                                  );
                                }),
                          );
                        });
                      }));
                    },
                  );
                },
              )
            ],
          ),
        );
      },
      onStoryPosted: () {
        // Navigator.popUntil(context, ModalRoute.withName('/'));
      },
    );
  }

  Widget placeholderBuilder(context, index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: 64.0,
        height: 64.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40.0),
          child: StoriesPlaceholder(),
        ),
      ),
    );
  }

  Widget closeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 16.0,
      ),
      child: Icon(
        Icons.close,
        size: 36.0,
      ),
    );
  }

  Widget transition(
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
}

class Themes {
  //Colors for theme
  static Color lightPrimary = Color(0xfffcfcff);
  static Color darkPrimary = Colors.grey[900];
  static Color lightGreen = Color(0xffedf2ca);
  static Color accentGreen = Color(0xff00c853);
  static Color lightAccent = Colors.blueGrey[900];
  static Color darkAccent = Colors.white;
  static Color lightBG = Color(0xfffcfcff);
  static Color darkBG = Colors.grey[900];
  static Color badgeColor = Colors.red;

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    backgroundColor: lightBG,
    primaryColor: lightPrimary,
    accentColor: lightAccent,
    cursorColor: lightAccent,
    scaffoldBackgroundColor: lightBG,
    inputDecorationTheme: InputDecorationTheme(labelStyle: TextStyle(color: Colors.black87)),
    appBarTheme: AppBarTheme(
      elevation: 0,
      textTheme: TextTheme(
        title: TextStyle(
          color: darkBG,
          fontSize: 18.0,
          fontWeight: FontWeight.w800,
        ),
      ),
      // iconTheme: IconThemeData(
      //   color: lightAccent,
      // ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    backgroundColor: darkBG,
    canvasColor: darkPrimary,
  );

  static InputDecoration inputPhoneStyle = InputDecoration(
    contentPadding: EdgeInsets.all(10.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5.0),
      borderSide: BorderSide(
        color: Colors.blue,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.blue,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.blue,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.red,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.red,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    hintText: '+7 000 000 00 00',
    labelText: 'Введи номер телефона',
  );

  static InputDecoration inputSmsStyle = InputDecoration(
    contentPadding: EdgeInsets.all(10.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5.0),
      borderSide: BorderSide(
        color: Colors.blue,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.blue,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.blue,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.red,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.red,
      ),
      borderRadius: BorderRadius.circular(5.0),
    ),
    hintText: '000000',
    labelText: 'Введи код из СМС',
  );
}
