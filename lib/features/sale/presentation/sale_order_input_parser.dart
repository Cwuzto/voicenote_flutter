class SaleParsedLine {
  const SaleParsedLine({
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String name;
  final int quantity;
  final int price;
}

class SaleOrderInputParser {
  const SaleOrderInputParser();

  SaleParsedLine? parse(
    String raw, {
    required int? Function(String productName) findProductPrice,
  }) {
    final input = _normalizeInput(raw);
    if (input.isEmpty) return null;

    final tokens = input.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    int quantity = 1;
    int? price;
    int start = 0;
    int end = tokens.length;

    final firstToken = tokens.first.toLowerCase().replaceAll('x', '');
    final firstNumber = int.tryParse(firstToken);
    if (firstNumber != null && firstNumber > 0) {
      quantity = firstNumber;
      start = 1;
    }

    final inferredPrice = _parsePriceToken(tokens.last, tokens, end - 1);
    if (inferredPrice != null) {
      price = inferredPrice;
      end = _stripPriceTokens(tokens, end);
    }

    final name = tokens.sublist(start, end).join(' ').trim();
    if (name.isEmpty) return null;

    price ??= findProductPrice(name) ?? 0;
    return SaleParsedLine(name: name, quantity: quantity, price: price);
  }

  int? _parsePriceToken(String token, List<String> tokens, int lastIndex) {
    final direct = _parsePrice(token);
    if (direct != null) return direct;

    if (lastIndex > 0) {
      final prev = tokens[lastIndex - 1].toLowerCase();
      if (_isThousandWord(prev)) {
        final amount = int.tryParse(token.replaceAll(RegExp(r'[^0-9]'), ''));
        if (amount != null) return amount * 1000;
      }
    }
    return null;
  }

  int _stripPriceTokens(List<String> tokens, int end) {
    if (end <= 0) return end;
    final last = tokens[end - 1].toLowerCase();
    if (end >= 2 && _isThousandWord(last)) return end - 2;
    return end - 1;
  }

  int? _parsePrice(String token) {
    var text = token.toLowerCase().trim();
    if (text.isEmpty) return null;

    text = text
        .replaceAll('vnd', '')
        .replaceAll('vnđ', '')
        .replaceAll('d', '')
        .replaceAll('đ', '')
        .trim();

    if (text.endsWith('k')) {
      final numeric = text.substring(0, text.length - 1).replaceAll(',', '.');
      final base = double.tryParse(numeric);
      if (base == null) return null;
      return (base * 1000).round();
    }

    final normalized = text.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(normalized);
  }

  bool _isThousandWord(String text) {
    return text == 'nghin' ||
        text == 'ngan' ||
        text == 'nghìn' ||
        text == 'ngàn';
  }

  String _normalizeInput(String raw) {
    return raw
        .replaceAll('vnđ', ' vnd ')
        .replaceAll('đ', ' d ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

