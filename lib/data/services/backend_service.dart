import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'ai_service.dart';

/// Service for communicating with the Tiny Steps backend API
class BackendService {
  // Override with --dart-define=TINYSTEPS_API_URL=... (e.g. a local wrangler dev server)
  static const String _baseUrl = String.fromEnvironment(
    'TINYSTEPS_API_URL',
    defaultValue: 'https://tinysteps-api.pardom-89.workers.dev',
  );
  static const String _tokenKey = 'backend_token';
  static const String _deviceIdKey = 'backend_device_id';
  static const Duration _aiTimeout = Duration(seconds: 35);
  static const Duration _shortTimeout = Duration(seconds: 15);

  final http.Client _client;

  String? _token;
  String? _deviceId;
  bool _loadedFromStorage = false;
  Future<void>? _registering;

  BackendService({http.Client? client}) : _client = client ?? http.Client();

  /// Server-assigned device ID (useful for support/debugging).
  String? get deviceId => _deviceId;

  /// Load stored credentials and register if needed.
  /// Safe to call repeatedly: it retries registration until a token exists.
  Future<void> initialize() async {
    if (!_loadedFromStorage) {
      final box = await Hive.openBox<String>('backend');
      _token = box.get(_tokenKey);
      _deviceId = box.get(_deviceIdKey);
      _loadedFromStorage = true;
    }

    if (_token == null) {
      await _register();
    }
  }

  Map<String, String> _authHeaders({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token ?? ''}',
      };

  /// Register a new device and get a token. Concurrent callers share one request.
  Future<void> _register() {
    return _registering ??= _doRegister().whenComplete(() => _registering = null);
  }

  Future<void> _doRegister() async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/register'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_shortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        final deviceId = data['deviceId'] as String?;
        if (token == null || deviceId == null) return;
        _token = token;
        _deviceId = deviceId;

