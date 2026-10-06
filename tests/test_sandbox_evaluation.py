import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
import evaluate_sandbox_orders as evaluation
from run_sandbox_local import LocalError

TEMP_DIR = "/home/antonio/.claude/jobs/10a0c6e5/tmp"


def response_for(case, request_id=1):
    expected = case["expected"]
    endpoints = expected["endpoints"]
    return {
        "request_id": request_id, "mode": "local",
        "order": {
            "action": expected["action"], "soldier_ids": expected["soldier_ids"].copy(),
            "start": endpoints[0] if endpoints else None,
            "end": expected["destination"] if expected["action"] in ("move_to", "attack") else (endpoints[1] if endpoints else None),
            "facing": expected["facing"], "message": "The requested order is understood.", "group_name": expected["group_name"],
        },
    }


class FakeLocalClient:
    def __init__(self, cases=None, failure=None, timeout=150):
        self.cases = evaluation.CASES if cases is None else cases
        self.calls = []
        self.failure = failure
        self.timeout = timeout

    def __call__(self, base, path, payload=None, timeout=None):
        self.calls.append((base, path, copy.deepcopy(payload), timeout))
        if path == "/health":
            return {"mode": "local", "model": "qwen3.5:4b", "ready": True, "request_timeout": self.timeout,
                    "protocol_version": 2, "supported_actions": list(evaluation.service.SUPPORTED_ACTIONS)}
        if path == "/api/version":
            return {"version": "0.35.1"}
        if path == "/api/ps":
            return {"models": []}
        if path == "/api/generate":
            return {"done": True}
        if path == "/orders":
            if self.failure:
                raise self.failure
            case = self.cases[(payload["request_id"] - 1) % len(self.cases)]
            return response_for(case, payload["request_id"])
        raise AssertionError("Unexpected route: " + path)


