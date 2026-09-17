import 'package:flutter/material.dart';

import 'screens/documents_screen.dart';
import 'services/groq_service.dart';
import 'services/storage_service.dart';
import 'services/voice_service.dart';

void main() {
  runApp(const AICompanionApp());
}

// ======================================================
// YUSSSY DESIGN SYSTEM
// ======================================================

class YusssyColors {
  static const background = Color(0xFFF7F2E9);
  static const surface = Color(0xFFFCF9F3);
  static const surfaceDark = Color(0xFFEDE5D8);

  static const burgundy = Color(0xFF3D0029);
  static const burgundyLight = Color(0xFF6B294F);

  static const ink = Color(0xFF292522);
  static const mutedInk = Color(0xFF746C65);

  static const border = Color(0xFFDCD2C4);
  static const success = Color(0xFF49634D);
  static const danger = Color(0xFF8B3A3A);
}

final ValueNotifier<int> chatClearNotifier = ValueNotifier<int>(0);

/// Shared greeting used whenever chat is reset, so all three reset paths
/// (Settings > Clear Chat, Settings > Clear Everything, in-chat delete)
/// stay in sync.
Map<String, String> greetingMessage() => {
  'role': 'assistant',
  'content': 'Hello! I’m Yusssy. What would you like to learn today?',
};

// ======================================================
// APP
// ======================================================

class AICompanionApp extends StatelessWidget {
  const AICompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: YusssyColors.burgundy,
          brightness: Brightness.light,
        ).copyWith(
          primary: YusssyColors.burgundy,
          onPrimary: Colors.white,
          secondary: YusssyColors.burgundyLight,
          surface: YusssyColors.surface,
          onSurface: YusssyColors.ink,
          outline: YusssyColors.border,
        );

    return MaterialApp(
      title: 'Yusssy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: YusssyColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: YusssyColors.background,
          foregroundColor: YusssyColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: YusssyColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: YusssyColors.burgundy,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? YusssyColors.burgundy : YusssyColors.mutedInk,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? Colors.white : YusssyColors.mutedInk,
              size: 22,
            );
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: YusssyColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: YusssyColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: YusssyColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: YusssyColors.burgundy,
              width: 1.5,
            ),
          ),
          hintStyle: const TextStyle(
            color: YusssyColors.mutedInk,
            fontSize: 14,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: YusssyColors.border,
          thickness: 0.8,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: YusssyColors.ink,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ======================================================
// MAIN SCREEN
// ======================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onOpenChat: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
        onOpenDocuments: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()),
          );
        },
      ),
      const ChatScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ======================================================
