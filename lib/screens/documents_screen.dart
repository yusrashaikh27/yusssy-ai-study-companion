import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/pdf_service.dart';
import '../services/storage_service.dart';

class YusssyDocumentColors {
  static const background = Color(0xFFF7F2E9);
  static const surface = Color(0xFFFCF9F3);
  static const surfaceDark = Color(0xFFEDE5D8);

  static const burgundy = Color(0xFF3D0029);
  static const burgundyLight = Color(0xFF6B294F);

  static const ink = Color(0xFF292522);
  static const mutedInk = Color(0xFF746C65);

  static const border = Color(0xFFDCD2C4);
  static const danger = Color(0xFF8B3A3A);
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> _documents = [];

  String? _selectedDocumentId;
  String? _selectedFileName;

  bool _isLoadingDocuments = true;
  bool _isUploading = false;
  bool _isAsking = false;

  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final documents = await PdfService.getDocuments();

      if (!mounted) return;

      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingDocuments = false;
      });

      _showMessage('Could not load documents.');
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result.isEmpty) return;

    final file = result.first;
    final filePath = file.path;

    if (filePath == null || filePath.isEmpty) {
      _showMessage('Could not access the selected PDF.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await PdfService.uploadPdf(filePath, file.name);
      await _loadDocuments();

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showMessage('PDF uploaded and indexed successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showMessage('Upload error: $e');
    }
  }

  Future<void> _selectDocument(Map<String, dynamic> document) async {
    final documentId = document['document_id'] as String;
    final savedMessages = await StorageService.loadPdfChat(documentId);

    if (!mounted) return;

    setState(() {
      _selectedDocumentId = documentId;
      _selectedFileName = document['filename'] as String;
      _messages
        ..clear()
        ..addAll(savedMessages);
    });

    _scrollToBottom();
  }

  Future<void> _confirmDeleteDocument(Map<String, dynamic> document) async {
    final fileName = document['filename'] ?? 'this PDF';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: YusssyDocumentColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Delete PDF?',
            style: TextStyle(
              color: YusssyDocumentColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$fileName"?\n\nThe PDF and its saved chat will be removed.',
            style: const TextStyle(
              color: YusssyDocumentColors.mutedInk,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: YusssyDocumentColors.burgundy),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: YusssyDocumentColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _deleteDocument(document);
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final documentId = document['document_id'];

    try {
      await PdfService.deleteDocument(documentId);
      await StorageService.clearPdfChat(documentId);

      if (!mounted) return;

      setState(() {
        _documents.removeWhere((item) => item['document_id'] == documentId);

        if (_selectedDocumentId == documentId) {
          _selectedDocumentId = null;
          _selectedFileName = null;
          _messages.clear();
        }
      });

      _showMessage('PDF deleted.');
    } catch (_) {
      if (mounted) {
        _showMessage('Could not delete PDF.');
      }
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();

    if (question.isEmpty || _isAsking) return;

    if (_selectedDocumentId == null) {
      _showMessage('Select a PDF first.');
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _questionController.clear();
      _isAsking = true;
    });

    await StorageService.savePdfChat(_selectedDocumentId!, _messages);
    _scrollToBottom();

    try {
      final answer = await PdfService.askPdf(question, _selectedDocumentId!);

      if (!mounted) return;

      setState(() {
        _messages.add({'role': 'assistant', 'content': answer});
        _isAsking = false;
      });

      await StorageService.savePdfChat(_selectedDocumentId!, _messages);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAsking = false;
      });

      _showMessage('Error: $e');
    }
  }

  void _askSuggestion(String question) {
    _questionController.text = question;
    _askQuestion();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: YusssyDocumentColors.burgundy,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YusssyDocumentColors.background,
      appBar: AppBar(
        backgroundColor: YusssyDocumentColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'My Documents',
          style: TextStyle(
            color: YusssyDocumentColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isUploading ? null : _loadDocuments,
            icon: const Icon(
              Icons.refresh_rounded,
              color: YusssyDocumentColors.ink,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildUploadSection(),
          if (_documents.isNotEmpty) _buildDocumentHeader(),
          if (_documents.isNotEmpty) _buildDocumentList(),
          Expanded(
            child: _isLoadingDocuments
                ? const Center(
                    child: CircularProgressIndicator(
                      color: YusssyDocumentColors.burgundy,
                    ),
                  )
                : _selectedDocumentId == null
                ? _buildNoSelection()
                : _messages.isEmpty
                ? _buildReadyState()
                : _buildMessages(),
          ),
          if (_isAsking) _buildSearchingIndicator(),
          if (_selectedDocumentId != null) _buildQuestionInput(),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: InkWell(
        onTap: _isUploading ? null : _uploadPdf,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
          decoration: BoxDecoration(
            color: YusssyDocumentColors.burgundy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isUploading ? 'Indexing your PDF' : 'Add a study PDF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isUploading
                          ? 'Preparing it for questions...'
                          : 'Upload notes, textbooks or study material',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        children: [
          const Text(
            'Library',
            style: TextStyle(
              color: YusssyDocumentColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: YusssyDocumentColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_documents.length} ${_documents.length == 1 ? 'document' : 'documents'}',
              style: const TextStyle(
                color: YusssyDocumentColors.mutedInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final document = _documents[index];
          final documentId = document['document_id'];
          final isSelected = documentId == _selectedDocumentId;

          return GestureDetector(
            onTap: () => _selectDocument(document),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 238,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isSelected
                    ? YusssyDocumentColors.surfaceDark
                    : YusssyDocumentColors.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: isSelected
                      ? YusssyDocumentColors.burgundy
                      : YusssyDocumentColors.border,
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: YusssyDocumentColors.burgundy.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: YusssyDocumentColors.burgundy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          document['filename'] ?? 'PDF',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: YusssyDocumentColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.layers_outlined,
                              size: 13,
                              color: YusssyDocumentColors.mutedInk,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${document['chunks'] ?? 0} chunks',
                              style: const TextStyle(
                                color: YusssyDocumentColors.mutedInk,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDeleteDocument(document),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: YusssyDocumentColors.mutedInk,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoSelection() {
    final hasDocuments = _documents.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: YusssyDocumentColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: YusssyDocumentColors.border),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 38,
                color: YusssyDocumentColors.burgundy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasDocuments ? 'Choose a document' : 'Build your study library',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: YusssyDocumentColors.ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasDocuments
                  ? 'Select a PDF from your library to start exploring it with Yusssy.'
                  : 'Upload your first study PDF and turn your notes into something you can ask questions about.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: YusssyDocumentColors.mutedInk,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            if (!hasDocuments) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _uploadPdf,
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: const Text('Upload your first PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: YusssyDocumentColors.burgundy,
                  side: const BorderSide(color: YusssyDocumentColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: YusssyDocumentColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: YusssyDocumentColors.border),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 34,
                color: YusssyDocumentColors.burgundy,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ready to explore',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YusssyDocumentColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 6),
              Text(
                _selectedFileName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: YusssyDocumentColors.burgundyLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 9),
            const Text(
              'Ask a question and Yusssy will find the relevant parts of your document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YusssyDocumentColors.mutedInk,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 21),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  icon: Icons.summarize_outlined,
                  text: 'Summarize',
                  onTap: () => _askSuggestion('Summarize this PDF'),
                ),
                _SuggestionChip(
                  icon: Icons.topic_outlined,
                  text: 'Main topics',
                  onTap: () =>
                      _askSuggestion('Explain the main topics of this PDF'),
                ),
                _SuggestionChip(
                  icon: Icons.school_outlined,
                  text: 'Exam questions',
                  onTap: () => _askSuggestion(
                    'Generate important exam questions from this PDF',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message['role'] == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(
                    color: YusssyDocumentColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: YusssyDocumentColors.border),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/yusssy_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? YusssyDocumentColors.burgundy
                        : YusssyDocumentColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(17),
                      topRight: const Radius.circular(17),
                      bottomLeft: Radius.circular(isUser ? 17 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 17),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: YusssyDocumentColors.border),
                  ),
                  child: Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : YusssyDocumentColors.ink,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 5),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: YusssyDocumentColors.burgundyLight,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Searching your document...',
            style: TextStyle(
              color: YusssyDocumentColors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 7, 13, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _askQuestion(),
                decoration: InputDecoration(
                  hintText: 'Ask about this PDF...',
                  hintStyle: const TextStyle(
                    color: YusssyDocumentColors.mutedInk,
                    fontSize: 13.5,
                  ),
                  filled: true,
                  fillColor: YusssyDocumentColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: YusssyDocumentColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: YusssyDocumentColors.burgundy,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isAsking
                    ? YusssyDocumentColors.surfaceDark
                    : YusssyDocumentColors.burgundy,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Ask',
                onPressed: _isAsking ? null : _askQuestion,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: _isAsking
                      ? YusssyDocumentColors.mutedInk
                      : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(
        Icons.arrow_forward_rounded,
        size: 14,
        color: YusssyDocumentColors.burgundy,
      ),
      label: Text(text),
      onPressed: onTap,
      side: const BorderSide(color: YusssyDocumentColors.border),
      backgroundColor: YusssyDocumentColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      labelStyle: const TextStyle(
        color: YusssyDocumentColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