class ScoreTests(unittest.TestCase):
    def test_all_cases_have_valid_expected_orders_and_original_cases_are_retained(self):
        original_names = [
            "basic_line", "line_paraphrase", "row_paraphrase", "reversed_endpoints", "no_facing_requested",
            "explicit_pair", "other_endpoints", "stop_all", "stop_one", "missing_endpoint", "unknown_landmark",
            "ambiguous_places", "unsupported_square", "follow_basic", "unsupported_cannons",
            "unsupported_split_tasks", "invalid_instructions",
        ]
        self.assertEqual([case["name"] for case in evaluation.CASES[:17]], original_names)
        self.assertEqual(len(evaluation.CASES), 54)
        self.assertEqual(len({case["name"] for case in evaluation.CASES}), 54)
        for case in evaluation.CASES:
            with self.subTest(case=case["name"]):
                context = evaluation.context_for_case(case)
                passed, failures = evaluation.score_response(response_for(case), case, 1, context)
                self.assertTrue(passed, failures)
                evaluation.service.validate_request({"request_id": 1, "prompt": case["prompt"], "context": context})

    def test_patrol_order_is_not_an_unordered_line(self):
        case = next(case for case in evaluation.CASES if case["name"] == "patrol_reverse")
        context = evaluation.context_for_case(case)
        response = response_for(case)
        self.assertEqual((response["order"]["start"], response["order"]["end"]), ("B", "A"))
        response["order"].update(start="A", end="B")
        passed, failures = evaluation.score_response(response, case, 1, context)
        self.assertFalse(passed)
        self.assertIn("The ordered patrol endpoints differ from the request.", failures)

    def test_follow_is_supported_and_named_selection_requires_exact_membership(self):
        by_name = {case["name"]: case for case in evaluation.CASES}
        self.assertEqual(by_name["follow_basic"]["prompt"], "Follow me in formation.")
        self.assertEqual(by_name["follow_basic"]["expected"]["action"], "follow_player")
        for name in ("follow_alpha", "patrol_beta", "named_move", "named_stop"):
            case = by_name[name]
            context = evaluation.context_for_case(case)
            response = response_for(case)
            response["order"]["soldier_ids"] = evaluation.SOLDIER_IDS.copy()
            with self.subTest(name=name):
                passed, failures = evaluation.score_response(response, case, 1, context)
                self.assertFalse(passed)
                self.assertIn("The selected soldiers differ from the request.", failures)

    def test_creation_scores_normalized_name_and_exact_membership(self):
        case = next(case for case in evaluation.CASES if case["name"] == "create_alpha")
        context = evaluation.context_for_case(case)
        response = response_for(case)
        response["order"]["group_name"] = "Alpha"
        self.assertEqual(evaluation.score_response(response, case, 1, context), (True, []))
        response["order"]["group_name"] = "beta"
        passed, failures = evaluation.score_response(response, case, 1, context)
        self.assertFalse(passed)
        self.assertIn("The new group name differs from the request.", failures)
        response = response_for(case)
        response["order"]["soldier_ids"] = [evaluation.SOLDIER_IDS[0]]
        self.assertFalse(evaluation.score_response(response, case, 1, context)[0])

    def test_named_context_is_copied_and_preserves_all(self):
        case = next(case for case in evaluation.CASES if case["name"] == "create_overlap")
        original = copy.deepcopy(case)
        context = evaluation.context_for_case(case)
        self.assertEqual(context["groups"]["all"], evaluation.SOLDIER_IDS)
        context["groups"]["alpha"].clear()
        self.assertEqual(case, original)
        self.assertEqual(evaluation.context_for_case(case)["groups"]["alpha"], evaluation.SOLDIER_IDS[:6])

    def test_unknown_missing_and_compound_group_cases_require_clarification(self):
        by_name = {case["name"]: case for case in evaluation.CASES}
        for name in ("unknown_group", "missing_group", "create_missing_name", "create_duplicate",
                     "create_reserved", "create_invalid_name", "create_limit", "compound_supported",
                     "compound_creation", "patrol_missing_endpoint", "patrol_unknown_endpoint", "patrol_one_endpoint",
                     "unsupported_square", "unsupported_cannons", "unsupported_split_tasks"):
            with self.subTest(name=name):
                self.assertEqual(by_name[name]["expected"]["action"], "clarify")
                self.assertEqual(by_name[name]["expected"]["soldier_ids"], [])
                self.assertIsNone(by_name[name]["expected"]["group_name"])

    def test_legacy_six_field_response_is_rejected(self):
        case = evaluation.CASES[0]
        response = response_for(case)
        del response["order"]["group_name"]
        self.assertFalse(evaluation.score_response(response, case, 1, evaluation.context_for_case(case))[0])

    def test_endpoint_and_soldier_order_does_not_change_score(self):
        case = evaluation.CASES[0]
        response = response_for(case)
        response["order"]["start"], response["order"]["end"] = "B", "A"
        response["order"]["soldier_ids"].reverse()
        self.assertEqual(evaluation.score_response(response, case, 1, evaluation.context_for_case(case)), (True, []))

    def test_valid_json_with_wrong_interpretation_fails(self):
        case = evaluation.CASES[0]
        for changes in [{"soldier_ids": evaluation.SOLDIER_IDS[:2]}, {"start": "B", "end": "C"}, {"facing": "A"}, {"action": "stop", "start": None, "end": None, "facing": None}]:
            response = response_for(case)
            response["order"].update(changes)
            with self.subTest(changes=changes):
                passed, failures = evaluation.score_response(response, case, 1, evaluation.context_for_case(case))
                self.assertFalse(passed)
                self.assertTrue(failures)
                self.assertNotIn("Order validation failed", failures[0])

    def test_invalid_order_fields_duplicates_and_unknown_ids_fail(self):
        case = evaluation.CASES[0]
        for changes in [{"executable": "code"}, {"soldier_ids": ["soldier_01", "soldier_01"]}, {"soldier_ids": ["soldier_01", "unknown"]}, {"message": ""}]:
            response = response_for(case)
            response["order"].update(changes)
            with self.subTest(changes=changes):
                passed, failures = evaluation.score_response(response, case, 1, evaluation.context_for_case(case))
                self.assertFalse(passed)
                self.assertIn("Order validation failed", failures[0])

    def test_movement_requires_exact_destination_and_selected_soldiers(self):
        case = next(case for case in evaluation.CASES if case["name"] == "move_basic")
        context = evaluation.context_for_case(case)
        for changes in ({"end": "A"}, {"soldier_ids": evaluation.SOLDIER_IDS[:2]}, {"facing": "A"},
                        {"action": "form_line", "start": "A"}, {"start": "C", "end": None}):
            response = response_for(case)
            response["order"].update(changes)
            with self.subTest(changes=changes):
                passed, failures = evaluation.score_response(response, case, 1, context)
                self.assertFalse(passed)
                self.assertTrue(failures)
        response = response_for(case)
        response["order"]["soldier_ids"].reverse()
        self.assertEqual(evaluation.score_response(response, case, 1, context), (True, []))

    def test_movement_cannot_be_scored_as_an_unordered_line_pair(self):
        case = next(case for case in evaluation.CASES if case["name"] == "move_basic")
        response = response_for(case)
        response["order"].update(action="form_line", start="C", end="A")
        passed, failures = evaluation.score_response(response, case, 1, evaluation.context_for_case(case))
        self.assertFalse(passed)
        self.assertIn("The movement destination differs from the request.", failures)

    def test_movement_facing_subsets_and_missing_destinations_are_explicit(self):
        by_name = {case["name"]: case for case in evaluation.CASES}
        self.assertIsNone(by_name["move_basic"]["expected"]["facing"])
        self.assertEqual(by_name["move_facing"]["expected"]["facing"], "A")
        self.assertEqual(by_name["move_single"]["expected"]["soldier_ids"], ["soldier_07"])
        self.assertEqual(by_name["move_numbered_pair"]["expected"]["soldier_ids"], evaluation.SOLDIER_IDS[:2])
        self.assertEqual(by_name["move_explicit_pair"]["expected"]["soldier_ids"], ["soldier_02", "soldier_05"])
        self.assertNotIn("C", evaluation.context_for_case(by_name["move_missing_destination"])["landmarks"])
        for name in ("move_missing_destination", "move_unknown_destination", "move_unspecified_destination"):
            self.assertEqual(by_name[name]["expected"]["action"], "clarify")
            self.assertEqual(by_name[name]["expected"]["soldier_ids"], [])

    def test_move_factory_uses_destination_and_optional_facing(self):
        case = evaluation._case("custom_move", "Go to B.", action="move_to", destination="B")
        self.assertEqual(case["expected"]["destination"], "B")
        self.assertIsNone(case["expected"]["endpoints"])
        self.assertIsNone(case["expected"]["facing"])
        response = response_for(case)
        self.assertEqual(response["order"]["end"], "B")
        self.assertIsNone(response["order"]["start"])
        self.assertEqual(evaluation.score_response(response, case, 1, evaluation.context_for_case(case)), (True, []))

    def test_observed_pair_command_requires_movement_not_clarification(self):
        case = next(case for case in evaluation.CASES if case["name"] == "move_pair_should_go_float_context")
        self.assertEqual(case["prompt"], "Only soldier_01 and soldier_02 should go to C.")
        self.assertEqual(case["expected"]["action"], "move_to")
        self.assertEqual(case["expected"]["soldier_ids"], ["soldier_01", "soldier_02"])
        self.assertEqual(case["expected"]["destination"], "C")
        context = evaluation.context_for_case(case)
        response = response_for(case)
        self.assertEqual(evaluation.score_response(response, case, 1, context), (True, []))
        response["order"].update(action="clarify", soldier_ids=[], start=None, end=None, facing=None,
                                 message="No destination or supported action was specified.")
        passed, failures = evaluation.score_response(response, case, 1, context)
        self.assertFalse(passed)
        self.assertIn("Expected action move_to, received clarify.", failures)
        self.assertIn("The selected soldiers differ from the request.", failures)
        self.assertIn("The movement destination differs from the request.", failures)

    def test_float_context_preserves_values_groups_and_original_case(self):
        case = next(case for case in evaluation.CASES if case["name"] == "move_pair_should_go_float_context")
        original = copy.deepcopy(case)
        context = evaluation.context_for_case(case)
        integers = evaluation.context_for_case(dict(case, float_context=False))
        self.assertEqual(context, integers)
        self.assertEqual(context["groups"], {"all": evaluation.SOLDIER_IDS})
        self.assertEqual(context["landmarks"]["C"], [936.0, 648.0])
        for soldier in context["soldiers"]:
            self.assertTrue(all(type(number) is float for number in soldier["position"]))
        for point in context["landmarks"].values():
            self.assertTrue(all(type(number) is float for number in point))
        self.assertTrue(all(type(number) is int for soldier in integers["soldiers"] for number in soldier["position"]))
        self.assertEqual(case, original)
        payload = {"request_id": 1, "prompt": case["prompt"], "context": context}
        evaluation.service.validate_request(payload)
        parsed = evaluation.service.parse_json(json.dumps(payload))
        self.assertIs(type(parsed["context"]["landmarks"]["C"][0]), float)
        context["soldiers"][0]["position"][0] = -1.0
        self.assertEqual(evaluation.context_for_case(case)["soldiers"][0]["position"], [872.0, 536.0])

    def test_float_context_keeps_missing_landmarks_missing(self):
        case = evaluation._case("float_missing", "Move to C.", action="clarify", missing=("C",), float_context=True)
        context = evaluation.context_for_case(case)
        self.assertNotIn("C", context["landmarks"])
        self.assertIs(type(context["landmarks"]["A"][0]), float)
        self.assertIs(type(context["soldiers"][0]["position"][0]), float)
        evaluation.service.validate_request({"request_id": 1, "prompt": case["prompt"], "context": context})

    def test_response_fields_mode_and_integer_id_are_strict(self):
        case = evaluation.CASES[0]
        for changes in [{"mode": "cloud"}, {"mode": "fixture"}, {"request_id": True}, {"request_id": 2}, {"extra": 1}]:
            response = response_for(case)
            response.update(changes)
            with self.subTest(changes=changes):
                self.assertFalse(evaluation.score_response(response, case, 1, evaluation.context_for_case(case))[0])
        self.assertFalse(evaluation.score_response([], case, 1, evaluation.context_for_case(case))[0])

    def test_missing_endpoint_context_and_context_independence(self):
        missing_case = next(case for case in evaluation.CASES if case["name"] == "missing_endpoint")
        missing_context = evaluation.context_for_case(missing_case)
        self.assertNotIn("B", missing_context["landmarks"])
        missing_context["groups"]["all"].clear()
        context = evaluation.context_for_case(evaluation.CASES[0])
        self.assertIn("B", context["landmarks"])
        self.assertEqual(context["groups"]["all"], evaluation.SOLDIER_IDS)

    def test_no_facing_requested_requires_null(self):
        case = next(case for case in evaluation.CASES if case["name"] == "no_facing_requested")
        response = response_for(case)
        response["order"]["facing"] = "C"
        self.assertFalse(evaluation.score_response(response, case, 1, evaluation.context_for_case(case))[0])


