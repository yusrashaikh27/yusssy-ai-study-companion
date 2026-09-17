import 'dart:convert';

import 'package:http/http.dart' as http;

class PdfService {
  static const String baseUrl =
      'https://yusssy-ai-study-companion.onrender.com';

  // --------------------------------------------------
  // UPLOAD PDF
  // --------------------------------------------------

  static Future<Map<String, dynamic>> uploadPdf(
    String filePath,
    String fileName,
  ) async {
    try {
      print('PDF UPLOAD STARTED');
      print('File: $fileName');
      print('Path: $filePath');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-pdf'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );

      print('Sending PDF to Render...');

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      print('Upload status: ${response.statusCode}');
      print('Upload response: $responseBody');

      if (response.statusCode != 200) {
        throw Exception(
          'Upload failed (${response.statusCode}): $responseBody',
        );
      }

      final data = jsonDecode(responseBody);

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      print('PDF UPLOAD SUCCESSFUL');

      return Map<String, dynamic>.from(data);
    } catch (e) {
      print('PDF UPLOAD ERROR: $e');
      rethrow;
    }
  }

  // --------------------------------------------------
  // GET ALL DOCUMENTS
  // --------------------------------------------------

  static Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/documents'));

      print('Documents status: ${response.statusCode}');
      print('Documents response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Could not load documents: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data['documents'] == null) {
        return [];
      }

      return List<Map<String, dynamic>>.from(data['documents']);
    } catch (e) {
      print('GET DOCUMENTS ERROR: $e');
      rethrow;
    }
  }

  // --------------------------------------------------
  // ASK QUESTION ABOUT PDF
  // --------------------------------------------------

  static Future<String> askPdf(String question, String documentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question, 'document_id': documentId}),
      );

      print('Ask PDF status: ${response.statusCode}');
      print('Ask PDF response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Server error (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return data['response'];
    } catch (e) {
      print('ASK PDF ERROR: $e');
      rethrow;
    }
  }

  // --------------------------------------------------
  // DELETE DOCUMENT
  // --------------------------------------------------

  static Future<void> deleteDocument(String documentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
      );

      print('Delete status: ${response.statusCode}');
      print('Delete response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Could not delete document: '
          '${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        throw Exception(data['error']);
      }
    } catch (e) {
      print('DELETE DOCUMENT ERROR: $e');
      rethrow;
    }
  }
}
