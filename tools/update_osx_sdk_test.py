#!/usr/bin/env python3

import json
import tempfile
import unittest
import urllib.error
import urllib.parse
from pathlib import Path
from unittest import mock

import update_osx_sdk


OLD_SDK_URL = (
    "https://swcdn.apple.com/content/downloads/old-release/old-package/"
    "CLTools_macOSNMOS_SDK.pkg"
)
SDK_URL = (
    "https://swcdn.apple.com/content/downloads/new-release/new-package/"
    "CLTools_macOSNMOS_SDK.pkg"
)
TIMESTAMP = "20260817040506"
SNAPSHOT_URL = f"https://web.archive.org/web/{TIMESTAMP}id_/{SDK_URL}"
OLD_SNAPSHOT_URL = f"https://web.archive.org/web/20260430051604id_/{OLD_SDK_URL}"
JOB_ID = "spn2-abc123-def456"
ACCEPT_HEADER = "text/html,application/xhtml+xml,application/xml"
OLD_SHA256 = "0" * 64
NEW_SHA256 = "f" * 64
CDX_HEADER = ["timestamp", "original", "statuscode"]
MODULE_TEXT = (
    "before = True\n"
    "osx.from_archive(\n"
    f'    sha256 = "{OLD_SHA256}",\n'
    '    strip_prefix = "Payload/Library/Developer/CommandLineTools/'
    'SDKs/MacOSX26.5.sdk",\n'
    '    type = "pkg",\n'
    "    urls = [\n"
    f'        "{OLD_SDK_URL}",\n'
    f'        "{OLD_SNAPSHOT_URL}",\n'
    "    ],\n"
    ")\n"
    "after = True\n"
)


def response(payload=None, *, body=None, headers=None):
    result = mock.MagicMock()
    result.__enter__.return_value = result
    result.read.return_value = (
        json.dumps(payload).encode("utf-8") if body is None else body
    )
    result.headers = headers or {}
    return result


def cdx(*, timestamp=TIMESTAMP, original=SDK_URL, status="200"):
    return response([CDX_HEADER, [timestamp, original, status]])


def save_job():
    return response(body=f'<html data-job-id="{JOB_ID}"></html>'.encode("utf-8"))


def capture_success(*, timestamp=TIMESTAMP, original=SDK_URL):
    return response(
        {"status": "success", "timestamp": timestamp, "original_url": original}
    )


class WaybackTest(unittest.TestCase):
    def urlopen(self, *results):
        return mock.patch.object(
            update_osx_sdk.urllib.request, "urlopen", side_effect=results
        )

    def assert_save_post(self, request):
        self.assertIsInstance(request, update_osx_sdk.urllib.request.Request)
        self.assertEqual(request.get_method(), "POST")

        parsed = urllib.parse.urlparse(request.full_url)
        self.assertEqual(
            (parsed.scheme, parsed.netloc, parsed.path),
            ("https", "web.archive.org", "/save/"),
        )
        expected = {
            "url": [SDK_URL],
            "force_get": ["1"],
            "skip_first_archive": ["1"],
        }
        self.assertEqual(urllib.parse.parse_qs(parsed.query), expected)
        self.assertEqual(
            urllib.parse.parse_qs(request.data.decode("ascii")), expected
        )
        self.assertEqual(request.get_header("Accept"), ACCEPT_HEADER)
        self.assertEqual(
            request.get_header("Content-type"),
            "application/x-www-form-urlencoded",
        )


