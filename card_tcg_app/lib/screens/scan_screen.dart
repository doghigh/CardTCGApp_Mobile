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
  final _notesCtrl = TextEditingController();

  String? _frontPath;
  String? _backPath;
  String _status = 'Tap a button to capture the card front and back.';
  bool _busy = false;
  List<ValuationResult> _valuations = [];
  double _estimate = 0.0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setCtrl.dispose();
    _numberCtrl.dispose();
    _notesCtrl.dispose();
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

  Future<void> _capture(String side) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xfile == null) return;

    setState(() {
      _busy = true;
      _status = 'Processing $side...';
    });

    final saved = await _saveImage(xfile, side);

    if (side == 'front') {
      setState(() => _frontPath = saved);
      final info = await _ocr.extractCardInfo(saved);
      setState(() {
        if (info['name']!.isNotEmpty && _nameCtrl.text.isEmpty) {
          _nameCtrl.text = info['name']!;
        }
        if (info['card_number']!.isNotEmpty && _numberCtrl.text.isEmpty) {
          _numberCtrl.text = info['card_number']!;
        }
        _status = 'Front captured.${info['name']!.isNotEmpty ? ' Detected: ${info['name']}' : ' Name not detected — enter manually.'}';
      });
    } else {
      setState(() {
        _backPath = saved;
        _status = 'Back captured.';
      });
    }

    setState(() => _busy = false);

    if (side == 'front' && _nameCtrl.text.isNotEmpty) {
      await _fetchPricing();
    }
  }

  Future<void> _fetchPricing() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a card name first.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Fetching prices for "$name"...';
    });
    final results = await _valuator.fetchAll(name, setName: _setCtrl.text.trim());
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card name is required.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Saving...';
    });
    final card = TradingCard(
      name: _nameCtrl.text.trim(),
      setName: _setCtrl.text.trim(),
      cardNumber: _numberCtrl.text.trim(),
      frontScanPath: _frontPath,
      backScanPath: _backPath,
      estimatedValue: _estimate,
      purchaseDate: DateTime.now().toIso8601String().substring(0, 10),
      notes: _notesCtrl.text.trim(),
    );
    final id = await _db.addCard(card);
    for (final v in _valuations) {
      await _db.addValuation(id, v.source, v.value, v.url);
    }
    setState(() {
      _busy = false;
      _status = 'Saved! "${card.name}" added to collection.';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${card.name}" added to collection.'),
          backgroundColor: Colors.green[700],
        ),
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
      _status = 'Tap a button to capture the card front and back.';
    });
    _nameCtrl.clear();
    _setCtrl.clear();
    _numberCtrl.clear();
    _notesCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Images row
            Row(
              children: [
                Expanded(
                  child: _ImageCapture(
                    label: 'Front',
                    path: _frontPath,
                    onCapture: _busy ? null : () => _capture('front'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageCapture(
                    label: 'Back',
                    path: _backPath,
                    onCapture: _busy ? null : () => _capture('back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_busy) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(_status,
                        style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card details
            _buildField('Card Name *', _nameCtrl),
            const SizedBox(height: 8),
            _buildField('Set', _setCtrl),
            const SizedBox(height: 8),
            _buildField('Card Number', _numberCtrl),
            const SizedBox(height: 8),
            _buildField('Notes', _notesCtrl, maxLines: 2),
            const SizedBox(height: 16),

            // Pricing
            if (_valuations.isNotEmpty) ...[
              _PricingCard(valuations: _valuations, estimate: _estimate),
              const SizedBox(height: 12),
            ],

            // Actions
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
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _ImageCapture extends StatelessWidget {
  final String label;
  final String? path;
  final VoidCallback? onCapture;

  const _ImageCapture({required this.label, this.path, this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onCapture,
          child: CardImage(
            path: path,
            placeholder: 'Tap to\ncapture $label',
            width: double.infinity,
            height: 180,
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  final List<ValuationResult> valuations;
  final double estimate;

  const _PricingCard({required this.valuations, required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimated Value: \$${estimate.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.greenAccent)),
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
}
