import 'package:flutter/material.dart';
import '../models/card.dart';
import '../services/database_service.dart';
import '../widgets/card_image.dart';
import 'card_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<TradingCard> _cards = [];
  Map<String, double> _stats = {};
  Map<String, int> _byGame = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() => _loading = true);
    final cards = await _db.getCards(query: query);
    final stats = await _db.getCollectionStats();

    // Tally cards by game
    final byGame = <String, int>{};
    for (final c in cards) {
      if (c.game.isNotEmpty) byGame[c.game] = (byGame[c.game] ?? 0) + c.quantity;
    }

    setState(() {
      _cards = cards;
      _stats = stats;
      _byGame = byGame;
      _loading = false;
    });
  }

  Future<void> _openCard(TradingCard card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardDetailScreen(card: card)),
    );
    _load(query: _searchCtrl.text.trim());
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
    final totalValue = _stats['total'] ?? 0;
    final totalCost = _stats['total_cost'] ?? 0;
    final profitLoss = totalValue - totalCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, set, or game...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () { _searchCtrl.clear(); _load(); },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => _load(query: v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats panel
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Cards', value: '${_stats['count']?.toInt() ?? 0}'),
                    _Stat(label: 'Total Value', value: '\$${totalValue.toStringAsFixed(2)}'),
                    _Stat(label: 'Total Cost', value: '\$${totalCost.toStringAsFixed(2)}'),
                    _Stat(
                      label: 'P / L',
                      value: '${profitLoss >= 0 ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}',
                      valueColor: totalCost == 0
                          ? Colors.grey
                          : profitLoss >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                    ),
                  ],
                ),
                if (_byGame.isNotEmpty && _searchCtrl.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _byGame.entries
                        .toList()
                        .sorted((a, b) => b.value.compareTo(a.value))
                        .map((e) => Chip(
                              label: Text('${e.key}: ${e.value}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: Colors.grey[800],
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          // Card list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _cards.isEmpty
                    ? Center(
                        child: Text(
                          _searchCtrl.text.isEmpty
                              ? 'No cards yet.\nUse Scan to add your first card.'
                              : 'No results.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(query: _searchCtrl.text),
                        child: ListView.builder(
                          itemCount: _cards.length,
                          itemBuilder: (_, i) => _CardTile(
                            card: _cards[i],
                            gradeColor: _gradeColor(_cards[i].conditionScore),
                            onTap: () => _openCard(_cards[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

extension _ListSort<T> on List<T> {
  List<T> sorted(int Function(T a, T b) compare) => [...this]..sort(compare);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: valueColor ?? Colors.white)),
      Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
    ],
  );
}

class _CardTile extends StatelessWidget {
  final TradingCard card;
  final Color gradeColor;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.gradeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: SizedBox(width: 48, height: 64, child: CardImage(path: card.frontScanPath, placeholder: '')),
      title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          if (card.setName.isNotEmpty) card.setName,
          if (card.cardNumber.isNotEmpty) '#${card.cardNumber}',
          if (card.game.isNotEmpty) card.game,
        ].join(' · '),
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('\$${card.estimatedValue.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (card.conditionGrade != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: gradeColor.withValues(alpha: 0.6)),
              ),
              child: Text(card.conditionGrade!, style: TextStyle(color: gradeColor, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
