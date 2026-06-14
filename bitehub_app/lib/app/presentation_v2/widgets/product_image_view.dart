import 'package:flutter/material.dart';

// ???? ???? ProductImageView ???? ???? ????? ???? ?? ???? ????.
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.imagePath,
    required this.fit,
  });

  // ??? ??????? imagePath ??? ?????? ???? ????? ????.
  final String imagePath;
  // ??? ??????? fit ??? ?????? ???? ????? ????.
  final BoxFit fit;

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    if (imagePath.trim().isEmpty) {
      return _fallback();
    }
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: fit,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Image.asset(
      imagePath,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  // ???? ???? _fallback ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _fallback() {
    return const ColoredBox(
      color: Color(0xFFF0F1EC),
      child: Center(
        child: Icon(
          Icons.restaurant_outlined,
          color: Color(0xFF8A928E),
          size: 28,
        ),
      ),
    );
  }
}
