import 'dart:io';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

Future<String> fixExifRotation(String imagePath, {bool isFront = false}) async {
  final originalFile = File(imagePath);
  List<int> imageBytes = await originalFile.readAsBytes();

  final originalImage = img.decodeImage(imageBytes);

  final height = originalImage.height;
  final width = originalImage.width;

  // Let's check for the image size
  if (height >= width) {
    // I'm interested in portrait photos so
    // I'll just return here
    return originalFile.path;
  }

  // We'll use the exif package to read exif data
  // This is map of several exif properties
  // Let's check 'Image Orientation'
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

  // Here you can select whether you'd like to save it as png
  // or jpg with some compression
  // I choose jpg with 100% quality
  final fixedFile = await originalFile.writeAsBytes(img.encodeJpg(fixedImage));

  return fixedFile.path;
}
