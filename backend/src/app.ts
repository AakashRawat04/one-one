import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { ZodError } from "zod";
import { isHttpError } from "./http/httpError.js";
import { logger } from "./logger.js";
import { createGroupRoutes } from "./routes/groupRoutes.js";
import { createHealthRoutes } from "./routes/healthRoutes.js";
import { createLiveKitRoutes } from "./routes/liveKitRoutes.js";
import { createNotificationRoutes } from "./routes/notificationRoutes.js";

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

  app.use(createHealthRoutes());
  app.use(createGroupRoutes());
  app.use(createLiveKitRoutes());
  app.use(createNotificationRoutes());

  app.use((_request, response) => {
    response.status(404).json({
      error: "not_found"
    });
  });

  app.use(
    (
      error: unknown,
      _request: express.Request,
      response: express.Response,
      _next: express.NextFunction
    ) => {
      if (isHttpError(error)) {
        response.status(error.statusCode).json({
          error: error.code,
          message: error.message
        });
        return;
      }

      if (error instanceof ZodError) {
        response.status(400).json({
          error: "validation_failed",
          issues: error.flatten().fieldErrors
        });
        return;
      }

      logger.error({ error }, "unhandled request error");
      response.status(500).json({
        error: "internal_server_error"
      });
    }
  );

  return app;
}
