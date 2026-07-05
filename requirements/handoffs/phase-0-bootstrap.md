# Phase 0 Handoff: Repo Bootstrap

## Status

Complete.

## Directories Created

- Flutter app: `app/`
- Backend API: `backend/`
- Handoffs: `requirements/handoffs/`

## Commands

Flutter dependency install:

```sh
cd app
flutter pub get
```

Flutter local run:

```sh
cd app
flutter run
```

Backend dependency install:

```sh
cd backend
npm install
```

Backend dev server:

```sh
cd backend
npm run dev
```

Backend health check:

```sh
curl http://localhost:8080/healthz
```

## Verification

- `cd app && flutter pub get`: passed.
- `cd app && flutter analyze`: passed, no issues found.
- `cd app && flutter test`: passed, generated widget smoke test succeeds.
- `cd backend && npm install`: passed using `fnm` Node 20.19.4, 0 vulnerabilities reported.
- `cd backend && npm run build`: passed.
- `cd backend && npm start`: passed; compiled server listened on port 8080.
- `curl http://localhost:8080/healthz`: returned `{"ok":true,"service":"one-one-token-api"}`.

## Known Issues

- Flutter reported the local Java version as newer than the known Gradle compatibility range: Java 26.0.1 with Gradle 8.14. If Android builds fail, configure Flutter to use JDK 17-24 or upgrade the Gradle wrapper to a compatible version.
- The machine has a broken Homebrew Node 25 binary at `/opt/homebrew/bin/node`. Backend verification succeeded by running `eval "$(fnm env --shell zsh)" && fnm use 20.19.4` before npm commands.
- No real Firebase or LiveKit secrets are configured.
- Product features are intentionally not implemented in Phase 0.

## Next Phase

Phase 1 can start after verification: background audio spike with LiveKit receive behavior and Android foreground service.
