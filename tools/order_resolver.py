"""Turn a tagged order sentence into a sandbox order.

A small classifier predicts one action label for the sentence and one BIO tag per
word. This module does everything after that without a model: it parses soldier
selections such as "soldiers 1 through 6", looks up group names in the request
context, checks landmarks and group names, and returns the seven-field order the
game executes. Anything it cannot resolve becomes a clarify order.
"""

import re

import sandbox_order_service as service

# Span types a tagger marks. SEL selects soldiers by number, ID or "everyone";
# GROUP names an existing group; NEWGROUP is the name of a group being created.
SPAN_TYPES = ("SEL", "GROUP", "NEWGROUP", "DEST", "START", "END", "FACE")
TAGS = ("O",) + tuple(prefix + "-" + kind for kind in SPAN_TYPES for prefix in ("B", "I"))
ACTIONS = service.SUPPORTED_ACTIONS

# A word may contain letters, digits, _ and inner hyphens, so group names such as
# group2, left_flank and east-side and IDs such as soldier_03 stay whole. A word that
# starts with digits, such as 9alpha, also stays whole so the group-name check rejects
# it instead of reading a soldier number and a name. Plain numbers stay separate.
TOKEN_PATTERN = re.compile(r"[0-9]*[A-Za-z][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*(?:'[A-Za-z]+)?|[0-9]+|[^\sA-Za-z0-9]")

NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
    "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6, "seventh": 7,
    "eighth": 8, "ninth": 9, "tenth": 10, "eleventh": 11, "twelfth": 12,
}
EVERYONE_WORDS = {"all", "everyone", "everybody", "squad", "team", "unit", "troops", "men", "soldiers", "you", "lot", "platoon", "whole", "entire", "every"}
RANGE_WORDS = {"through", "thru", "to", "-", "until", "till"}
LIST_WORDS = {",", "and", "&", "plus", "with", "also"}
FILLER_WORDS = {"soldier", "soldiers", "number", "numbers", "no", ".", "#", "the", "of", "only", "just", "both", "trooper", "troopers", "private", "privates"}
LANDMARK_FILLER = {"landmark", "point", "marker", "flag", "spot", "position", "the", "location", "waypoint", "letter"}
GROUP_FILLER = {"group", "squad", "team", "unit", "the", "called", "named"}
# Words a tagger may include at the edge of a span that carry no selection or place.
EDGE_WORDS = {"only", "just", "please", "now", "asap", "ok", "okay", "right", "alright", ",", ".", "!", "?"}


def tokenize(text):
    return TOKEN_PATTERN.findall(text)


def spans(tokens, tags):
    """Return [(type, [tokens])] for each BIO span, in sentence order."""
    if len(tokens) != len(tags):
        raise ValueError("Every token needs exactly one tag.")
    result = []
    current = None
    for token, tag in zip(tokens, tags):
        if tag not in TAGS:
            raise ValueError("Unknown tag %r." % tag)
        if tag == "O":
            current = None
            continue
        prefix, kind = tag.split("-", 1)
        # An I- tag after O or after another span type starts a new span, as B- would.
        if prefix == "B" or current is None or current[0] != kind:
            current = (kind, [])
            result.append(current)
        current[1].append(token)
    return result


def parse_selection(words, known_ids):
    """Return a set of soldier IDs, the string "all", or None if the span cannot be read."""
    lowered = [word.lower() for word in words]
    numbers = []
    ranges = []
    pending_range = False
    meaningful = False
    for word in lowered:
        if re.fullmatch(r"soldier_[0-9]+", word):
            number = int(word.split("_")[1])
        elif word.isdigit():
            number = int(word)
        elif word in NUMBER_WORDS:
            number = NUMBER_WORDS[word]
        elif word in RANGE_WORDS and numbers:
            pending_range = True
            continue
        elif word in EVERYONE_WORDS:
            meaningful = True
            continue
        elif word in LIST_WORDS or word in FILLER_WORDS:
            continue
        else:
            return None
        if pending_range:
            ranges.append((numbers.pop(), number))
            pending_range = False
        else:
            numbers.append(number)
    if pending_range:
        return None
    if not numbers and not ranges:
        return "all" if meaningful else None
    selected = set()
    for low, high in ranges:
        if low > high:
            return None
        numbers.extend(range(low, high + 1))
    for number in numbers:
        soldier_id = "soldier_%02d" % number
        if soldier_id not in known_ids:
            return None
        selected.add(soldier_id)
    return selected


def parse_landmark(words, landmarks):
    remaining = [word for word in words if word.lower() not in LANDMARK_FILLER]
    if len(remaining) != 1 or remaining[0].upper() not in landmarks:
        return None
    return remaining[0].upper()


def parse_group(words):
    remaining = [word.lower() for word in words if word.lower() not in GROUP_FILLER]
    if len(remaining) != 1:
        return None
    return remaining[0]


