import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_export.dart';
import '../../../data/models/product_model.dart';

class CartItemWidget extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemWidget({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = product.sellingPrice * quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.lightTheme.colorScheme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomImageWidget(
                  imageUrl: product.imagePath ??
                      "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  semanticLabel: "${product.name} product image",
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name and remove button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: AppTheme.errorLight,
                          size: 18,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price and quantity controls
                  Row(
                    children: [
                      // Quantity controls
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.dividerLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                onQuantityChanged(quantity - 1);
                                HapticFeedback.lightImpact();
                              },
                              icon: CustomIconWidget(
                                iconName: 'remove',
                                color: AppTheme.textPrimaryLight,
                                size: 16,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                quantity.toString(),
                                style: AppTheme.lightTheme.textTheme.titleMedium
                                    ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: quantity < product.stock
                                  ? () {
                                      onQuantityChanged(quantity + 1);
                                      HapticFeedback.lightImpact();
                                    }
                                  : null,
                              icon: CustomIconWidget(
                                iconName: 'add',
                                color: quantity < product.stock
                                    ? AppTheme.textPrimaryLight
                                    : AppTheme.textDisabledLight,
                                size: 16,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Subtotal
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\u20B1${product.sellingPrice.toStringAsFixed(2)} x $quantity',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                              fontSize: 11,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\u20B1${subtotal.toStringAsFixed(2)}',
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              fontSize: 14,
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
