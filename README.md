# NEO-GENESIS

NEO-GENESIS — Android AI assistant in Jarvis style with Flutter frontend and Firebase backend.

## Архитектура

- Frontend: Flutter + Dart
- Backend: Node.js + Firebase (Firestore, Auth, Cloud Functions)
- ИИ: Groq API (whisper-large-v3, llama-3.2-90b-vision-preview, llama-3.3-70b-specdec)
- CI/CD: GitHub Actions собирает релизный APK

## Структура

- `/lib` — Flutter app UI
- `/android` — Android-specific manifest и AccessibilityService
- `/backend` — Node.js + Firebase Cloud Functions
- `./github/workflows/main.yml` — CI для сборки APK
- `deploy.sh` — скрипт создания репозитория и пуша
