from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import httpx
from core.http.middleware import register_middlewares
from core.metrics import metrics
from fastapi import FastAPI


def _load_health_router():
    router_path = Path(__file__).resolve().parents[1] / "api" / "routers" / "health.py"
    spec = importlib.util.spec_from_file_location("metrics_health_router", router_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load health router from {router_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.router


health_router = _load_health_router()


class MetricsRouterTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        metrics.reset()
        app = FastAPI()
        register_middlewares(app)

        @app.get("/ping")
        async def ping():
            return {"ok": True}

        app.include_router(health_router, prefix="/ling-api")
        self._app = app

    def tearDown(self) -> None:
        metrics.reset()

    async def test_metrics_endpoint_renders_prometheus_snapshot(self) -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self._app),
            base_url="http://testserver",
        ) as client:
            ping_response = await client.get("/ping")
            self.assertEqual(ping_response.status_code, 200)

            response = await client.get("/ling-api/metrics")

        self.assertEqual(response.status_code, 200)
        self.assertIn(
            'ling_http_requests_total{method="GET",path="/ping",status="200"} 1.0',
            response.text,
        )
        self.assertIn(
            'ling_http_request_duration_ms_count{method="GET",path="/ping",status="200"} 1.0',
            response.text,
        )
        self.assertIn("ling_http_inflight_requests 0.0", response.text)
        self.assertIn("# TYPE ling_process_cpu_seconds_total counter", response.text)
        self.assertIn("# TYPE ling_process_resident_memory_bytes gauge", response.text)
        self.assertNotIn("ling_http_requests_total 1.0", response.text)
        self.assertNotIn("ling_http_requests_total 2.0", response.text)


if __name__ == "__main__":
    unittest.main()
