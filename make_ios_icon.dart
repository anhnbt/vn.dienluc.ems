import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('icon-2048.png');
  final image = decodePng(file.readAsBytesSync());
  if (image == null) return;
  final background = Image(image.width, image.height);
  fill(background, getColor(255, 255, 255));
  drawImage(background, image);
  // remove alpha flag in image 3.3.0 isn't strictly needed if we Composite, 
  // but to be absolutely sure, we can strip alpha channels by converting to jpeg then to png
  File('icon_ios.png').writeAsBytesSync(encodePng(background));
  
  final fileJpeg = File('icon_ios.png');
  final imgFinal = decodePng(fileJpeg.readAsBytesSync());
  if (imgFinal != null) {
      final imgNoAlpha = Image(imgFinal.width, imgFinal.height, channels: Channels.rgb);
      drawImage(imgNoAlpha, imgFinal);
      File('icon_ios.png').writeAsBytesSync(encodePng(imgNoAlpha));
  }
  print('Done converting logo to opaque icon_ios.png');
}
