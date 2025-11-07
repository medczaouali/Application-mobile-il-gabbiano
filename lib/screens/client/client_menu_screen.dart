import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/cart_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import '../../db/database_helper.dart';
import '../../models/menu_item.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/custom_app_bar.dart';

class ClientMenuScreen extends StatefulWidget {
  const ClientMenuScreen({super.key});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _searchController = TextEditingController();
  String? _selectedCategory; // null or 'All' means no filter
  late Future<List<MenuItem>> _menuFuture; // cache the future so typing doesn't refetch

  // helper to extract top-level category
  String _topCat(String cat) => cat.contains('>') ? cat.split('>').first.trim() : cat;

  String _allLabel(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    switch (code) {
      case 'fr':
        return 'Tous';
      case 'it':
        return 'Tutti';
      case 'es':
        return 'Todos';
      case 'de':
        return 'Alle';
      case 'pt':
        return 'Todos';
      case 'ar':
        return 'الكل';
      default:
        return 'All';
    }
  }

  @override
  void initState() {
    super.initState();
    // Load menu once; avoid recreating the Future on every keystroke which
    // was causing FutureBuilder to go to waiting state and dismiss the keyboard.
    _menuFuture = _dbHelper.getMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: CustomAppBar(title: AppLocalizations.of(context).t('menu')),
      body: FutureBuilder<List<MenuItem>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(AppLocalizations.of(context).t('error').replaceAll('{msg}', snapshot.error.toString())));
          final menu = snapshot.data ?? <MenuItem>[];

          // unique categories for chips
          final cats = <String>{};
          for (final m in menu) cats.add(_topCat(m.category));
          final catList = cats.toList()..sort();
          final allLabel = _allLabel(context);
          catList.insert(0, allLabel);

          // apply filters
          final search = _searchController.text.trim().toLowerCase();
          final filtered = menu.where((item) {
            final matchesSearch = search.isEmpty || item.name.toLowerCase().contains(search) || item.description.toLowerCase().contains(search);
            if (!matchesSearch) return false;
            final selected = _selectedCategory;
            if (selected == null || selected == allLabel) return true;
            return _topCat(item.category) == selected;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: AppLocalizations.of(context).t('our_menu'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(icon: Icon(Icons.filter_list), onPressed: () {}),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (ctx, i) {
                    final cat = catList[i];
                    final selected = (_selectedCategory ?? allLabel) == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          // toggle: if tapping selected, go back to All
                          if (selected) {
                            _selectedCategory = allLabel;
                          } else {
                            _selectedCategory = cat;
                          }
                        });
                      },
                    );
                  },
                  separatorBuilder: (_, __) => SizedBox(width: 8),
                  itemCount: catList.length,
                ),
              ),

              Expanded(
                child: Builder(builder: (context) {
                  final bottomInset = MediaQuery.of(context).padding.bottom;
                  // Reserve space for the FAB (56) + margins (~16) + safe area + extra 8
                  final gridBottomPadding = bottomInset + 56 + 16 + 8;
                  return GridView.builder(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, gridBottomPadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                (item.imagePath != null && item.imagePath!.isNotEmpty)
                                ? (item.imagePath!.startsWith('http')
                                  ? Image(image: CachedNetworkImageProvider(item.imagePath!), fit: BoxFit.cover)
                                  : Image.file(File(item.imagePath!), fit: BoxFit.cover))
                                  : Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.restaurant_menu, size: 48, color: Colors.grey))),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                                    child: Text(_topCat(item.category), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),

                          const Spacer(),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                            child: Row(
                              children: [
                                // Price: allow it to shrink if space is limited
                                Flexible(
                                  flex: 0,
                                  fit: FlexFit.loose,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text('${item.price.toStringAsFixed(2)}€', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // Spacer to push the button to the right and allow the row to adapt
                                const Spacer(),

                                // Make the add control flexible to avoid overflow
                                LayoutBuilder(builder: (context, constraints) {
                                  final showIconOnly = constraints.maxWidth < 90;
                                  if (showIconOnly) {
                                    return SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                                        iconSize: 18,
                                        onPressed: () async {
                                          try {
                                            await cart.addItem(item);
                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(AppLocalizations.of(context).t('added_to_cart').replaceAll('{item}', item.name)),
                                                action: SnackBarAction(label: AppLocalizations.of(context).t('cancel'), onPressed: () async {
                                                  final foundIndex = cart.items.indexWhere((c) => c.productId == item.id);
                                                  if (foundIndex != -1) {
                                                    final found = cart.items[foundIndex];
                                                    if (found.quantity > 1) {
                                                      await cart.updateQuantity(found.id!, found.quantity - 1);
                                                    } else {
                                                      await cart.removeItem(found.id!);
                                                    }
                                                  }
                                                }),
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('add_to_cart_failed'))));
                                          }
                                        },
                                        icon: const Icon(Icons.add_shopping_cart),
                                        tooltip: AppLocalizations.of(context).t('add_to_cart'),
                                      ),
                                    );
                                  }

                                  return SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await cart.addItem(item);
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(AppLocalizations.of(context).t('added_to_cart').replaceAll('{item}', item.name)),
                                              action: SnackBarAction(label: AppLocalizations.of(context).t('cancel'), onPressed: () async {
                                                final foundIndex = cart.items.indexWhere((c) => c.productId == item.id);
                                                if (foundIndex != -1) {
                                                  final found = cart.items[foundIndex];
                                                  if (found.quantity > 1) {
                                                    await cart.updateQuantity(found.id!, found.quantity - 1);
                                                  } else {
                                                    await cart.removeItem(found.id!);
                                                  }
                                                }
                                              }),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('error').replaceAll('{msg}', "impossible d'ajouter au panier"))));
                                        }
                                      },
                                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                                      label: const SizedBox.shrink(),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        minimumSize: const Size(40, 36),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
                }),
                ),
              ],
            );
        },
      ),
      floatingActionButton: const CartFab(),
    );
  }
}

class CartFab extends StatefulWidget {
  const CartFab({Key? key}) : super(key: key);

  @override
  State<CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<CartFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _prevCount = -1; // -1 means uninitialized; don't animate first build

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<CartProvider, int>(
      selector: (_, p) => p.itemCount,
      builder: (context, count, child) {
        if (_prevCount == -1) {
          _prevCount = count; // initialize without animating
        } else if (count != _prevCount) {
          // animate on changes
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _ctrl.forward(from: 0.0);
          });
          _prevCount = count;
        }

        final scale = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Transform.scale(scale: scale.value, child: child),
          child: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen())),
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_cart),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2)),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