class EvaluationTests(unittest.TestCase):
    def test_repeat_ids_statistics_and_default_do_not_unload_model(self):
        cases = evaluation.CASES[:2]
        client = FakeLocalClient(cases)
        clock = mock.Mock(side_effect=[0, 10, 20, 22, 30, 34, 40, 46])
        with mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
            report = evaluation.evaluate("http://127.0.0.1:8787", cases=cases, repeat=2, client=client, clock=clock)
        self.assertEqual((report["passed"], report["total"], report["accuracy"]), (4, 4, 1.0))
        self.assertEqual(report["first_request_seconds"], 10)
        self.assertEqual(report["warm_median_seconds"], 4)
        self.assertEqual(report["warm_p95_seconds"], 6)
        self.assertIsNone(report["cold_request_seconds"])
        self.assertFalse(report["cold_start_verified"])
        calls = [call for call in client.calls if call[1] == "/orders"]
        self.assertEqual([call[2]["request_id"] for call in calls], [1, 2, 3, 4])
        self.assertFalse(any(call[1] == "/api/generate" for call in client.calls))

    def test_pair_regression_evaluation_sends_float_game_coordinates(self):
        cases = [next(case for case in evaluation.CASES if case["name"] == "move_pair_should_go_float_context")]
        client = FakeLocalClient(cases)
        with mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
            report = evaluation.evaluate("http://127.0.0.1:8788", cases=cases, client=client, clock=mock.Mock(side_effect=[0, 4]))
        self.assertEqual((report["passed"], report["total"]), (1, 1))
        payload = next(call[2] for call in client.calls if call[1] == "/orders")
        self.assertEqual(payload["prompt"], "Only soldier_01 and soldier_02 should go to C.")
        self.assertEqual(payload["context"]["landmarks"]["C"], [936.0, 648.0])
        self.assertTrue(all(type(number) is float for point in payload["context"]["landmarks"].values() for number in point))
        self.assertTrue(all(type(number) is float for soldier in payload["context"]["soldiers"] for number in soldier["position"]))
        self.assertEqual(report["results"][0]["expected"]["action"], "move_to")
        self.assertEqual(report["results"][0]["expected"]["soldier_ids"], evaluation.SOLDIER_IDS[:2])
        self.assertEqual(report["results"][0]["expected"]["destination"], "C")

    def test_cold_measurement_unloads_only_selected_model_and_verifies(self):
        cases = evaluation.CASES[:1]
        client = FakeLocalClient(cases)
        with mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
            report = evaluation.evaluate("http://127.0.0.1:8787", cases=cases, cold=True, client=client, clock=mock.Mock(side_effect=[0, 7]))
        self.assertEqual(report["cold_request_seconds"], 7)
        self.assertTrue(report["cold_start_verified"])
        unload = next(call for call in client.calls if call[1] == "/api/generate")
        self.assertEqual(unload[2], {"model": "qwen3.5:4b", "stream": False, "keep_alive": 0})
        index = client.calls.index(unload)
        self.assertEqual(client.calls[index + 1][1], "/api/ps")
        self.assertIsNone(report["warm_median_seconds"])

    def test_cold_test_refuses_model_still_loaded_or_unknown_status(self):
        for status in [{"models": [{"name": "qwen3.5:4b"}]}, {"models": [{"model": "qwen3.5:4b"}]}, {}]:
            client = mock.Mock(side_effect=[{"done": True}, status])
            with self.subTest(status=status), self.assertRaises(LocalError):
                evaluation.unload_for_cold_request("http://127.0.0.1:11434", "qwen3.5:4b", client)

    def test_cloud_fixture_unready_and_cloud_model_are_refused_before_orders(self):
        for health in [{"mode": "cloud"}, {"mode": "fixture"}, {"mode": "local", "ready": False}, {"mode": "local", "ready": True, "model": "remote:cloud"}, {"mode": "local", "ready": True, "model": "remote:cloud "}]:
            client = mock.Mock(return_value=health)
            with self.subTest(health=health), self.assertRaises(LocalError):
                evaluation.evaluate("http://127.0.0.1:8787", client=client)
            self.assertEqual(client.call_count, 1)
            self.assertEqual(client.call_args.args[1], "/health")

    def test_incompatible_protocol_or_actions_are_refused_before_orders(self):
        base = FakeLocalClient()("http://127.0.0.1:8790", "/health")
        for changes in ({"protocol_version": None}, {"protocol_version": 1}, {"protocol_version": True},
                        {"protocol_version": 2.0}, {"supported_actions": ["form_line", "move_to", "stop", "clarify"]}):
            client = mock.Mock(return_value=dict(base, **changes))
            with self.subTest(changes=changes), self.assertRaises(LocalError):
                evaluation.evaluate("http://127.0.0.1:8790", client=client)
            self.assertEqual(client.call_count, 1)

    def test_entire_protocol_two_dataset_with_mock_responses(self):
        client = FakeLocalClient()
        with mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
            report = evaluation.evaluate("http://127.0.0.1:8790", client=client)
        self.assertEqual((report["passed"], report["total"]), (54, 54))
        self.assertEqual(len([call for call in client.calls if call[1] == "/orders"]), 54)
        self.assertFalse(any(call[1] == "/api/generate" for call in client.calls))

    def test_http_failures_keep_status_response_and_latency(self):
        cases = evaluation.CASES[:1]
        client = FakeLocalClient(cases, failure=LocalError("model busy", 503, {"error": "model busy"}))
        with mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
            report = evaluation.evaluate("http://127.0.0.1:8787", cases=cases, client=client, clock=mock.Mock(side_effect=[0, 3]))
        result = report["results"][0]
        self.assertEqual(report["passed"], 0)
        self.assertEqual(result["http_status"], 503)
        self.assertEqual(result["response"], {"error": "model busy"})
        self.assertEqual(result["failures"], ["model busy"])
        self.assertEqual(result["seconds"], 3)

    def test_health_timeout_bounds_and_types(self):
        for timeout, expected in [(30, 30), (True, 150), (float("nan"), 150), (float("inf"), 150), (1, 150), (301, 150), ("30", 150)]:
            client = FakeLocalClient(evaluation.CASES[:1], timeout=timeout)
            with self.subTest(timeout=timeout), mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
                evaluation.evaluate("http://127.0.0.1:8787", cases=evaluation.CASES[:1], client=client, clock=mock.Mock(side_effect=[0, 1]))
            self.assertEqual(next(call[3] for call in client.calls if call[1] == "/orders"), expected)

    def test_metadata_filters_fields_and_reports_errors(self):
        client = mock.Mock(side_effect=[LocalError("no runtime response"), {"models": [{"name": "qwen3.5:4b", "size_vram": 5, "unrelated": "omit"}, None]}])
        result = evaluation.metadata("http://127.0.0.1:11434", client)
        self.assertEqual(result["runtime"], {"error": "no runtime response"})
        self.assertEqual(result["running_models"], [{"name": "qwen3.5:4b", "size_vram": 5}])

    def test_percentile_uses_nearest_rank(self):
        self.assertIsNone(evaluation.percentile_95([]))
        self.assertEqual(evaluation.percentile_95([7]), 7)
        self.assertEqual(evaluation.percentile_95(list(range(1, 101))), 95)

    def test_empty_evaluation_does_not_invent_accuracy_or_latency(self):
        report = evaluation.evaluate("http://127.0.0.1:8787", cases=[], client=FakeLocalClient([]))
        self.assertEqual(report["total"], 0)
        self.assertIsNone(report["accuracy"])
        self.assertIsNone(report["first_request_seconds"])
        self.assertIsNone(report["warm_p95_seconds"])


