import 'dart:io';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

/// 
Future<String> fixExifRotation(String imagePath, {bool isFront = false}) async {
  final originalFile = File(imagePath);
  List<int> imageBytes = await originalFile.readAsBytes();

  final originalImage = img.decodeImage(imageBytes);

  final height = originalImage.height;
  final width = originalImage.width;

  if (height >= width) {
    return originalFile.path;
  }

  final exifData = await readExifFromBytes(imageBytes);

  img.Image fixedImage;

  final info = exifData['Image Orientation'].values.first ?? 0;

  switch (info) {
    case 1:
      if (isFront)
        fixedImage = img.copyRotate(originalImage, -90);
      else
      fixedImage = img.copyRotate(originalImage, 90);
      break;
    case 3:
      if (isFront)
        fixedImage = img.copyRotate(originalImage, 90);
      else
      fixedImage = img.copyRotate(originalImage, -90);
      break;
    case 8:
      // fixedImage = img.copyRotate(originalImage, 180);
      break;
    default:
      fixedImage = img.copyRotate(originalImage, 0);
  }

  if (isFront) fixedImage = img.flipVertical(fixedImage);

  final fixedFile = await originalFile.writeAsBytes(img.encodeJpg(fixedImage));

  return fixedFile.path;
}
