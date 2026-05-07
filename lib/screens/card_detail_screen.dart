import 'package:flutter/material.dart';
import '../models/card.dart';
import '../services/database_service.dart';
import '../services/valuation_service.dart';
import '../widgets/card_image.dart';

class CardDetailScreen extends StatefulWidget {
  final TradingCard card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final _db = DatabaseService();
  final _valuator = ValuationService();

  late TradingCard _card;
  List<Map<String, dynamic>> _valuations = [];
  bool _fetchingPrice = false;
  bool _editing = false;

  // Edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _setCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _rarityCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _qtyCtrl;
  late String _editGame;
  late String? _editCondition;
  late bool _editFoil;

  static const _games = [
    'Pokémon', 'Magic: The Gathering', 'Yu-Gi-Oh!', 'One Piece',
    'Lorcana', 'Flesh and Blood', 'Sports', 'Other',
  ];

  static const _conditions = [
    'Gem Mint', 'Mint', 'Near Mint', 'Excellent',
    'Very Good', 'Good', 'Played', 'Poor',
  ];

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _initControllers();
    _loadValuations();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: _card.name);
    _setCtrl = TextEditingController(text: _card.setName);
    _numberCtrl = TextEditingController(text: _card.cardNumber);
    _rarityCtrl = TextEditingController(text: _card.rarity);
    _notesCtrl = TextEditingController(text: _card.notes);
    _purchasePriceCtrl = TextEditingController(
        text: _card.purchasePrice > 0 ? _card.purchasePrice.toStringAsFixed(2) : '');
    _yearCtrl = TextEditingController(
        text: _card.year > 0 ? '${_card.year}' : '');
    _qtyCtrl = TextEditingController(text: '${_card.quantity}');
    _editGame = _games.contains(_card.game) ? _card.game : 'Other';
    _editCondition = _conditions.contains(_card.conditionGrade) ? _card.conditionGrade : null;
    _editFoil = _card.foil;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setCtrl.dispose();
    _numberCtrl.dispose();
    _rarityCtrl.dispose();
    _notesCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _yearCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadValuations() async {
    if (_card.id == null) return;
    final v = await _db.getValuations(_card.id!);
    setState(() => _valuations = v);
  }

  Future<void> _saveEdits() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card name is required.')),
      );
      return;
    }
    final updated = _card.copyWith(
      name: _nameCtrl.text.trim(),
      setName: _setCtrl.text.trim(),
      cardNumber: _numberCtrl.text.trim(),
      rarity: _rarityCtrl.text.trim(),
      game: _editGame,
      year: int.tryParse(_yearCtrl.text) ?? 0,
      foil: _editFoil,
      conditionGrade: _editCondition,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0.0,
      notes: _notesCtrl.text.trim(),
      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
    );
    await _db.updateCard(updated);
    setState(() {
      _card = updated;
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card updated.'), backgroundColor: Colors.green),
      );
    }
  }

  void _cancelEdits() {
    _initControllers();
    setState(() => _editing = false);
  }

  Future<void> _revalue() async {
    setState(() => _fetchingPrice = true);
    final results = await _valuator.fetchAll(_card.name, setName: _card.setName, game: _card.game);
    final estimate = _valuator.computeEstimate(results, _card.conditionScore ?? 85);
    final updated = _card.copyWith(estimatedValue: estimate);
    await _db.updateCard(updated);
    if (_card.id != null) {
      for (final v in results) {
        await _db.addValuation(_card.id!, v.source, v.value, v.url);
      }
    }
    await _loadValuations();
    setState(() { _card = updated; _fetchingPrice = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated: \$${estimate.toStringAsFixed(2)}'), backgroundColor: Colors.green[700]),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Remove "${_card.name}" from your collection?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && _card.id != null) {
      await _db.deleteCard(_card.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Color _gradeColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.yellow;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Card' : _card.name),
        actions: _editing
            ? [
                TextButton(onPressed: _cancelEdits, child: const Text('Cancel')),
                TextButton(onPressed: _saveEdits, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold))),
              ]
            : [
                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => setState(() => _editing = true)),
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _editing ? _buildEditForm() : _buildReadView(),
      ),
    );
  }

  Widget _buildReadView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: CardImage(path: _card.frontScanPath, placeholder: 'No front image', height: 200)),
            const SizedBox(width: 12),
            Expanded(child: CardImage(path: _card.backScanPath, placeholder: 'No back image', height: 200)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _InfoChip(label: 'Est. Value', value: '\$${_card.estimatedValue.toStringAsFixed(2)}', color: Colors.greenAccent)),
            if (_card.purchasePrice > 0) ...[
              const SizedBox(width: 8),
              Expanded(child: _InfoChip(
                label: 'Profit / Loss',
                value: '${_card.estimatedValue >= _card.purchasePrice ? '+' : ''}\$${(_card.estimatedValue - _card.purchasePrice).toStringAsFixed(2)}',
                color: _card.estimatedValue >= _card.purchasePrice ? Colors.greenAccent : Colors.redAccent,
              )),
            ],
            if (_card.conditionGrade != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _InfoChip(label: 'Condition', value: _card.conditionGrade!, color: _gradeColor(_card.conditionScore))),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _DetailRow('Set', _card.setName),
                _DetailRow('Card #', _card.cardNumber),
                _DetailRow('Game', _card.game),
                _DetailRow('Rarity', _card.rarity),
                _DetailRow('Language', _card.language),
                _DetailRow('Year', _card.year > 0 ? '${_card.year}' : ''),
                _DetailRow('Foil', _card.foil ? 'Yes' : 'No'),
                _DetailRow('Qty', '${_card.quantity}'),
                _DetailRow('Purchase Price', _card.purchasePrice > 0 ? '\$${_card.purchasePrice.toStringAsFixed(2)}' : ''),
                _DetailRow('Purchase Date', _card.purchaseDate),
                if (_card.notes.isNotEmpty) _DetailRow('Notes', _card.notes),
              ],
            ),
          ),
        ),
        if (_valuations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Price Sources', style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _valuations
                    .map((v) => _DetailRow(v['source'] as String, '\$${(v['value'] as num).toStringAsFixed(2)}'))
                    .toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _fetchingPrice ? null : _revalue,
          icon: _fetchingPrice
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh),
          label: Text(_fetchingPrice ? 'Fetching...' : 'Re-fetch Price'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: CardImage(path: _card.frontScanPath, placeholder: 'No front image', height: 160)),
            const SizedBox(width: 12),
            Expanded(child: CardImage(path: _card.backScanPath, placeholder: 'No back image', height: 160)),
          ],
        ),
        const SizedBox(height: 16),
        _field('Card Name *', _nameCtrl),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('Set', _setCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _field('Card #', _numberCtrl)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('Rarity', _rarityCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _field('Year', _yearCtrl, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _editGame,
          decoration: _inputDeco('Game'),
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: _games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _editGame = v!),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _editCondition,
          decoration: _inputDeco('Condition'),
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: [
            const DropdownMenuItem(value: null, child: Text('— Not graded —', style: TextStyle(color: Colors.grey))),
            ..._conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
          ],
          onChanged: (v) => setState(() => _editCondition = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('Qty', _qtyCtrl, keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _field('Buy Price \$', _purchasePriceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Foil / Holographic', style: TextStyle(color: Colors.white, fontSize: 14)),
          value: _editFoil,
          onChanged: (v) => setState(() => _editFoil = v),
        ),
        _field('Notes', _notesCtrl, maxLines: 3),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco(label),
        ),
      );

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey[400]),
    filled: true,
    fillColor: Colors.grey[850],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}
