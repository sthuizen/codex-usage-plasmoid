import importlib.util
import os
import pathlib
import unittest
from unittest import mock
from types import SimpleNamespace


HELPER = pathlib.Path(__file__).parents[1] / "bridge/fetch_usage.py"
SPEC = importlib.util.spec_from_file_location("fetch_usage", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FetchUsageTests(unittest.TestCase):
    def test_missing_or_invalid_percent_stays_unknown(self):
        for value in [None, 'bad', float('nan'), float('inf')]:
            self.assertIsNone(MODULE.remaining({'usedPercent': value})['remainingPercent'])
        self.assertIsNone(MODULE.remaining({'windowDurationMins': 300})['remainingPercent'])

    def test_failed_initialization_reaps_process(self):
        process = mock.Mock()
        process.poll.return_value = None
        with mock.patch.object(MODULE.subprocess, 'Popen', return_value=process):
            server = MODULE.AppServer('fake-codex')
        with mock.patch.object(server, 'wait_for_id', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                server.__enter__()
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=2)
        process.stdin.close.assert_called_once()
        process.stdout.close.assert_called_once()

    def test_account_auth_states(self):
        server = mock.Mock()
        for account, state in [(None, 'auth_required'), ({'type': 'apiKey'}, 'unsupported_auth'), ({'type': 'chatgpt'}, 'authenticated')]:
            server.request.return_value = {'account': account}
            self.assertEqual(MODULE.account_state(server)['state'], state)

    def test_multiple_messages_in_one_pipe_write(self):
        read_fd, write_fd = os.pipe()
        try:
            with os.fdopen(read_fd, "r") as stream:
                server = MODULE.AppServer.__new__(MODULE.AppServer)
                server.process = SimpleNamespace(stdout=stream)
                server.timeout_seconds = 0.1
                server._read_buffer = b""
                os.write(write_fd, b'{"method":"notification"}\n{"id":1,"result":{}}\n')
                self.assertEqual(server.read_message()["method"], "notification")
                self.assertEqual(server.read_message()["id"], 1)
        finally:
            os.close(write_fd)

    def test_partial_message_times_out_then_can_complete(self):
        read_fd, write_fd = os.pipe()
        try:
            with os.fdopen(read_fd, "r") as stream:
                server = MODULE.AppServer.__new__(MODULE.AppServer)
                server.process = SimpleNamespace(stdout=stream)
                server.timeout_seconds = 0.01
                server._read_buffer = b""
                os.write(write_fd, b'{"id":')
                with self.assertRaises(TimeoutError):
                    server.read_message()
                os.write(write_fd, b'2}\n')
                self.assertEqual(server.read_message(), {"id": 2})
        finally:
            os.close(write_fd)

    def test_closed_pipe_reports_error(self):
        read_fd, write_fd = os.pipe()
        os.close(write_fd)
        with os.fdopen(read_fd, "r") as stream:
            server = MODULE.AppServer.__new__(MODULE.AppServer)
            server.process = SimpleNamespace(stdout=stream)
            server.timeout_seconds = 0.01
            server._read_buffer = b""
            with self.assertRaises(MODULE.BridgeError):
                server.read_message()

    def test_remaining_is_clamped(self):
        self.assertEqual(MODULE.remaining({"usedPercent": -10})["remainingPercent"], 100)
        self.assertEqual(MODULE.remaining({"usedPercent": 40.5})["remainingPercent"], 60)
        self.assertEqual(MODULE.remaining({"usedPercent": 120})["remainingPercent"], 0)

    def test_normalise_limits(self):
        payload = {
            "rateLimits": {
                "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 123},
                "secondary": {"usedPercent": 60, "windowDurationMins": 10080, "resetsAt": 456},
                "credits": {"hasCredits": True, "unlimited": False, "balance": "12.50"},
            }
        }
        result = MODULE.normalise_limits(payload)
        self.assertEqual([window["remainingPercent"] for window in result["windows"]], [75, 40])
        self.assertEqual(result["windows"][0]["windowDurationMins"], 300)
        self.assertEqual(result["credits"]["balance"], "12.50")

    def test_multi_bucket_limits_are_flattened_without_legacy_duplicates(self):
        payload = {
            "rateLimits": {
                "limitId": "legacy",
                "primary": {"usedPercent": 99, "windowDurationMins": 60},
            },
            "rateLimitsByLimitId": {
                "codex": {
                    "limitId": "codex",
                    "primary": {"usedPercent": 10, "windowDurationMins": 180},
                    "secondary": {"usedPercent": 20, "windowDurationMins": 20160},
                },
                "special": {
                    "limitId": "special",
                    "limitName": "Special models",
                    "primary": {"usedPercent": 30, "windowDurationMins": 1440},
                },
            },
        }
        result = MODULE.normalise_limits(payload)
        self.assertEqual(len(result["windows"]), 3)
        self.assertEqual(
            [window["windowDurationMins"] for window in result["windows"]],
            [180, 20160, 1440],
        )
        self.assertEqual(result["windows"][2]["limitName"], "Special models")

    def test_single_or_no_window_is_valid(self):
        one = MODULE.normalise_limits(
            {"rateLimits": {"primary": {"usedPercent": 12, "windowDurationMins": 60}}}
        )
        self.assertEqual(len(one["windows"]), 1)
        self.assertEqual(one["windows"][0]["remainingPercent"], 88)

        none = MODULE.normalise_limits({})
        self.assertEqual(none["windows"], [])
        self.assertEqual(none["state"], "ready")

    def test_auth_url_validation(self):
        self.assertEqual(
            MODULE.safe_auth_url("https://chatgpt.com/auth/login"),
            "https://chatgpt.com/auth/login",
        )
        with self.assertRaises(MODULE.BridgeError):
            MODULE.safe_auth_url("https://example.com/steal")


if __name__ == "__main__":
    unittest.main()
