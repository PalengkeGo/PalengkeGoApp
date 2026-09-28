import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const canvasSize = 512;
  const brandColor = 0xFF235108; // ABGR: A=0xFF, B=0x23, G=0x51, R=0x08 -> #085123

  // 1. Load logo.png
  final logoBytes = File('assets/images/logo.png').readAsBytesSync();
  final logo = img.decodePng(logoBytes)!;
  print('Loaded logo.png: ${logo.width}x${logo.height}');

  // Create 512x512 canvas filled with brand green #085123
  final fullCanvas = img.Image(width: canvasSize, height: canvasSize);
  img.fill(fullCanvas, color: img.ColorRgba8(8, 81, 35, 255));

  // Place native uncompressed logo.png in the center
  // Native logo is 322x160.
  // (512 - 322) / 2 = 95, (512 - 160) / 2 = 176
  final dstX = (canvasSize - logo.width) ~/ 2;
  final dstY = (canvasSize - logo.height) ~/ 2;

  img.compositeImage(
    fullCanvas,
    logo,
    dstX: dstX,
    dstY: dstY,
  );

  final outIconPath = 'assets/images/app_launcher_icon.png';
  File(outIconPath).writeAsBytesSync(img.encodePng(fullCanvas));
  print('Wrote $outIconPath (${fullCanvas.width}x${fullCanvas.height})');

  // 2. Load logonobg.png for adaptive foreground
  final noBgBytes = File('assets/images/logonobg.png').readAsBytesSync();
  final noBgLogo = img.decodePng(noBgBytes)!;
  print('Loaded logonobg.png: ${noBgLogo.width}x${noBgLogo.height}');

  // Scale logonobg proportionally to fit nicely in the adaptive safe zone (~300px wide)
  final targetWidth = 300;
  final targetHeight = (targetWidth * noBgLogo.height / noBgLogo.width).round();
  final scaledNoBg = img.copyResize(
    noBgLogo,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );

  final fgCanvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(fgCanvas, color: img.ColorRgba8(0, 0, 0, 0));

  final fgX = (canvasSize - scaledNoBg.width) ~/ 2;
  final fgY = (canvasSize - scaledNoBg.height) ~/ 2;

  img.compositeImage(
    fgCanvas,
    scaledNoBg,
    dstX: fgX,
    dstY: fgY,
  );

  final outFgPath = 'assets/images/app_launcher_foreground.png';
  File(outFgPath).writeAsBytesSync(img.encodePng(fgCanvas));
  print('Wrote $outFgPath (${fgCanvas.width}x${fgCanvas.height})');
}
