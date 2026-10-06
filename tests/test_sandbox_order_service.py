"""Offline checks for the sandbox order service. Model requests are mocked."""

import copy
import http.client
import importlib.util
import io
import json
import math
import socket
import threading
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

SERVICE_PATH = Path(__file__).resolve().parents[1] / "tools" / "sandbox_order_service.py"
SPEC = importlib.util.spec_from_file_location("sandbox_order_service", SERVICE_PATH)
service = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(service)


def request_data():
    return {
        "request_id": 7,
        "prompt": "Form a line between A and B facing C.",
        "context": {
            "soldiers": [
                {"id": "soldier_01", "position": [800, 600]},
                {"id": "soldier_02", "position": [824, 600]},
                {"id": "soldier_03", "position": [848, 600]},
            ],
            "groups": {"all": ["soldier_01", "soldier_02", "soldier_03"]},
            "landmarks": {"A": [800, 640], "B": [896, 640], "C": [848, 720]},
        },
    }


def line_order():
    return {
        "action": "form_line", "soldier_ids": ["soldier_01", "soldier_02", "soldier_03"],
        "start": "A", "end": "B", "facing": "C", "message": "Form a line A-B facing C.", "group_name": None,
    }


def move_order(soldiers=None, destination="C", facing=None):
    return {
        "action": "move_to", "soldier_ids": ["soldier_01", "soldier_02", "soldier_03"] if soldiers is None else list(soldiers),
        "start": None, "end": destination, "facing": facing, "message": "Move the selected soldiers near the destination.", "group_name": None,
    }


def extended_order(action, soldiers=None, group_name=None):
    return {
        "action": action, "soldier_ids": ["soldier_01"] if soldiers is None else soldiers,
        "start": "B" if action == "patrol" else None,
        "end": "A" if action == "patrol" else None,
        "facing": None, "message": "The requested order is understood.", "group_name": group_name,
    }


def cloud_response(order=None):
    return {
        "stop_reason": "tool_use",
        "content": [{"type": "tool_use", "id": "toolu_test", "name": "emit_order", "input": order or line_order()}],
    }


def local_response(order=None, **values):
    response = {
        "model": service.DEFAULT_LOCAL_MODEL,
        "done": True,
        "done_reason": "stop",
        "message": {"role": "assistant", "content": json.dumps(order or line_order())},
        "eval_count": 40,
        "eval_duration": 2_000_000_000,
        "prompt_eval_count": 200,
        "prompt_eval_duration": 1_000_000_000,
        "load_duration": 100_000_000,
        "total_duration": 3_100_000_000,
    }
    response.update(values)
    return response


class RequestValidationTests(unittest.TestCase):
    def setUp(self):
        self.request = request_data()

    def test_valid_request(self):
        self.assertIs(service.validate_request(self.request), self.request)

    def test_request_fields_are_exact(self):
        for field in ("request_id", "prompt", "context"):
            value = copy.deepcopy(self.request)
            del value[field]
            with self.subTest(field=field), self.assertRaises(service.OrderError):
                service.validate_request(value)
        self.request["unknown"] = 1
        with self.assertRaises(service.OrderError):
            service.validate_request(self.request)

    def test_request_ids(self):
        for value in (-1, True, 1.2, "7", None, service.MAX_REQUEST_ID + 1):
            self.request["request_id"] = value
            with self.subTest(value=value), self.assertRaises(service.OrderError):
                service.validate_request(self.request)
        for value in (0, service.MAX_REQUEST_ID):
            self.request["request_id"] = value
            service.validate_request(self.request)

    def test_prompt_bounds(self):
        for value in (None, False, "", " \n\t", "a" * 2001):
            self.request["prompt"] = value
            with self.subTest(value_type=type(value)), self.assertRaises(service.OrderError):
                service.validate_request(self.request)
        self.request["prompt"] = "a" * 2000
        service.validate_request(self.request)

    def test_invalid_unicode_prompt_is_rejected(self):
        self.request["prompt"] = "bad" + chr(0xD800) + "text"
        with self.assertRaises(service.OrderError):
            service.validate_request(self.request)

    def test_context_fields_are_exact(self):
        for value in (None, [], {"soldiers": []}, dict(self.request["context"], secret="ignored")):
            self.request["context"] = value
            with self.subTest(value=value), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_soldier_count(self):
        for soldiers in (None, {}, [], [{}] * 65):
            self.request["context"]["soldiers"] = soldiers
            with self.subTest(soldiers_type=type(soldiers)), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_soldier_fields(self):
        for soldier in ({"id": "soldier_01"}, {"id": "soldier_01", "position": [1, 2], "extra": 0}, None):
            self.request["context"]["soldiers"][0] = soldier
            with self.subTest(soldier=soldier), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_soldier_ids_are_unique_short_names(self):
        for soldier_id in (None, True, [], "", "a" * 65, "bad id", "../file", "soldier_02"):
            self.request["context"]["soldiers"][0]["id"] = soldier_id
            with self.subTest(soldier_id=soldier_id), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_positions_are_bounded_finite_pairs(self):
        invalid = (None, [], [1], [1, 2, 3], [True, 2], ["1", 2], [math.nan, 2], [math.inf, 2], [1_000_001, 2], [10 ** 1000, 2])
        for point in invalid:
            self.request["context"]["soldiers"][0]["position"] = point
            with self.subTest(point_type=type(point)), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_all_group_exact_membership(self):
        for group in ([], ["soldier_01"], ["soldier_01"] * 3, ["unknown"], "all", None):
            self.request["context"]["groups"]["all"] = group
            with self.subTest(group=group), self.assertRaises(service.OrderError):
                service.validate_request(self.request)
        self.request["context"]["groups"] = {"all": ["soldier_01", "soldier_02", "soldier_03"], "other": []}
        with self.assertRaises(service.OrderError):
            service.validate_request(self.request)

    def test_named_groups_allow_overlap_and_preserve_input(self):
        groups = self.request["context"]["groups"]
        groups.update(alpha=["soldier_01", "soldier_02"], beta=["soldier_02", "soldier_03"])
        original = copy.deepcopy(self.request)
        self.assertIs(service.validate_request(self.request), self.request)
        self.assertEqual(self.request, original)

    def test_named_group_names_and_memberships_are_strict(self):
        for name in ("Alpha", "ALL", "", "9alpha", "a" * 25, "a b", "ä", "a\n", 1, None):
            value = request_data()
            value["context"]["groups"][name] = ["soldier_01"]
            with self.subTest(name=name), self.assertRaises(service.OrderError):
                service.validate_request(value)
        for members in ([], None, "soldier_01", ["unknown"], ["soldier_01"] * 2, [True]):
            value = request_data()
            value["context"]["groups"]["alpha"] = members
            with self.subTest(members=members), self.assertRaises(service.OrderError):
                service.validate_request(value)

    def test_named_group_count_and_required_all(self):
        groups = self.request["context"]["groups"]
        groups.update({"g%d" % index: ["soldier_01"] for index in range(8)})
        service.validate_request(self.request)
        groups["ninth"] = ["soldier_01"]
        with self.assertRaises(service.OrderError):
            service.validate_request(self.request)
        for groups in ({}, {"alpha": ["soldier_01"]}, None, []):
            self.request["context"]["groups"] = groups
            with self.subTest(groups=groups), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_landmarks_are_optional_and_only_a_to_h(self):
        self.request["context"]["landmarks"] = {}
        service.validate_request(self.request)
        self.request["context"]["landmarks"] = {"A": [1, 2], "D": [3, 4], "H": [5, 6]}
        service.validate_request(self.request)
        for value in (None, [], {"I": [1, 2]}, {"d": [1, 2]}, {"A": [False, 2]}, {"A": [1, math.inf]}):
            self.request["context"]["landmarks"] = value
            with self.subTest(value=value), self.assertRaises(service.OrderError):
                service.validate_request(self.request)

    def test_json_rejects_duplicates_nonfinite_and_bad_encoding(self):
        invalid = (b'{"a":1,"a":2}', b'{"a":NaN}', b'{"a":Infinity}', b'{"a":-Infinity}', b'{"a":1e400}', b'\xff', b'not json', b'[' * 2000 + b']' * 2000)
        for value in invalid:
            with self.subTest(value_start=value[:20]), self.assertRaises(service.OrderError):
                service.parse_json(value)
        self.assertEqual(service.parse_json(b'{"a": 1}'), {"a": 1})