class CommandTests(unittest.TestCase):
    def test_main_outputs_json_and_returns_failure_when_any_case_fails(self):
        for passed, expected in [(2, 0), (1, 1), (0, 1)]:
            report = {"passed": passed, "total": 2, "results": []}
            stdout = io.StringIO()
            with self.subTest(passed=passed), mock.patch.object(evaluation, "evaluate", return_value=report), mock.patch.object(evaluation.sys, "stdout", new=stdout), mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
                self.assertEqual(evaluation.main([]), expected)
            self.assertEqual(json.loads(stdout.getvalue()), report)

    def test_new_output_file_and_existing_file_is_never_overwritten(self):
        report = {"passed": 1, "total": 1}
        with tempfile.TemporaryDirectory(dir=TEMP_DIR) as directory:
            output = Path(directory) / "report.json"
            with mock.patch.object(evaluation, "evaluate", return_value=report) as evaluate, mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()):
                self.assertEqual(evaluation.main(["--output", str(output)]), 0)
                self.assertEqual(json.loads(output.read_text()), report)
                self.assertEqual(evaluation.main(["--output", str(output)]), 1)
                self.assertEqual(evaluate.call_count, 1)
                self.assertEqual(json.loads(output.read_text()), report)

    def test_main_setup_failure_is_nonzero(self):
        with mock.patch.object(evaluation, "evaluate", side_effect=LocalError("No local model")), mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()) as stderr:
            self.assertEqual(evaluation.main([]), 1)
            self.assertIn("No local model", stderr.getvalue())

    def test_repeat_argument_bounds(self):
        for repeat in ["0", "21"]:
            with self.subTest(repeat=repeat), mock.patch.object(evaluation.sys, "stderr", new=io.StringIO()), self.assertRaises(SystemExit) as error:
                evaluation.parse_args(["--repeat", repeat])
            self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