class FindWaybackSnapshotTest(WaybackTest):
    def test_status_200_cdx_snapshot_and_exact_query(self):
        with self.urlopen(cdx()) as urlopen:
            self.assertEqual(
                update_osx_sdk.find_wayback_snapshot(SDK_URL), SNAPSHOT_URL
            )

        expected_query = urllib.parse.urlencode(
            {
                "url": SDK_URL,
                "output": "json",
                "filter": "statuscode:200",
                "fl": "timestamp,original,statuscode",
                "matchType": "exact",
                "limit": "1",
                "gzip": "false",
            }
        )
        urlopen.assert_called_once_with(
            "https://web.archive.org/cdx/search/cdx?" + expected_query
        )

    def test_empty_cdx_responses_return_no_snapshot(self):
        cases = {
            "empty_array": response([]),
            "header_only": response([CDX_HEADER]),
            "zero_bytes": response(body=b""),
            "whitespace": response(body=b" \n\t"),
        }
        for description, result in cases.items():
            with self.subTest(response=description):
                with self.urlopen(result):
                    self.assertIsNone(update_osx_sdk.find_wayback_snapshot(SDK_URL))

    def test_malformed_cdx_responses_are_rejected(self):
        cases = {
            "invalid_json": response(body=b"not valid JSON"),
            "invalid_response": response({"status": "200"}),
            "invalid_header": response([["timestamp", "original"]]),
            "invalid_row": response([CDX_HEADER, [TIMESTAMP, SDK_URL]]),
            "short_timestamp": cdx(timestamp="20260817"),
            "nonnumeric_timestamp": cdx(timestamp="2026081704050x"),
            "wrong_original": cdx(original=OLD_SDK_URL),
            "non_200_status": cdx(status="404"),
            "network_error": urllib.error.URLError("CDX unavailable"),
        }
        for description, result in cases.items():
            with self.subTest(response=description):
                with self.urlopen(result):
                    with self.assertRaises(RuntimeError):
                        update_osx_sdk.find_wayback_snapshot(SDK_URL)

    def test_existing_snapshot_does_not_start_capture(self):
        with self.urlopen(cdx()) as urlopen:
            self.assertEqual(
                update_osx_sdk.ensure_wayback_snapshot(SDK_URL), SNAPSHOT_URL
            )
        self.assertEqual(urlopen.call_count, 1)

    def test_dry_run_does_not_start_capture(self):
        with self.urlopen(response([])) as urlopen:
            with self.assertRaisesRegex(RuntimeError, "dry.run"):
                update_osx_sdk.ensure_wayback_snapshot(SDK_URL, save=False)
        self.assertEqual(urlopen.call_count, 1)
        self.assertIsInstance(urlopen.call_args.args[0], str)


class SaveWaybackSnapshotTest(WaybackTest):
    def test_post_and_pending_status_match_official_capture_protocol(self):
        job = save_job()
        pending = response(
            {"status": "pending"}, headers={"Retry-After": "2"}
        )
        with self.urlopen(
            response([]), job, pending, capture_success()
        ) as urlopen:
            with mock.patch.object(update_osx_sdk.time, "sleep") as sleep:
                self.assertEqual(
                    update_osx_sdk.ensure_wayback_snapshot(SDK_URL), SNAPSHOT_URL
                )

        self.assertEqual(urlopen.call_count, 4)
        self.assert_save_post(urlopen.call_args_list[1].args[0])
        job.read.assert_called_once_with(1024 * 1024)
        for call in urlopen.call_args_list[2:]:
            request = call.args[0]
            self.assertEqual(request.get_method(), "GET")
            self.assertEqual(
                request.full_url,
                "https://web.archive.org/save/status/" + JOB_ID,
            )
            self.assertEqual(request.get_header("Accept"), ACCEPT_HEADER)
            self.assertIsNone(request.data)
        sleep.assert_called_once_with(2)

    def test_empty_cdx_bodies_start_capture(self):
        for body in (b"", b" \n\t"):
            with self.subTest(body=body):
                with self.urlopen(
                    response(body=body), save_job(), capture_success()
                ) as urlopen:
                    self.assertEqual(
                        update_osx_sdk.ensure_wayback_snapshot(SDK_URL), SNAPSHOT_URL
                    )
                self.assertEqual(urlopen.call_count, 3)
                self.assert_save_post(urlopen.call_args_list[1].args[0])

    def test_failed_and_invalid_capture_statuses_are_rejected(self):
        cases = {
            "capture_error": response(
                {"status": "error", "message": "capture failed"}
            ),
            "wrong_original": capture_success(original=OLD_SDK_URL),
            "short_timestamp": capture_success(timestamp="20260817"),
            "nonnumeric_timestamp": capture_success(
                timestamp="2026081704050x"
            ),
            "invalid_status_json": response(body=b"not valid JSON"),
            "status_network_error": urllib.error.URLError("status unavailable"),
        }
        for description, result in cases.items():
            with self.subTest(response=description):
                with self.urlopen(response([]), save_job(), result):
                    with self.assertRaises(RuntimeError):
                        update_osx_sdk.ensure_wayback_snapshot(SDK_URL)

    def test_missing_capture_job_fails_without_requerying_cdx(self):
        body = response(body=b"<html>missing capture job</html>")
        with self.urlopen(response([]), body) as urlopen:
            with self.assertRaises(RuntimeError):
                update_osx_sdk.ensure_wayback_snapshot(SDK_URL)

        self.assertEqual(urlopen.call_count, 2)
        self.assert_save_post(urlopen.call_args_list[1].args[0])
        body.read.assert_called_once_with(1024 * 1024)

    def test_capture_post_network_failure_is_reported(self):
        with self.urlopen(
            response([]), urllib.error.URLError("Save Page Now unavailable")
        ):
            with self.assertRaises(RuntimeError):
                update_osx_sdk.ensure_wayback_snapshot(SDK_URL)