        final box = await Hive.openBox<String>('backend');
        await box.put(_tokenKey, token);
        await box.put(_deviceIdKey, deviceId);
      }
    } catch (e) {
      // Registration failed - caller falls back
    }
  }

  /// Drops the current token and re-registers. Returns true if a new token was obtained.
  Future<bool> _refreshToken() async {
    _token = null;
    await _register();
    return _token != null;
  }

  /// Decompose a task using the backend API.
  /// Returns null if the backend is unavailable (caller should fall back).
  /// Throws [RateLimitException] when the free limit or throttle is hit.
  Future<Map<String, dynamic>?> decomposeTask(
    String taskDescription, {
    DecompositionStyle style = DecompositionStyle.standard,
  }) async {
    return _postAi(
      '/v1/decompose',
      {
        'task': taskDescription,
        'style': style.name,
      },
    );
  }

  /// Get current usage stats
  Future<UsageStats?> getUsage() async {
    try {
      await initialize();
      if (_token == null) return null;

      var response = await _client
          .get(Uri.parse('$_baseUrl/v1/usage'), headers: _authHeaders())
          .timeout(_shortTimeout);
      if (response.statusCode == 401 && await _refreshToken()) {
        response = await _client
            .get(Uri.parse('$_baseUrl/v1/usage'), headers: _authHeaders())
            .timeout(_shortTimeout);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UsageStats(
          used: (data['used'] as num?)?.toInt() ?? 0,
          limit: (data['limit'] as num?)?.toInt() ?? UsageStats.defaultFreeLimit,
          remaining: (data['remaining'] as num?)?.toInt() ?? UsageStats.defaultFreeLimit,
          isPremium: data['isPremium'] == true,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Link this device to a RevenueCat customer so the backend can verify
  /// premium status server-side. Returns the backend's view of premium status.
  Future<bool> verifySubscription({required String revenueCatUserId}) async {
    try {
      await initialize();
      if (_token == null) return false;

      Future<http.Response> send() => _client
          .post(
            Uri.parse('$_baseUrl/v1/verify-subscription'),
            headers: _authHeaders(json: true),
            body: jsonEncode({'revenueCatUserId': revenueCatUserId}),
          )
          .timeout(_shortTimeout);

      var response = await send();
      if (response.statusCode == 401 && await _refreshToken()) {
        response = await send();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isPremium'] == true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Send user feedback to the backend. Returns true when it was stored.
  Future<bool> submitFeedback({
    required String message,
    String? email,
    String? platform,
  }) async {
    try {
      await initialize();
      if (_token == null) return false;

      Future<http.Response> send() => _client
          .post(
            Uri.parse('$_baseUrl/v1/feedback'),
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'message': message,
              if (email != null && email.isNotEmpty) 'email': email,
              if (platform != null) 'platform': platform,
            }),
          )
          .timeout(_shortTimeout);

      var response = await send();
      if (response.statusCode == 401 && await _refreshToken()) {
        response = await send();
      }
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get sub-steps for a step the user is stuck on.
  /// Returns null if the backend is unavailable.
  /// Throws [RateLimitException] when the free limit or throttle is hit.
  Future<SubStepsResult?> getSubSteps(
    String step, {
    String? taskContext,
  }) async {
    final data = await _postAi(
      '/v1/substeps',
      {
        'step': step,
        if (taskContext != null) 'taskContext': taskContext,
      },
    );
    if (data == null) return null;

    final rawSubsteps = data['substeps'];
    if (rawSubsteps is! List) return null;
    return SubStepsResult(
      substeps: rawSubsteps.whereType<String>().toList(),
      encouragement: data['encouragement'] as String?,
      usage: data['_usage'] as UsageStats?,
    );
  }

  /// POSTs to an AI endpoint with a single token-refresh retry.
  /// On success, the parsed body is returned with a `_usage` [UsageStats] entry.
  Future<Map<String, dynamic>?> _postAi(String path, Map<String, dynamic> body) async {
    try {
      await initialize();
      if (_token == null) return null;

      Future<http.Response> send() => _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _authHeaders(json: true),
            body: jsonEncode(body),
          )
          .timeout(_aiTimeout);

      var response = await send();
      if (response.statusCode == 401) {
        if (!await _refreshToken()) return null;
        response = await send();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          data['_usage'] = UsageStats.fromUsageJson(data['usage']);
          return data;
        }
      } else if (response.statusCode == 429) {
        throw RateLimitException.fromResponseBody(response.body);
      }

      // 5xx (including 502 for AI failures) and anything else: unavailable
      return null;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      return null;
    }
  }
}

/// Result from sub-steps API
class SubStepsResult {
  final List<String> substeps;
  final String? encouragement;
  final UsageStats? usage;

  SubStepsResult({
    required this.substeps,
    this.encouragement,
    this.usage,
  });
}

/// Usage statistics from the backend.
/// The free tier is a lifetime allowance (not daily); -1 means unlimited.
class UsageStats {
  static const int defaultFreeLimit = 5;

  final int used;
  final int limit;
  final int remaining;
  final bool isPremium;

  UsageStats({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isPremium,
  });

  bool get isUnlimited => limit < 0 || remaining < 0;

  static UsageStats? fromUsageJson(dynamic json) {
    if (json is! Map) return null;
    final used = (json['used'] as num?)?.toInt();
    final limit = (json['limit'] as num?)?.toInt();
    final remaining = (json['remaining'] as num?)?.toInt();
    if (used == null || limit == null || remaining == null) return null;
    return UsageStats(
      used: used,
      limit: limit,
      remaining: remaining,
      isPremium: limit < 0,
    );
  }
}

/// Exception thrown when the backend refuses an AI request.
class RateLimitException implements Exception {
  static const String codeFreeLimitReached = 'FREE_LIMIT_REACHED';
  static const String codeRateLimited = 'RATE_LIMITED';

  final String message;
  final int remaining;

  /// `FREE_LIMIT_REACHED` (lifetime free breakdowns used up) or
  /// `RATE_LIMITED` (temporary abuse throttle).
  final String? code;
  final UsageStats? usage;

  RateLimitException(this.message, this.remaining, {this.code, this.usage});

  bool get isFreeLimitReached => code == codeFreeLimitReached;

  factory RateLimitException.fromResponseBody(String body) {
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    final usage = UsageStats.fromUsageJson(data['usage']);
    final code = data['code'] as String?;
    return RateLimitException(
      (data['error'] as String?) ??
          (code == codeRateLimited
              ? 'Too many requests. Please try again later.'
              : 'Free breakdowns used up'),
      usage?.remaining ?? 0,
      code: code ?? codeFreeLimitReached,
      usage: usage,
    );
  }

  @override
  String toString() => message;
}
