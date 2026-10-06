import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))

import generate_order_dataset as generator  # noqa: E402
import order_resolver as resolver  # noqa: E402
import sandbox_order_service as service  # noqa: E402

IDS = ["soldier_%02d" % (index + 1) for index in range(12)]


def context(groups=None, landmarks="ABC"):
    points = {"A": [824.0, 520.0], "B": [824.0, 784.0], "C": [936.0, 648.0]}
    value = {
        "soldiers": [{"id": soldier_id, "position": [800.0, 500.0 + index]} for index, soldier_id in enumerate(IDS)],
        "groups": {"all": IDS.copy()},
        "landmarks": {name: points[name] for name in landmarks},
    }
    value["groups"].update(groups or {})
    return value


def tagged(*parts):
    """Build tokens and tags from (text, span type or None) parts."""
    tokens, tags = [], []
    for text, kind in parts:
        words = resolver.tokenize(text)
        tokens += words
        tags += ["O"] * len(words) if kind is None else ["B-" + kind] + ["I-" + kind] * (len(words) - 1)
    return tokens, tags


def core(order):
    return {key: order[key] for key in ("action", "soldier_ids", "start", "end", "facing", "group_name")}


class TokenizeAndSpansTest(unittest.TestCase):
    def test_names_and_ids_stay_whole(self):
        self.assertEqual(resolver.tokenize("Send soldier_03, left_flank and east-side to B."),
                         ["Send", "soldier_03", ",", "left_flank", "and", "east-side", "to", "B", "."])
        self.assertEqual(resolver.tokenize("soldiers 2-5, group2"), ["soldiers", "2", "-", "5", ",", "group2"])
        self.assertEqual(resolver.tokenize("group 9alpha with 1st"), ["group", "9alpha", "with", "1st"])

    def test_bio_spans(self):
        tokens = ["a", "b", "c", "d", "e"]
        self.assertEqual(resolver.spans(tokens, ["B-SEL", "I-SEL", "O", "I-SEL", "B-DEST"]),
                         [("SEL", ["a", "b"]), ("SEL", ["d"]), ("DEST", ["e"])])
        self.assertEqual(resolver.spans(tokens[:2], ["B-SEL", "B-SEL"]), [("SEL", ["a"]), ("SEL", ["b"])])
        with self.assertRaises(ValueError):
            resolver.spans(tokens, ["O"])
        with self.assertRaises(ValueError):
            resolver.spans(["a"], ["B-WHO"])


class SelectionTest(unittest.TestCase):
    def check(self, text, expected):
        self.assertEqual(resolver.parse_selection(resolver.tokenize(text), set(IDS)), expected, text)

    def test_numbers_ids_ranges_and_words(self):
        self.check("soldier_03", {"soldier_03"})
        self.check("soldiers 1, 2 and 5", {"soldier_01", "soldier_02", "soldier_05"})
        self.check("soldiers 2 through 4", {"soldier_02", "soldier_03", "soldier_04"})
        self.check("soldiers 4-6", {"soldier_04", "soldier_05", "soldier_06"})
        self.check("soldiers one and twelve", {"soldier_01", "soldier_12"})
        self.check("soldier no. 7", {"soldier_07"})
        self.check("the first and second soldier", {"soldier_01", "soldier_02"})
        for text in ("everyone", "all of you", "the whole squad", "every soldier"):
            self.check(text, "all")

    def test_unreadable_or_unknown_selections(self):
        for text in ("soldier 13", "soldiers 5 to 2", "soldiers 3 to", "the tall ones", "soldier_00"):
            self.check(text, None)