class UpdateOSXFromArchiveTest(unittest.TestCase):
    def make_update(self, archive_url=SNAPSHOT_URL):
        return update_osx_sdk.MacOSSDKUpdate(
            sdk_version="27.1",
            url=SDK_URL,
            sha256=NEW_SHA256,
            archive_url=archive_url,
        )

    def test_module_update_replaces_all_four_fields(self):
        updated = update_osx_sdk.update_osx_from_archive(
            MODULE_TEXT, self.make_update()
        )
        expected = (
            f'    sha256 = "{NEW_SHA256}",',
            '    strip_prefix = "Payload/Library/Developer/'
            'CommandLineTools/SDKs/MacOSX27.1.sdk",',
            f'        "{SDK_URL}",',
            f'        "{SNAPSHOT_URL}",',
        )
        for field in expected:
            with self.subTest(field=field):
                self.assertIn(field, updated)
        self.assertNotIn(OLD_SHA256, updated)
        self.assertNotIn(OLD_SDK_URL, updated)
        self.assertTrue(updated.startswith("before = True\n"))
        self.assertTrue(updated.endswith("after = True\n"))

    def test_unverified_or_mismatched_snapshot_is_rejected(self):
        for snapshot in (None, OLD_SNAPSHOT_URL):
            with self.subTest(snapshot=snapshot):
                with self.assertRaises(RuntimeError):
                    update_osx_sdk.update_osx_from_archive(
                        MODULE_TEXT, self.make_update(snapshot)
                    )

    def test_main_does_not_mutate_module_when_capture_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            module_path = Path(directory) / "MODULE.bazel"
            module_path.write_text(MODULE_TEXT)
            with (
                mock.patch.object(
                    update_osx_sdk, "parse_sucatalog", return_value={}
                ),
                mock.patch.object(
                    update_osx_sdk,
                    "latest_nmos_sdk_update",
                    return_value=self.make_update(None),
                ),
                mock.patch.object(
                    update_osx_sdk,
                    "ensure_wayback_snapshot",
                    side_effect=RuntimeError("capture failed"),
                ),
            ):
                with self.assertRaisesRegex(RuntimeError, "capture failed"):
                    update_osx_sdk.main(["--module", str(module_path)])
            self.assertEqual(module_path.read_text(), MODULE_TEXT)


if __name__ == "__main__":
    unittest.main()
