cat > README.md <<'EOF'
# Yusssy — AI Study Companion

> **Learn. Explore. Create.**

Yusssy is an AI-powered study companion built with **Flutter** and **FastAPI**. It combines conversational AI with document-based learning so students can chat with an AI assistant, upload PDF study material, and ask questions based on their documents.

## ✨ Features

- 🤖 **AI Chat** — Ask questions and have natural conversations with an AI assistant.
- 📚 **PDF Upload** — Upload study material directly from the app.
- 🔎 **RAG-based Document Q&A** — Ask questions about uploaded PDFs and receive answers based on relevant document content.
- 📄 **Multiple PDF Support** — Work with multiple uploaded documents.
- 💬 **Local Chat Persistence** — Chat history is stored locally on the device.
- 🎙️ **Voice Assistant** — Voice input/output support is integrated for future expansion.
- 🎨 **Clean UI/UX** — Minimal, student-focused interface with Yusssy branding.
- 📱 **Android Support** — Tested on both Android Emulator and a physical Android device.

## 🧠 How Yusssy Works

```text
                    ┌─────────────────────┐
                    │   Flutter App       │
                    │      Yusssy         │
                    └──────────┬──────────┘
                               │
                    HTTP Requests / Responses
                               │
                               ▼
                    ┌─────────────────────┐
                    │     FastAPI         │
                    │      Backend        │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
                 ▼                           ▼
        ┌─────────────────┐        ┌─────────────────┐
        │   Groq API      │        │   RAG Pipeline  │
        │   LLM           │        │                 │
        └─────────────────┘        └────────┬────────┘
                                            │
                                   PDF → Text → Chunks
                                            │
                                            ▼
                                   Sentence Embeddings
                                            │
                                            ▼
                                   Similarity Search
                                            │
                                            ▼
                                      Relevant Context
                                            │
                                            ▼
                                      AI-generated Answer
                                      🔍 RAG Pipeline

Yusssy’s document question-answering system uses Retrieval-Augmented Generation (RAG).

The process is:

1. User uploads a PDF.
2. FastAPI extracts the PDF text.
3. The text is divided into smaller chunks.
4. Each chunk is converted into an embedding using all-MiniLM-L6-v2.
5. Embeddings are stored for retrieval.
6. When the user asks a question, relevant chunks are retrieved using similarity search.
7. The retrieved context is sent to the LLM.
8. The AI generates an answer based on the relevant document content.

This allows Yusssy to answer questions using the user’s study material rather than relying only on general model knowledge.

🛠️ Tech Stack

Frontend

* Flutter
* Dart
* Material 3

Backend

* Python
* FastAPI
* Uvicorn

AI

* Groq API
* openai/gpt-oss-120b
* Sentence Transformers
* all-MiniLM-L6-v2

Storage

* Shared Preferences
* Local document metadata
* Vector embeddings

Flutter Packages

* http
* file_picker
* speech_to_text
* flutter_tts
* shared_preferences
* flutter_launcher_icons
* flutter_native_splash

📁 Project Structure
ai_companion/
│
├── android/                 # Android application
├── assets/
│   └── images/
│       └── yusssy_logo.png  # App branding
│
├── backend/
│   ├── main.py              # FastAPI API
│   ├── rag.py               # RAG pipeline
│   ├── documents/           # Local PDF/RAG data (ignored by Git)
│   ├── .env.example         # Environment variable template
│   └── venv/                # Python virtual environment (ignored)
│
├── lib/
│   ├── main.dart            # Main Flutter application
│   ├── screens/
│   │   └── documents_screen.dart
│   └── services/
│       ├── groq_service.dart
│       ├── pdf_service.dart
│       ├── storage_service.dart
│       └── voice_service.dart
│
├── test/
├── pubspec.yaml
└── README.md
🚀 Getting Started

Prerequisites

Make sure you have:

* Flutter SDK
* Dart SDK
* Android Studio / Android SDK
* Python 3
* A Groq API key

1. Clone the repository
git clone https://github.com/yusrashaikh27/yusssy-ai-study-companion.git
cd yusssy-ai-study-companion
2. Set up the backend
cd backend
python3 -m venv venv
source venv/bin/activate
Install dependencies:
pip install fastapi uvicorn httpx python-dotenv sentence-transformers numpy
Create your environment file:
cp .env.example .env
Open .env and add your Groq API key:
GROQ_API_KEY=your_actual_groq_api_key
3. Start the backend
From the backend directory:
python -m uvicorn main:app --host 0.0.0.0 --port 8000
The API will run on:
http://localhost:8000
4. Configure the Flutter app

The Flutter app communicates with the FastAPI backend.

For an Android Emulator, use:
http://10.0.2.2:8000
For a physical Android device, use your computer’s local network IP:
http://YOUR_COMPUTER_IP:8000
Make sure the phone and computer are connected to the same Wi-Fi network.

5. Install Flutter dependencies

From the project root:
flutter pub get
6. Run the app
flutter run
Or specify an Android device:
flutter run -d emulator-5554
🔐 Security

API keys and local user data are intentionally excluded from Git.

The repository ignores:
.env
backend/.env
backend/venv/
backend/documents/
build/
.dart_tool/
Never commit your actual Groq API key.

📱 Android Release

A release APK was successfully built and tested on a physical Android device.

Build using:
flutter build apk --release
The generated APK will be located at:
build/app/outputs/flutter-apk/app-release.apk
🧪 Testing

Run Flutter tests with:
flutter test
Check the project with:
flutter analyze
🔮 Future Improvements

* Cloud document storage
* User authentication
* Streaming AI responses
* Improved voice interaction
* Study progress tracking
* Quiz generation from PDFs
* Flashcard generation
* Deployment of the FastAPI backend
* Production-ready remote database and vector storage

👩‍💻 Author

Yusra Shaikh

Built as a portfolio project to explore:

* Flutter application development
* REST API integration
* Generative AI
* Retrieval-Augmented Generation
* Vector embeddings
* Python backend development

⸻

Yusssy — Learn. Explore. Create.
EOF/