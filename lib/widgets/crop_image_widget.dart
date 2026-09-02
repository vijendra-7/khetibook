import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CropImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double scale;
  final double imageOffsetX;
  final double imageOffsetY;
  final double size;
  final Widget? placeholder;

  const CropImageWidget({
    super.key,
    required this.imageUrl,
    this.scale = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
    this.size = 40,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder ?? Icon(Icons.eco_rounded, size: size, color: Colors.green);
    }

    final isSvg = imageUrl!.toLowerCase().endsWith('.svg');

    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(imageOffsetX, imageOffsetY),
        child: isSvg
            ? SvgPicture.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholderBuilder: (BuildContext context) => Container(
                  padding: const EdgeInsets.all(10),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => placeholder ?? Container(
                  padding: const EdgeInsets.all(10),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => placeholder ?? Icon(Icons.eco_rounded, size: size, color: Colors.green),
              ),
      ),
    );
  }
}
