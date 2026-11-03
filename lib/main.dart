import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'product_logic.dart';

Future<void> main() async {
  // Bindings must exist before any plugin (Firebase) uses platform channels.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Campus Supply Desk - Variant B',
    home: ProductPage(),
  ));
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('campus_products');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productStream =
      _products.snapshots(includeMetadataChanges: true);

  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  String _query = '';
  double? _min;
  double? _max;
  String? _filterError;

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ));
  }

  // ---------- Filters ----------

  void _applyFilters() {
    final min = validateBound(_minController.text, 'Min');
    final max = validateBound(_maxController.text, 'Max');
    String? error = min.error ?? max.error;
    error ??= validateRange(min.value, max.value);
    setState(() {
      _query = _searchController.text;
      _filterError = error;
      // Invalid bounds are not applied; the last valid range stays off.
      _min = error == null ? min.value : null;
      _max = error == null ? max.value : null;
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _minController.clear();
    _maxController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _query = '';
      _min = null;
      _max = null;
      _filterError = null;
    });
  }

  // ---------- Create / Update ----------

  Future<void> _createOrUpdate(
      [QueryDocumentSnapshot<Map<String, dynamic>>? document]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductEditor(products: _products, document: document),
    );
    if (saved == true) {
      _showMessage(document == null ? 'Product added.' : 'Product updated.');
    }
  }

  // ---------- Delete by document ID ----------

  Future<void> _deleteProduct(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "$name"?\nDocument ID: $id'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _products.doc(id).delete();
      _showMessage('Deleted "$name" ($id).');
    } on FirebaseException catch (e) {
      _showMessage('Delete failed: ${e.message ?? e.code}', isError: true);
    } catch (e) {
      _showMessage('Delete failed: $e', isError: true);
    }
  }

  // ---------- UI ----------

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            key: const Key('searchField'),
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _applyFilters(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('minField'),
                  controller: _minController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Min price', border: OutlineInputBorder()),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('maxField'),
                  controller: _maxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Max price', border: OutlineInputBorder()),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('resetButton'),
                onPressed: _resetFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
          if (_filterError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_filterError!,
                  style: TextStyle(color: Colors.red.shade700)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Supply Desk')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load products: ${snapshot.error}',
                        textAlign: TextAlign.center),
                  ));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;
                final docs = data.docs.where((doc) {
                  final d = doc.data();
                  return matchesFilters(
                    name: (d['name'] ?? '').toString(),
                    price: readPrice(d['price']),
                    query: _query,
                    min: _min,
                    max: _max,
                  );
                }).toList()
                  ..sort((a, b) => (a.data()['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .compareTo(
                          (b.data()['name'] ?? '').toString().toLowerCase()));

                final source = data.metadata.isFromCache ? 'cache' : 'server';
                final pending = data.metadata.hasPendingWrites
                    ? ' · pending writes'
                    : '';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text('${docs.length} of ${data.docs.length} shown'),
                          const Spacer(),
                          Text('Source: $source$pending',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(child: Text('No matching products.'))
                          : ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final doc = docs[i];
                                final name =
                                    (doc.data()['name'] ?? '(no name)')
                                        .toString();
                                final price = readPrice(doc.data()['price']);
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    title: Text(name),
                                    subtitle: Text(
                                        '${price == null ? 'invalid price' : '\$${price.toStringAsFixed(2)}'}\nID: ${doc.id}'),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _createOrUpdate(doc),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _deleteProduct(doc.id, name),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Bottom sheet editor. Owns and disposes its own controllers.
class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  String? _nameError;
  String? _priceError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.document?.data();
    _name = TextEditingController(text: (d?['name'] ?? '').toString());
    final p = readPrice(d?['price']);
    _price = TextEditingController(text: p == null ? '' : p.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = validateName(_name.text);
    final price = validatePrice(_price.text);
    setState(() {
      _nameError = name.error;
      _priceError = price.error;
      _saveError = null;
    });
    if (!name.isOk || !price.isOk) return;

    setState(() => _saving = true);
    final payload = {'name': name.value, 'price': price.value};
    try {
      if (widget.document == null) {
        await widget.products.add(payload);
      } else {
        await widget.products.doc(widget.document!.id).update(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed: ${e.message ?? e.code}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.document != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(editing ? 'Edit product' : 'Add product',
              style: Theme.of(context).textTheme.titleLarge),
          if (editing)
            Text('ID: ${widget.document!.id}',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration:
                InputDecoration(labelText: 'Name', errorText: _nameError),
          ),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Price (e.g. 9.75)', errorText: _priceError),
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_saveError!,
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : (editing ? 'Update' : 'Create')),
          ),
        ],
      ),
    );
  }
}
