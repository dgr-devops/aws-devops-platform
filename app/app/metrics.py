import time

from fastapi import Request
from prometheus_client import Counter, Histogram

REQUESTS = Counter("http_requests_total", "Peticiones HTTP", ["method", "path", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Latencia HTTP", ["method", "path"])


async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        path = route.path if route else "unmatched"
        REQUESTS.labels(request.method, path, str(status)).inc()
        LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
