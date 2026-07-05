import { Router } from "express";
import { getReadiness } from "../services/readiness.js";

export function createHealthRoutes() {
  const router = Router();

  router.get("/healthz", (_request, response) => {
    response.status(200).json({
      ok: true,
      service: "one-one-token-api"
    });
  });

  router.get("/readyz", (_request, response) => {
    response.status(200).json(getReadiness());
  });

  return router;
}
