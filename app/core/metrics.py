"""Lightweight in-process metrics registry."""

from __future__ import annotations

import os
import sys
import time
from collections import defaultdict
from collections.abc import Mapping
from threading import Lock
from typing import TypeAlias

MetricLabels: TypeAlias = tuple[tuple[str, str], ...]
MetricKey: TypeAlias = tuple[str, MetricLabels]


def _normalize_labels(labels: Mapping[str, object] | None) -> MetricLabels:
    if not labels:
        return ()
    return tuple(sorted((str(key), str(value)) for key, value in labels.items()))


def _escape_label_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def _format_sample_name(name: str, labels: MetricLabels) -> str:
    if not labels:
        return name
    label_text = ",".join(f'{key}="{_escape_label_value(value)}"' for key, value in labels)
    return f"{name}{{{label_text}}}"


def _read_process_memory_bytes() -> tuple[int | None, int | None]:
    try:
        with open("/proc/self/statm", encoding="utf-8") as statm:
            size_pages, rss_pages, *_ = statm.read().split()
        page_size = os.sysconf("SC_PAGE_SIZE")
        return int(rss_pages) * page_size, int(size_pages) * page_size
    except (FileNotFoundError, OSError, ValueError):
        pass

    try:
        import resource

        rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    except (ImportError, OSError):
        return None, None

    if sys.platform != "darwin":
        rss *= 1024
    return int(rss), None


class MetricsRegistry:
    def __init__(self) -> None:
        self._lock = Lock()
        self._counters: dict[MetricKey, float] = defaultdict(float)
        self._gauges: dict[MetricKey, float] = {}
        self._observations: dict[MetricKey, dict[str, float]] = {}
        self._process_started_at = time.time()
        self._last_cpu_wall_time = self._process_started_at
        self._last_cpu_time = time.process_time()

    def reset(self) -> None:
        with self._lock:
            self._counters.clear()
            self._gauges.clear()
            self._observations.clear()
            self._process_started_at = time.time()
            self._last_cpu_wall_time = self._process_started_at
            self._last_cpu_time = time.process_time()

    def inc_counter(
        self,
        name: str,
        amount: float = 1.0,
        labels: Mapping[str, object] | None = None,
    ) -> None:
        with self._lock:
            self._counters[(name, _normalize_labels(labels))] += amount

    def set_gauge(
        self,
        name: str,
        value: float,
        labels: Mapping[str, object] | None = None,
    ) -> None:
        with self._lock:
            self._gauges[(name, _normalize_labels(labels))] = value

    def inc_gauge(
        self,
        name: str,
        amount: float = 1.0,
        labels: Mapping[str, object] | None = None,
    ) -> None:
        with self._lock:
            key = (name, _normalize_labels(labels))
            self._gauges[key] = self._gauges.get(key, 0.0) + amount

    def dec_gauge(
        self,
        name: str,
        amount: float = 1.0,
        labels: Mapping[str, object] | None = None,
    ) -> None:
        with self._lock:
            key = (name, _normalize_labels(labels))
            self._gauges[key] = self._gauges.get(key, 0.0) - amount

    def observe(
        self,
        name: str,
        value: float,
        labels: Mapping[str, object] | None = None,
    ) -> None:
        with self._lock:
            bucket = self._observations.setdefault(
                (name, _normalize_labels(labels)),
                {"count": 0.0, "sum": 0.0, "max": 0.0},
            )
            bucket["count"] += 1.0
            bucket["sum"] += value
            bucket["max"] = max(bucket["max"], value)

    def _collect_process_metrics(self) -> tuple[dict[MetricKey, float], dict[MetricKey, float]]:
        now = time.time()
        cpu_time = time.process_time()
        elapsed_wall = max(now - self._last_cpu_wall_time, 0.0)
        elapsed_cpu = max(cpu_time - self._last_cpu_time, 0.0)
        cpu_percent = (elapsed_cpu / elapsed_wall * 100.0) if elapsed_wall > 0 else 0.0
        self._last_cpu_wall_time = now
        self._last_cpu_time = cpu_time

        counters: dict[MetricKey, float] = {
            ("ling_process_cpu_seconds_total", ()): cpu_time,
        }
        gauges: dict[MetricKey, float] = {
            ("ling_process_cpu_percent", ()): cpu_percent,
            ("ling_process_start_time_seconds", ()): self._process_started_at,
        }
        rss_bytes, virtual_bytes = _read_process_memory_bytes()
        if rss_bytes is not None:
            gauges[("ling_process_resident_memory_bytes", ())] = float(rss_bytes)
        if virtual_bytes is not None:
            gauges[("ling_process_virtual_memory_bytes", ())] = float(virtual_bytes)
        return counters, gauges

    def render_prometheus(self) -> str:
        with self._lock:
            process_counters, process_gauges = self._collect_process_metrics()
            counters = {**self._counters, **process_counters}
            gauges = {**self._gauges, **process_gauges}
            observations = {
                key: dict(value)
                for key, value in self._observations.items()
            }

        lines: list[str] = []
        rendered_types: set[tuple[str, str]] = set()
        for (name, labels), value in sorted(counters.items()):
            if (name, "counter") not in rendered_types:
                lines.append(f"# TYPE {name} counter")
                rendered_types.add((name, "counter"))
            lines.append(f"{_format_sample_name(name, labels)} {value}")
        for (name, labels), value in sorted(gauges.items()):
            if (name, "gauge") not in rendered_types:
                lines.append(f"# TYPE {name} gauge")
                rendered_types.add((name, "gauge"))
            lines.append(f"{_format_sample_name(name, labels)} {value}")
        for (name, labels), value in sorted(observations.items()):
            if (name, "summary") not in rendered_types:
                lines.append(f"# TYPE {name} summary")
                rendered_types.add((name, "summary"))
            lines.append(f"{_format_sample_name(f'{name}_count', labels)} {value['count']}")
            lines.append(f"{_format_sample_name(f'{name}_sum', labels)} {value['sum']}")
            lines.append(f"{_format_sample_name(f'{name}_max', labels)} {value['max']}")
        return "\n".join(lines) + "\n"


metrics = MetricsRegistry()
