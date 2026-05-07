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
    setState(() {
      _cards = cards;
      _stats = stats;
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
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => _load(query: v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Cards', value: '${_stats['count']?.toInt() ?? 0}'),
                _Stat(
                  label: 'Total Value',
                  value: '\$${(_stats['total'] ?? 0).toStringAsFixed(2)}',
                ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
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
      leading: SizedBox(
        width: 48,
        height: 64,
        child: CardImage(path: card.frontScanPath, placeholder: ''),
      ),
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
              child: Text(card.conditionGrade!,
                  style: TextStyle(color: gradeColor, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
