import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/card.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  DatabaseService._();
  factory DatabaseService() => _instance;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'cards.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            set_name TEXT,
            card_number TEXT,
            rarity TEXT,
            game TEXT,
            publisher TEXT,
            year INTEGER,
            language TEXT,
            foil INTEGER DEFAULT 0,
            front_scan_path TEXT,
            back_scan_path TEXT,
            condition_grade TEXT,
            condition_score REAL,
            estimated_value REAL DEFAULT 0,
            purchase_price REAL DEFAULT 0,
            purchase_date TEXT,
            notes TEXT,
            quantity INTEGER DEFAULT 1,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE valuations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            card_id INTEGER,
            source TEXT,
            value REAL,
            url TEXT,
            fetched_at TEXT,
            FOREIGN KEY (card_id) REFERENCES cards(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE cards ADD COLUMN publisher TEXT');
        }
      },
    );
  }

  Future<int> addCard(TradingCard card) async {
    final d = await db;
    return d.insert('cards', card.toMap());
  }

  Future<void> updateCard(TradingCard card) async {
    final d = await db;
    await d.update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> deleteCard(int id) async {
    final d = await db;
    await d.delete('cards', where: 'id = ?', whereArgs: [id]);
    await d.delete('valuations', where: 'card_id = ?', whereArgs: [id]);
  }

  Future<List<TradingCard>> getCards({String? query}) async {
    final d = await db;
    List<Map<String, dynamic>> rows;
    if (query != null && query.isNotEmpty) {
      rows = await d.query(
        'cards',
        where: 'name LIKE ? OR set_name LIKE ? OR game LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await d.query('cards', orderBy: 'created_at DESC');
    }
    return rows.map(TradingCard.fromMap).toList();
  }

  Future<TradingCard?> getCard(int id) async {
    final d = await db;
    final rows = await d.query('cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TradingCard.fromMap(rows.first);
  }

  Future<void> addValuation(int cardId, String source, double value, String? url) async {
    final d = await db;
    await d.insert('valuations', {
      'card_id': cardId,
      'source': source,
      'value': value,
      'url': url,
      'fetched_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getValuations(int cardId) async {
    final d = await db;
    return d.query('valuations', where: 'card_id = ?', whereArgs: [cardId]);
  }

  Future<Map<String, double>> getCollectionStats() async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COUNT(*) as count, '
      'SUM(estimated_value * quantity) as total, '
      'SUM(purchase_price * quantity) as total_cost '
      'FROM cards',
    );
    return {
      'count': (rows.first['count'] as int? ?? 0).toDouble(),
      'total': (rows.first['total'] as num? ?? 0).toDouble(),
      'total_cost': (rows.first['total_cost'] as num? ?? 0).toDouble(),
    };
  }
}
