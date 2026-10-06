import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock
import urllib.error

TOOLS = Path(__file__).resolve().parents[1] / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
import run_sandbox_local as launcher


class Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


def arguments(**changes):
    values = {
        "provider": "ollama", "python": sys.executable, "tagger_dir": Path("/nonexistent/order_tagger"),
        "model": "qwen3.5:4b", "ollama_url": "http://127.0.0.1:11434",
        "service_port": 8787, "ollama": None, "godot": None,
        "startup_timeout": 30.0, "check": False, "headless": False, "igpu": False,
    }
    values.update(changes)
    return argparse.Namespace(**values)


def ready(model="qwen3.5:4b"):
    return {"mode": "local", "model": model, "ready": True, "request_timeout": 150, "protocol_version": 2,
            "supported_actions": list(launcher.service.SUPPORTED_ACTIONS)}


class RequestTests(unittest.TestCase):
    def test_shared_url_checks_normalize_localhost(self):
        self.assertEqual(launcher.normalize_base_url("http://localhost:11434"), "http://127.0.0.1:11434")

    def test_remote_urls_are_rejected_before_open(self):
        for url in ["https://127.0.0.1:11434", "http://example.com:11434", "http://127.0.0.1:11434/path", "http://user@127.0.0.1:11434"]:
            opener = mock.Mock()
            with self.subTest(url=url), self.assertRaises(launcher.LocalError):
                launcher.request_json(url, "/health", opener=opener)
            opener.open.assert_not_called()

    def test_response_parsing_and_post_body(self):
        opener = mock.Mock()
        opener.open.return_value = Response(b'{"ready":true}')
        result = launcher.request_json("http://127.0.0.1:11434", "/orders", {"value": "A"}, timeout=9, opener=opener)
        request = opener.open.call_args.args[0]
        self.assertEqual(result, {"ready": True})
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(json.loads(request.data), {"value": "A"})
        self.assertEqual(opener.open.call_args.kwargs["timeout"], 9)

    def test_invalid_duplicate_and_oversized_json(self):
        for body in [b"not json", b'{"x":1,"x":2}', b"x" * (launcher.MAX_RESPONSE_BYTES + 1)]:
            opener = mock.Mock()
            opener.open.return_value = Response(body)
            with self.subTest(body_size=len(body)), self.assertRaises(launcher.LocalError):
                launcher.request_json("http://127.0.0.1:11434", "/health", opener=opener)

    def test_no_redirect_and_no_proxy_handlers(self):
        with self.assertRaises(launcher.LocalError):
            launcher.NoRedirects().redirect_request(None, None, 302, "redirect", {}, "https://example.com")
        opener = mock.Mock()
        opener.open.return_value = Response(b"{}")
        with mock.patch.object(launcher.urllib.request, "build_opener", return_value=opener) as build:
            launcher.request_json("http://127.0.0.1:11434", "/health")
        handlers = build.call_args.args
        self.assertIsInstance(handlers[0], launcher.urllib.request.ProxyHandler)
        self.assertEqual(handlers[0].proxies, {})
        self.assertIsInstance(handlers[1], launcher.NoRedirects)

    def test_http_error_keeps_safe_status_and_response(self):
        opener = mock.Mock()
        opener.open.side_effect = urllib.error.HTTPError("http://127.0.0.1:8787/orders", 503, "busy", {}, Response(b'{"error":"Model busy","mode":"local"}'))
        with self.assertRaises(launcher.LocalError) as error:
            launcher.request_json("http://127.0.0.1:8787", "/orders", opener=opener)
        self.assertEqual(error.exception.status, 503)
        self.assertEqual(str(error.exception), "Model busy")
        self.assertEqual(error.exception.response["mode"], "local")

    def test_network_error_is_reported(self):
        opener = mock.Mock()
        opener.open.side_effect = urllib.error.URLError("connection refused")
        with self.assertRaises(launcher.LocalError) as error:
            launcher.request_json("http://127.0.0.1:11434", "/api/version", opener=opener)
        self.assertIn("Could not reach", str(error.exception))

    def test_api_paths_cannot_replace_address(self):
        for path in ["//example.com", "orders"]:
            opener = mock.Mock()
            with self.assertRaises(launcher.LocalError):
                launcher.request_json("http://127.0.0.1:8787", path, opener=opener)
            opener.open.assert_not_called()

    def test_occupied_incompatible_port_is_not_reused(self):
        with mock.patch.object(launcher, "request_json", side_effect=launcher.LocalError("Invalid JSON")), mock.patch.object(launcher, "port_is_open", return_value=True):
            with self.assertRaises(launcher.LocalError) as error:
                launcher.existing_json("http://127.0.0.1:8787", "/health", "local order service")
        self.assertIn("already in use", str(error.exception))

    def test_closed_port_can_be_started(self):
        with mock.patch.object(launcher, "request_json", side_effect=launcher.LocalError("connection refused")), mock.patch.object(launcher, "port_is_open", return_value=False):
            self.assertIsNone(launcher.existing_json("http://127.0.0.1:8787", "/health", "local order service"))


