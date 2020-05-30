part of '../views/story_view.dart';

/// This is a representation of a story item (or page).
class StoryWrap extends ChangeNotifier {
  /// Specifies how long the page should be displayed. It should be a reasonable
  /// amount of time greater than 0 milliseconds.
  Duration _duration;

  /// Has this page been shown already? This is used to indicate that the page
  /// has been displayed. If some pages are supposed to be skipped in a story,
  /// mark them as shown `shown = true`.
  ///
  /// However, during initialization of the story view, all pages after the
  /// last unshown page will have their [shown] attribute altered to false. This
  /// is because the next item to be displayed is taken by the last unshown
  /// story item.
  bool shown;

  /// The page content
  final Widget view;

  StoryWrap({
    @required this.view,
    Duration duration = const Duration(seconds: 5),
    this.shown = false,
  })  : assert(duration != null),
        _duration = duration;

  /// Short hand to create text-only page.
  ///
  /// [text] is the text to be displayed on [backgroundColor]. The text color
  /// alternates between [Colors.black] and [Colors.white] depending on the
  /// calculated contrast. This is to ensure readability of text.
  ///
  /// Works for inline and full-page stories. See [StoryView.inline] for more on
  /// what inline/full-page means.
  factory StoryWrap.text({
    @required String text,
    @required Color backgroundColor,
    TextStyle style,
    bool shown,
    Duration duration,
    bool roundedTop = false,
    bool roundedBottom = false,
  }) {
    assert(text is String);

    if (backgroundColor == null) backgroundColor = Colors.black;

    final _contrast = contrast([
      backgroundColor.red,
      backgroundColor.green,
      backgroundColor.blue,
    ], [
      255,
      255,
      255
    ] /** white text */);

    return StoryWrap(
      view: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundedTop ? 8 : 0),
            bottom: Radius.circular(roundedBottom ? 8 : 0),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Center(
          child: Text(
            text,
            style: (style ?? TextStyle())
                .copyWith(color: _contrast > 1.8 ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        color: backgroundColor,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for a full-page image content.
  ///
  /// You can provide any image provider for [image].
  factory StoryWrap.pageImage({
    @required ImageProvider image,
    String caption,
    Widget errorWidget,
    Widget loadingWidget,
    bool shown,
    Duration duration,
    BoxFit fit = BoxFit.cover,
  }) {
    assert(fit != null);

    return StoryWrap(
      view: StoryWidget(
        story: Image(
          image: image,
          fit: fit,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for creating inline image page.
  factory StoryWrap.inlineImage({
    @required ImageProvider image,
    bool shown,
    Text caption,
    Duration duration,
    bool roundedTop = true,
    BoxFit fit = BoxFit.cover,
    bool roundedBottom = true,
  }) {
    assert(fit != null);

    return StoryWrap(
      view: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundedTop ? 8.0 : 0),
            bottom: Radius.circular(roundedBottom ? 8.0 : 0),
          ),
          image: DecorationImage(
            image: image,
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 8,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              child: caption == null ? SizedBox() : caption,
              width: double.infinity,
            ),
          ),
        ),
      ),
      shown: shown,
      duration: duration,
    );
  }

  factory StoryWrap.pageGif({
    @required String url,
    bool shown,
    String caption,
    Duration duration,
    Widget errorWidget,
    Widget loadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    BoxFit fit = BoxFit.cover,
  }) {
    assert(fit != null);

    return StoryWrap(
      view: StoryWidget(
        story: StoryImage.url(
          url: url,
          fit: fit,
          controller: controller,
          errorWidget: errorWidget,
          requestHeaders: requestHeaders,
          loadingWidget: loadingWidget,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  /// Shorthand for creating inline gif page.
  factory StoryWrap.inlineGif({
    @required String url,
    bool shown,
    Text caption,
    Duration duration,
    Widget errorWidget,
    Widget loadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    bool roundedTop = true,
    BoxFit fit = BoxFit.cover,
    bool roundedBottom = false,
  }) {
    return StoryWrap(
      view: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundedTop ? 8.0 : 0),
            bottom: Radius.circular(roundedBottom ? 8.0 : 0),
          ),
        ),
        child: Container(
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              StoryImage.url(
                url: url,
                controller: controller,
                fit: fit,
                errorWidget: errorWidget,
                loadingWidget: loadingWidget,
                requestHeaders: requestHeaders,
              ),
              caption.data != null && caption.data.length > 0
                  ? Container(
                      margin: EdgeInsets.only(
                        bottom: 16,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          child: caption == null ? SizedBox() : caption,
                          width: double.infinity,
                        ),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
      shown: shown,
      duration: duration,
    );
  }

  factory StoryWrap.pageVideo({
    @required String url,
    bool shown,
    String caption,
    Widget errorWidget,
    Widget loadingWidget,
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    BoxFit fit = BoxFit.cover,
    Duration duration = const Duration(seconds: 10),
  }) {
    assert(fit != null);
    return StoryWrap(
      view: StoryWidget(
        story: StoryVideo.url(
          url: url,
          fit: fit,
          controller: controller,
          requestHeaders: requestHeaders,
          errorWidget: errorWidget,
          loadingWidget: loadingWidget,
        ),
        caption: caption,
      ),
      shown: shown,
      duration: duration,
    );
  }

  Duration get duration => _duration;

  /// Whatever duration changes, notify listeners
  set duration(Duration d) {
    _duration = d;
    notifyListeners();
  }
}
