import 'dart:io';

import 'package:flutter/material.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';

class ReportEvidencePicker extends StatelessWidget {
  const ReportEvidencePicker({
    super.key,
    required this.images,
    required this.onChanged,
  });

  final List<File> images;
  final ValueChanged<List<File>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: images.length >= 5
            ? null
            : () async {
                final image = await ImagePickerHelper.pickImage(context);
                if (image != null) onChanged([...images, image]);
              },
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text('Attach photos (${images.length}/5)'),
      ),
      if (images.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < images.length; index++)
              Stack(
                children: [
                  FutureBuilder(
                    future: ImagePickerHelper.readBytes(images[index]),
                    builder: (context, snapshot) => Container(
                      width: 72,
                      height: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: snapshot.hasData
                          ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                          : const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onChanged([
                        for (var i = 0; i < images.length; i++)
                          if (i != index) images[i],
                      ]),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
          ],
        ),
      const SizedBox(height: 8),
      const Text('Optional, up to 5 photos; 5 MB maximum per photo.'),
    ],
  );
}
