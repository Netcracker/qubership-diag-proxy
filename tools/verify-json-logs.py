#!/usr/bin/env python3

import json
import os
import subprocess
import time
import unittest

IMAGE = os.environ.get("DIAG_PROXY_IMAGE", "diag-proxy:test")


def docker(*args, check=True):
    return subprocess.run(
        ["docker", *args], capture_output=True, text=True, check=check, timeout=30
    )


class JsonLogsTest(unittest.TestCase):
    def test_startup_preserves_special_characters_in_one_record(self):
        host = 'collector"\\\u043a\u0438\u0440\u0438\u043b\u043b\u0438\u0446\u0430' + "".join(chr(i) for i in range(1, 32)) + "\n"
        result = docker(
            "run",
            "--rm",
            "--user",
            "0",
            "--entrypoint",
            "/bin/ash",
            "-e",
            "SKIP_HOSTNAME_RESOLVING=true",
            "-e",
            f"ESC_COLLECTOR_HOST={host}",
            IMAGE,
            "/docker-entrypoint.d/100-render-agent-config.sh",
        )
        records = result.stdout.splitlines()
        self.assertEqual(len(records), 1, result.stdout)
        record = json.loads(records[0])
        self.assertEqual(record["endpoint_host"], host)
        self.assertEqual(record["level"], "INFO")
        self.assertEqual(result.stderr, "")

    def test_resolved_endpoint_keeps_the_configured_host(self):
        result = docker(
            "run",
            "--rm",
            "--user",
            "0",
            "--entrypoint",
            "/bin/ash",
            "--add-host",
            "collector.test:127.0.0.1",
            "-e",
            "ESC_COLLECTOR_HOST=collector.test",
            IMAGE,
            "/docker-entrypoint.d/100-render-agent-config.sh",
        )
        record = json.loads(result.stdout)
        self.assertEqual(record["endpoint_host"], "collector.test")
        self.assertEqual(record["resolved_ip"], "127.0.0.1")

    def test_warning_omits_empty_fields_and_goes_to_stderr(self):
        result = docker(
            "run",
            "--rm",
            "--user",
            "0",
            "--entrypoint",
            "/bin/ash",
            IMAGE,
            "-c",
            '. /docker-entrypoint.d/100-render-agent-config.sh; log_json WARN warning empty "" present value',
        )
        self.assertEqual(result.stdout, "")
        record = json.loads(result.stderr)
        self.assertEqual(record["level"], "WARN")
        self.assertEqual(record["message"], "warning")
        self.assertEqual(record["present"], "value")
        self.assertNotIn("empty", record)

    def test_dns_failure_is_json_on_stderr_and_stops_startup(self):
        result = docker(
            "run",
            "--rm",
            "--user",
            "0",
            "--entrypoint",
            "/bin/ash",
            "-e",
            "ESC_COLLECTOR_HOST=no-such-collector.invalid",
            IMAGE,
            "/docker-entrypoint.d/100-render-agent-config.sh",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        record = json.loads(result.stderr)
        self.assertEqual(record["level"], "ERROR")
        self.assertEqual(record["host"], "no-such-collector.invalid")

    def test_access_records_escape_request_id_and_omit_secrets(self):
        container = docker(
            "run",
            "-d",
            "--tmpfs",
            "/etc/nginx/conf.d:mode=777",
            "--tmpfs",
            "/tmp:mode=1777",
            "-e",
            "ESC_STATIC_HOST=127.0.0.1",
            "-e",
            "ESC_STATIC_PORT=9",
            IMAGE,
        ).stdout.strip()
        try:
            for _ in range(50):
                ready = docker(
                    "exec",
                    container,
                    "wget",
                    "-qO-",
                    "http://127.0.0.1:8888/health",
                    check=False,
                )
                if ready.returncode == 0:
                    break
                time.sleep(0.1)
            self.assertEqual(ready.returncode, 0, docker("logs", container).stderr)
            request_id = 'request"\\\tend'
            for headers in [[], ["--header", f"X-Request-Id: {request_id}"]]:
                result = docker(
                    "exec",
                    container,
                    "wget",
                    "-qO-",
                    "--header",
                    "Authorization: Bearer auth-secret",
                    "--header",
                    "Cookie: session=cookie-secret",
                    *headers,
                    "http://127.0.0.1:8080/missing?token=query-secret",
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0)
            logs = docker("logs", container)
            all_records = [json.loads(line) for line in logs.stdout.splitlines()]
            records = [record for record in all_records if "method" in record]
            self.assertEqual(len(records), 2, logs.stdout)
            self.assertNotIn("request_id", records[0])
            self.assertEqual(records[1]["request_id"], request_id)
            for record in records:
                self.assertEqual(record["uri"], "/missing")
                self.assertEqual(record["status"], "502")
                self.assertEqual(record["level"], "INFO")
            self.assertNotIn("query-secret", logs.stdout)
            self.assertNotIn("auth-secret", logs.stdout + logs.stderr)
            self.assertNotIn("cookie-secret", logs.stdout + logs.stderr)
            self.assertIn("connect() failed", logs.stderr)
        finally:
            docker("rm", "-f", container)


if __name__ == "__main__":
    unittest.main()
