part of '../views/story_publisher.dart';

class PublisherController {
  final _uploadStatus = StreamController<PublisherStatus>()..add(PublisherStatus.none);

  final StoryType initialType;

  final CameraLensDirection initialCamera;

  Stream _stream;

  _StoryPublisherState _publisherState;

  _StoryPublisherResultState _resultState;

  PublisherController({
    this.initialType = StoryType.image,
    this.initialCamera = CameraLensDirection.front,
  }) {
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
    _publisherState.changeLens(direction);
  }

  void changeType(StoryType type) {
    assert(_publisherState != null, "No [StoryPublisher] attached to controller");
    _publisherState.changeType(type);
  }

  Future<ExternalMediaStatus> sendExternal(File file, StoryType type) {
    return _publisherState.sendExternalMedia(file, type);
  }

  void addAttachment(AttachmentWidget attachment) {
    assert(_resultState != null, "No [_StoryPublisherResult] attached to controller");
    _resultState.addAttachment(attachment);
  }

  void removeAttachment(AttachmentWidget attachment) {
    assert(_resultState != null, "No [_StoryPublisherResult] attached to controller");
    _resultState.removeAttachment(attachment);
  }

  Future<File> saveStory(String directory) async {
    assert(_resultState != null, "No [_StoryPublisherResult] attached to controller");

    var filePath;

    if (_resultState.widget.type == StoryType.image) {
      filePath = await _resultState._capturePng();
    } else {
      filePath = _resultState.widget.filePath;
    }

    final basename = path.basename(filePath);

    final file = File(path.join(directory, basename));

    return file.writeAsBytes(await File(filePath).readAsBytes());
  }

  void dispose() {
    _uploadStatus?.close();
  }
}
