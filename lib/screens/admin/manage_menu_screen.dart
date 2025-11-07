import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../db/database_helper.dart';
import '../../models/menu_item.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});
  @override
  _ManageMenuScreenState createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Future<List<MenuItem>> _menuFuture; // cache to avoid refetch/focus loss

  @override
  void initState() {
    super.initState();
    _menuFuture = _dbHelper.getMenu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure we rebuild when the search text changes without losing focus
    _searchController.removeListener(_onSearchChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // only rebuild the widget tree; keep the focus node intact
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildMenuCard(MenuItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: item.imagePath != null && item.imagePath!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(item.imagePath!), width: 64, height: 64, fit: BoxFit.cover),
                )
              : Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  child: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.primary),
                ),
          title: Text(item.name, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${item.price.toStringAsFixed(2)} € · ${item.category}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddMenuItemDialog(item: item)),
              IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () async { await _dbHelper.deleteMenuItem(item.id!); setState(() {}); }),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPizzaGroups(List<MenuItem> items) {
    // group by subcategory after '>'
    final Map<String, List<MenuItem>> subs = {};
    for (final i in items) {
      final cat = i.category;
      final sub = cat.contains('>') ? cat.split('>').last.trim() : 'Pizze (Autres)';
      subs.putIfAbsent(sub, () => []).add(i);
    }
    final keys = subs.keys.toList()..sort();
    return keys.map((k) {
      final list = subs[k]!..sort((a,b)=>a.name.compareTo(b.name));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Text(k, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          ...list.map((it) => _buildMenuCard(it)).toList(),
        ],
      );
    }).toList();
  }

  void _showAddMenuItemDialog({MenuItem? item}) async {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: item?.name);
    final _descriptionController =
        TextEditingController(text: item?.description);
    final _priceController =
        TextEditingController(text: item?.price.toString());
  // category controlled by dropdowns below
    File? _imageFile = item?.imagePath != null ? File(item!.imagePath!) : null;
    final ImagePicker _picker = ImagePicker();

    // Prepare categories and initial selection outside the builder so the values
    // persist across rebuilds triggered by StatefulBuilder.setState.
    final categories = [
      'Antipasti',
      'Primi Piatti',
      'Secondi',
      'Insalatone',
      'Contorni',
      'Fritti',
      'Pizza',
      'Birre in bottiglia',
      'Bevande',
      'Vino sfuso',
      'Vino in bottiglia',
      'Caffetteria e liquori'
    ];
    final pizzaSub = [
      'Pizze classiche',
      'Pizze fritte',
      'Pizze speciali',
      'Pizze speciali con pesce',
      'Calzoni'
    ];
    final itemCat = item?.category;
    String _selectedCategory;
    String? _selectedPizzaSub;
    if (itemCat != null && itemCat.contains('>')) {
      final parts = itemCat.split('>');
      _selectedCategory = parts.first.trim();
      _selectedPizzaSub = parts.length > 1 ? parts.last.trim() : null;
    } else {
      _selectedCategory = itemCat ?? categories.first;
      _selectedPizzaSub = null;
    }
    // If the stored category isn't in our known categories list (maybe due to
    // capitalization or custom categories), add it temporarily so the
    // DropdownButtonFormField can display it as the selected value.
    if (!_selectedCategory.isEmpty && !categories.contains(_selectedCategory)) {
      categories.insert(0, _selectedCategory);
    }
    if (_selectedPizzaSub != null && _selectedPizzaSub.isNotEmpty && !pizzaSub.contains(_selectedPizzaSub)) {
      pizzaSub.insert(0, _selectedPizzaSub);
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> _pickImageFromSource(ImageSource source) async {
            try {
              final pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
              if (pickedFile != null) {
                try {
                  final appDir = await getApplicationDocumentsDirectory();
                  final filename = 'menu_${item?.id ?? 'new'}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
                  final savedPath = p.join(appDir.path, filename);

                  // delete previous app-stored image if exists
                  if (_imageFile != null && _imageFile!.path.startsWith(appDir.path)) {
                    try {
                      final oldFile = File(_imageFile!.path);
                      if (await oldFile.exists()) await oldFile.delete();
                    } catch (_) {}
                  }

                  await File(pickedFile.path).copy(savedPath);
                  setState(() {
                    _imageFile = File(savedPath);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image enregistrée')));
                } catch (e) {
                  // fallback to original picked path
                  setState(() {
                    _imageFile = File(pickedFile.path);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de copier l\'image; utilisation du chemin d\'origine')));
                }
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la sélection de l\'image')));
            }
          }

          void _showImageSourceActionSheet() {
            showModalBottomSheet(context: context, builder: (ctx) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: Icon(Icons.photo_library),
                      title: Text('Galerie'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _pickImageFromSource(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.camera_alt),
                      title: Text('Caméra'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _pickImageFromSource(ImageSource.camera);
                      },
                    ),
                    if (_imageFile != null)
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: Colors.redAccent),
                        title: Text('Supprimer la photo', style: TextStyle(color: Colors.redAccent)),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          try {
                            if (_imageFile != null && _imageFile!.path.isNotEmpty) {
                              final appDir = await getApplicationDocumentsDirectory();
                              if (_imageFile!.path.startsWith(appDir.path)) {
                                final f = File(_imageFile!.path);
                                if (await f.exists()) await f.delete();
                              }
                            }
                          } catch (_) {}
                          setState(() => _imageFile = null);
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.close),
                      title: Text('Annuler'),
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              );
            });
          }

          return AlertDialog(
            title: Text(item == null ? 'Ajouter un article' : 'Modifier l\'article'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _imageFile == null
                        ? Text('Aucune image sélectionnée.')
                        : Image.file(_imageFile!, height: 150),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.image),
                          label: Text('Choisir une image'),
                          onPressed: _showImageSourceActionSheet,
                        ),
                        if (_imageFile != null)
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              try {
                                final appDir = await getApplicationDocumentsDirectory();
                                if (_imageFile != null && _imageFile!.path.startsWith(appDir.path)) {
                                  final f = File(_imageFile!.path);
                                  if (await f.exists()) await f.delete();
                                }
                              } catch (_) {}
                              setState(() => _imageFile = null);
                            },
                          )
                      ],
                    ),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Nom'),
                      validator: (value) =>
                          value!.isEmpty ? 'Veuillez entrer un nom' : null,
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                      validator: (value) => value!.isEmpty
                          ? 'Veuillez entrer une description'
                          : null,
                    ),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(labelText: 'Prix'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value!.isEmpty ? 'Veuillez entrer un prix' : null,
                    ),
                    // Category selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(labelText: 'Catégorie'),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() {
                        _selectedCategory = v!;
                        if (_selectedCategory != 'Pizza') _selectedPizzaSub = null;
                      }),
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez sélectionner une catégorie' : null,
                    ),
                    if (_selectedCategory == 'Pizza')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPizzaSub ?? pizzaSub.first,
                          decoration: InputDecoration(labelText: 'Sous-catégorie Pizza'),
                          items: pizzaSub.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedPizzaSub = v),
                          validator: (v) => v == null || v.isEmpty ? 'Veuillez sélectionner une sous-catégorie' : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Annuler'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
                    ElevatedButton(
                      child: Text('Sauvegarder'),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final combinedCategory = _selectedCategory == 'Pizza' && _selectedPizzaSub != null
                              ? 'Pizza > ${_selectedPizzaSub!}'
                              : _selectedCategory;
                          final newItem = MenuItem(
                            id: item?.id,
                            name: _nameController.text,
                            description: _descriptionController.text,
                            price: double.parse(_priceController.text),
                            category: combinedCategory,
                            imagePath: _imageFile?.path,
                          );
                          if (item == null) {
                            await _dbHelper.createMenuItem(newItem);
                          } else {
                            await _dbHelper.updateMenuItem(newItem);
                          }
                          Navigator.of(context).pop();
                          this.setState(() {});
                        }
                      },
                    ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Gérer le Menu'),
      body: FutureBuilder<List<MenuItem>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucun article dans le menu.'));
          }
          final menuItems = snapshot.data!;

          // Group items by top-level category (split by '>')
          final Map<String, List<MenuItem>> grouped = {};
          for (final it in menuItems) {
            final cat = it.category;
            final top = cat.contains('>') ? cat.split('>').first.trim() : cat;
            grouped.putIfAbsent(top, () => []).add(it);
          }

          // Sort categories alphabetically but try to keep a friendly order
          final categoryOrder = [
            'Antipasti',
            'Primi Piatti',
            'Secondi',
            'Insalatone',
            'Contorni',
            'Fritti',
            'Pizza',
            'Birre in bottiglia',
            'Bevande',
            'Vino sfuso',
            'Vino in bottiglia',
            'Caffetteria e liquori'
          ];
          final categories = grouped.keys.toList()
            ..sort((a, b) {
              final ia = categoryOrder.indexOf(a);
              final ib = categoryOrder.indexOf(b);
              if (ia == -1 && ib == -1) return a.compareTo(b);
              if (ia == -1) return 1;
              if (ib == -1) return -1;
              return ia.compareTo(ib);
            });

          // Build tabs for categories
          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _searchFocusNode,
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Rechercher un article',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      // re-request focus so the cursor remains active
                                      FocusScope.of(context).requestFocus(_searchFocusNode);
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          // controller listener handles rebuilds; don't call setState here to avoid focus loss
                          onChanged: (_) {},
                        ),
                      ),
                      SizedBox(width: 12),
                      IconButton(icon: Icon(Icons.filter_list), onPressed: () { /* future filters */ }),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabs: categories.map((c) => Tab(text: c)).toList(),
                ),
                // If there's a search query, show a single list with global results
                Expanded(
                  child: Builder(builder: (context) {
                    final search = _searchController.text.trim().toLowerCase();
                    if (search.isNotEmpty) {
                      // flatten all items and filter globally
                      final allItems = grouped.values.expand((l) => l).toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                      final filtered = allItems.where((it) {
                        final name = it.name.toLowerCase();
                        final desc = it.description.toLowerCase();
                        final cat = it.category.toLowerCase();
                        return name.contains(search) || desc.contains(search) || cat.contains(search);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(child: Text('Aucun résultat pour "$search"'));
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: ListView(
                          children: filtered.map((it) => _buildMenuCard(it)).toList(),
                        ),
                      );
                    }

                    // Default behavior: show tabbed view per category
                    return TabBarView(
                      children: categories.map((cat) {
                        final items = grouped[cat]!..sort((a, b) => a.name.compareTo(b.name));
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: ListView(
                            children: [
                              if (cat == 'Pizza') ..._buildPizzaGroups(items) else ...items.map((it) => _buildMenuCard(it)).toList(),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenuItemDialog(),
        child: Icon(Icons.add),
        tooltip: 'Ajouter un article',
      ),
    );
  }
}
