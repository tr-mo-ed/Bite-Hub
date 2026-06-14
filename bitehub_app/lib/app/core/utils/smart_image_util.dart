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

    return '';
  }

  static bool isNetworkImage(String path) {
    return path.startsWith('http');
  }
}
