# One One Token API

Node/TypeScript backend for the Flutter + LiveKit walkie-talkie app.

Phase 0 includes only the backend scaffold and a health endpoint. LiveKit token generation, Firebase Admin verification, FCM sends, group APIs, and nudge APIs are implemented in later phases.

Phase 2 adds Firebase Admin, LiveKit token, FCM utility, readiness, and Docker scaffolding.
Phase 4/5 add group/invite APIs and the authenticated LiveKit token endpoint.
Phase 6/7 add friend-live/nudge notification endpoints. Push-to-talk locking is currently client/Firebase-owned.

## Run Locally

Use Node 20-24. If this machine routes `npm` through a broken Homebrew Node install, initialize `fnm` first:

```sh
eval "$(fnm env --shell zsh)"
fnm use 20.19.4
```

```sh
cp .env.example .env
npm install
npm run dev
```

Health check:

```sh
curl http://localhost:8080/healthz
```

Readiness check:

```sh
curl http://localhost:8080/readyz
```

## Current API Surface

All `/v1/*` endpoints require:

```txt
Authorization: Bearer <Firebase ID token>
```

Endpoints:

```txt
POST /v1/groups
POST /v1/groups/:groupId/invites
POST /v1/invites/join
POST /v1/livekit/token
POST /v1/groups/:groupId/notifications/friend-live
POST /v1/groups/:groupId/nudges
```

## Build

```sh
npm run build
npm start
```

## Docker

```sh
cp .env.example .env
docker compose up --build
```

## Environment

Do not commit real secrets. Keep local values in `.env`; deployment values should come from VM/container secrets.

After Phase 2/4/5 changes, run `npm install` once so `package-lock.json` includes the new backend dependencies.
