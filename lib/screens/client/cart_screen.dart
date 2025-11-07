import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/screens/client/payment_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('cart')),
      ),
      body: items.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).t('empty_cart')).animate().fadeIn())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return ListTile(
                  leading: (() {
                    final img = item.menuItem!.imagePath;
                    if (img != null && img.isNotEmpty) {
                      if (img.startsWith('http')) {
                        return CircleAvatar(backgroundImage: CachedNetworkImageProvider(img));
                      }
                      try {
                        return CircleAvatar(backgroundImage: FileImage(File(img)));
                      } catch (_) {
                        // fallback to icon
                        return CircleAvatar(child: Icon(Icons.restaurant));
                      }
                    }
                    return CircleAvatar(child: Icon(Icons.restaurant));
                  })(),
                  title: Text(item.menuItem!.name),
                  subtitle: Text('${item.menuItem!.price.toStringAsFixed(2)}€ x ${item.quantity}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (item.quantity > 1) {
                            cart.updateQuantity(item.id!, item.quantity - 1);
                          } else {
                            cart.removeItem(item.id!);
                          }
                        },
                      ),
                      Text('${item.quantity}', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () {
                          cart.updateQuantity(item.id!, item.quantity + 1);
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (100 * i).ms);
              },
            ),
      bottomNavigationBar: items.isNotEmpty
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${AppLocalizations.of(context).t('place_order') == 'Place Order' ? 'Total' : 'Total'}: ${cart.totalPrice.toStringAsFixed(2)}€',
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => PaymentScreen()),
                        );
                      },
                      label: Text(AppLocalizations.of(context).t('place_order')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().slide()
          : null,
    );
  }
}
