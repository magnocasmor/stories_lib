import 'dart:async';

enum PublisherStatus { none, showingResult, compressing, sending, complete, failure }

class PublisherController {
  final _uploadStatus = StreamController<PublisherStatus>()..add(PublisherStatus.none);

  Stream _stream;

  PublisherController() {
    _stream = _uploadStatus.stream.asBroadcastStream();
  }

  Stream<PublisherStatus> get stream => _stream;

  void addStatus(PublisherStatus status) {
    _uploadStatus?.add(status);
  }

  void dispose() {
    _uploadStatus?.close();
  }
}