// HOME SCREEN
// ======================================================

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenDocuments;

  const HomeScreen({
    super.key,
    required this.onOpenChat,
    required this.onOpenDocuments,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceService _voiceService = VoiceService();

  bool _isListening = false;
  bool _isProcessingVoice = false;

  String _recognizedText = '';

  Future<void> _startVoice() async {
    // Guard against double-start: don't start listening again while we're
    // already listening or still processing a previous question.
    if (_isProcessingVoice || _isListening) {
      return;
    }

    setState(() {
      _recognizedText = '';
    });

    await _voiceService.startListening(
      onResult: (text) {
        if (!mounted) return;

        setState(() {
          _recognizedText = text;
        });
      },
      onListeningChanged: (listening) {
        if (!mounted) return;

        setState(() {
          _isListening = listening;
        });
      },
    );
  }

  Future<void> _stopVoice() async {
    await _voiceService.stopListening(
      onListeningChanged: (listening) {
        if (!mounted) return;

        setState(() {
          _isListening = listening;
        });
      },
    );

    if (_recognizedText.trim().isEmpty) {
      return;
    }

    await _processVoiceQuestion(_recognizedText.trim());
  }

  Future<void> _processVoiceQuestion(String question) async {
    setState(() {
      _isProcessingVoice = true;
    });

    try {
      final answer = await GroqService.sendMessage([
        {'role': 'user', 'content': question},
      ]);

      if (!mounted) return;

      await _voiceService.speak(answer);

      if (!mounted) return;

      setState(() {
        _isProcessingVoice = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessingVoice = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Voice error: $e')));
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: YusssyColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: YusssyColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/yusssy_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yusssy',
                        style: TextStyle(
                          color: YusssyColors.burgundy,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Learn. Explore. Create.',
                        style: TextStyle(
                          color: YusssyColors.mutedInk,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: YusssyColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: YusssyColors.border),
                  ),
                  child: IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile — coming soon.')),
                      );
                    },
                    tooltip: 'Profile',
                    icon: const Icon(
                      Icons.person_outline_rounded,
                      color: YusssyColors.ink,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 34),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 25),
              decoration: BoxDecoration(
                color: YusssyColors.burgundy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A quieter way to learn.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Ask questions, explore your study material, '
                    'and turn information into understanding.',
                    style: TextStyle(
                      color: Color(0xFFE8DDE3),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  SizedBox(height: 19),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: Color(0xFFD9BFCF),
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Your personal learning space',
                        style: TextStyle(
                          color: Color(0xFFE8DDE3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 31),

            const Text(
              'Explore',
              style: TextStyle(
                color: YusssyColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Choose how you want to learn today.',
              style: TextStyle(color: YusssyColors.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 17),

            _FeatureCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat',
              subtitle: 'Ask questions and explore ideas with Yusssy.',
              onTap: widget.onOpenChat,
            ),

            const SizedBox(height: 11),

            _FeatureCard(
              icon: Icons.menu_book_outlined,
              title: 'My Documents',
              subtitle: 'Upload PDFs and ask questions using your documents.',
              onTap: widget.onOpenDocuments,
            ),

            const SizedBox(height: 11),

            _FeatureCard(
              icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              title: _isListening ? 'Listening...' : 'Voice Assistant',
              subtitle: _isProcessingVoice
                  ? 'Yusssy is preparing your answer...'
                  : 'Talk naturally and learn hands-free.',
              onTap: _isListening ? _stopVoice : _startVoice,
              iconColor: _isListening
                  ? YusssyColors.danger
                  : YusssyColors.burgundy,
            ),

            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: YusssyColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: YusssyColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mic_none_rounded,
                      color: YusssyColors.burgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        _recognizedText,
                        style: const TextStyle(
                          color: YusssyColors.ink,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: YusssyColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: YusssyColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: YusssyColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: YusssyColors.burgundy,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A little suggestion',
                          style: TextStyle(
                            color: YusssyColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Upload your study material and ask focused '
                          'questions. Yusssy can search your documents '
                          'for the information you need.',
                          style: TextStyle(
                            color: YusssyColors.mutedInk,
                            height: 1.45,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// FEATURE CARD
// ======================================================

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? YusssyColors.burgundy;

    return Material(
      color: YusssyColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: YusssyColors.burgundy.withValues(alpha: 0.06),
        highlightColor: YusssyColors.burgundy.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: YusssyColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: YusssyColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: YusssyColors.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: YusssyColors.mutedInk,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: YusssyColors.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// CHAT SCREEN
// ======================================================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [greetingMessage()];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    chatClearNotifier.addListener(_handleChatClear);
    _loadSavedChat();
  }

  void _handleChatClear() {
    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..add(greetingMessage());
    });

    _scrollToBottom();
  }

  Future<void> _loadSavedChat() async {
    final savedMessages = await StorageService.loadChat();

    if (!mounted) return;

    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(savedMessages);
      });

      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});

      _messageController.clear();
      _isLoading = true;
    });

    await StorageService.saveChat(_messages);

    _scrollToBottom();

    try {
      final response = await GroqService.sendMessage(_messages);

      if (!mounted) return;

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});

        _isLoading = false;
      });

      await StorageService.saveChat(_messages);

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      // Roll back the unanswered user message and restore it to the
      // input field so nothing is silently lost on failure.
      setState(() {
        _isLoading = false;
        _messages.removeLast();
        _messageController.text = text;
      });

      await StorageService.saveChat(_messages);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }

  Future<void> _clearChat() async {
    await StorageService.clearChat();

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..add(greetingMessage());
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Chat history cleared.')));
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

  @override
  void dispose() {
    chatClearNotifier.removeListener(_handleChatClear);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: YusssyColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: YusssyColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/yusssy_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yusssy',
                  style: TextStyle(
                    color: YusssyColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Your learning space',
                  style: TextStyle(
                    color: YusssyColors.mutedInk,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _isLoading ? null : _clearChat,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: YusssyColors.mutedInk,
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation',
                      style: TextStyle(color: YusssyColors.mutedInk),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isUser)
                              Container(
                                width: 31,
                                height: 31,
                                margin: const EdgeInsets.only(right: 8, top: 2),
                                decoration: BoxDecoration(
                                  color: YusssyColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: YusssyColors.border,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Image.asset(
                                      'assets/images/yusssy_logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? YusssyColors.burgundy
                                      : YusssyColors.surface,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(17),
                                    topRight: const Radius.circular(17),
                                    bottomLeft: Radius.circular(
                                      isUser ? 17 : 5,
                                    ),
                                    bottomRight: Radius.circular(
                                      isUser ? 5 : 17,
                                    ),
                                  ),
                                  border: isUser
                                      ? null
                                      : Border.all(color: YusssyColors.border),
                                ),
                                child: Text(
                                  message['content'] ?? '',
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : YusssyColors.ink,
                                    fontSize: 14.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: YusssyColors.burgundy,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Yusssy is thinking...',
                    style: TextStyle(
                      color: YusssyColors.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 7, 13, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask Yusssy anything...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      style: FilledButton.styleFrom(
                        backgroundColor: YusssyColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SETTINGS
// ======================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearChat(BuildContext context) async {
    await StorageService.clearChat();

    // Reset the live ChatScreen (kept alive by IndexedStack) so it doesn't
    // keep showing messages that were just wiped from storage.
    chatClearNotifier.value++;

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Chat history cleared.')));
  }

  Future<void> _clearEverything(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: YusssyColors.surface,
          title: const Text(
            'Clear saved data?',
            style: TextStyle(
              color: YusssyColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This will remove saved chat conversations '
            'from this device.',
            style: TextStyle(color: YusssyColors.mutedInk, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: YusssyColors.mutedInk),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: YusssyColors.burgundy,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    await StorageService.clearEverything();

    // Same reset as above — keeps the live ChatScreen in sync with storage.
    chatClearNotifier.value++;

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved chat data cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: YusssyColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: YusssyColors.burgundy,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 61,
                  height: 61,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: YusssyColors.surface,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/yusssy_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yusssy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Learn. Explore. Create.',
                        style: TextStyle(
                          color: Color(0xFFE8DDE3),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          const _SectionTitle(title: 'Data & Storage'),

          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Clear Chat History',
            subtitle: 'Remove normal AI conversations',
            onTap: () => _clearChat(context),
          ),

          const SizedBox(height: 9),

          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Saved Data',
            subtitle: 'Remove locally saved conversations',
            onTap: () => _clearEverything(context),
          ),

          const SizedBox(height: 28),

          const _SectionTitle(title: 'About Yusssy'),

          const SizedBox(height: 10),

          const _SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Yusssy',
            subtitle: 'Your personal AI learning companion',
          ),

          const SizedBox(height: 9),

          const _SettingsTile(
            icon: Icons.code_rounded,
            title: 'Technology',
            subtitle: 'Flutter • FastAPI • Groq • RAG',
          ),

          const SizedBox(height: 9),

          const _SettingsTile(
            icon: Icons.layers_outlined,
            title: 'Features',
            subtitle: 'AI Chat • PDF RAG • Voice • Local History',
          ),

          const SizedBox(height: 34),

          const Center(
            child: Column(
              children: [
                Text(
                  'Yusssy',
                  style: TextStyle(
                    color: YusssyColors.burgundy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Learn. Explore. Create.',
                  style: TextStyle(
                    color: YusssyColors.mutedInk,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SETTINGS SECTION TITLE
// ======================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: YusssyColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ======================================================
// SETTINGS TILE
// ======================================================

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YusssyColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: YusssyColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: YusssyColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: YusssyColors.burgundy, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: YusssyColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: YusssyColors.mutedInk,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: YusssyColors.mutedInk,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
