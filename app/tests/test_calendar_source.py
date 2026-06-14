import unittest

from services.calendar_domain.source import event_source, normalize_source, provider_for_source


class CalendarSourceTests(unittest.TestCase):
    def test_event_source_defaults_unknown_values_to_ling(self) -> None:
        event = type("Event", (), {"source": None})()
        self.assertEqual(event_source(event), "ling")

        event.source = "unknown"
        self.assertEqual(event_source(event), "ling")

        self.assertEqual(normalize_source("unknown"), "ling")

    def test_event_source_preserves_external_sources(self) -> None:
        event = type("Event", (), {"source": " APPLE "})()
        self.assertEqual(event_source(event), "apple")

    def test_normalize_source_preserves_supported_sources(self) -> None:
        self.assertEqual(normalize_source(" FEISHU "), "feishu")
        self.assertEqual(normalize_source("DINGTALK"), "dingtalk")
        self.assertEqual(normalize_source("apple"), "apple")

    def test_provider_for_source_maps_known_providers(self) -> None:
        self.assertEqual(provider_for_source(" APPLE "), "apple_local")
        self.assertEqual(provider_for_source("FEISHU"), "feishu")
        self.assertEqual(provider_for_source(" dingtalk "), "dingtalk")
        self.assertEqual(provider_for_source("unknown"), "ling")