class OrderValidationTests(unittest.TestCase):
    def setUp(self):
        self.context = request_data()["context"]

    def test_valid_line_and_optional_facing(self):
        order = line_order()
        self.assertIs(service.validate_order(order, self.context), order)
        order["facing"] = None
        service.validate_order(order, self.context)

    def test_valid_subset_stop_and_clarify(self):
        order = line_order()
        order["soldier_ids"] = ["soldier_01", "soldier_03"]
        service.validate_order(order, self.context)
        order.update(action="stop", soldier_ids=["soldier_02"], start=None, end=None, facing=None)
        service.validate_order(order, self.context)
        order.update(action="clarify", soldier_ids=[], message="Place landmarks A and B.")
        service.validate_order(order, self.context)

    def test_valid_movement_all_subset_single_and_optional_facing(self):
        for selected in (None, ["soldier_02"], ["soldier_01", "soldier_03"]):
            for facing in (None, "A", "C"):
                order = move_order(selected, facing=facing)
                with self.subTest(selected=selected, facing=facing):
                    self.assertIs(service.validate_order(order, self.context), order)

    def test_movement_requires_destination_null_start_and_known_facing(self):
        for changes in ({"start": "A"}, {"end": None}, {"end": "Z"}, {"end": True},
                        {"end": []}, {"facing": "Z"}, {"facing": []}, {"target": "C"}):
            with self.subTest(changes=changes), self.assertRaises(service.OrderError):
                service.validate_order(dict(move_order(), **changes), self.context)
        context = copy.deepcopy(self.context)
        del context["landmarks"]["C"]
        with self.assertRaises(service.OrderError):
            service.validate_order(move_order(), context)

    def test_movement_selection_must_be_nonempty_unique_and_known(self):
        for selected in ([], ["soldier_01", "soldier_01"], ["unknown"], "all", None):
            with self.subTest(selected=selected), self.assertRaises(service.OrderError):
                service.validate_order(dict(move_order(), soldier_ids=selected), self.context)

    def test_schema_describes_movement_without_adding_order_fields(self):
        schema = service.order_tool(self.context)["input_schema"]
        self.assertEqual(schema["properties"]["action"]["enum"], list(service.SUPPORTED_ACTIONS))
        self.assertEqual(set(schema["properties"]), service.ORDER_FIELDS)
        self.assertEqual(set(schema["required"]), service.ORDER_FIELDS)
        self.assertIn("null for move_to", schema["properties"]["start"]["description"])
        self.assertIn("move_to destination", schema["properties"]["end"]["description"])
        self.assertIn("otherwise null", schema["properties"]["facing"]["description"])

    def test_follow_patrol_and_creation_accept_known_subsets(self):
        for action in ("follow_player", "patrol", "create_group"):
            for ids in (["soldier_01"], self.context["groups"]["all"]):
                order = extended_order(action, ids, "alpha" if action == "create_group" else None)
                with self.subTest(action=action, ids=ids):
                    self.assertEqual(service.validate_order(order, self.context), order)
            for ids in ([], None, "all", ["unknown"], ["soldier_01"] * 2):
                order = extended_order(action, ids, "alpha" if action == "create_group" else None)
                order["soldier_ids"] = ids
                with self.subTest(action=action, ids=ids), self.assertRaises(service.OrderError):
                    service.validate_order(order, self.context)

    def test_patrol_preserves_order_and_requires_distinct_existing_endpoints(self):
        order = extended_order("patrol")
        self.assertIs(service.validate_order(order, self.context), order)
        self.assertEqual((order["start"], order["end"]), ("B", "A"))
        for changes in ({"start": None}, {"end": None}, {"end": "B"}, {"start": "Z"}, {"facing": "C"}):
            with self.subTest(changes=changes), self.assertRaises(service.OrderError):
                service.validate_order(dict(order, **changes), self.context)
        del self.context["landmarks"]["B"]
        with self.assertRaises(service.OrderError):
            service.validate_order(order, self.context)

    def test_follow_and_creation_have_no_landmarks(self):
        for action in ("follow_player", "create_group"):
            for field in ("start", "end", "facing"):
                order = extended_order(action, group_name="alpha" if action == "create_group" else None)
                order[field] = "A"
                with self.subTest(action=action, field=field), self.assertRaises(service.OrderError):
                    service.validate_order(order, self.context)

    def test_group_creation_normalizes_a_copy_and_allows_overlap(self):
        self.context["groups"]["beta"] = ["soldier_01"]
        original = copy.deepcopy(self.context)
        order = extended_order("create_group", group_name="Alpha_2-X")
        result = service.validate_order(order, self.context)
        self.assertEqual(result["group_name"], "alpha_2-x")
        self.assertIsNot(result, order)
        self.assertEqual(order["group_name"], "Alpha_2-X")
        self.assertEqual(self.context, original)
        self.assertEqual(service.normalize_group_name("A" * 24), "a" * 24)

    def test_creation_rejects_missing_invalid_reserved_duplicate_and_excess_names(self):
        self.context["groups"]["alpha"] = ["soldier_02"]
        for name in (None, True, [], "", " all", "all", "ALL", "Alpha", "9alpha", "a" * 25, "a b", "ä", "a\n"):
            with self.subTest(name=name), self.assertRaises(service.OrderError):
                service.validate_order(extended_order("create_group", group_name=name), self.context)
        self.context["groups"].update({"g%d" % index: ["soldier_01"] for index in range(7)})
        with self.assertRaises(service.OrderError):
            service.validate_order(extended_order("create_group", group_name="new"), self.context)

    def test_only_creation_sets_group_name(self):
        orders = [line_order(), move_order(), extended_order("follow_player"), extended_order("patrol"),
                  extended_order("stop"), extended_order("clarify", [])]
        for order in orders:
            order["group_name"] = "alpha"
            with self.subTest(action=order["action"]), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)

    def test_exact_order_fields(self):
        for field in service.ORDER_FIELDS:
            order = line_order()
            del order[field]
            with self.subTest(field=field), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)
        order = dict(line_order(), extra="ignored")
        with self.assertRaises(service.OrderError):
            service.validate_order(order, self.context)

    def test_unsupported_actions_and_message_bounds(self):
        for action in ("square", "follow", "fire_cannon", None, [], True):
            order = dict(line_order(), action=action)
            with self.subTest(action=action), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)
        for message in (None, "", " ", "a" * 501):
            order = dict(line_order(), message=message)
            with self.subTest(message_type=type(message)), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)

    def test_line_soldier_selection(self):
        for ids in ([], ["soldier_01"], ["soldier_01"] * 2, ["soldier_01", "unknown"], "all", None):
            order = dict(line_order(), soldier_ids=ids)
            with self.subTest(ids=ids), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)

    def test_line_endpoints_and_facing(self):
        for values in ({"start": None}, {"end": None}, {"end": "A"}, {"start": "D"}, {"facing": "D"}, {"facing": []}, {"end": True}):
            order = dict(line_order(), **values)
            with self.subTest(values=values), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)

    def test_attack_may_name_one_place(self):
        attack = {"action": "attack", "soldier_ids": ["soldier_01"], "start": None, "end": None, "facing": None, "message": "Attack.", "group_name": None}
        self.assertEqual(service.validate_order(attack, self.context), attack)
        self.assertEqual(service.validate_order(dict(attack, end="B"), self.context)["end"], "B")
        for values in ({"start": "A"}, {"facing": "C"}, {"end": "D"}, {"soldier_ids": []}, {"group_name": "alpha"}):
            with self.subTest(values=values), self.assertRaises(service.OrderError):
                service.validate_order(dict(attack, **values), self.context)

    def test_invalid_unicode_order_message_is_rejected(self):
        order = dict(line_order(), message=chr(0xD800))
        with self.assertRaises(service.OrderError):
            service.validate_order(order, self.context)

    def test_stop_and_clarify_cannot_assign_landmarks(self):
        for action in ("stop", "clarify"):
            order = dict(line_order(), action=action)
            if action == "clarify":
                order["soldier_ids"] = []
            with self.subTest(action=action), self.assertRaises(service.OrderError):
                service.validate_order(order, self.context)
        order.update(start=None, end=None, facing=None, soldier_ids=["soldier_01"])
        with self.assertRaises(service.OrderError):
            service.validate_order(order, self.context)


