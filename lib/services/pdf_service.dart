import 'dart:convert';

import 'package:http/http.dart' as http;

class PdfService {
  static const String baseUrl = 'http://192.168.1.9:8000';

  // --------------------------------------------------
  // UPLOAD PDF
  // --------------------------------------------------

  static Future<Map<String, dynamic>> uploadPdf(
    String filePath,
    String fileName,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload-pdf'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final data = jsonDecode(responseBody);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return data;
  }

  // --------------------------------------------------
  // GET ALL DOCUMENTS
  // --------------------------------------------------

  static Future<List<Map<String, dynamic>>> getDocuments() async {
    final response = await http.get(Uri.parse('$baseUrl/documents'));

    if (response.statusCode != 200) {
      throw Exception('Could not load documents.');
    }

    final data = jsonDecode(response.body);

    if (data['documents'] == null) {
      return [];
    }

    return List<Map<String, dynamic>>.from(data['documents']);
  }

  // --------------------------------------------------
  // ASK QUESTION ABOUT PDF
  // --------------------------------------------------

  static Future<String> askPdf(String question, String documentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ask-pdf'),

      headers: {'Content-Type': 'application/json'},

      body: jsonEncode({'question': question, 'document_id': documentId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return data['response'];
  }

  // --------------------------------------------------
  // DELETE DOCUMENT
  // --------------------------------------------------

  static Future<void> deleteDocument(String documentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/documents/$documentId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not delete document.');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
