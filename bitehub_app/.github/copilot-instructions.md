Project: Bite Hub Flutter App

Purpose
- Keep AI coding agents oriented around the current Bite Hub mobile app.

Big picture
- Main app path: `bitehub_app/`.
- Backend path: `bitehub_backend_workspace/bitehub_backend_workspace/`.
- Flutter entrypoint: `lib/main.dart`.
- App modules live under `lib/app/`, with `data/`, `presentation/`, and `presentation_v2/` split by responsibility.
- API integration is centralized in `lib/app/data/services/api_service.dart`.

Developer workflows
- Install dependencies: `flutter pub get`.
- Static analysis: `flutter analyze`.
- Tests: `flutter test`.
- Run with a custom backend URL using `BITE_HUB_API_BASE_URL` when needed.

Backend integration
- Default API base URL is `http://127.0.0.1:8000`.
- Main mobile endpoints are under `/api/v2/app/`.
- Live order updates use WebSocket path `/ws/cafe/<cafe_id>/orders/`.

Conventions
- Do not add legacy app or dashboard paths.
- Keep new Flutter work under `bitehub_app/`.
- Keep Django work under `bitehub_backend_workspace/bitehub_backend_workspace/`.
- Assets belong in `bitehub_app/assets/` and must be declared in `pubspec.yaml`.
