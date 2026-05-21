import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:bitehub_app/app/data/models/product_model.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/product_image_view.dart';

// ???? ???? FeaturedProductCarousel ???? ???? ????? ???? ?? ???? ????.
class FeaturedProductCarousel extends StatelessWidget {
  // ??? ??????? products ??? ?????? ???? ????? ????.
  final List<ProductModel> products;
  // ??? ??????? onAddToCart ??? ?????? ???? ????? ????.
  final ValueChanged<ProductModel> onAddToCart;

  const FeaturedProductCarousel({
    super.key,
    required this.products,
    required this.onAddToCart,
  });

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: products.length,
      options: CarouselOptions(
        height: 260,
        viewportFraction: 0.72,
        enlargeCenterPage: true,
        enlargeFactor: 0.18,
        autoPlay: products.length > 1,
      ),
      itemBuilder: (context, index, _) {
        final product = products[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                  child: ProductImageView(
                    imagePath: product.getImageUrl(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.category,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} د.ل',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3559C7),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => onAddToCart(product),
                          icon: const Icon(Icons.add_shopping_cart_rounded,
                              size: 18),
                          label: const Text('أضف'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
