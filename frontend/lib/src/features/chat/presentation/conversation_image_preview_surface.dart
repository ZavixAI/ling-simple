import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LingConversationImagePreviewSurface extends StatelessWidget {
  const LingConversationImagePreviewSurface({
    super.key,
    required this.image,
    this.controls,
    this.aspectRatio,
  });

  final Widget image;
  final Widget? controls;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('conversation_image_preview_background'),
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = _previewSize(constraints, aspectRatio);
              return SizedBox(
                width: size.width,
                height: size.height,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: image,
                ),
              );
            },
          ),
        ),
        if (controls != null) Positioned(top: 12, right: 12, child: controls!),
      ],
    );
  }
}

Size _previewSize(BoxConstraints constraints, double? aspectRatio) {
  final maxWidth = constraints.maxWidth;
  final maxHeight = constraints.maxHeight;
  final ratio = aspectRatio != null && aspectRatio > 0 ? aspectRatio : 1.0;
  var width = maxWidth;
  var height = width / ratio;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * ratio;
  }
  return Size(width, height);
}

Future<double?> decodeLingConversationImageAspectRatio(Uint8List bytes) async {
  if (bytes.isEmpty) {
    return null;
  }
  try {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    final image = await completer.future;
    final width = image.width;
    final height = image.height;
    image.dispose();
    if (width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  } catch (_) {
    return null;
  }
}
