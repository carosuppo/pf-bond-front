import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/group_model.dart';

class GroupService {
  // Candidate base URLs to try (emulator, local network, localhost)
  static const List<String> _androidCandidates = [
    'http://10.0.2.2:3000',
    'http://192.168.100.107:3000',
    'http://localhost:3000',
  ];

  static const List<String> _defaultCandidates = [
    'http://192.168.100.107:3000',
    'http://localhost:3000',
  ];

  String? _resolvedBaseUrl;

  Future<String> _resolveBaseUrl() async {
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;

    if (kIsWeb) {
      _resolvedBaseUrl = 'http://localhost:3000';
      return _resolvedBaseUrl!;
    }

    final candidates = Platform.isAndroid
        ? _androidCandidates
        : _defaultCandidates;

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/');
        final resp = await http.get(uri).timeout(const Duration(seconds: 3));
        // Any response (including 404) means we reached the host
        if (resp.statusCode >= 100 && resp.statusCode < 600) {
          _resolvedBaseUrl = candidate;
          return _resolvedBaseUrl!;
        }
      } catch (_) {
        // ignore and try next candidate
      }
    }

    throw Exception(
      'No se pudo conectar con el backend en ninguna URL candidata',
    );
  }

  Future<GroupModel> createGroup(String name) async {
    final baseUrl = await _resolveBaseUrl();
    final url = Uri.parse('$baseUrl/group');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return GroupModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear grupo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en la comunicación con el servidor: $e');
    }
  }
}
