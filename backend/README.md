# One One Token API

Node/TypeScript backend for the Flutter + LiveKit walkie-talkie app.

Phase 0 includes only the backend scaffold and a health endpoint. LiveKit token generation, Firebase Admin verification, FCM sends, group APIs, and nudge APIs are implemented in later phases.

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

## Build

```sh
npm run build
npm start
```

## Environment

Do not commit real secrets. Keep local values in `.env`; deployment values should come from VM/container secrets.
