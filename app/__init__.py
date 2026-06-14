"""Starter backend application package."""

from __future__ import annotations

import sys
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent

if str(PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(PACKAGE_ROOT))

__version__ = "0.1.0"

__all__ = ["PACKAGE_ROOT", "__version__"]
