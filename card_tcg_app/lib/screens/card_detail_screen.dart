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

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _loadValuations();
  }

  Future<void> _loadValuations() async {
    if (_card.id == null) return;
    final v = await _db.getValuations(_card.id!);
    setState(() => _valuations = v);
  }

  Future<void> _revalue() async {
    setState(() => _fetchingPrice = true);
    final results = await _valuator.fetchAll(_card.name, setName: _card.setName);
    final estimate = _valuator.computeEstimate(results, _card.conditionScore ?? 85);

    final updated = _card.copyWith(estimatedValue: estimate);
    await _db.updateCard(updated);
    if (_card.id != null) {
      for (final v in results) {
        await _db.addValuation(_card.id!, v.source, v.value, v.url);
      }
    }
    await _loadValuations();
    setState(() {
      _card = updated;
      _fetchingPrice = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated: \$${estimate.toStringAsFixed(2)}'),
          backgroundColor: Colors.green[700],
        ),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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
        title: Text(_card.name),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Images
            Row(
              children: [
                Expanded(
                    child: CardImage(
                        path: _card.frontScanPath,
                        placeholder: 'No front image',
                        height: 200)),
                const SizedBox(width: 12),
                Expanded(
                    child: CardImage(
                        path: _card.backScanPath,
                        placeholder: 'No back image',
                        height: 200)),
              ],
            ),
            const SizedBox(height: 16),

            // Value & grade
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: 'Estimated Value',
                    value: '\$${_card.estimatedValue.toStringAsFixed(2)}',
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                if (_card.conditionGrade != null)
                  Expanded(
                    child: _InfoChip(
                      label: 'Condition',
                      value: _card.conditionGrade!,
                      color: _gradeColor(_card.conditionScore),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
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
                    _DetailRow('Purchase Price',
                        _card.purchasePrice > 0 ? '\$${_card.purchasePrice.toStringAsFixed(2)}' : ''),
                    _DetailRow('Purchase Date', _card.purchaseDate),
                    if (_card.notes.isNotEmpty) _DetailRow('Notes', _card.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Valuations
            if (_valuations.isNotEmpty) ...[
              Text('Price Sources',
                  style: TextStyle(
                      color: Colors.grey[300],
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 6),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: _valuations
                        .map((v) => _DetailRow(v['source'] as String,
                            '\$${(v['value'] as num).toStringAsFixed(2)}'))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _fetchingPrice ? null : _revalue,
              icon: _fetchingPrice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              label: Text(_fetchingPrice ? 'Fetching...' : 'Re-fetch Price'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    );
  }
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
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
