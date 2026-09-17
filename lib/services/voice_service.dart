import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;

  Future<bool> initialize() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
        },
        onError: (error) {
          print('Speech error: $error');
        },
      );

      print('Speech available: $_speechAvailable');

      return _speechAvailable;
    } catch (e) {
      print('Speech initialization error: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool listening) onListeningChanged,
  }) async {
    try {
      if (!_speechAvailable) {
        final available = await initialize();

        if (!available) {
          print('Speech recognition is not available.');
          return;
        }
      }

      onListeningChanged(true);

      await _speech.listen(
        onResult: (result) {
          print('Recognized: ${result.recognizedWords}');

          onResult(result.recognizedWords);

          if (result.finalResult) {
            print('Final speech result received.');
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      print('Start listening error: $e');
      onListeningChanged(false);
    }
  }

  Future<void> stopListening({
    required Function(bool listening) onListeningChanged,
  }) async {
    try {
      await _speech.stop();
    } catch (e) {
      print('Stop listening error: $e');
    }

    onListeningChanged(false);
  }

  Future<void> speak(String text) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
  }
}