class ResolveTest(unittest.TestCase):
    def test_group_move_resolves_members(self):
        tokens, tags = tagged(("move", None), ("group alpha", "GROUP"), ("to", None), ("A", "DEST"))
        order = resolver.resolve("move_to", tokens, tags, context({"alpha": IDS[:6]}))
        self.assertEqual(core(order), {"action": "move_to", "soldier_ids": IDS[:6], "start": None, "end": "A", "facing": None, "group_name": None})

    def test_no_selection_means_everyone_and_selections_combine(self):
        tokens, tags = tagged(("follow me", None))
        self.assertEqual(resolver.resolve("follow_player", tokens, tags, context())["soldier_ids"], IDS)
        tokens, tags = tagged(("Alpha", "GROUP"), ("and", None), ("soldier 9", "SEL"), (", stop", None))
        self.assertEqual(resolver.resolve("stop", tokens, tags, context({"alpha": ["soldier_02"]}))["soldier_ids"], ["soldier_02", "soldier_09"])

    def test_untagged_group_or_soldier_asks_instead_of_moving_everyone(self):
        for parts in ((("bowmen to", None), ("C", "DEST")), (("soldier 4 and", None), ("bowmen", "GROUP"), ("to", None), ("B", "DEST")),
                      (("send soldier_04 to", None), ("A", "DEST"))):
            tokens, tags = tagged(*parts)
            order = resolver.resolve("move_to", tokens, tags, context({"bowmen": IDS[:3]}))
            self.assertEqual(order["action"], "clarify", tokens)
        tokens, tags = tagged(("all", None), ("go to", None), ("A", "DEST"))
        self.assertEqual(resolver.resolve("move_to", tokens, tags, context())["soldier_ids"], IDS)

    def test_politeness_words_at_span_edges_are_ignored(self):
        tokens, tags = tagged(("Only", "SEL"), ("soldier_03", "SEL"), ("should stop", None))
        self.assertEqual(resolver.resolve("stop", tokens, tags, context())["soldier_ids"], ["soldier_03"])
        tokens, tags = tagged(("go to", None), ("C asap", "DEST"))
        self.assertEqual(resolver.resolve("move_to", tokens, tags, context())["end"], "C")

    def test_line_patrol_and_facing(self):
        tokens, tags = tagged(("line up from", None), ("point B", "START"), ("to", None), ("a", "END"), ("facing", None), ("C", "FACE"))
        self.assertEqual(core(resolver.resolve("form_line", tokens, tags, context())),
                         {"action": "form_line", "soldier_ids": IDS, "start": "B", "end": "A", "facing": "C", "group_name": None})
        tokens, tags = tagged(("patrol from", None), ("C", "START"), ("to", None), ("A", "END"))
        order = resolver.resolve("patrol", tokens, tags, context())
        self.assertEqual((order["start"], order["end"]), ("C", "A"))

    def test_create_group(self):
        tokens, tags = tagged(("create group", None), ("Night_Owls", "NEWGROUP"), ("with", None), ("soldiers 3 and 4", "SEL"))
        order = resolver.resolve("create_group", tokens, tags, context())
        self.assertEqual(core(order), {"action": "create_group", "soldier_ids": ["soldier_03", "soldier_04"], "start": None, "end": None, "facing": None, "group_name": "night_owls"})

    def test_problems_become_clarify(self):
        groups = {"alpha": IDS[:2]}
        cases = [
            ("move_to", [("Charlie", "GROUP"), ("go to", None), ("A", "DEST")], context(groups)),
            ("move_to", [("go to", None), ("the river", "DEST")], context()),
            ("move_to", [("go to", None), ("B", "DEST")], context(landmarks="AC")),
            ("move_to", [("go", None)], context()),
            ("move_to", [("go to", None), ("A", "DEST"), ("from", None), ("B", "START")], context()),
            ("form_line", [("soldier 1", "SEL"), ("line up between", None), ("A", "START"), ("and", None), ("B", "END")], context()),
            ("form_line", [("line up between", None), ("A", "START"), ("and", None), ("A", "END")], context()),
            ("patrol", [("patrol around", None), ("B", "START")], context()),
            ("patrol", [("patrol", None), ("A", "START"), ("to", None), ("B", "END"), ("facing", None), ("C", "FACE")], context()),
            ("create_group", [("create group", None), ("alpha", "NEWGROUP"), ("with", None), ("soldier 3", "SEL")], context(groups)),
            ("create_group", [("create group", None), ("ALL", "NEWGROUP"), ("with", None), ("soldier 3", "SEL")], context()),
            ("create_group", [("create group", None), ("ninth", "NEWGROUP"), ("with", None), ("soldier 3", "SEL")],
             context({"g%d" % index: ["soldier_01"] for index in range(8)})),
            ("create_group", [("create group", None), ("bravo", "NEWGROUP")], context()),
            ("create_group", [("create group", None), ("9alpha", "NEWGROUP"), ("with", None), ("soldier 3", "SEL")], context()),
            ("stop", [("stop", None), ("soldier 14", "SEL")], context()),
            ("follow_player", [("bravo", "NEWGROUP"), ("follow me", None)], context()),
            ("clarify", [("form a square at A", None)], context()),
        ]
        for action, parts, request in cases:
            with self.subTest(parts=parts):
                tokens, tags = tagged(*parts)
                order = resolver.resolve(action, tokens, tags, request)
                self.assertEqual(order["action"], "clarify")
                self.assertEqual(service.validate_order(order, request), order)


class GeneratorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = generator.generate(11, {"train": 3000, "dev": 400, "test": 400})

    def test_same_seed_gives_same_data(self):
        counts = {"train": 50, "dev": 10, "test": 10}
        self.assertEqual(generator.generate(11, counts), generator.generate(11, counts))

    def test_tags_resolve_to_the_intended_order(self):
        for split, examples in self.data.items():
            for example in examples:
                with self.subTest(split=split, text=example["text"]):
                    self.assertEqual(len(example["tokens"]), len(example["tags"]))
                    self.assertEqual(example["tokens"], resolver.tokenize(example["text"]))
                    order = resolver.resolve(example["action"], example["tokens"], example["tags"], example["context"])
                    self.assertEqual(core(order), example["order"])
                    service.validate_request({"request_id": 1, "prompt": example["text"], "context": example["context"]})

    def test_sentence_clarify_has_no_spans(self):
        for example in self.data["train"]:
            if example["action"] == "clarify":
                self.assertEqual(set(example["tags"]), {"O"})

    def test_same_text_always_has_the_same_labels(self):
        labels = {}
        for examples in self.data.values():
            for example in examples:
                value = (example["action"], tuple(example["tags"]))
                self.assertEqual(labels.setdefault(example["text"], value), value, example["text"])

    def test_held_out_wording_stays_out_of_train_and_dev(self):
        train_texts = {example["text"].lower() for example in self.data["train"]}
        for split in ("dev", "test"):
            self.assertFalse(any(example["text"].lower() in train_texts for example in self.data[split]))
        for example in self.data["test"]:
            self.assertTrue(example["test_only_parts"], example["text"])
        for split in ("train", "dev"):
            for example in self.data[split]:
                self.assertEqual(example["test_only_parts"], [], example["text"])
                lowered = [token.lower() for token in example["tokens"]]
                for name in generator.GROUP_NAMES.test_only:
                    self.assertNotIn(name, example["context"]["groups"])
                    self.assertNotIn(name, lowered)

    def test_every_action_and_clarify_reason_appears(self):
        self.assertEqual({example["action"] for example in self.data["train"]}, set(resolver.ACTIONS))
        notes = {example["note"] for example in self.data["train"]}
        for note in ("unknown place", "unknown group", "missing landmark", "duplicate group", "compound", "shape", "injection"):
            self.assertIn(note, notes)


if __name__ == "__main__":
    unittest.main()
