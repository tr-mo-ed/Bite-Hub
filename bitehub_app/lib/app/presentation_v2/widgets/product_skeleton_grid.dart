import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ???? ???? ProductSkeletonGrid ???? ???? ????? ???? ?? ???? ????.
class ProductSkeletonGrid extends StatelessWidget {
  const ProductSkeletonGrid({super.key});

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: List.generate(
                2,
                (index) => Expanded(
                  child: Container(
                    margin:
                        EdgeInsetsDirectional.only(start: index == 0 ? 0 : 12),
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
