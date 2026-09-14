import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

/// Mirrors LocalStore's method signatures so switching from local-only to
/// a real backend is a matter of swapping which service the screens call,
/// not rewriting the screens. Point [baseUrl] at your deployed Flask app
/// (the one in the budgetapp.zip from earlier) once it exposes matching
/// JSON endpoints, e.g.:
///   GET    /api/budgets
///   POST   /api/budgets
///   GET    /api/budgets/<id>/transactions
///   POST   /api/transactions
///   DELETE /api/transactions/<id>
///   POST   /api/sms   <-- forward raw SMS text here for server-side parsing
class ApiService {
  final String baseUrl;
  final String? authToken;

  ApiService({required this.baseUrl, this.authToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Future<List<Budget>> getBudgets() async {
    final res = await http.get(Uri.parse('$baseUrl/api/budgets'), headers: _headers);
    _checkOk(res);
    return (jsonDecode(res.body) as List).map((e) => Budget.fromJson(e)).toList();
  }

  Future<List<Transaction>> getTransactions(String budgetId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/budgets/$budgetId/transactions'), headers: _headers);
    _checkOk(res);
    return (jsonDecode(res.body) as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> addTransaction(Transaction tx) async {
    final res = await http.post(Uri.parse('$baseUrl/api/transactions'), headers: _headers, body: jsonEncode(tx.toJson()));
    _checkOk(res);
    return Transaction.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteTransaction(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/transactions/$id'), headers: _headers);
    _checkOk(res);
  }

  /// Send a raw MoMo SMS body to the backend so parsing can also happen
  /// server-side (useful if you later add a server-side webhook source,
  /// e.g. an Android forwarding service posting directly to the API instead
  /// of going through this Flutter app at all).
  Future<Transaction?> submitRawSms(String budgetId, String smsBody) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sms'),
      headers: _headers,
      body: jsonEncode({'budgetId': budgetId, 'body': smsBody}),
    );
    if (res.statusCode == 204) return null; // server couldn't parse it confidently
    _checkOk(res);
    return Transaction.fromJson(jsonDecode(res.body));
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}
