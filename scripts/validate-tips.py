#!/usr/bin/env python3
"""Validate a claude-tips content file (content/tips.json by default).

Uses only the Python standard library. Exit status 0 when the file is valid,
1 when any problem is found, 2 when the file cannot be read or parsed.

Each tip carries its Chinese title and detail at the top level and the
English ones under "en": { "title", "detail" }. The public file needs "en"
on every tip and group; in a tips.local.json it is optional, and a tip
without it shows its Chinese text in the English view.

Usage:
    scripts/validate-tips.py [path ...]
    scripts/validate-tips.py --local ~/.claude/claude-tips/tips.local.json
"""

import json
import re
import sys
from pathlib import Path

VALID_GROUPS = {"say", "slash", "mine"}
REQUIRED_FIELDS = ("id", "group", "title", "copy", "detail", "keywords", "icon", "source")
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
CJK_PATTERN = re.compile(r"[一-鿿]")
SOURCE_KINDS = {"builtin-skill", "builtin-tool", "builtin-command", "user-skill", "plugin-skill"}

REPO_DIR = Path(__file__).resolve().parent.parent
DEFAULT_PATH = REPO_DIR / "content" / "tips.json"
# Generated copies that must match content/tips.json byte for byte.
FALLBACK_COPIES = (REPO_DIR / "pane" / "assets" / "tips.json",)


def is_non_empty_string(value):
    return isinstance(value, str) and value.strip() != ""


def validate_tip(tip, index, local):
    """Return a list of problem strings for one tip."""
    label = f"tips[{index}]"
    if not isinstance(tip, dict):
        return [f"{label}: must be an object"]
    if isinstance(tip.get("id"), str):
        label = f"tips[{index}] ({tip['id']})"

    # A local entry that only hides a public tip needs nothing but its id.
    if local and tip.get("hidden") is True:
        if not is_non_empty_string(tip.get("id")):
            return [f"{label}: hidden entry needs an id"]
        return []

    problems = []
    for field in REQUIRED_FIELDS:
        if field not in tip:
            problems.append(f"{label}: missing required field '{field}'")

    tip_id = tip.get("id")
    if "id" in tip and not (isinstance(tip_id, str) and ID_PATTERN.match(tip_id)):
        problems.append(f"{label}: id must be kebab-case (got {tip_id!r})")

    group = tip.get("group")
    if "group" in tip and group not in VALID_GROUPS:
        problems.append(f"{label}: group must be one of {sorted(VALID_GROUPS)} (got {group!r})")

    title = tip.get("title")
    if "title" in tip:
        if not is_non_empty_string(title):
            problems.append(f"{label}: title must be a non-empty string")
        elif not CJK_PATTERN.search(title):
            problems.append(f"{label}: title must contain Chinese text")
        elif "\n" in title:
            problems.append(f"{label}: title must be a single line")

    copy = tip.get("copy")
    if "copy" in tip:
        if not is_non_empty_string(copy):
            problems.append(f"{label}: copy must be a non-empty string")
        elif not copy.isascii():
            bad = sorted({ch for ch in copy if not ch.isascii()})
            problems.append(f"{label}: copy must be ASCII only (found {''.join(bad)!r})")

    if "detail" in tip and not is_non_empty_string(tip.get("detail")):
        problems.append(f"{label}: detail must be a non-empty string")

    keywords = tip.get("keywords")
    if "keywords" in tip and not (
        isinstance(keywords, list) and all(is_non_empty_string(k) for k in keywords)
    ):
        problems.append(f"{label}: keywords must be a list of non-empty strings")

    if "icon" in tip and not is_non_empty_string(tip.get("icon")):
        problems.append(f"{label}: icon must be a non-empty string")

    source = tip.get("source")
    if "source" in tip:
        if not isinstance(source, dict):
            problems.append(f"{label}: source must be an object with kind and name")
        else:
            if source.get("kind") not in SOURCE_KINDS:
                problems.append(
                    f"{label}: source.kind must be one of {sorted(SOURCE_KINDS)} "
                    f"(got {source.get('kind')!r})"
                )
            if not is_non_empty_string(source.get("name")):
                problems.append(f"{label}: source.name must be a non-empty string")

    problems.extend(validate_english(tip, label, required=not local))

    if "hidden" in tip and not isinstance(tip.get("hidden"), bool):
        problems.append(f"{label}: hidden must be true or false")

    return problems


