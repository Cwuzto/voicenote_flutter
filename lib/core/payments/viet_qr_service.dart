import 'dart:convert';
import 'dart:io';

class VietQrBankVm {
  const VietQrBankVm({
    required this.name,
    required this.code,
    required this.bin,
    required this.shortName,
  });

  final String name;
  final String code;
  final String bin;
  final String shortName;
}

class VietQrBuildResult {
  const VietQrBuildResult({
    required this.bank,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.transferContent,
    required this.imageUri,
  });

  final VietQrBankVm bank;
  final String accountNumber;
  final String accountName;
  final int amount;
  final String transferContent;
  final Uri imageUri;
}

class VietQrService {
  VietQrService({HttpClient? httpClient}) : _httpClient = httpClient;

  final HttpClient? _httpClient;

  static List<VietQrBankVm>? _bankCache;

  Future<VietQrBuildResult> buildOrderPaymentQr({
    required String bankName,
    required String accountNumber,
    required String accountName,
    required int amount,
    required String orderId,
  }) async {
    final normalizedAccountNumber = accountNumber.replaceAll(' ', '').trim();
    final normalizedAccountName = accountName.trim();
    if (normalizedAccountNumber.isEmpty) {
      throw const VietQrException('So tai khoan khong duoc de trong.');
    }
    if (normalizedAccountName.isEmpty) {
      throw const VietQrException('Ten chu tai khoan khong duoc de trong.');
    }
    if (amount <= 0) {
      throw const VietQrException('So tien hoa don phai lon hon 0.');
    }

    final bank = await resolveBank(bankName);
    if (bank == null) {
      throw VietQrException(
        'Khong nhan dien duoc ngan hang "$bankName". '
        'Hay sua ten ngan hang theo ten pho bien nhu Vietcombank, MB Bank, ACB...',
      );
    }

    final transferContent = buildTransferContent(orderId);
    return VietQrBuildResult(
      bank: bank,
      accountNumber: normalizedAccountNumber,
      accountName: normalizedAccountName,
      amount: amount,
      transferContent: transferContent,
      imageUri: Uri.https(
        'img.vietqr.io',
        '/image/${bank.bin}-$normalizedAccountNumber-compact2.png',
        {
          'amount': amount.toString(),
          'addInfo': transferContent,
          'accountName': normalizedAccountName,
        },
      ),
    );
  }

  Future<VietQrBankVm?> resolveBank(String rawBankName) async {
    final search = _compact(rawBankName);
    if (search.isEmpty) {
      return null;
    }

    final banks = await fetchBanks();
    VietQrBankVm? partialMatch;
    for (final bank in banks) {
      final aliases = [
        _compact(bank.shortName),
        _compact(bank.code),
        _compact(bank.name),
      ];
      if (aliases.any((alias) => alias == search)) {
        return bank;
      }
      if (aliases.any(
        (alias) => search.contains(alias) || alias.contains(search),
      )) {
        partialMatch ??= bank;
      }
    }
    return partialMatch;
  }

  Future<List<VietQrBankVm>> fetchBanks() async {
    final cached = _bankCache;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final client = _httpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(
        Uri.https('api.vietqr.io', '/v2/banks'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VietQrException(
          'Khong tai duoc danh sach ngan hang VietQR (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const VietQrException('Danh sach ngan hang VietQR khong hop le.');
      }
      final data = decoded['data'];
      if (data is! List) {
        throw const VietQrException('VietQR khong tra ve danh sach ngan hang.');
      }

      final banks = data
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => VietQrBankVm(
              name: (item['name'] ?? '').toString(),
              code: (item['code'] ?? '').toString(),
              bin: (item['bin'] ?? '').toString(),
              shortName: (item['shortName'] ?? item['short_name'] ?? '')
                  .toString(),
            ),
          )
          .where((item) => item.bin.isNotEmpty)
          .toList(growable: false);

      if (banks.isEmpty) {
        throw const VietQrException('Danh sach ngan hang VietQR dang rong.');
      }

      _bankCache = banks;
      return banks;
    } on SocketException {
      throw const VietQrException(
        'Khong ket noi duoc VietQR. Hay kiem tra internet va thu lai.',
      );
    } on FormatException {
      throw const VietQrException(
        'Phan hoi tu VietQR khong dung dinh dang JSON.',
      );
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  static String buildTransferContent(String orderId) {
    final compactId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = compactId.length <= 12
        ? compactId
        : compactId.substring(compactId.length - 12);
    return 'HD$suffix';
  }

  static String _compact(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(' ', '');
  }
}

class VietQrException implements Exception {
  const VietQrException(this.message);

  final String message;

  @override
  String toString() => message;
}
