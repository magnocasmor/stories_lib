class ExceededDurationException implements Exception {}

class ExceededSizeException implements Exception {}

class CompressFailException implements Exception {
  final String message;

  CompressFailException([this.message]);
}

class UploadFailException implements Exception {
  final String message;

  UploadFailException([this.message]);
}

class ShortDurationException implements Exception {}