def validate_english(entry, label, required, fields=("title", "detail")):
    """Check an entry's "en" object: English title (one line) and detail, no Chinese."""
    if "en" not in entry:
        return [f"{label}: missing required field 'en'"] if required else []
    english = entry["en"]
    if not isinstance(english, dict):
        return [f"{label}: en must be an object with {', '.join(fields)}"]
    problems = []
    for field in fields:
        value = english.get(field)
        if field not in english:
            problems.append(f"{label}: en is missing '{field}'")
        elif not is_non_empty_string(value):
            problems.append(f"{label}: en.{field} must be a non-empty string")
        elif CJK_PATTERN.search(value):
            problems.append(f"{label}: en.{field} must be English (found Chinese text)")
        elif field == "title" and "\n" in value:
            problems.append(f"{label}: en.title must be a single line")
    unknown = sorted(set(english) - set(fields))
    if unknown:
        problems.append(f"{label}: en has unknown field(s) {unknown}")
    return problems


def validate_document(data, local):
    problems = []
    if not isinstance(data, dict):
        return ["top level must be an object"]
    if data.get("version") != 1:
        problems.append(f"version must be 1 (got {data.get('version')!r})")
    tips = data.get("tips")
    if not isinstance(tips, list):
        return problems + ["'tips' must be a list"]

    if not local:
        groups = data.get("groups")
        if not isinstance(groups, list):
            problems.append("'groups' must be a list")
        else:
            group_ids = [g.get("id") for g in groups if isinstance(g, dict)]
            if set(group_ids) != VALID_GROUPS:
                problems.append(f"groups must define exactly {sorted(VALID_GROUPS)}")
            for index, group in enumerate(groups):
                if isinstance(group, dict):
                    label = f"groups[{index}] ({group.get('id')})"
                    problems.extend(validate_english(group, label, required=True, fields=("title",)))

    seen = {}
    for index, tip in enumerate(tips):
        problems.extend(validate_tip(tip, index, local))
        tip_id = tip.get("id") if isinstance(tip, dict) else None
        if isinstance(tip_id, str):
            if tip_id in seen:
                problems.append(f"tips[{index}]: duplicate id '{tip_id}' (first at tips[{seen[tip_id]}])")
            else:
                seen[tip_id] = index
    return problems


def validate_file(path, local):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"{path}: file not found", file=sys.stderr)
        return 2
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        print(f"{path}: cannot parse JSON: {error}", file=sys.stderr)
        return 2

    problems = validate_document(data, local)
    if problems:
        for problem in problems:
            print(f"{path}: {problem}", file=sys.stderr)
        print(f"{path}: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    count = len(data.get("tips", []))
    print(f"{path}: OK ({count} tips)")
    return 0


def main(argv):
    local = False
    paths = []
    for arg in argv:
        if arg == "--local":
            local = True
        elif arg in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        else:
            paths.append(arg)
    check_copies = not paths
    if not paths:
        paths = [str(DEFAULT_PATH)]
    status = max(validate_file(path, local) for path in paths)
    if check_copies:
        status = max(status, check_fallback_copies())
        status = max(status, check_pane_icons())
    return status


def check_fallback_copies():
    """Fail when a generated fallback copy has drifted from content/tips.json."""
    source = DEFAULT_PATH.read_bytes()
    status = 0
    for copy in FALLBACK_COPIES:
        if not copy.parent.parent.is_dir():
            continue  # that front end is not in this checkout
        if not copy.exists() or copy.read_bytes() != source:
            print(
                f"{copy}: out of date with content/tips.json; run scripts/sync-pane-fallback.sh",
                file=sys.stderr,
            )
            status = 1
    return status


PANE_ICONS = REPO_DIR / "pane" / "hooks" / "icons.ts"
EXAMPLE_PATH = REPO_DIR / "content" / "tips.local.example.json"


def check_pane_icons():
    """Fail when a content file names an icon the side pane has no drawing for."""
    if not PANE_ICONS.exists():
        return 0  # the pane is not in this checkout
    table = PANE_ICONS.read_text(encoding="utf-8")
    start = table.find("export const ICON_PATHS")
    end = table.find("\n}", start)
    drawn = set(re.findall(r"^\s+'?([A-Za-z0-9.]+)'?:\s*\[", table[start:end], re.MULTILINE))
    status = 0
    for path in (DEFAULT_PATH, EXAMPLE_PATH):
        if not path.exists():
            continue
        tips = json.loads(path.read_text(encoding="utf-8")).get("tips", [])
        for name in sorted({tip.get("icon") for tip in tips if tip.get("icon")} - drawn):
            print(
                f"{path}: icon {name!r} has no drawing in pane/hooks/icons.ts; add one there",
                file=sys.stderr,
            )
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
