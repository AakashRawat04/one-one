# One One

Android-first Flutter + LiveKit walkie-talkie app for a small private friend group.

The implementation follows:

- `requirements/flutter-livekit-erd.md`
- `requirements/flutter-livekit-tech-plan.md`
- `requirements/flutter-livekit-agent-phase-prompts.md`

## Repo Structure

```txt
app/          Flutter Android client
backend/      Node/TypeScript token and notification API
requirements/ Planning docs and implementation handoffs
```

## Flutter App

```sh
cd app
flutter pub get
flutter run
```

Current state: Phase 0 scaffold only. Product features start after the background-audio spike.

## Backend

```sh
cd backend
cp .env.example .env
npm install
npm run dev
```

Health check:

```sh
curl http://localhost:8080/healthz
```

## Implementation Order

Follow the phases in `requirements/flutter-livekit-agent-phase-prompts.md`. Phase 1 must validate Android foreground service + LiveKit receive behavior before full product features are built.
