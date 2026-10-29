import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'session_manager.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => statusCode != null ? 'HTTP $statusCode: $message' : message;
}

class ApiClient {
  static final http.Client _client = http.Client();

  static Future<dynamic> request(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final baseUrl = AppConfig.baseUrl;
    final uri = Uri.parse(baseUrl).resolve(path.startsWith('/') ? path.substring(1) : path);

    final finalUri = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tunnel-Skip-AntiPhishing-Page': 'true',
    };

    final token = SessionManager.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      http.Response response;
      final payload = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(finalUri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await _client.post(finalUri, headers: headers, body: payload).timeout(timeout);
          break;
        case 'PUT':
          response = await _client.put(finalUri, headers: headers, body: payload).timeout(timeout);
          break;
        case 'PATCH':
          response = await _client.patch(finalUri, headers: headers, body: payload).timeout(timeout);
          break;
        case 'DELETE':
          response = await _client.delete(finalUri, headers: headers).timeout(timeout);
          break;
        default:
          throw ApiException('Phương thức HTTP không hỗ trợ: $method');
      }

      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Không thể kết nối đến máy chủ. Vui lòng kiểm tra địa chỉ IP/mạng LAN.');
    } on TimeoutException {
      throw const ApiException('Hết thời gian chờ phản hồi từ máy chủ.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi kết nối: $e');
    }
  }

  static Future<dynamic> uploadFile(
    String path,
    File file, {
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final baseUrl = AppConfig.baseUrl;
    final uri = Uri.parse(baseUrl).resolve(path.startsWith('/') ? path.substring(1) : path);

    final request = http.MultipartRequest('POST', uri);

    request.headers['X-Tunnel-Skip-AntiPhishing-Page'] = 'true';
    final token = SessionManager.token;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Lỗi kết nối mạng khi tải ảnh lên.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi tải file: $e');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;
    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
      }
    } catch (_) {
      data = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    var errorMessage = 'Yêu cầu thất bại';
    if (data is Map) {
      if (data.containsKey('message') && data['message'] != null && data['message'].toString().isNotEmpty) {
        errorMessage = data['message'].toString();
      } else if (data.containsKey('errors') && data['errors'] is Map) {
        final errMap = data['errors'] as Map;
        final List<String> errList = [];
        errMap.forEach((k, v) {
          if (v is List) {
            errList.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            errList.add(v.toString());
          }
        });
        if (errList.isNotEmpty) {
          errorMessage = errList.join('; ');
        }
      } else if (data.containsKey('error') && data['error'] != null) {
        errorMessage = data['error'].toString();
      } else if (data.containsKey('title') && data['title'] != null) {
        errorMessage = data['title'].toString();
      }
    }

    throw ApiException(errorMessage, response.statusCode);
  }

  static Future<bool> testConnection([String? customUrl]) async {
    final url = customUrl ?? AppConfig.baseUrl;
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {'X-Tunnel-Skip-AntiPhishing-Page': 'true'},
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
