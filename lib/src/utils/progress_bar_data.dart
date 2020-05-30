/// Capsule holding the duration and shown property of each story. Passed down
/// to the pages bar to render the page indicators.
class PageData {
  final bool shown;
  final Duration duration;

  PageData(this.duration, this.shown);
}