class ProcessTests(unittest.TestCase):
    def test_cleanup_touches_only_registered_processes_in_reverse_order(self):
        events = []
        first = mock.Mock()
        second = mock.Mock()
        unrelated = mock.Mock()
        for name, child in [("first", first), ("second", second)]:
            child.poll.return_value = None
            child.terminate.side_effect = lambda name=name: events.append(name)
        owner = launcher.OwnedProcesses(popen=mock.Mock(side_effect=[first, second]))
        owner.start(["ollama", "serve"], {})
        owner.start(["service"], {})
        owner.close()
        self.assertEqual(events, ["second", "first"])
        self.assertEqual(owner.children, [])
        unrelated.terminate.assert_not_called()
        owner.close()
        self.assertEqual(events, ["second", "first"])

    def test_cleanup_skips_exited_and_kills_only_own_unresponsive_child(self):
        exited = mock.Mock()
        exited.poll.return_value = 0
        stuck = mock.Mock()
        stuck.poll.return_value = None
        stuck.wait.side_effect = [subprocess.TimeoutExpired("own", 5), 0]
        owner = launcher.OwnedProcesses(popen=mock.Mock(side_effect=[exited, stuck]))
        owner.start(["exited"], {})
        owner.start(["stuck"], {})
        owner.close()
        exited.terminate.assert_not_called()
        stuck.terminate.assert_called_once()
        stuck.kill.assert_called_once()

    def test_waiting_stops_when_child_exits(self):
        child = mock.Mock()
        child.poll.return_value = 1
        with mock.patch.object(launcher, "request_json") as request:
            with self.assertRaises(launcher.LocalError):
                launcher.wait_for_json("http://127.0.0.1:11434", "/api/version", child, launcher.is_ollama_version)
        request.assert_not_called()

    def test_waiting_returns_readiness_without_sleep(self):
        child = mock.Mock()
        child.poll.return_value = None
        with mock.patch.object(launcher, "request_json", return_value={"version": "0.35.1"}), mock.patch.object(launcher.time, "sleep") as sleep:
            value = launcher.wait_for_json("http://127.0.0.1:11434", "/api/version", child, launcher.is_ollama_version)
        self.assertEqual(value["version"], "0.35.1")
        sleep.assert_not_called()