def untagged_selection(tokens, tags, groups):
    """Return a group name or soldier reference the tagger left outside every span.

    Without this check such an order would fall back to everyone: "bowmen to C"
    with "bowmen" untagged would move the whole squad.
    """
    lowered = [token.lower() for token in tokens]
    for index, word in enumerate(lowered):
        if tags[index] != "O":
            continue
        if word != "all" and word in groups:
            return tokens[index]
        if re.fullmatch(r"soldier_[0-9]+", word):
            return tokens[index]
        if word in ("soldier", "soldiers") and index + 1 < len(tokens) and tags[index + 1] == "O" and (lowered[index + 1].isdigit() or lowered[index + 1] in NUMBER_WORDS):
            return "%s %s" % (tokens[index], tokens[index + 1])
    return None


def clarify(message):
    return {"action": "clarify", "soldier_ids": [], "start": None, "end": None, "facing": None, "message": message, "group_name": None}


def resolve(action, tokens, tags, context):
    """Return the seven-field order for a tagged sentence in the given request context."""
    if action not in ACTIONS:
        raise ValueError("Unknown action %r." % action)
    if action == "clarify":
        return clarify("That order is not supported. Try moving, a line, following, patrolling, attacking, a group or stop.")
    known_ids = {soldier["id"] for soldier in context["soldiers"]}
    groups = context["groups"]
    landmarks = context["landmarks"]
    found = {kind: [] for kind in SPAN_TYPES}
    for kind, words in spans(tokens, tags):
        while words and words[0].lower() in EDGE_WORDS:
            words = words[1:]
        while words and words[-1].lower() in EDGE_WORDS:
            words = words[:-1]
        if words:
            found[kind].append(words)

    missed = untagged_selection(tokens, tags, groups)
    if missed:
        return clarify("I could not tell whether the order is for %s. Name the soldiers again." % missed)

    selected = set()
    everyone = False
    for words in found["SEL"]:
        parsed = parse_selection(words, known_ids)
        if parsed is None:
            return clarify("I could not tell which soldiers you mean by \"%s\"." % " ".join(words))
        if parsed == "all":
            everyone = True
        else:
            selected |= parsed
    for words in found["GROUP"]:
        name = parse_group(words)
        if name is None or name not in groups:
            return clarify("There is no group called \"%s\"." % " ".join(words))
        selected |= set(groups[name])
    if everyone or (not selected and action != "create_group"):
        selected = set(groups["all"])
    soldier_ids = [soldier_id for soldier_id in groups["all"] if soldier_id in selected]

    points = {}
    for kind in ("DEST", "START", "END", "FACE"):
        if len(found[kind]) > 1:
            return clarify("The order names more than one %s landmark." % kind.lower())
        if found[kind]:
            point = parse_landmark(found[kind][0], landmarks)
            if point is None:
                return clarify("\"%s\" is not one of the placed landmarks (%s)." % (" ".join(found[kind][0]), ", ".join(sorted(landmarks)) or "none"))
            points[kind] = point
    order = {"action": action, "soldier_ids": soldier_ids, "start": None, "end": None, "facing": points.get("FACE"), "group_name": None}
    uses = {"DEST"} if action in ("move_to", "attack") else {"START", "END"} if action in ("form_line", "patrol") else set()
    if action in ("form_line", "move_to"):
        uses.add("FACE")
    extra = [kind for kind in points if kind not in uses]
    if extra:
        return clarify("That order does not use a %s landmark." % extra[0].lower())

    if action == "move_to":
        if "DEST" not in points:
            names = sorted(landmarks)
            listed = ", ".join(names[:-1]) + " or " + names[-1] if len(names) > 1 else "".join(names) or "a landmark"
            return clarify("Where should they go? Name landmark %s." % listed)
        order["end"] = points["DEST"]
        message = "%d soldiers move to %s." % (len(soldier_ids), points["DEST"])
    elif action in ("form_line", "patrol"):
        if "START" not in points or "END" not in points or points["START"] == points["END"]:
            return clarify("A %s needs two different landmarks." % ("line" if action == "form_line" else "patrol"))
        if action == "form_line" and len(soldier_ids) < 2:
            return clarify("A line needs at least two soldiers.")
        order["start"], order["end"] = points["START"], points["END"]
        message = "%d soldiers %s %s–%s." % (len(soldier_ids), "form a line" if action == "form_line" else "patrol", points["START"], points["END"])
    elif action == "create_group":
        if len(found["NEWGROUP"]) != 1:
            return clarify("What should the new group be called?")
        try:
            name = service.normalize_group_name(" ".join(found["NEWGROUP"][0]))
        except service.OrderError:
            return clarify("Group names use letters, digits, _ or -, start with a letter and have at most 24 characters.")
        if name == "all" or name in groups:
            return clarify("A group called %s already exists." % name)
        if len(groups) - 1 >= service.MAX_NAMED_GROUPS:
            return clarify("There are already eight named groups.")
        if not soldier_ids:
            return clarify("Which soldiers should be in group %s?" % name)
        order["group_name"] = name
        message = "Group %s: %d soldiers." % (name, len(soldier_ids))
    elif action == "follow_player":
        message = "%d soldiers follow you." % len(soldier_ids)
    elif action == "attack":
        order["end"] = points.get("DEST")
        message = "%d soldiers attack%s." % (len(soldier_ids), " at " + points["DEST"] if "DEST" in points else "")
    else:
        message = "%d soldiers stop." % len(soldier_ids)
    if found["NEWGROUP"] and action != "create_group":
        return clarify("Only a create-group order names a new group.")
    order["message"] = message
    return service.validate_order(order, context)
