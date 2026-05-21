class SmartImageUtil {
  static String getImagePath(
    String productName,
    String? serverImageUrl, {
    String? category,
    int? imageVariant,
  }) {
    if (serverImageUrl != null &&
        serverImageUrl.isNotEmpty &&
        serverImageUrl.startsWith('http')) {
      return serverImageUrl;
    }

    final text = '${category ?? ''} $productName'.toLowerCase();
    if (text.contains('\u0642\u0647\u0648\u0629') || text.contains('coffee')) {
      return _pickVariant(
        const [
          'assets/images/coffee_placeholder.png',
          'assets/images/coffee_placeholder2.png',
        ],
        imageVariant,
      );
    }
    if (text.contains('\u0628\u064a\u062a\u0632\u0627') ||
        text.contains('pizza')) {
      return _pickVariant(_assetPool('assets/images/pizza', 5), imageVariant);
    }
    if (text.contains('\u0628\u0631\u063a\u0631') ||
        text.contains('\u0628\u0631\u062c\u0631') ||
        text.contains('burger') ||
        text.contains('burg')) {
      return _pickVariant(_assetPool('assets/images/burger', 5), imageVariant);
    }
    if (text.contains('\u062d\u0644\u0648\u064a\u0627\u062a') ||
        text.contains('\u062d\u0644\u0648\u0649') ||
        text.contains('dessert') ||
        text.contains('sweet')) {
      return _pickVariant(_assetPool('assets/images/dessert', 5), imageVariant);
    }
    if (text.contains('\u0645\u0634\u0631\u0648\u0628\u0627\u062a') ||
        text.contains('\u0645\u0634\u0631\u0648\u0628') ||
        text.contains('\u0639\u0635\u064a\u0631') ||
        text.contains('\u0645\u0627\u0621') ||
        text.contains('drink') ||
        text.contains('juice')) {
      return _pickVariant(_assetPool('assets/images/drink', 5), imageVariant);
    }

    return 'assets/images/logo.png';
  }

  static bool isNetworkImage(String path) {
    return path.startsWith('http');
  }

  static List<String> _assetPool(String baseName, int count) {
    return List.generate(count, (i) => '$baseName${i + 1}.png');
  }

  static String _pickVariant(List<String> items, int? imageVariant) {
    if (items.isEmpty) {
      return 'assets/images/logo.png';
    }
    if (imageVariant != null && imageVariant >= 0) {
      return items[imageVariant % items.length];
    }
    return items.first;
  }
}
