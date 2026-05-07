import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/card.dart';
import '../services/ocr_service.dart';
import '../services/valuation_service.dart';
import '../services/database_service.dart';
import '../widgets/card_image.dart';

bool _isSports(String type) => const {
  'Baseball', 'Basketball', 'Football', 'Soccer',
  'Hockey', 'Golf', 'Wrestling', 'Other Sports',
}.contains(type);

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _valuator = ValuationService();
  final _db = DatabaseService();

  final _nameCtrl = TextEditingController();
  final _setCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _rarityCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController(text: '0.00');
  final _yearCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  String? _frontPath;
  String? _backPath;
  String _status = 'Tap a panel to capture the card front and back.';
  bool _busy = false;
  List<ValuationResult> _valuations = [];
  double _estimate = 0.0;
  String _cardType = 'Pokémon';
  String? _condition;
  bool _foil = false;

  static const _cardTypes = [
    'Pokémon', 'Magic: The Gathering', 'Yu-Gi-Oh!', 'One Piece',
    'Lorcana', 'Flesh and Blood', 'Other TCG',
    'Baseball', 'Basketball', 'Football', 'Soccer',
    'Hockey', 'Golf', 'Wrestling', 'Other Sports',
  ];

  static const _conditions = [
    'Gem Mint', 'Mint', 'Near Mint', 'Excellent',
    'Very Good', 'Good', 'Played', 'Poor',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setCtrl.dispose();
    _numberCtrl.dispose();
    _rarityCtrl.dispose();
    _publisherCtrl.dispose();
    _notesCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _yearCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<String> _saveImage(XFile xfile, String tag) async {
    final dir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(dir.path, 'scans'));
    await scansDir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = p.join(scansDir.path, 'card_${ts}_$tag.jpg');
    await File(xfile.path).copy(dest);
    return dest;
  }

  Future<void> _pickImage(String side, ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xfile == null) return;

    setState(() { _busy = true; _status = 'Processing $side...'; });

    final saved = await _saveImage(xfile, side);

    if (side == 'front') {
      setState(() => _frontPath = saved);
      final info = await _ocr.extractCardInfo(saved);
      setState(() {
        if (info['name']!.isNotEmpty && _nameCtrl.text.isEmpty) _nameCtrl.text = info['name']!;
        if (info['card_number']!.isNotEmpty && _numberCtrl.text.isEmpty) _numberCtrl.text = info['card_number']!;
        if ((info['set_name'] ?? '').isNotEmpty && _setCtrl.text.isEmpty) _setCtrl.text = info['set_name']!;
        _status = 'Front captured. ${info['name']!.isNotEmpty ? 'Detected: ${info['name']}' : 'Name not detected — enter manually.'}';
      });
    } else {
      setState(() { _backPath = saved; _status = 'Back captured.'; });
    }

    setState(() => _busy = false);

    if (side == 'front' && _nameCtrl.text.isNotEmpty) await _fetchPricing();
  }

  void _showSourceDialog(String side) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(context); _pickImage(side, ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(side, ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchPricing() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a card name first.')));
      return;
    }
    setState(() { _busy = true; _status = 'Fetching prices for "$name"...'; });
    final results = await _valuator.fetchAll(name, setName: _setCtrl.text.trim(), game: _cardType);
    final estimate = _valuator.computeEstimate(results, 85);
    setState(() {
      _valuations = results;
      _estimate = estimate;
      _busy = false;
      _status = results.isEmpty
          ? 'No prices found.'
          : 'Found ${results.length} source(s). Estimate: \$${estimate.toStringAsFixed(2)}';
    });
  }

  Future<void> _saveCard() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card name is required.')));
      return;
    }
    setState(() { _busy = true; _status = 'Saving...'; });

    final card = TradingCard(
      name: _nameCtrl.text.trim(),
      setName: _setCtrl.text.trim(),
      cardNumber: _numberCtrl.text.trim(),
      rarity: _rarityCtrl.text.trim(),
      game: _cardType,
      publisher: _publisherCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text) ?? 0,
      foil: _foil,
      frontScanPath: _frontPath,
      backScanPath: _backPath,
      conditionGrade: _condition,
      estimatedValue: _estimate,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0.0,
      purchaseDate: DateTime.now().toIso8601String().substring(0, 10),
      notes: _notesCtrl.text.trim(),
      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
    );

    final id = await _db.addCard(card);
    for (final v in _valuations) {
      await _db.addValuation(id, v.source, v.value, v.url);
    }

    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${card.name}" added to collection.'), backgroundColor: Colors.green[700]),
      );
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _frontPath = null;
      _backPath = null;
      _valuations = [];
      _estimate = 0.0;
      _cardType = 'Pokémon';
      _condition = null;
      _foil = false;
      _status = 'Tap a panel to capture the card front and back.';
    });
    _nameCtrl.clear();
    _setCtrl.clear();
    _numberCtrl.clear();
    _rarityCtrl.clear();
    _publisherCtrl.clear();
    _notesCtrl.clear();
    _purchasePriceCtrl.text = '0.00';
    _qtyCtrl.text = '1';
    _yearCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sports = _isSports(_cardType);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Card'),
        actions: [
          if (_frontPath != null || _backPath != null)
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reset', onPressed: _busy ? null : _reset),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _ImagePanel(label: 'Front', path: _frontPath, onTap: _busy ? null : () => _showSourceDialog('front'))),
                const SizedBox(width: 12),
                Expanded(child: _ImagePanel(label: 'Back', path: _backPath, onTap: _busy ? null : () => _showSourceDialog('back'))),
              ],
            ),
            const SizedBox(height: 12),
            _StatusBar(busy: _busy, message: _status),
            const SizedBox(height: 16),

            // Card Type — always first
            DropdownButtonFormField<String>(
              initialValue: _cardType,
              decoration: _inputDeco('Card Type'),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _cardTypes.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _cardType = v!),
            ),
            const SizedBox(height: 8),

            // Name field — label depends on type
            _buildField(sports ? 'Player Name *' : 'Card Name *', _nameCtrl),
            const SizedBox(height: 8),

            if (sports) ...[
              // Sports layout: Year | Team
              Row(children: [
                Expanded(child: _buildField('Year', _yearCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Team', _setCtrl)),
              ]),
              const SizedBox(height: 8),
              _buildField('Publisher', _publisherCtrl),
            ] else ...[
              // TCG layout: Generation/Set | Card #
              Row(children: [
                Expanded(child: _buildField('Generation / Set', _setCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Card #', _numberCtrl)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildField('Rarity', _rarityCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Year', _yearCtrl, keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              _buildField('Publisher', _publisherCtrl),
            ],

            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _condition,
              decoration: _inputDeco('Condition'),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Not graded —', style: TextStyle(color: Colors.grey))),
                ..._conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildField('Qty', _qtyCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Buy Price \$', _purchasePriceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Foil / Holographic', style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _foil,
              onChanged: (v) => setState(() => _foil = v),
            ),
            _buildField('Notes', _notesCtrl, maxLines: 2),
            const SizedBox(height: 16),
            if (_valuations.isNotEmpty) ...[
              _PricingCard(valuations: _valuations, estimate: _estimate),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _fetchPricing,
                    icon: const Icon(Icons.attach_money),
                    label: const Text('Fetch Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveCard,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Card'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDeco(label),
      );

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey[400]),
    filled: true,
    fillColor: Colors.grey[900],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _StatusBar extends StatelessWidget {
  final bool busy;
  final String message;
  const _StatusBar({required this.busy, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
    child: Row(
      children: [
        if (busy) ...[
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(message, style: TextStyle(color: Colors.grey[300], fontSize: 13))),
      ],
    ),
  );
}

class _ImagePanel extends StatelessWidget {
  final String label;
  final String? path;
  final VoidCallback? onTap;
  const _ImagePanel({required this.label, this.path, this.onTap});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GestureDetector(
        onTap: onTap,
        child: CardImage(path: path, placeholder: 'Tap to\ncapture $label', width: double.infinity, height: 180),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ],
  );
}

class _PricingCard extends StatelessWidget {
  final List<ValuationResult> valuations;
  final double estimate;
  const _PricingCard({required this.valuations, required this.estimate});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.grey[900],
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimated Value: \$${estimate.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent)),
          const SizedBox(height: 6),
          ...valuations.map((v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• ${v.source}: \$${v.value.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[300], fontSize: 13)),
          )),
        ],
      ),
    ),
  );
}
