from __future__ import annotations

import ast
import unittest
from pathlib import Path


class BackendArchitectureGuardrailTests(unittest.TestCase):
    def test_infra_package_init_does_not_reexport_helpers(self) -> None:
        source_path = (
            Path(__file__).resolve().parents[1] / "core" / "infra" / "__init__.py"
        )
        module = ast.parse(source_path.read_text(encoding="utf-8"))

        reexports: list[str] = []
        for node in module.body:
            if isinstance(node, ast.ImportFrom) and (node.module or "").startswith(
                "core.infra."
            ):
                reexports.append(node.module or "")
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        reexports.append("__all__")

        self.assertEqual(
            reexports,
            [],
            "core.infra.__init__ should not expose helper methods; import from "
            "the owning internal module instead.",
        )

    def test_backend_callers_import_infra_helpers_from_internal_modules(self) -> None:
        app_root = Path(__file__).resolve().parents[1]
        violations: list[str] = []

        for source_path in app_root.rglob("*.py"):
            if source_path == app_root / "core" / "infra" / "__init__.py":
                continue
            module = ast.parse(source_path.read_text(encoding="utf-8"))
            for node in ast.walk(module):
                if isinstance(node, ast.ImportFrom) and node.module == "core.infra":
                    relative = source_path.relative_to(app_root)
                    violations.append(f"{relative}:{node.lineno}")

        self.assertEqual(
            violations,
            [],
            "Import infra helpers from core.infra.<module>, not core.infra.",
        )

    def test_session_manager_connection_init_does_not_run_schema_mutations(self) -> None:
        source_path = Path(__file__).resolve().parents[1] / "core" / "infra" / "db.py"
        module = ast.parse(source_path.read_text(encoding="utf-8"))

        init_conn: ast.AsyncFunctionDef | None = None
        for node in module.body:
            if not isinstance(node, ast.ClassDef) or node.name != "SessionManager":
                continue
            for child in node.body:
                if isinstance(child, ast.AsyncFunctionDef) and child.name == "init_conn":
                    init_conn = child
                    break

        self.assertIsNotNone(init_conn, "SessionManager.init_conn should exist")
        assert init_conn is not None

        forbidden_calls = {
            "create_all",
            "sync_database_schema",
        }
        seen_calls: set[str] = set()

        for node in ast.walk(init_conn):
            if isinstance(node, ast.Call):
                func = node.func
                if isinstance(func, ast.Name) and func.id in forbidden_calls:
                    seen_calls.add(func.id)
                if isinstance(func, ast.Attribute):
                    if func.attr == "run_sync":
                        seen_calls.add("run_sync")
                    if func.attr in forbidden_calls:
                        seen_calls.add(func.attr)

        self.assertEqual(
            seen_calls,
            set(),
            "Database connection initialization should not perform schema mutation. "
            f"Violations: {sorted(seen_calls)}",
        )

    def test_infra_resource_startup_runs_explicit_schema_initialization(self) -> None:
        source_path = Path(__file__).resolve().parents[1] / "lifecycle.py"
        module = ast.parse(source_path.read_text(encoding="utf-8"))

        initialize_infra_resources: ast.AsyncFunctionDef | None = None
        for node in module.body:
            if isinstance(node, ast.AsyncFunctionDef) and node.name == "initialize_infra_resources":
                initialize_infra_resources = node
                break

        self.assertIsNotNone(
            initialize_infra_resources,
            "initialize_infra_resources should exist",
        )
        assert initialize_infra_resources is not None

        seen_initialize_schema = False
        for node in ast.walk(initialize_infra_resources):
            if not isinstance(node, ast.Call):
                continue
            func = node.func
            if isinstance(func, ast.Attribute) and func.attr == "initialize_schema":
                seen_initialize_schema = True
                break

        self.assertTrue(
            seen_initialize_schema,
            "Infrastructure startup should explicitly initialize database schema.",
        )

    def test_legacy_watch_domain_is_not_reintroduced_as_public_surface(self) -> None:
        app_root = Path(__file__).resolve().parents[1]
        self.assertFalse(
            (app_root / "api" / "mcp_tools" / "watch.py").exists(),
            "Legacy watch MCP tools should stay folded into task_* tools.",
        )
        self.assertFalse(
            (app_root / "api" / "routers" / "watches.py").exists(),
            "Legacy watch routes should stay folded into /tasks.",
        )

        mcp_source = (app_root / "api" / "mcp.py").read_text(encoding="utf-8")
        self.assertNotIn(
            '"watch_',
            mcp_source,
            "MCP exports should expose task_* tools, not legacy watch_* tools.",
        )


if __name__ == "__main__":
    unittest.main()
