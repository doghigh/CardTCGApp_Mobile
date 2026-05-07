class TradingCard {
  final int? id;
  final String name;
  final String setName;
  final String cardNumber;
  final String rarity;
  final String game;
  final int year;
  final String language;
  final bool foil;
  final String? frontScanPath;
  final String? backScanPath;
  final String? conditionGrade;
  final double? conditionScore;
  final double estimatedValue;
  final double purchasePrice;
  final String purchaseDate;
  final String notes;
  final int quantity;
  final DateTime createdAt;

  TradingCard({
    this.id,
    required this.name,
    this.setName = '',
    this.cardNumber = '',
    this.rarity = '',
    this.game = '',
    this.year = 0,
    this.language = 'English',
    this.foil = false,
    this.frontScanPath,
    this.backScanPath,
    this.conditionGrade,
    this.conditionScore,
    this.estimatedValue = 0.0,
    this.purchasePrice = 0.0,
    this.purchaseDate = '',
    this.notes = '',
    this.quantity = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'set_name': setName,
        'card_number': cardNumber,
        'rarity': rarity,
        'game': game,
        'year': year,
        'language': language,
        'foil': foil ? 1 : 0,
        'front_scan_path': frontScanPath,
        'back_scan_path': backScanPath,
        'condition_grade': conditionGrade,
        'condition_score': conditionScore,
        'estimated_value': estimatedValue,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate,
        'notes': notes,
        'quantity': quantity,
        'created_at': createdAt.toIso8601String(),
      };

  factory TradingCard.fromMap(Map<String, dynamic> m) => TradingCard(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        setName: m['set_name'] as String? ?? '',
        cardNumber: m['card_number'] as String? ?? '',
        rarity: m['rarity'] as String? ?? '',
        game: m['game'] as String? ?? '',
        year: m['year'] as int? ?? 0,
        language: m['language'] as String? ?? 'English',
        foil: (m['foil'] as int? ?? 0) == 1,
        frontScanPath: m['front_scan_path'] as String?,
        backScanPath: m['back_scan_path'] as String?,
        conditionGrade: m['condition_grade'] as String?,
        conditionScore: (m['condition_score'] as num?)?.toDouble(),
        estimatedValue: (m['estimated_value'] as num?)?.toDouble() ?? 0.0,
        purchasePrice: (m['purchase_price'] as num?)?.toDouble() ?? 0.0,
        purchaseDate: m['purchase_date'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        quantity: m['quantity'] as int? ?? 1,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  TradingCard copyWith({
    int? id,
    String? name,
    String? setName,
    String? cardNumber,
    String? rarity,
    String? game,
    int? year,
    String? language,
    bool? foil,
    String? frontScanPath,
    String? backScanPath,
    String? conditionGrade,
    double? conditionScore,
    double? estimatedValue,
    double? purchasePrice,
    String? purchaseDate,
    String? notes,
    int? quantity,
  }) =>
      TradingCard(
        id: id ?? this.id,
        name: name ?? this.name,
        setName: setName ?? this.setName,
        cardNumber: cardNumber ?? this.cardNumber,
        rarity: rarity ?? this.rarity,
        game: game ?? this.game,
        year: year ?? this.year,
        language: language ?? this.language,
        foil: foil ?? this.foil,
        frontScanPath: frontScanPath ?? this.frontScanPath,
        backScanPath: backScanPath ?? this.backScanPath,
        conditionGrade: conditionGrade ?? this.conditionGrade,
        conditionScore: conditionScore ?? this.conditionScore,
        estimatedValue: estimatedValue ?? this.estimatedValue,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        notes: notes ?? this.notes,
        quantity: quantity ?? this.quantity,
        createdAt: createdAt,
      );
}
