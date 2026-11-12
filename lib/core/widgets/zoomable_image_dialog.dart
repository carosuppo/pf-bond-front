import 'package:flutter/material.dart';

import 'reset_on_release_interactive_viewer.dart';

Future<void> showZoomableImageDialog(
  BuildContext context, {
  required String imageUrl,
  String closeLabel = 'Cerrar imagen',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: _ZoomableImageViewer(imageUrl: imageUrl, closeLabel: closeLabel),
      ),
    ),
  );
}

class _ZoomableImageViewer extends StatelessWidget {
  const _ZoomableImageViewer({
    required this.imageUrl,
    required this.closeLabel,
  });

  final String imageUrl;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ResetOnReleaseInteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 56,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: closeLabel,
            color: Colors.white,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
