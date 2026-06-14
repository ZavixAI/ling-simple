from __future__ import annotations

import logging
import os
import tempfile
import unittest
from unittest.mock import patch

from config.settings import init_app_config
from utils.logging import init_logging


class LoggingConfigTests(unittest.TestCase):
    def test_init_logging_quiets_apscheduler_executor_success_logs(self) -> None:
        original_level = logging.getLogger("apscheduler.executors").level

        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.dict(os.environ, {"LING_LOGS_DIR": tmpdir}, clear=True):
                init_app_config()
                init_logging()

        try:
            self.assertEqual(
                logging.getLogger("apscheduler.executors").level,
                logging.WARNING,
            )
        finally:
            logging.getLogger("apscheduler.executors").setLevel(original_level)


if __name__ == "__main__":
    unittest.main()