class LauncherTests(unittest.TestCase):
    def _run_with_probes(self, args, probes, health=None, owner=None):
        owner = owner or mock.Mock(spec=launcher.OwnedProcesses)
        owner.start.return_value.wait.return_value = 0
        with mock.patch.object(launcher, "existing_json", side_effect=probes), mock.patch.object(launcher, "resolve_binary", side_effect=lambda name, explicit=None: "/local/bin/" + name), mock.patch.object(launcher, "wait_for_json", side_effect=[{"version": "0.35.1"}, health or ready()]), mock.patch.object(launcher.sys, "stdout", new=io.StringIO()), mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
            result = launcher.run(args, processes=owner, environment={"ANTHROPIC_API_KEY": "not forwarded", "EXAMPLE": "kept"})
        return result, owner

    def test_existing_servers_are_reused_and_only_game_is_owned(self):
        result, owner = self._run_with_probes(arguments(), [{"version": "0.35.1"}, ready()])
        self.assertEqual(result, 0)
        owner.start.assert_called_once()
        command, environment = owner.start.call_args.args
        self.assertEqual(command[0], "/local/bin/godot")
        self.assertEqual(command[-1], "res://scenes/sandbox.tscn")
        self.assertEqual(environment["SANDBOX_SERVICE_URL"], "http://127.0.0.1:8787")
        self.assertNotIn("ANTHROPIC_API_KEY", environment)
        self.assertEqual(environment["OLLAMA_NO_CLOUD"], "1")
        owner.close.assert_called_once()

    def test_new_servers_are_owned_and_local_provider_is_explicit(self):
        result, owner = self._run_with_probes(arguments(check=True), [None, None])
        self.assertEqual(result, 0)
        self.assertEqual(owner.start.call_count, 2)
        ollama_command, ollama_env = owner.start.call_args_list[0].args
        service_command, service_env = owner.start.call_args_list[1].args
        self.assertEqual(ollama_command, ["/local/bin/ollama", "serve"])
        self.assertEqual(ollama_env["OLLAMA_HOST"], "127.0.0.1:11434")
        self.assertEqual(ollama_env["OLLAMA_NO_CLOUD"], "1")
        self.assertIn("--provider", service_command)
        self.assertIn("ollama", service_command)
        self.assertEqual(service_env["SANDBOX_PROVIDER"], "ollama")
        self.assertEqual(service_env["SANDBOX_MODEL"], "qwen3.5:4b")
        owner.close.assert_called_once()

    def test_igpu_flag_only_configures_an_owned_ollama_process(self):
        result, owner = self._run_with_probes(arguments(check=True, igpu=True), [None, None])
        self.assertEqual(result, 0)
        self.assertEqual(owner.start.call_args_list[0].args[1]["OLLAMA_IGPU_ENABLE"], "1")
        self.assertNotIn("OLLAMA_IGPU_ENABLE", owner.start.call_args_list[1].args[1])
        result, owner = self._run_with_probes(arguments(check=True, igpu=True), [{"version": "0.35.1"}, ready()])
        self.assertEqual(result, 0)
        owner.start.assert_not_called()

    def test_check_mode_does_not_open_game_window(self):
        result, owner = self._run_with_probes(arguments(check=True), [{"version": "0.35.1"}, ready()])
        self.assertEqual(result, 0)
        owner.start.assert_not_called()
        owner.close.assert_called_once()

    def test_headless_flag_and_custom_port_reach_game(self):
        result, owner = self._run_with_probes(arguments(headless=True, service_port=8877), [{"version": "0.35.1"}, ready()])
        self.assertEqual(result, 0)
        self.assertIn("--headless", owner.start.call_args.args[0])
        self.assertEqual(owner.start.call_args.args[1]["SANDBOX_SERVICE_URL"], "http://127.0.0.1:8877")

    def test_incompatible_mode_model_and_missing_weights_do_not_launch(self):
        for health in [{"mode": "cloud", "model": "claude", "ready": True}, ready("another:4b"), {"mode": "local", "model": "qwen3.5:4b", "ready": False, "error": "Pull the model first."}]:
            with self.subTest(health=health):
                result, owner = self._run_with_probes(arguments(), [{"version": "0.35.1"}, health])
                self.assertEqual(result, 1)
                owner.start.assert_not_called()
                owner.close.assert_called_once()

    def test_old_service_is_refused_without_owning_or_stopping_it(self):
        health = ready()
        del health["supported_actions"]
        spawn = mock.Mock()
        owner = launcher.OwnedProcesses(popen=spawn)
        with mock.patch.object(launcher, "existing_json", side_effect=[{"version": "0.35.1"}, health]), \
             mock.patch.object(launcher.sys, "stdout", new=io.StringIO()), \
             mock.patch.object(launcher.sys, "stderr", new=io.StringIO()) as output, \
             mock.patch.object(owner, "close", wraps=owner.close) as close:
            self.assertEqual(launcher.run(arguments(), processes=owner), 1)
        self.assertIn("Restart", output.getvalue())
        self.assertIn("--service-port 8790", output.getvalue())
        spawn.assert_not_called()
        close.assert_called_once()
        self.assertEqual(owner.children, [])

    def test_missing_or_malformed_movement_capabilities_are_refused(self):
        for actions in (None, "move_to", {}, [], ["form_line", "stop", "clarify"], ["move_to", 1],
                        ["move_to", []], ["move_to", ""], ["move_to", " stop"]):
            health = dict(ready(), supported_actions=actions)
            with self.subTest(actions=actions), self.assertRaises(launcher.LocalError) as error:
                launcher.check_local_health(health, arguments().model)
            self.assertIn("move_to", str(error.exception))

    def test_movement_service_accepts_compatible_additional_actions(self):
        health = dict(ready(), supported_actions=[*launcher.service.SUPPORTED_ACTIONS, "future_action"])
        self.assertIs(launcher.check_local_health(health, arguments().model), health)

    def test_readiness_and_model_errors_remain_distinct_from_capability_errors(self):
        for changes, text in (({"model": "another-model"}, "instead"),
                              ({"ready": False, "error": "Pull the model first."}, "Pull the model first.")):
            health = ready()
            del health["supported_actions"]
            health.update(changes)
            with self.subTest(changes=changes), self.assertRaises(launcher.LocalError) as error:
                launcher.check_local_health(health, arguments().model)
            self.assertIn(text, str(error.exception))

    def test_protocol_version_requires_exact_integer_two(self):
        for version in (None, True, False, 1, 3, 2.0, "2", [], {}):
            health = dict(ready(), protocol_version=version)
            with self.subTest(version=version), self.assertRaises(launcher.LocalError):
                launcher.check_local_health(health, arguments().model)
        health = ready()
        del health["protocol_version"]
        spawn = mock.Mock()
        owner = launcher.OwnedProcesses(popen=spawn)
        with mock.patch.object(launcher, "existing_json", side_effect=[{"version": "0.35.1"}, health]), \
             mock.patch.object(launcher.sys, "stdout", new=io.StringIO()), \
             mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
            self.assertEqual(launcher.run(arguments(), processes=owner), 1)
        spawn.assert_not_called()
        self.assertEqual(owner.children, [])

    def test_every_advertised_action_is_required(self):
        for missing in launcher.service.SUPPORTED_ACTIONS:
            health = dict(ready(), supported_actions=[action for action in launcher.service.SUPPORTED_ACTIONS if action != missing])
            with self.subTest(missing=missing), self.assertRaises(launcher.LocalError):
                launcher.check_local_health(health, arguments().model)

    def test_bad_version_does_not_start_any_child(self):
        result, owner = self._run_with_probes(arguments(), [{"version": 12}])
        self.assertEqual(result, 1)
        owner.start.assert_not_called()

    def test_cloud_model_and_invalid_ports_do_not_contact_servers(self):
        for args in [arguments(model="example:cloud"), arguments(service_port=0), arguments(service_port=99999)]:
            owner = mock.Mock(spec=launcher.OwnedProcesses)
            with mock.patch.object(launcher, "existing_json") as probe, mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
                self.assertEqual(launcher.run(args, processes=owner), 1)
            probe.assert_not_called()
            owner.start.assert_not_called()
            owner.close.assert_called_once()

    def test_interrupt_and_spawn_failure_cleanup_owned_children(self):
        for failure, expected in [(KeyboardInterrupt(), 130), (OSError("cannot start"), 1)]:
            owner = mock.Mock(spec=launcher.OwnedProcesses)
            owner.start.side_effect = failure
            with mock.patch.object(launcher, "existing_json", return_value=None), mock.patch.object(launcher, "resolve_binary", return_value="/local/bin/ollama"), mock.patch.object(launcher.sys, "stdout", new=io.StringIO()), mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
                self.assertEqual(launcher.run(arguments(), processes=owner), expected)
            owner.close.assert_called_once()

    def test_environment_is_copied_not_modified(self):
        environment = {"ANTHROPIC_API_KEY": "preserve caller value", "EXAMPLE": "kept"}
        owner = mock.Mock(spec=launcher.OwnedProcesses)
        with mock.patch.object(launcher, "existing_json", side_effect=[{"version": "0.35.1"}, ready()]), mock.patch.object(launcher.sys, "stdout", new=io.StringIO()):
            self.assertEqual(launcher.run(arguments(check=True), processes=owner, environment=environment), 0)
        self.assertEqual(environment, {"ANTHROPIC_API_KEY": "preserve caller value", "EXAMPLE": "kept"})

    def test_startup_timeout_closes_owned_server(self):
        owner = mock.Mock(spec=launcher.OwnedProcesses)
        with mock.patch.object(launcher, "existing_json", return_value=None), mock.patch.object(launcher, "resolve_binary", return_value="/local/bin/ollama"), mock.patch.object(launcher, "wait_for_json", side_effect=launcher.LocalError("Timed out")), mock.patch.object(launcher.sys, "stdout", new=io.StringIO()), mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
            self.assertEqual(launcher.run(arguments(), processes=owner), 1)
        owner.start.assert_called_once()
        owner.close.assert_called_once()

    def test_surrounding_model_whitespace_is_rejected_before_contact(self):
        for model in ["example:cloud ", " qwen3.5:4b", "   "]:
            owner = mock.Mock(spec=launcher.OwnedProcesses)
            with self.subTest(model=model), mock.patch.object(launcher, "existing_json") as probe, mock.patch.object(launcher.sys, "stderr", new=io.StringIO()):
                self.assertEqual(launcher.run(arguments(model=model), processes=owner), 1)
            probe.assert_not_called()

    def test_binary_resolution_fallback_and_missing_executable(self):
        with mock.patch.object(launcher.shutil, "which", side_effect=[None, "/local/bin/godot4"]), mock.patch.object(launcher.Path, "is_file", return_value=True), mock.patch.object(launcher.os, "access", return_value=True):
            self.assertEqual(launcher.resolve_binary("godot"), "/local/bin/godot4")
        with mock.patch.object(launcher.shutil, "which", return_value=None), mock.patch.object(launcher.Path, "is_file", return_value=False):
            with self.assertRaises(launcher.LocalError):
                launcher.resolve_binary("ollama")

    def test_startup_timeout_argument_bounds(self):
        for timeout in ["0", "301", "nan", "inf"]:
            with self.subTest(timeout=timeout), mock.patch.object(launcher.sys, "stderr", new=io.StringIO()), self.assertRaises(SystemExit) as error:
                launcher.parse_args(["--startup-timeout", timeout])
            self.assertEqual(error.exception.code, 2)

    def test_bert_provider_starts_only_the_order_service_with_the_chosen_python(self):
        tagger_dir = Path("/models/order_tagger")
        health = ready(model=launcher.service.tagger_model_name(tagger_dir))
        owner = mock.Mock(spec=launcher.OwnedProcesses)
        args = arguments(provider="bert", python="/envs/torch/bin/python", tagger_dir=tagger_dir, check=True)
        with mock.patch.object(launcher, "existing_json", return_value=None), mock.patch.object(launcher, "wait_for_json", return_value=health), mock.patch.object(launcher.sys, "stdout", new=io.StringIO()):
            self.assertEqual(launcher.run(args, processes=owner, environment={"ANTHROPIC_API_KEY": "not forwarded"}), 0)
        owner.start.assert_called_once()
        command, environment = owner.start.call_args.args
        self.assertEqual(command[0], "/envs/torch/bin/python")
        self.assertEqual(command[-4:], ["--provider", "bert", "--port", "8787"])
        self.assertEqual(environment["SANDBOX_TAGGER_DIR"], str(tagger_dir))
        self.assertEqual(environment["HF_HUB_OFFLINE"], "1")
        self.assertNotIn("ANTHROPIC_API_KEY", environment)

    def test_bert_provider_reports_a_tagger_that_is_not_ready(self):
        tagger_dir = Path("/models/order_tagger")
        health = dict(ready(model=launcher.service.tagger_model_name(tagger_dir)), ready=False, error="This Python lacks PyTorch or transformers (torch).")
        owner = mock.Mock(spec=launcher.OwnedProcesses)
        stderr = io.StringIO()
        with mock.patch.object(launcher, "existing_json", return_value=health), mock.patch.object(launcher.sys, "stderr", new=stderr):
            self.assertEqual(launcher.run(arguments(provider="bert", tagger_dir=tagger_dir), processes=owner), 1)
        owner.start.assert_not_called()
        self.assertIn("lacks PyTorch", stderr.getvalue())

    def test_argument_defaults_and_igpu_option(self):
        with mock.patch.dict(launcher.os.environ, {}, clear=True):
            args = launcher.parse_args(["--igpu", "--check"])
        self.assertEqual(args.provider, "bert")
        self.assertEqual(args.tagger_dir, launcher.service.DEFAULT_TAGGER_DIR)
        self.assertEqual(args.python, sys.executable)
        self.assertEqual(args.model, launcher.service.DEFAULT_LOCAL_MODEL)
        self.assertEqual(args.ollama_url, "http://127.0.0.1:11434")
        self.assertTrue(args.igpu and args.check)


if __name__ == "__main__":
    unittest.main()
