import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

class ValuationResult {
  final String source;
  final double value;
  final String? url;
  ValuationResult({required this.source, required this.value, this.url});
}

class ValuationService {
  static final ValuationService _instance = ValuationService._();
  ValuationService._();
  factory ValuationService() => _instance;

  Future<List<ValuationResult>> fetchAll(String name, {String? setName}) async {
    final results = await Future.wait([
      _fetchPriceCharting(name, setName: setName),
      _fetchEbay(name, setName: setName),
    ]);
    return results.whereType<ValuationResult>().toList();
  }

  double computeEstimate(List<ValuationResult> results, double conditionScore) {
    if (results.isEmpty) return 0.0;
    final avg = results.map((r) => r.value).reduce((a, b) => a + b) / results.length;
    final factor = conditionScore / 100.0;
    return avg * (0.5 + 0.5 * factor);
  }

  Future<ValuationResult?> _fetchPriceCharting(String name, {String? setName}) async {
    try {
      final query = Uri.encodeComponent(setName != null ? '$name $setName' : name);
      final url = 'https://www.pricecharting.com/search-products?q=$query&type=prices';
      final resp = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final doc = html.parse(resp.body);
      final priceEl = doc.querySelector('#used_price .price, .price .js-price');
      if (priceEl == null) return null;
      final text = priceEl.text.replaceAll(RegExp(r'[^\d.]'), '');
      final value = double.tryParse(text);
      if (value == null || value <= 0) return null;
      return ValuationResult(source: 'PriceCharting', value: value, url: url);
    } catch (_) {
      return null;
    }
  }

  Future<ValuationResult?> _fetchEbay(String name, {String? setName}) async {
    try {
      final query = Uri.encodeComponent(
          setName != null ? '$name $setName pokemon card' : '$name pokemon card');
      final url =
          'https://www.ebay.com/sch/i.html?_nkw=$query&LH_Sold=1&LH_Complete=1&_sop=13';
      final resp = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final doc = html.parse(resp.body);
      final prices = doc
          .querySelectorAll('.s-item__price')
          .map((e) => double.tryParse(e.text.replaceAll(RegExp(r'[^\d.]'), '')))
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (prices.isEmpty) return null;
      prices.sort();
      final median = prices[prices.length ~/ 2];
      return ValuationResult(source: 'eBay (sold)', value: median, url: url);
    } catch (_) {
      return null;
    }
  }
}
