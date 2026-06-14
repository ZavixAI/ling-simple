from __future__ import annotations

import unittest

from core.http.context import (
    background_request_context,
    clear_request_context,
    get_request_context,
    get_request_id,
    set_request_context,
)


class RequestContextTests(unittest.TestCase):
    def tearDown(self) -> None:
        clear_request_context()

    def test_background_request_context_sets_and_restores_request_id(self) -> None:
        set_request_context("outer123")

        with background_request_context("scheduled-task") as request_id:
            self.assertEqual(get_request_id(), request_id)
            self.assertEqual(len(request_id), 12)
            self.assertEqual(get_request_context()["task_name"], "scheduled-task")

        self.assertEqual(get_request_id(), "outer123")

    def test_request_id_defaults_to_background_without_context(self) -> None:
        clear_request_context()

        self.assertEqual(get_request_id(), "background")


if __name__ == "__main__":
    unittest.main()