class CloudTests(unittest.TestCase):
    def setUp(self):
        self.request = request_data()
        self.calls = []

    def planner_with_response(self, response):
        def opener(request, timeout):
            self.calls.append((request, timeout))
            data = response if isinstance(response, bytes) else json.dumps(response).encode()
            return io.BytesIO(data)
        return service.PlannerService(api_key="test-key-never-log", opener=opener)

    def test_forced_tool_request_and_private_key_location(self):
        planner = self.planner_with_response(cloud_response())
        self.assertEqual(planner.plan(self.request), line_order())
        request, timeout = self.calls[0]
        payload = json.loads(request.data)
        self.assertEqual(request.full_url, service.CLOUD_URL)
        self.assertEqual(timeout, 30)
        self.assertEqual(request.get_header("X-api-key"), "test-key-never-log")
        self.assertNotIn("test-key-never-log", request.data.decode())
        self.assertEqual(payload["model"], service.DEFAULT_MODEL)
        self.assertEqual(payload["tool_choice"], {"type": "tool", "name": "emit_order", "disable_parallel_tool_use": True})
        self.assertTrue(payload["tools"][0]["strict"])
        self.assertFalse(payload["tools"][0]["input_schema"]["additionalProperties"])
        self.assertEqual(set(payload["tools"][0]["input_schema"]["required"]), service.ORDER_FIELDS)
        for unsupported in ("uniqueItems", "maxItems", "minLength", "maxLength"):
            self.assertNotIn(unsupported, json.dumps(payload["tools"][0]["input_schema"]))
        self.assertEqual(json.loads(payload["messages"][0]["content"])["context"], self.request["context"])

    def test_cloud_movement_order_and_supported_actions(self):
        order = move_order(["soldier_02"], destination="B", facing="A")
        planner = self.planner_with_response(cloud_response(order))
        self.assertEqual(planner.plan(self.request), order)
        health = planner.health()
        self.assertEqual(health["supported_actions"], list(service.SUPPORTED_ACTIONS))
        health["supported_actions"].clear()
        self.assertEqual(planner.health()["supported_actions"], list(service.SUPPORTED_ACTIONS))
        self.assertIn("move_to", json.loads(self.calls[0][0].data)["tools"][0]["input_schema"]["properties"]["action"]["enum"])

    def test_shared_rules_define_movement_and_preserve_unsupported_actions(self):
        for text in ("move_to walks one or more selected soldiers", "start must be null and end is the",
                     "ID in the all group", "Resolve numbered soldier selections",
                     "Square formations, cannon operation", "follow_player follows the actual player"):
            with self.subTest(text=text):
                self.assertIn(text, service.SYSTEM_PROMPT)
                self.assertIn(text, service.LOCAL_SYSTEM_PROMPT)

    def test_cloud_extended_orders_and_named_context(self):
        self.request["context"]["groups"]["beta"] = ["soldier_01"]
        for action in ("follow_player", "patrol", "create_group"):
            order = extended_order(action, group_name="Alpha" if action == "create_group" else None)
            with self.subTest(action=action):
                planner = self.planner_with_response(cloud_response(order))
                result = planner.plan(self.request)
                self.assertEqual(result, dict(order, group_name="alpha" if action == "create_group" else None))
                payload = json.loads(self.calls[-1][0].data)
                self.assertEqual(json.loads(payload["messages"][0]["content"])["context"], self.request["context"])
                self.assertEqual(planner.health()["protocol_version"], 2)
        legacy = line_order()
        del legacy["group_name"]
        with self.assertRaises(service.OrderError) as error:
            self.planner_with_response(cloud_response(legacy)).plan(self.request)
        self.assertEqual(error.exception.status, 502)

    def test_configurable_model_and_timeout(self):
        planner = self.planner_with_response(cloud_response())
        planner.model = "chosen-model"
        planner.timeout = 9
        planner.plan(self.request)
        self.assertEqual(json.loads(self.calls[0][0].data)["model"], "chosen-model")
        self.assertEqual(self.calls[0][1], 9)

    def test_missing_key_does_not_call_cloud(self):
        planner = service.PlannerService(opener=lambda *_args, **_kwargs: self.fail("cloud must not be called"))
        with self.assertRaises(service.OrderError) as raised:
            planner.plan(self.request)
        self.assertEqual(raised.exception.status, 503)
        self.assertFalse(planner.health()["ready"])
        self.assertNotIn("api_key", planner.health())

    def test_fixture_is_fixed_and_explicitly_labelled(self):
        planner = service.PlannerService(fixture=True, opener=lambda *_args, **_kwargs: self.fail("fixture must not call cloud"))
        order = planner.plan(self.request)
        self.request["prompt"] = "This is unrelated text: please stop everyone."
        self.assertEqual(planner.plan(self.request), order)
        self.assertIn("does not interpret", order["message"])
        self.assertEqual(planner.health(), {"mode": "fixture", "model": "fixed response (not an LLM)", "ready": True,
                                             "protocol_version": 2, "supported_actions": list(service.SUPPORTED_ACTIONS)})

    def test_fixture_missing_landmarks_returns_clarify(self):
        self.request["context"]["landmarks"] = {}
        order = service.PlannerService(fixture=True).plan(self.request)
        self.assertEqual(order["action"], "clarify")
        self.assertEqual(order["soldier_ids"], [])

    def test_fixture_optional_facing(self):
        del self.request["context"]["landmarks"]["C"]
        self.assertIsNone(service.PlannerService(fixture=True).plan(self.request)["facing"])

    def test_invalid_requests_do_not_call_cloud(self):
        planner = self.planner_with_response(cloud_response())
        self.request["context"]["soldiers"][0]["position"] = [math.nan, 0]
        with self.assertRaises(service.OrderError):
            planner.plan(self.request)
        self.assertEqual(self.calls, [])

    def test_cloud_terminal_states_do_not_execute(self):
        for reason in ("end_turn", "max_tokens", "refusal", "pause_turn", None):
            response = dict(cloud_response(), stop_reason=reason)
            with self.subTest(reason=reason), self.assertRaises(service.OrderError) as raised:
                self.planner_with_response(response).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_cloud_requires_exactly_one_named_tool(self):
        base = cloud_response()["content"][0]
        cases = (
            [], None, "tool", [base, base],
            [dict(base, name="run_code")],
            [{"type": "text", "text": "I refuse."}],
            [{"type": "refusal"}], [{"type": []}], [None],
            [dict(base, input={"action": "form_line"})],
            [dict(base, input=dict(line_order(), soldier_ids=["unknown", "soldier_01"]))],
        )
        for content in cases:
            response = dict(cloud_response(), content=content)
            with self.subTest(content=content), self.assertRaises(service.OrderError) as raised:
                self.planner_with_response(response).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_cloud_may_include_text_before_tool(self):
        response = cloud_response()
        response["content"].insert(0, {"type": "text", "text": "Here is the requested order."})
        self.assertEqual(self.planner_with_response(response).plan(self.request), line_order())

    def test_cloud_response_json_and_size_limits(self):
        for body in (b"not json", b'\xff', b'{"stop_reason":NaN}', b'{"stop_reason":"tool_use","stop_reason":"tool_use"}', b" " * (service.MAX_PROVIDER_BYTES + 1)):
            with self.subTest(body_start=body[:20]), self.assertRaises(service.OrderError) as raised:
                self.planner_with_response(body).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_cloud_errors_are_safe_and_release_capacity(self):
        errors = (
            urllib.error.HTTPError(service.CLOUD_URL, 401, "test-key-never-log", {}, None),
            urllib.error.HTTPError(service.CLOUD_URL, 403, "test-key-never-log", {}, None),
            urllib.error.HTTPError(service.CLOUD_URL, 404, "test-key-never-log", {}, None),
            urllib.error.HTTPError(service.CLOUD_URL, 429, "test-key-never-log", {}, None),
            urllib.error.HTTPError(service.CLOUD_URL, 500, "test-key-never-log", {}, None),
            urllib.error.URLError("test-key-never-log"), socket.timeout("test-key-never-log"),
            UnicodeError("test-key-never-log"),
        )
        for error in errors:
            def opener(_request, timeout):
                raise error
            planner = service.PlannerService(api_key="test-key-never-log", opener=opener)
            with self.subTest(error_type=type(error)), self.assertRaises(service.OrderError) as raised:
                planner.plan(self.request)
            self.assertEqual(raised.exception.status, 502)
            self.assertNotIn("test-key-never-log", str(raised.exception))
            self.assertTrue(planner._cloud_requests.acquire(blocking=False))
            self.assertTrue(planner._cloud_requests.acquire(blocking=False))
            planner._cloud_requests.release()
            planner._cloud_requests.release()

    def test_cloud_capacity_is_bounded(self):
        planner = self.planner_with_response(cloud_response())
        planner._cloud_requests.acquire()
        planner._cloud_requests.acquire()
        try:
            with self.assertRaises(service.OrderError) as raised:
                planner.plan(self.request)
            self.assertEqual(raised.exception.status, 503)
            self.assertEqual(self.calls, [])
        finally:
            planner._cloud_requests.release()
            planner._cloud_requests.release()

    def test_cloud_redirects_do_not_forward_key(self):
        handler = service.NoCloudRedirects()
        request = self.planner_with_response(cloud_response())
        request.plan(self.request)
        with self.assertRaises(urllib.error.HTTPError):
            handler.redirect_request(self.calls[0][0], None, 302, "redirect", {}, "https://other.example/")


