#!/usr/bin/env python3
"""Start the soldier sandbox with a local interpreter and stop only processes started here.

The default interpreter is the trained BERT order tagger in models/order_tagger. It
needs a Python with PyTorch and transformers (--python or SANDBOX_PYTHON).
--provider ollama uses a local Ollama model instead.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import sandbox_order_service as service

PROJECT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = service.DEFAULT_LOCAL_MODEL
DEFAULT_OLLAMA_URL = "http://127.0.0.1:11434"
MAX_RESPONSE_BYTES = 131_072


class LocalError(Exception):
    def __init__(self, message, status=None, response=None):
        super().__init__(message)
        self.status = status
        self.response = response


class NoRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        raise LocalError("Local requests must not redirect to another address.", code)


def normalize_base_url(value):
    normalizer = getattr(service, "normalize_ollama_url", None)
    if normalizer is None:
        raise LocalError("The order service does not have its Ollama adapter yet.")
    try:
        return normalizer(value)
    except (service.OrderError, ValueError) as error:
        raise LocalError(str(error)) from error


def request_json(base_url, path, payload=None, timeout=2.0, opener=None):
    base_url = normalize_base_url(base_url)
    if not path.startswith("/") or path.startswith("//"):
        raise LocalError("Local API paths must begin with one slash.")
    data = None if payload is None else json.dumps(payload, allow_nan=False).encode("utf-8")
    headers = {} if data is None else {"Content-Type": "application/json"}
    request = urllib.request.Request(base_url + path, data=data, headers=headers)
    opener = opener or urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirects())
    try:
        with opener.open(request, timeout=timeout) as response:
            body = response.read(MAX_RESPONSE_BYTES + 1)
    except urllib.error.HTTPError as error:
        try:
            body = error.read(MAX_RESPONSE_BYTES + 1)
            parsed = service.parse_json(body) if len(body) <= MAX_RESPONSE_BYTES else None
        except (service.OrderError, OSError, ValueError):
            parsed = None
        message = parsed.get("error") if isinstance(parsed, dict) else None
        raise LocalError(str(message or "Local API returned HTTP %d." % error.code)[:500], error.code, parsed) from error
    except (urllib.error.URLError, socket.timeout, TimeoutError, OSError) as error:
        raise LocalError("Could not reach %s%s: %s" % (base_url, path, str(error)[:200])) from error
    if len(body) > MAX_RESPONSE_BYTES:
        raise LocalError("The local API response was too large.")
    try:
        return service.parse_json(body)
    except service.OrderError as error:
        raise LocalError("The local API returned invalid JSON: %s" % error) from error


def port_is_open(base_url):
    parsed = urllib.parse.urlsplit(normalize_base_url(base_url))
    try:
        with socket.create_connection((parsed.hostname, parsed.port or 80), timeout=1.0):
            return True
    except OSError:
        return False


def existing_json(base_url, path, description):
    try:
        return request_json(base_url, path)
    except LocalError as error:
        if port_is_open(base_url):
            raise LocalError("%s is already in use, but it is not a compatible %s. %s" % (base_url, description, error)) from error
        return None


def wait_for_json(base_url, path, process, predicate, timeout=30.0):
    deadline = time.monotonic() + timeout
    last_error = "No response yet."
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise LocalError("The process for %s exited before becoming ready." % base_url)
        try:
            value = request_json(base_url, path, timeout=min(2.0, max(0.1, deadline - time.monotonic())))
            if predicate(value):
                return value
            last_error = "The API returned an unexpected readiness response."
        except LocalError as error:
            last_error = str(error)
        time.sleep(0.1)
    raise LocalError("Timed out waiting for %s. %s" % (base_url, last_error))


class OwnedProcesses:
    def __init__(self, popen=None):
        self._popen = popen or subprocess.Popen
        self.children = []

    def start(self, command, environment):
        child = self._popen(command, env=environment, cwd=str(PROJECT_DIR))
        self.children.append(child)
        return child

    def close(self):
        for child in reversed(self.children):
            if child.poll() is not None:
                continue
            try:
                child.terminate()
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)
            except ProcessLookupError:
                pass
        self.children.clear()


def resolve_binary(name, explicit=None):
    if explicit:
        path = shutil.which(explicit) or explicit
    else:
        path = shutil.which(name)
        if path is None and name == "ollama":
            path = str(Path.home() / ".local/bin/ollama")
        if path is None and name == "godot":
            path = shutil.which("godot4")
    if not path or not Path(path).is_file() or not os.access(path, os.X_OK):
        raise LocalError("Could not find an executable %s. Install it or specify --%s." % (name, name))
    return str(path)


def is_ollama_version(value):
    return isinstance(value, dict) and isinstance(value.get("version"), str) and bool(value["version"].strip())


def is_local_health(value):
    return isinstance(value, dict) and value.get("mode") == "local" and type(value.get("ready")) is bool


def check_local_health(value, model):
    if not is_local_health(value):
        raise LocalError("The order-service port is occupied by another mode or application. Use --service-port with an unused port.")
    if value.get("model") != model:
        raise LocalError("The running order service uses %s instead of %s. Use another --service-port." % (value.get("model"), model))
    if not value["ready"]:
        raise LocalError(str(value.get("error") or "Ollama or the selected local model is not ready. Run ollama pull %s first." % model)[:500])
    if type(value.get("protocol_version")) is not int or value["protocol_version"] != service.PROTOCOL_VERSION:
        raise LocalError("The running order service needs protocol version 2. Restart that service manually, or use --service-port 8790.")
    actions = value.get("supported_actions")
    if (not isinstance(actions, list)
            or any(not isinstance(action, str) or not action or action != action.strip() for action in actions)
            or not set(service.SUPPORTED_ACTIONS).issubset(actions)):
        raise LocalError("The running order service lacks required actions, including move_to, follow_player, patrol and create_group. Restart it manually, or use --service-port 8790.")
    return value


def start_tagger_service(args, processes, environment, service_url):
    """Start or reuse a bert-provider order service and return its health."""
    model = service.tagger_model_name(args.tagger_dir)
    health = existing_json(service_url, "/health", "local order service")
    if health is None:
        service_env = {**environment, "SANDBOX_PROVIDER": "bert", "SANDBOX_TAGGER_DIR": str(args.tagger_dir),
                       "HF_HUB_OFFLINE": "1", "TRANSFORMERS_OFFLINE": "1", "USE_TF": "0"}
        print("Starting the local order service with the order tagger in %s…" % args.tagger_dir, flush=True)
        child = processes.start([args.python, str(PROJECT_DIR / "tools/sandbox_order_service.py"), "--provider", "bert",
                                 "--port", str(args.service_port)], service_env)
        health = wait_for_json(service_url, "/health", child, is_local_health, args.startup_timeout)
    return check_local_health(health, model)


def run(args, processes=None, environment=None):
    processes = processes or OwnedProcesses()
    environment = dict(os.environ if environment is None else environment)
    environment.pop("ANTHROPIC_API_KEY", None)
    environment["OLLAMA_NO_CLOUD"] = "1"
    try:
        if not 1 <= args.service_port <= 65535:
            raise LocalError("--service-port must be between 1 and 65535.")
        if args.provider == "bert":
            health = start_tagger_service(args, processes, environment, "http://127.0.0.1:%d" % args.service_port)
            print("Local order tagger ready: %s. No language model or API key is used." % health["model"], flush=True)
            return 0 if args.check else launch_game(args, processes, environment)
        ollama_url = normalize_base_url(args.ollama_url)
        if not args.model.strip() or args.model != args.model.strip() or len(args.model) > 200 or args.model.lower().endswith(":cloud"):
            raise LocalError("Choose a nonempty local model name, not a :cloud model.")
        service_url = "http://127.0.0.1:%d" % args.service_port
        version = existing_json(ollama_url, "/api/version", "Ollama server")
        if version is None:
            ollama = resolve_binary("ollama", args.ollama)
            environment["OLLAMA_HOST"] = urllib.parse.urlsplit(ollama_url).netloc
            print("Starting local Ollama at %s…" % ollama_url, flush=True)
            ollama_env = environment.copy()
            if args.igpu:
                ollama_env["OLLAMA_IGPU_ENABLE"] = "1"
            child = processes.start([ollama, "serve"], ollama_env)
            version = wait_for_json(ollama_url, "/api/version", child, is_ollama_version, args.startup_timeout)
        elif not is_ollama_version(version):
            raise LocalError("The Ollama port is occupied by an application without a valid /api/version response.")
        else:
            print("Using existing Ollama %s at %s." % (version["version"], ollama_url), flush=True)
            if args.igpu:
                print("--igpu does not change the settings of an existing Ollama server.", flush=True)
        health = existing_json(service_url, "/health", "local order service")
        if health is None:
            service_env = {**environment, "SANDBOX_PROVIDER": "ollama", "SANDBOX_MODEL": args.model, "SANDBOX_OLLAMA_URL": ollama_url}
            print("Starting the local order service for %s…" % args.model, flush=True)
            child = processes.start([sys.executable, str(PROJECT_DIR / "tools/sandbox_order_service.py"), "--provider", "ollama", "--port", str(args.service_port)], service_env)
            health = wait_for_json(service_url, "/health", child, is_local_health, args.startup_timeout)
        check_local_health(health, args.model)
        print("Local model ready: %s. No provider API key is used." % health["model"], flush=True)
        if args.check:
            return 0
        return launch_game(args, processes, environment)
    except LocalError as error:
        print("Local sandbox: %s" % error, file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    except OSError as error:
        print("Local sandbox: could not start a process: %s" % error, file=sys.stderr)
        return 1
    finally:
        processes.close()


def launch_game(args, processes, environment):
    godot = resolve_binary("godot", args.godot)
    game_env = {**environment, "SANDBOX_SERVICE_URL": "http://127.0.0.1:%d" % args.service_port}
    command = [godot, "--path", str(PROJECT_DIR)]
    if args.headless:
        command.append("--headless")
    command.append("res://scenes/sandbox.tscn")
    game = processes.start(command, game_env)
    return game.wait()


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", choices=("bert", "ollama"), default="bert",
                        help="Order interpreter: the trained BERT tagger (default) or a local Ollama model")
    parser.add_argument("--python", default=os.environ.get("SANDBOX_PYTHON", sys.executable),
                        help="Python with PyTorch and transformers for the bert provider (default: SANDBOX_PYTHON, or this Python)")
    parser.add_argument("--tagger-dir", type=Path, default=Path(os.environ.get("SANDBOX_TAGGER_DIR", service.DEFAULT_TAGGER_DIR)),
                        help="Trained order tagger directory (default: models/order_tagger)")
    parser.add_argument("--model", default=os.environ.get("SANDBOX_MODEL", DEFAULT_MODEL), help="Ollama model for --provider ollama")
    parser.add_argument("--ollama-url", default=os.environ.get("SANDBOX_OLLAMA_URL", DEFAULT_OLLAMA_URL))
    parser.add_argument("--service-port", type=int, default=8787)
    parser.add_argument("--ollama", help="Path to the Ollama executable")
    parser.add_argument("--godot", help="Path to the Godot executable")
    parser.add_argument("--startup-timeout", type=float, default=30.0)
    parser.add_argument("--check", action="store_true", help="Check local readiness without opening a game window")
    parser.add_argument("--headless", action="store_true", help="Launch the sandbox without a visible window")
    parser.add_argument("--igpu", action="store_true", help="Enable integrated-GPU inference only when starting a new Ollama server")
    args = parser.parse_args(argv)
    if not 1 <= args.startup_timeout <= 300:
        parser.error("--startup-timeout must be between 1 and 300 seconds")
    return args


def main(argv=None):
    return run(parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
