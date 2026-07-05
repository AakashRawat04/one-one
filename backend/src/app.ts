import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { logger } from "./logger.js";

export function createApp() {
  const app = express();

  app.disable("x-powered-by");
  app.use(helmet());
  app.use(express.json({ limit: "64kb" }));
  app.use(
    pinoHttp({
      logger,
      autoLogging: {
        ignore: (request) => request.url === "/healthz"
      }
    })
  );

  app.get("/healthz", (_request, response) => {
    response.status(200).json({
      ok: true,
      service: "one-one-token-api"
    });
  });

  app.use((_request, response) => {
    response.status(404).json({
      error: "not_found"
    });
  });

  return app;
}
