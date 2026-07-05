# Phase 2 Handoff: Backend Foundation

## Status

Code generated. Manual dependency install/build verification is pending.

## Implemented

- Firebase Admin lazy initialization.
- Firebase ID token verification middleware.
- Firebase Realtime Database accessor.
- Firebase Cloud Messaging multicast utility.
- LiveKit access-token utility using `livekit-server-sdk`.
- `/healthz` liveness endpoint.
- `/readyz` readiness endpoint showing Firebase/LiveKit configuration status.
- Central HTTP error handling.
- Dockerfile and backend docker-compose service.

## Files Added Or Changed

- `backend/package.json`
- `backend/.env.example`
- `backend/README.md`
- `backend/Dockerfile`
- `backend/docker-compose.yml`
- `backend/src/config.ts`
- `backend/src/app.ts`
- `backend/src/firebase/adminApp.ts`
- `backend/src/firebase/auth.ts`
- `backend/src/firebase/database.ts`
- `backend/src/firebase/messaging.ts`
- `backend/src/http/asyncHandler.ts`
- `backend/src/http/httpError.ts`
- `backend/src/livekit/tokens.ts`
- `backend/src/routes/healthRoutes.ts`
- `backend/src/services/readiness.ts`

## Manual Checks

From `backend/`:

```sh
eval "$(fnm env --shell zsh)"
fnm use 20.19.4
npm install
npm run build
npm start
```

In another terminal:

```sh
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

## Notes

- `package-lock.json` is not updated in this handoff because runtime commands were intentionally not executed.
- Product endpoints for groups, token issuance with membership validation, nudges, and friend-live notifications are not exposed yet.
- LiveKit secrets stay only in backend env.
- Firebase Admin credentials stay only in backend env.

## Next Phase

Phase 3 app identity/device setup has been generated after this phase.
