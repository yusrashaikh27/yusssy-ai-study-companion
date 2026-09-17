import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _chatKey = 'normal_chat_history';

  static const String _pdfChatsKey = 'pdf_chat_history';

  // =========================
  // NORMAL CHAT
  // =========================

  static Future<void> saveChat(List<Map<String, String>> messages) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_chatKey, jsonEncode(messages));
  }

  static Future<List<Map<String, String>>> loadChat() async {
    final preferences = await SharedPreferences.getInstance();

    final data = preferences.getString(_chatKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(data);

      return List<Map<String, String>>.from(
        decoded.map((message) => Map<String, String>.from(message)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearChat() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_chatKey);
  }

  // =========================
  // PDF CHAT
  // =========================

  static Future<void> savePdfChat(
    String documentId,
    List<Map<String, String>> messages,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final allChats = await loadPdfChats();

    allChats[documentId] = messages;

    await preferences.setString(_pdfChatsKey, jsonEncode(allChats));
  }

  static Future<Map<String, List<Map<String, String>>>> loadPdfChats() async {
    final preferences = await SharedPreferences.getInstance();

    final data = preferences.getString(_pdfChatsKey);

    if (data == null || data.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;

      final result = <String, List<Map<String, String>>>{};

      decoded.forEach((documentId, messages) {
        result[documentId] = List<Map<String, String>>.from(
          messages.map((message) => Map<String, String>.from(message)),
        );
      });

      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, String>>> loadPdfChat(
    String documentId,
  ) async {
    final allChats = await loadPdfChats();

    return allChats[documentId] ?? [];
  }

  static Future<void> clearPdfChat(String documentId) async {
    final preferences = await SharedPreferences.getInstance();

    final allChats = await loadPdfChats();

    allChats.remove(documentId);

    await preferences.setString(_pdfChatsKey, jsonEncode(allChats));
  }

  // =========================
  // CLEAR EVERYTHING
  // =========================

  static Future<void> clearEverything() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_chatKey);
    await preferences.remove(_pdfChatsKey);
  }
}
