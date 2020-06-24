import 'dart:async';

import 'package:rxdart/rxdart.dart';

enum PlaybackState { pause, play, previous, forward, stop }

/// Controller to sync playback between animated child (story) views. This
/// helps make sure when stories are paused, the animation (gifs/slides) are
/// also paused.
///
/// Another reason for using the controller is to place the stories on `paused`
/// state when a media is loading.
class StoryController {
  /// Stream that broadcasts the playback state of the stories.
  var _playbackNotifier = BehaviorSubject<PlaybackState>();

  StreamSubscription<PlaybackState> _subs;

  var _myStoriesState;

  Future<StreamSubscription<PlaybackState>> addListener(
      void Function(PlaybackState) listener) async {
    // await _subs?.cancel();
    return _subs = _playbackNotifier.listen(listener);
  }

  /// Notify listeners with a [PlaybackState.pause] state
  void pause() {
    _playbackNotifier.add(PlaybackState.pause);
  }

  /// Notify listeners with a [PlaybackState.play] state
  void play() {
    _playbackNotifier.add(PlaybackState.play);
  }

  void stop() {
    _playbackNotifier.add(PlaybackState.stop);
  }

  void goForward() {
    _playbackNotifier.add(PlaybackState.forward);
  }

  void goBack() {
    _playbackNotifier.add(PlaybackState.previous);
  }

  void attachMyStories(dynamic myStoriesState) {
    assert(myStoriesState != null);
    _myStoriesState = myStoriesState;
  }

  void dettachMyStories() {
    _myStoriesState = null;
  }

  Future<void> deleteCurrentStory(int index) async {
    assert(_myStoriesState != null);
    return await _myStoriesState.deleteStory(index);
  }

  /// Remember to call dispose when the story screen is disposed to close
  /// the notifier stream.
  void dispose() {
    _playbackNotifier.close().whenComplete(() {
      _playbackNotifier = BehaviorSubject<PlaybackState>();
    });
  }
}
