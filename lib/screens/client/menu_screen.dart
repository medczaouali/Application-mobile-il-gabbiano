import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/menu_item.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/screens/client/cart_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:provider/provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<MenuItem>> _menuItemsFuture;
  String _selectedCategory = 'Tous';

  @override
  void initState() {
    super.initState();
    _menuItemsFuture = _dbHelper.getMenu();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('our_menu')),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => CartScreen()));
                },
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: FutureBuilder<List<MenuItem>>(
              future: _menuItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context).t('menu_empty')));
                }
                final allItems = snapshot.data!;
                final filteredItems = _selectedCategory == 'Tous'
                    ? allItems
                    : allItems.where((item) => item.category == _selectedCategory).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(10.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3 / 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (ctx, i) => _buildMenuItemCard(filteredItems[i]),
                ).animate().fadeIn();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    // In a real app, you'd get these from the DB
    final categories = [
      AppLocalizations.of(context).t('language') == 'Langue' ? 'Tous' : 'All',
      'Pizza',
      'Pasta',
      'Dessert',
      'Drink'
    ];
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: item.imagePath != null
                  ? Image(
                      image: item.imagePath!.startsWith('http')
                          ? CachedNetworkImageProvider(item.imagePath!)
                          : FileImage(File(item.imagePath!)) as ImageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.no_food, size: 50, color: Colors.grey),
                    )
                  : Icon(Icons.restaurant, size: 50, color: Colors.grey),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.price.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton(
                    onPressed: () {
                    cart.addItem(item);
                    final msg = AppLocalizations.of(context).t('added_to_cart').replaceAll('{item}', item.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.add_shopping_cart),
                  style: ElevatedButton.styleFrom(
                     shape: CircleBorder(),
                     padding: EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