class LocalTests(unittest.TestCase):
    def setUp(self):
        self.request = request_data()
        self.calls = []

    def planner(self, responses=None, **settings):
        values = {
            "/api/tags": {"models": [{"name": service.DEFAULT_LOCAL_MODEL}]},
            "/api/show": {"capabilities": ["completion", "thinking"], "thinking": {"values": [True, False], "default": True}},
            "/api/chat": local_response(),
        }
        values.update(responses or {})
        def opener(request, timeout):
            self.calls.append((request, timeout))
            path = request.full_url[len(planner.ollama_url):]
            response = values[path]
            if isinstance(response, Exception):
                raise response
            if callable(response):
                response = response(request)
            data = response if isinstance(response, bytes) else json.dumps(response).encode()
            return io.BytesIO(data)
        planner = service.PlannerService(
            provider="ollama", local_opener=opener,
            opener=lambda *_args, **_kwargs: self.fail("local inference must not call the cloud"), **settings,
        )
        return planner

    def test_local_payload_uses_existing_schema_and_no_key(self):
        planner = self.planner(api_key="test-key-never-log")
        self.assertEqual(planner.plan(self.request), line_order())
        self.assertEqual(planner.mode, "local")
        self.assertEqual(planner.model, service.DEFAULT_LOCAL_MODEL)
        self.assertEqual(len(self.calls), 2)
        metadata_request, probe_timeout = self.calls[0]
        self.assertEqual(metadata_request.full_url, service.DEFAULT_OLLAMA_URL + "/api/show")
        self.assertEqual(json.loads(metadata_request.data), {"model": service.DEFAULT_LOCAL_MODEL})
        self.assertEqual(probe_timeout, 3)
        request, timeout = self.calls[1]
        self.assertEqual(request.full_url, service.DEFAULT_OLLAMA_URL + "/api/chat")
        self.assertEqual(timeout, 120)
        self.assertIsNone(request.get_header("X-api-key"))
        self.assertNotIn("test-key-never-log", request.data.decode())
        payload = json.loads(request.data)
        expected_schema = service.order_tool(self.request["context"])["input_schema"]
        expected_schema["properties"]["message"].update(minLength=1, maxLength=160,
                                                        description="One brief sentence of at most 160 characters, without soldier IDs or coordinate lists.")
        self.assertEqual(payload["format"], expected_schema)
        self.assertEqual(payload["model"], service.DEFAULT_LOCAL_MODEL)
        self.assertFalse(payload["stream"])
        self.assertFalse(payload["think"])
        self.assertEqual(payload["keep_alive"], "10m")
        self.assertEqual(payload["options"], {"num_ctx": 4096, "num_predict": 768, "temperature": 0, "num_thread": 8,
                                               "presence_penalty": 0.0, "repeat_penalty": 1.0})
        self.assertEqual(payload["messages"][0]["role"], "system")
        self.assertNotIn("emit_order tool call", payload["messages"][0]["content"])
        user = json.loads(payload["messages"][1]["content"])
        self.assertEqual(set(user), {"context", "player_order"})
        self.assertEqual(user["player_order"], self.request["prompt"])
        self.assertEqual(user["context"], self.request["context"])
        self.assertNotIn("order_schema", user)
        self.assertNotIn("order_schema", payload["messages"][0]["content"])
        self.assertEqual(planner.last_local_metrics["eval_count"], 40)

    def test_local_payload_lists_members_of_mentioned_groups(self):
        self.request["context"]["groups"]["alpha"] = ["soldier_01", "soldier_02"]
        self.request["prompt"] = "move group Alpha to A"
        original = copy.deepcopy(self.request)
        planner = self.planner()
        planner.plan(self.request)
        user = json.loads(json.loads(self.calls[1][0].data)["messages"][1]["content"])
        self.assertEqual(user["player_order"], "move group Alpha (members: soldier_01, soldier_02) to A")
        self.assertEqual(user["context"], self.request["context"])
        self.assertEqual(self.request, original)

    def test_group_annotation_rules(self):
        groups = {"all": ["soldier_01", "soldier_02", "soldier_03"], "alpha": ["soldier_01"],
                  "alpha-2": ["soldier_02"], "c": ["soldier_03"]}
        annotate = service.annotate_group_names
        self.assertEqual(annotate("alpha-2 and ALPHA, go to C; alpha again", groups),
                         "alpha-2 (members: soldier_02) and ALPHA (members: soldier_01), go to C; alpha again")
        self.assertEqual(annotate("alphabet go to A", groups), "alphabet go to A")
        self.assertEqual(annotate("all soldiers go to C", groups), "all soldiers go to C")
        self.assertEqual(annotate("make alpha follow me", groups), "make alpha (members: soldier_01) follow me")
        self.assertEqual(annotate("the group named alpha goes to A", groups),
                         "the group named alpha (members: soldier_01) goes to A")
        for prompt in ("Create group alpha with soldier 2", "make alpha a group", "new group alpha",
                       "name soldiers 1 and 2 alpha", "call them alpha"):
            with self.subTest(prompt=prompt):
                self.assertEqual(annotate(prompt, groups), prompt)

    def test_local_sampler_explicitly_overrides_model_chat_penalties(self):
        metadata = {"parameters": "presence_penalty 1.5\nrepeat_penalty 1.15\ntemperature 0.7",
                    "thinking": {"values": [False, True]}}
        self.planner({"/api/show": metadata}).plan(self.request)
        payload = json.loads(self.calls[-1][0].data)
        self.assertEqual(payload["options"]["presence_penalty"], 0.0)
        self.assertEqual(payload["options"]["repeat_penalty"], 1.0)
        self.assertEqual(payload["options"]["temperature"], 0)
        self.assertEqual(payload["options"]["num_ctx"], 4096)
        self.assertEqual(payload["options"]["num_predict"], 768)
        self.assertEqual(payload["options"]["num_thread"], 8)
        self.assertFalse(payload["think"])
        self.assertEqual(payload["format"]["properties"]["message"]["maxLength"], 160)
        self.assertNotIn("order_schema", json.loads(payload["messages"][1]["content"]))

    def test_local_message_bounds_do_not_modify_cloud_schema(self):
        self.planner().plan(self.request)
        payload = json.loads(self.calls[-1][0].data)
        message_schema = payload["format"]["properties"]["message"]
        self.assertEqual((message_schema["minLength"], message_schema["maxLength"]), (1, 160))
        self.assertNotIn("order_schema", json.loads(payload["messages"][1]["content"]))
        self.assertIn("exactly seven fields", payload["messages"][0]["content"])
        self.assertIn("one brief sentence of at most 160 characters", payload["messages"][0]["content"])
        self.assertIn("Do not repeat\nsoldier IDs or coordinate lists", payload["messages"][0]["content"])
        self.assertNotIn("at most 160 characters", service.SYSTEM_PROMPT)
        cloud_calls = []
        def opener(request, timeout):
            cloud_calls.append(request)
            return io.BytesIO(json.dumps(cloud_response()).encode())
        service.PlannerService(api_key="test-key", opener=opener).plan(self.request)
        schema = json.loads(cloud_calls[0].data)["tools"][0]["input_schema"]
        for keyword in ("minLength", "maxLength", "uniqueItems", "maxItems"):
            self.assertNotIn(keyword, json.dumps(schema))
        self.assertNotIn("minLength", service.order_tool(self.request["context"])["input_schema"]["properties"]["message"])

    def test_local_message_validation_keeps_the_shared_500_character_limit(self):
        for message in ("", "   ", "x" * 501):
            with self.subTest(length=len(message)), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": local_response(dict(move_order(), message=message))}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)
        for length in (160, 500):
            order = dict(move_order(), message="x" * length)
            with self.subTest(length=length):
                self.assertEqual(self.planner({"/api/chat": local_response(order)}).plan(self.request), order)

    def test_local_movement_order_is_validated_without_cloud_fallback(self):
        order = move_order(["soldier_01", "soldier_03"], destination="A", facing="B")
        planner = self.planner({"/api/chat": local_response(order)})
        self.assertEqual(planner.plan(self.request), order)
        payload = json.loads(self.calls[-1][0].data)
        self.assertIn("move_to", payload["format"]["properties"]["action"]["enum"])
        self.assertEqual(payload["messages"][0]["content"], service.LOCAL_SYSTEM_PROMPT)
        for changes in ({"start": "A"}, {"end": None}, {"soldier_ids": []}):
            with self.subTest(changes=changes), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": local_response(dict(move_order(), **changes))}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_local_extended_orders_named_context_and_legacy_refusal(self):
        self.request["context"]["groups"]["beta"] = ["soldier_01"]
        for action in ("follow_player", "patrol", "create_group"):
            order = extended_order(action, group_name="Alpha" if action == "create_group" else None)
            with self.subTest(action=action):
                result = self.planner({"/api/chat": local_response(order)}).plan(self.request)
                self.assertEqual(result, dict(order, group_name="alpha" if action == "create_group" else None))
                payload = json.loads(self.calls[-1][0].data)
                self.assertEqual(json.loads(payload["messages"][1]["content"])["context"], self.request["context"])
                self.assertEqual(set(payload["format"]["required"]), service.ORDER_FIELDS)
        legacy = line_order()
        del legacy["group_name"]
        with self.assertRaises(service.OrderError) as error:
            self.planner({"/api/chat": local_response(legacy)}).plan(self.request)
        self.assertEqual(error.exception.status, 502)

    def test_all_health_states_advertise_protocol_and_actions(self):
        planners = [self.planner(), self.planner({"/api/tags": {"models": []}}),
                    service.PlannerService(), service.PlannerService(api_key="test-key"),
                    service.PlannerService(fixture=True)]
        for planner in planners:
            with self.subTest(mode=planner.mode, ready=planner.health()["ready"]):
                health = planner.health()
                self.assertIs(type(health["protocol_version"]), int)
                self.assertEqual(health["protocol_version"], 2)
                self.assertEqual(health["supported_actions"], list(service.SUPPORTED_ACTIONS))

    def test_shared_prompts_define_new_actions_names_and_compound_clarification(self):
        for prompt in (service.SYSTEM_PROMPT, service.LOCAL_SYSTEM_PROMPT):
            for text in ("follow_player", "patrol", "create_group", "group_name must be null",
                         "compound multi-action orders", "Unknown group names", "missing new group names",
                         "At most eight named groups", "Groups may overlap", "requested order"):
                with self.subTest(text=text):
                    self.assertIn(text, prompt)
        self.assertIn("actual context.groups membership", service.LOCAL_SYSTEM_PROMPT)

    def test_local_selection_and_landmark_directives_are_local_only(self):
        directives = (
            "Unless a subset is explicitly requested, select the entire all group.",
            "Everyone or\nall means every listed soldier ID, not just the minimum two needed for a line.",
            "Set facing to null unless the player explicitly requests a facing landmark.",
            "If any requested landmark is missing or unknown, return clarify.",
            "Never substitute\nanother existing landmark for a requested one.",
        )
        self.planner().plan(self.request)
        payload = json.loads(self.calls[-1][0].data)
        self.assertEqual(payload["messages"][0]["content"], service.LOCAL_SYSTEM_PROMPT)
        for directive in directives:
            with self.subTest(directive=directive):
                self.assertIn(directive, service.LOCAL_SYSTEM_PROMPT)
                self.assertNotIn(directive, service.SYSTEM_PROMPT)
                self.assertNotIn(directive, service.ORDER_RULES)
        self.assertEqual(service.SYSTEM_PROMPT, "You interpret orders for soldiers in a fictional game sandbox.\nReturn exactly one emit_order tool call.\n" + service.ORDER_RULES)

    def test_local_user_payload_orders_stable_fields_without_mutating_request(self):
        original = json.dumps(self.request)
        self.planner().plan(self.request)
        payload = json.loads(self.calls[-1][0].data)
        content = payload["messages"][1]["content"]
        user = json.loads(content)
        self.assertEqual(list(user), ["context", "player_order"])
        self.assertEqual(list(user["context"]), ["groups", "landmarks", "soldiers"])
        self.assertEqual(content, json.dumps(user, allow_nan=False, separators=(",", ":")))
        self.assertNotIn("order_schema", user)
        expected_schema = service.order_tool(self.request["context"])["input_schema"]
        expected_schema["properties"]["message"].update(minLength=1, maxLength=160,
                                                        description="One brief sentence of at most 160 characters, without soldier IDs or coordinate lists.")
        self.assertEqual(payload["format"], expected_schema)
        self.assertEqual(user["context"], self.request["context"])
        self.assertEqual(user["player_order"], self.request["prompt"])
        self.assertEqual(json.dumps(self.request), original)

    def test_local_url_normalization_and_restrictions(self):
        self.assertEqual(service.normalize_ollama_url("http://localhost:11434"), service.DEFAULT_OLLAMA_URL)
        self.assertEqual(service.normalize_ollama_url("HTTP://LOCALHOST:01234"), "http://127.0.0.1:1234")
        self.assertEqual(service.normalize_ollama_url("http://127.0.0.1"), "http://127.0.0.1")
        invalid = (
            None, "", "https://localhost:11434", "http://example.com:11434", "http://127.0.0.2:11434",
            "http://localhost:0", "http://localhost:65536", "http://localhost:999999", "http://localhost:bad",
            "http://localhost:11434/", "http://localhost:11434/api/chat", "http://name:secret@localhost:11434",
            "http://localhost:11434?", "http://localhost:11434#", "http://[::1]:11434", " http://localhost:11434",
        )
        for url in invalid:
            with self.subTest(url=url), self.assertRaises(ValueError):
                service.normalize_ollama_url(url)
        planner = self.planner(ollama_url="http://localhost:1234", timeout=9)
        planner.plan(self.request)
        self.assertEqual(self.calls[-1][0].full_url, "http://127.0.0.1:1234/api/chat")
        self.assertEqual(self.calls[-1][1], 9)

    def test_cloud_model_names_and_invalid_configuration_are_rejected(self):
        for model in ("qwen3.5:cloud", "qwen3.5:397b-cloud", "name-CLOUD", "", "bad model", "a" * 201, None):
            if model is None:
                continue
            with self.subTest(model=model), self.assertRaises(ValueError):
                self.planner(model=model)
        for provider in ("openai", None, ""):
            with self.subTest(provider=provider), self.assertRaises(ValueError):
                service.PlannerService(provider=provider)
        for timeout in (0, -1, True, math.inf, math.nan, 301):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                self.planner(timeout=timeout)

    def test_thinking_is_disabled_only_when_explicitly_supported(self):
        for metadata in ({}, {"capabilities": ["thinking"]}, {"thinking": {}}, {"thinking": {"values": [True]}},
                         {"thinking": {"values": ["false"]}}, {"thinking": {"values": [0]}}, {"thinking": {"values": False}}):
            with self.subTest(metadata=metadata):
                self.calls = []
                self.planner({"/api/show": metadata}).plan(self.request)
                self.assertNotIn("think", json.loads(self.calls[-1][0].data))
        self.calls = []
        self.planner({"/api/show": {"thinking": {"values": [False]}}}).plan(self.request)
        self.assertIs(json.loads(self.calls[-1][0].data)["think"], False)

    def test_metadata_is_cached_between_orders(self):
        planner = self.planner()
        planner.plan(self.request)
        planner.plan(self.request)
        self.assertEqual(sum(request.full_url.endswith("/api/show") for request, _timeout in self.calls), 1)
        self.assertEqual(sum(request.full_url.endswith("/api/chat") for request, _timeout in self.calls), 2)

    def test_remote_metadata_is_rejected_before_inference(self):
        for metadata in ({"remote_host": "https://ollama.com"}, {"remote_model": "other:cloud"}, {"remote": True}, {"cloud": True}):
            with self.subTest(metadata=metadata), self.assertRaises(service.OrderError) as raised:
                self.calls = []
                self.planner({"/api/show": metadata}).plan(self.request)
            self.assertEqual(raised.exception.status, 503)
            self.assertEqual(len(self.calls), 1)
            self.assertIn("remote", str(raised.exception))

    def test_health_checks_local_weights_without_generating(self):
        planner = self.planner()
        expected = {"mode": "local", "model": service.DEFAULT_LOCAL_MODEL, "ready": True, "request_timeout": 150,
                    "supported_actions": list(service.SUPPORTED_ACTIONS), "protocol_version": 2}
        self.assertEqual(planner.health(), expected)
        self.assertEqual(len(self.calls), 1)
        self.assertTrue(self.calls[0][0].full_url.endswith("/api/tags"))
        self.assertEqual(self.calls[0][0].get_method(), "GET")
        self.assertEqual(self.calls[0][1], 1.5)
        changed = planner.health()
        changed["ready"] = False
        changed["supported_actions"].clear()
        self.assertEqual(planner.health(), expected)
        self.assertEqual(len(self.calls), 1)
        with mock.patch.object(service.time, "monotonic", return_value=planner._health_cache[0] + 2):
            self.assertEqual(planner.health(), expected)
        self.assertEqual(len(self.calls), 2)

    def test_health_reports_missing_model(self):
        for tags in ({"models": []}, {"models": [{"name": "qwen3.5:9b"}]}):
            value = self.planner({"/api/tags": tags}).health()
            self.assertFalse(value["ready"])
            self.assertIn("ollama pull " + service.DEFAULT_LOCAL_MODEL, value["error"])

    def test_health_rejects_remote_weights_and_malformed_data(self):
        for tags in ({"models": [{"name": service.DEFAULT_LOCAL_MODEL, "remote_host": "https://ollama.com"}]},
                     {"models": [None]}, {"models": None}, {}, b"invalid", []):
            with self.subTest(tags=tags):
                value = self.planner({"/api/tags": tags}).health()
                self.assertFalse(value["ready"])
                self.assertIn("error", value)

    def test_health_reports_unavailable_runtime(self):
        value = self.planner({"/api/tags": urllib.error.URLError("connection refused")}).health()
        self.assertFalse(value["ready"])
        self.assertIn("ollama serve", value["error"])

    def test_model_alias_without_tag_matches_latest(self):
        planner = self.planner({"/api/tags": {"models": [{"name": "chosen-model:latest"}]},
                                "/api/chat": local_response(model="chosen-model:latest")}, model="chosen-model")
        self.assertTrue(planner.health()["ready"])
        self.assertEqual(planner.plan(self.request), line_order())

    def test_local_completion_states_must_finish(self):
        for values in ({"done": False}, {"done": 1}, {"done": None}, {"done_reason": "length"},
                       {"done_reason": "load"}, {"done_reason": "refusal"}, {"done_reason": None}):
            with self.subTest(values=values), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": local_response(**values)}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_local_response_must_be_an_assistant_json_order(self):
        messages = (
            None, "order", {"role": "user", "content": json.dumps(line_order())},
            {"role": "assistant", "content": ""}, {"role": "assistant", "content": []},
            {"role": "assistant", "content": "```json\n" + json.dumps(line_order()) + "\n```"},
            {"role": "assistant", "content": "I refuse."},
            {"role": "assistant", "content": json.dumps(line_order()), "tool_calls": [{}]},
        )
        for message in messages:
            with self.subTest(message=message), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": local_response(message=message)}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_local_order_semantics_use_existing_validation(self):
        for values in ({"soldier_ids": ["unknown", "soldier_01"]}, {"action": "attack"}, {"end": "D"},
                       {"soldier_ids": ["soldier_01", "soldier_01"]}, {"message": ""}, {"extra": "code"}):
            with self.subTest(values=values), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": local_response(dict(line_order(), **values))}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)

    def test_local_content_rejects_duplicate_and_nonfinite_fields(self):
        for content in ('{"action":"stop","action":"form_line"}', '{"action":NaN}', '[1,2]', 'not json'):
            message = {"role": "assistant", "content": content}
            with self.subTest(content=content), self.assertRaises(service.OrderError):
                self.planner({"/api/chat": local_response(message=message)}).plan(self.request)

    def test_local_response_model_must_match_and_be_local(self):
        for values in ({"model": "different:4b"}, {"model": "qwen3.5:cloud"}, {"model": None},
                       {"remote_host": "https://ollama.com"}, {"remote_model": "remote"}, {"cloud": True}):
            with self.subTest(values=values), self.assertRaises(service.OrderError):
                self.planner({"/api/chat": local_response(**values)}).plan(self.request)

    def test_local_response_body_bounds_and_encoding(self):
        for body in (b"invalid", b'\xff', b'{"done":true,"done":false}', b' ',
                     b" " * (service.MAX_PROVIDER_BYTES + 1), b'[]', b'{"error":"private detail"}'):
            with self.subTest(body_start=body[:20]), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": body}).plan(self.request)
            self.assertEqual(raised.exception.status, 502)
            self.assertNotIn("private detail", str(raised.exception))

    def test_local_error_does_not_call_cloud_and_releases_capacity(self):
        errors = (
            (urllib.error.URLError("private detail"), 503), (socket.timeout("private detail"), 504),
            (urllib.error.URLError(socket.timeout("private detail")), 504), (OSError("private detail"), 503),
            (UnicodeError("private detail"), 503),
        )
        for error, status in errors:
            planner = self.planner({"/api/chat": error}, api_key="test-key-never-log")
            with self.subTest(error_type=type(error)), self.assertRaises(service.OrderError) as raised:
                planner.plan(self.request)
            self.assertEqual(raised.exception.status, status)
            self.assertNotIn("private detail", str(raised.exception))
            self.assertTrue(planner._local_requests.acquire(blocking=False))
            planner._local_requests.release()

    def test_local_http_errors_report_missing_memory_and_redirects(self):
        cases = (
            (404, b'{"error":"private detail"}', 503, "ollama pull"),
            (500, b'{"error":"not enough memory for model"}', 502, "enough memory"),
            (500, b'{"error":"private detail"}', 502, "Check the local server log"),
            (302, b'{"error":"private detail"}', 502, "redirects"),
        )
        for code, body, status, text in cases:
            response_body = io.BytesIO(body)
            error = urllib.error.HTTPError(service.DEFAULT_OLLAMA_URL + "/api/chat", code, "private detail", {}, response_body)
            with self.subTest(code=code), self.assertRaises(service.OrderError) as raised:
                self.planner({"/api/chat": error}).plan(self.request)
            self.assertEqual(raised.exception.status, status)
            self.assertIn(text, str(raised.exception))
            self.assertNotIn("private detail", str(raised.exception))
            self.assertTrue(response_body.closed)

    def test_local_capacity_is_one_request(self):
        planner = self.planner()
        planner._local_requests.acquire()
        try:
            with self.assertRaises(service.OrderError) as raised:
                planner.plan(self.request)
            self.assertEqual(raised.exception.status, 503)
            self.assertEqual(self.calls, [])
        finally:
            planner._local_requests.release()

    def test_invalid_request_does_not_contact_local_model(self):
        self.request["context"]["landmarks"]["I"] = [1, 2]
        with self.assertRaises(service.OrderError):
            self.planner().plan(self.request)
        self.assertEqual(self.calls, [])

    def test_local_opener_disables_proxies_and_redirects(self):
        request = urllib.request.Request(service.DEFAULT_OLLAMA_URL + "/api/chat")
        with mock.patch.object(service.urllib.request, "build_opener") as build:
            service.open_local_request(request, 7)
            handlers = build.call_args.args
            self.assertIsInstance(handlers[0], urllib.request.ProxyHandler)
            self.assertEqual(handlers[0].proxies, {})
            self.assertIsInstance(handlers[1], service.NoLocalRedirects)
            build.return_value.open.assert_called_once_with(request, timeout=7)
        with self.assertRaises(urllib.error.HTTPError):
            service.NoLocalRedirects().redirect_request(request, None, 302, "redirect", {}, "https://other.example/")


