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
import { createSubscriptionRoutes } from "./routes/subscriptionRoutes.js";

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
  app.use(createSubscriptionRoutes());

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

      if (
        typeof error === "object" &&
        error !== null &&
        "status" in error &&
        error.status === 413
      ) {
        response.status(413).json({
          error: "request_too_large",
          message: "Request body exceeds the allowed size."
        });
        return;
      }

      logger.error({ error: serializeError(error) }, "unhandled request error");
      response.status(500).json({
        error: "internal_server_error"
      });
    }
  );

  return app;
}

function serializeError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack
    };
  }

  if (typeof error === "object" && error !== null) {
    const record = error as Record<string, unknown>;
    return {
      name: record.name,
      message: record.message,
      code: record.code,
      stack: record.stack,
      value: record
    };
  }

  return {
    message: String(error),
    value: error
  };
}
