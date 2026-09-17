import 'dart:convert';

import 'package:http/http.dart' as http;

class GroqService {
  static const String backendUrl = 'http://192.168.1.9:8000/chat';

  static Future<String> sendMessage(List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'messages': messages}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Backend error: ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return data['response'];
  }
}