def torch_available():
    return importlib.util.find_spec("torch") is not None and importlib.util.find_spec("transformers") is not None


class TaggerProviderTests(unittest.TestCase):
    def setUp(self):
        self.request = request_data()

    def test_missing_tagger_is_reported_and_executes_nothing(self):
        planner = service.PlannerService(provider="bert", tagger_dir="/nonexistent/order_tagger",
                                         local_opener=lambda *_args, **_kwargs: self.fail("Ollama must not be called"))
        health = planner.health()
        self.assertEqual((health["mode"], health["ready"], health["protocol_version"]), ("local", False, 2))
        self.assertEqual(health["model"], "order-tagger:order_tagger")
        self.assertTrue(health["error"])
        with self.assertRaises(service.OrderError) as error:
            planner.plan(self.request)
        self.assertEqual(error.exception.status, 503)

    def test_tagger_errors_never_fall_back(self):
        planner = service.PlannerService(provider="bert", tagger_dir="/nonexistent/order_tagger",
                                         opener=lambda *_args, **_kwargs: self.fail("cloud must not be called"),
                                         local_opener=lambda *_args, **_kwargs: self.fail("Ollama must not be called"))
        with self.assertRaises(service.OrderError):
            planner.plan(self.request)

    @unittest.skipUnless(torch_available() and (service.DEFAULT_TAGGER_DIR / "model.pt").is_file(), "needs PyTorch, transformers and models/order_tagger")
    def test_trained_tagger_interprets_orders(self):
        planner = service.PlannerService(provider="bert")
        self.assertTrue(planner.health()["ready"], planner.health().get("error"))
        order = planner.plan(self.request)
        self.assertEqual((order["action"], order["start"], order["end"], order["facing"]), ("form_line", "A", "B", "C"))
        self.request["context"]["groups"]["alpha"] = ["soldier_01", "soldier_02"]
        self.request["prompt"] = "move group alpha to A"
        order = planner.plan(self.request)
        self.assertEqual((order["action"], order["soldier_ids"], order["end"]), ("move_to", ["soldier_01", "soldier_02"], "A"))
        self.request["prompt"] = "fire the cannons"
        self.assertEqual(planner.plan(self.request)["action"], "clarify")


