import { createServer } from "node:http";
import { createApp } from "./app.js";
import { config } from "./config.js";
import { logger } from "./logger.js";

const app = createApp();
const server = createServer(app);

server.listen(config.PORT, () => {
  logger.info({ port: config.PORT }, "token api listening");
});

function shutdown(signal: NodeJS.Signals) {
  logger.info({ signal }, "shutting down token api");
  server.close((error) => {
    if (error) {
      logger.error({ error }, "failed to close server cleanly");
      process.exit(1);
    }

    process.exit(0);
  });
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