class CliTests(unittest.TestCase):
    def run_cli(self, args=(), environment=None):
        with mock.patch.dict(service.os.environ, environment or {}, clear=True), \
             mock.patch("sys.argv", [str(SERVICE_PATH), *args]), \
             mock.patch.object(service, "OrderServer") as server, \
             mock.patch("sys.stdout", new_callable=io.StringIO) as output:
            server.return_value.serve_forever.side_effect = KeyboardInterrupt
            service.main()
            planner = server.call_args.args[1]
            server.return_value.server_close.assert_called_once()
            return planner, output.getvalue()

    def test_cli_defaults_to_the_bert_tagger(self):
        planner, output = self.run_cli()
        self.assertEqual((planner.mode, planner.provider), ("local", "bert"))
        self.assertEqual(planner.model, service.tagger_model_name(service.DEFAULT_TAGGER_DIR))
        self.assertIn("No cloud fallback", output)
        planner, _output = self.run_cli(["--tagger-dir", "/nonexistent/tagger"])
        self.assertFalse(planner.health()["ready"])

    def test_cli_ollama_provider_without_key(self):
        planner, output = self.run_cli(["--provider", "ollama"])
        self.assertEqual(planner.mode, "local")
        self.assertEqual(planner.model, service.DEFAULT_LOCAL_MODEL)
        self.assertEqual(planner.ollama_url, service.DEFAULT_OLLAMA_URL)
        self.assertIn("No cloud fallback", output)

    def test_anthropic_is_an_explicit_choice(self):
        planner, output = self.run_cli(["--provider", "anthropic"])
        self.assertEqual(planner.mode, "cloud")
        self.assertEqual(planner.model, service.DEFAULT_MODEL)
        self.assertIn("ANTHROPIC_API_KEY", output)
        planner, _output = self.run_cli(environment={"SANDBOX_PROVIDER": "anthropic", "SANDBOX_MODEL": "chosen-model", "ANTHROPIC_API_KEY": "test-key"})
        self.assertEqual(planner.model, "chosen-model")
        self.assertEqual(planner.api_key, "test-key")

    def test_local_environment_and_fixture_are_explicit(self):
        planner, _output = self.run_cli(environment={"SANDBOX_PROVIDER": "ollama", "SANDBOX_MODEL": "other:4b", "SANDBOX_OLLAMA_URL": "http://localhost:1234"})
        self.assertEqual(planner.model, "other:4b")
        self.assertEqual(planner.ollama_url, "http://127.0.0.1:1234")
        planner, output = self.run_cli(["--fixture"], {"SANDBOX_OLLAMA_URL": "invalid"})
        self.assertEqual(planner.mode, "fixture")
        self.assertIn("not interpreted", output)

    def test_invalid_cli_configuration_fails_before_listening(self):
        for environment in ({"SANDBOX_PROVIDER": "other"}, {"SANDBOX_PROVIDER": "ollama", "SANDBOX_MODEL": "qwen:cloud"},
                            {"SANDBOX_PROVIDER": "ollama", "SANDBOX_OLLAMA_URL": "https://external.example"}):
            with mock.patch.dict(service.os.environ, environment, clear=True), \
                 mock.patch("sys.argv", [str(SERVICE_PATH)]), \
                 mock.patch.object(service, "OrderServer") as server, \
                 mock.patch("sys.stderr", new_callable=io.StringIO), \
                 self.subTest(environment=environment), self.assertRaises(SystemExit):
                service.main()
            server.assert_not_called()


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = service.OrderServer(("127.0.0.1", 0), service.PlannerService(fixture=True))
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def send(self, method="POST", path="/orders", body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=2)
        if body is None and method == "POST":
            body = json.dumps(request_data())
        actual_headers = {"Content-Type": "application/json"}
        actual_headers.update(headers or {})
        try:
            connection.request(method, path, body=body, headers=actual_headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read()), dict(response.getheaders())
        finally:
            connection.close()

    def test_health_and_order_round_trip(self):
        status, value, headers = self.send("GET", "/health")
        self.assertEqual(status, 200)
        self.assertEqual(value["mode"], "fixture")
        self.assertTrue(value["ready"])
        self.assertEqual(value["protocol_version"], 2)
        self.assertEqual(value["supported_actions"], list(service.SUPPORTED_ACTIONS))
        self.assertEqual(headers["Cache-Control"], "no-store")
        status, value, _headers = self.send()
        self.assertEqual(status, 200)
        self.assertEqual(value["request_id"], 7)
        self.assertEqual(value["mode"], "fixture")
        self.assertEqual(value["order"]["action"], "form_line")

    def test_localhost_host_is_allowed(self):
        self.assertEqual(self.send(headers={"Host": "localhost:%d" % self.port})[0], 200)

    def test_browser_origin_and_rebinding_hosts_are_rejected(self):
        for headers in ({"Origin": "https://example.com"}, {"Origin": "null"}, {"Origin": "http://127.0.0.1:%d" % self.port}, {"Host": "other.example:%d" % self.port}, {"Host": "127.0.0.1:1"}):
            with self.subTest(headers=headers):
                status, _value, response_headers = self.send(headers=headers)
                self.assertEqual(status, 403)
                self.assertNotIn("Access-Control-Allow-Origin", response_headers)
        self.assertEqual(self.send("OPTIONS", "/orders")[0], 403)

    def test_wrong_paths_and_media_types_are_rejected(self):
        self.assertEqual(self.send(path="/other")[0], 404)
        self.assertEqual(self.send("GET", "/orders")[0], 404)
        self.assertEqual(self.send(headers={"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.send(headers={"Content-Type": "application/json; charset=utf-8"})[0], 200)

    def test_body_size_and_transfer_encoding(self):
        self.assertEqual(self.send(body="x" * (service.MAX_BODY_BYTES + 1))[0], 413)
        self.assertEqual(self.send(body="")[0], 400)
        self.assertEqual(self.send(headers={"Transfer-Encoding": "chunked"})[0], 400)
        self.assertEqual(self.send(headers={"Content-Length": "invalid"})[0], 411)

    def test_bad_json_and_context_return_useful_errors(self):
        self.assertEqual(self.send(body="not json")[0], 400)
        value = request_data()
        value["context"]["landmarks"]["I"] = [1, 2]
        status, error, _headers = self.send(body=json.dumps(value))
        self.assertEqual(status, 400)
        self.assertEqual(error["request_id"], 7)
        self.assertIn("landmarks", error["error"])

    def test_duplicate_length_and_host_headers_are_rejected(self):
        for duplicate, expected in (("Content-Length", 411), ("Host", 403)):
            connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=2)
            body = json.dumps(request_data()).encode()
            try:
                connection.putrequest("POST", "/orders")
                connection.putheader("Content-Type", "application/json")
                connection.putheader("Content-Length", str(len(body)))
                connection.putheader(duplicate, str(len(body)) if duplicate == "Content-Length" else "127.0.0.1:%d" % self.port)
                connection.endheaders(body)
                response = connection.getresponse()
                self.assertEqual(response.status, expected)
                response.read()
            finally:
                connection.close()

    def test_cloud_configuration_error_is_returned_as_json(self):
        previous = self.server.service
        self.server.service = service.PlannerService()
        try:
            status, value, _headers = self.send()
            self.assertEqual(status, 503)
            self.assertEqual(value["mode"], "cloud")
            self.assertEqual(value["request_id"], 7)
            self.assertIn("ANTHROPIC_API_KEY", value["error"])
        finally:
            self.server.service = previous

    def test_invalid_cloud_result_is_returned_as_json(self):
        previous = self.server.service
        self.server.service = service.PlannerService(api_key="test-key-never-log", opener=lambda *_args, **_kwargs: io.BytesIO(b"invalid"))
        try:
            status, value, _headers = self.send()
            self.assertEqual(status, 502)
            self.assertEqual(value["mode"], "cloud")
            self.assertEqual(value["request_id"], 7)
            self.assertNotIn("test-key-never-log", json.dumps(value))
        finally:
            self.server.service = previous

    def test_local_health_and_exact_order_envelope(self):
        def opener(request, timeout):
            if request.full_url.endswith("/api/tags"):
                value = {"models": [{"name": service.DEFAULT_LOCAL_MODEL}]}
            elif request.full_url.endswith("/api/show"):
                value = {"thinking": {"values": [False, True], "default": True}}
            else:
                value = local_response()
            return io.BytesIO(json.dumps(value).encode())
        previous = self.server.service
        self.server.service = service.PlannerService(provider="ollama", local_opener=opener)
        try:
            status, value, _headers = self.send("GET", "/health")
            self.assertEqual(status, 200)
            self.assertEqual(value, {"mode": "local", "ready": True, "model": service.DEFAULT_LOCAL_MODEL, "request_timeout": 150,
                                     "supported_actions": list(service.SUPPORTED_ACTIONS), "protocol_version": 2})
            status, value, _headers = self.send()
            self.assertEqual(status, 200)
            self.assertEqual(value, {"request_id": 7, "mode": "local", "order": line_order()})
        finally:
            self.server.service = previous

    def test_movement_envelope_round_trip_in_local_and_cloud_modes(self):
        order = move_order(["soldier_02"], destination="B", facing="A")
        def local_opener(request, timeout):
            if request.full_url.endswith("/api/tags"):
                value = {"models": [{"name": service.DEFAULT_LOCAL_MODEL}]}
            elif request.full_url.endswith("/api/show"):
                value = {"thinking": {"values": [False, True]}}
            else:
                value = local_response(order)
            return io.BytesIO(json.dumps(value).encode())
        planners = (
            service.PlannerService(provider="ollama", local_opener=local_opener),
            service.PlannerService(api_key="test-key", opener=lambda *_args, **_kwargs: io.BytesIO(json.dumps(cloud_response(order)).encode())),
        )
        previous = self.server.service
        try:
            for planner in planners:
                self.server.service = planner
                with self.subTest(mode=planner.mode):
                    status, health, _headers = self.send("GET", "/health")
                    self.assertEqual(status, 200)
                    self.assertIn("move_to", health["supported_actions"])
                    body = request_data()
                    body["prompt"] = "Send soldier_02 to B and face A."
                    status, value, _headers = self.send(body=json.dumps(body))
                    self.assertEqual(status, 200)
                    self.assertEqual(value, {"request_id": 7, "mode": planner.mode, "order": order})
                    self.assertEqual(set(value["order"]), service.ORDER_FIELDS)
        finally:
            self.server.service = previous

    def test_extended_orders_round_trip_in_both_provider_modes(self):
        previous = self.server.service
        body = request_data()
        body["context"]["groups"]["beta"] = ["soldier_01"]
        try:
            for action in ("follow_player", "patrol", "create_group"):
                order = extended_order(action, group_name="Alpha" if action == "create_group" else None)
                def local_opener(request, timeout):
                    value = {"thinking": {"values": [False]}} if request.full_url.endswith("/api/show") else local_response(order)
                    return io.BytesIO(json.dumps(value).encode())
                planners = (
                    service.PlannerService(provider="ollama", local_opener=local_opener),
                    service.PlannerService(api_key="test-key", opener=lambda *_args, **_kwargs: io.BytesIO(json.dumps(cloud_response(order)).encode())),
                )
                for planner in planners:
                    self.server.service = planner
                    with self.subTest(action=action, mode=planner.mode):
                        status, value, _headers = self.send(body=json.dumps(body))
                        self.assertEqual(status, 200)
                        expected = dict(order, group_name="alpha" if action == "create_group" else None)
                        self.assertEqual(value, {"request_id": 7, "mode": planner.mode, "order": expected})
                        self.assertEqual(body["context"]["groups"], request_data()["context"]["groups"] | {"beta": ["soldier_01"]})
        finally:
            self.server.service = previous

    def test_bind_must_be_loopback(self):
        with self.assertRaises(ValueError):
            service.OrderServer(("0.0.0.0", 0), service.PlannerService(fixture=True))


if __name__ == "__main__":
    unittest.main()
