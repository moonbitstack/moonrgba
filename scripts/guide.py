"""Writes the output of `src/examples/guide` into `docs/guide.html`.

    python scripts/guide.py            run the program, update the page
    python scripts/guide.py --check    exit 1 if the page is out of date

The program prints its values under a `@@chapter` line. The page has one slot per
chapter, `<!-- run:chapter -->` on one side of a block and `<!-- /run:chapter -->`
on the other, and this puts the lines between the markers, escaped.

Keeping the transcript generated means the listings and the numbers under them
cannot drift apart: change the library, run this, and the page either updates or
CI says it no longer matches.
"""

import html
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "guide.html"
PACKAGE = "src/examples/guide"


def transcript() -> dict[str, list[str]]:
    """The program's stdout, split into chapters by its `@@name` markers."""
    result = subprocess.run(
        ["moon", "run", PACKAGE, "--target", "native"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        sys.exit(f"moon run {PACKAGE} failed:\n{result.stderr or result.stdout}")

    chapters: dict[str, list[str]] = {}
    current = None
    for line in result.stdout.splitlines():
        if line.startswith("@@"):
            current = line[2:].strip()
            chapters[current] = []
        elif current is not None:
            chapters[current].append(line)
    return chapters


def fill(page: str, chapters: dict[str, list[str]]) -> str:
    """Replace every slot's contents, and complain about a chapter left empty."""
    for name, lines in chapters.items():
        opening = f"<!-- run:{name} -->"
        closing = f"<!-- /run:{name} -->"
        if opening not in page:
            sys.exit(f"docs/guide.html has no slot for the chapter {name!r}")
        head, _, rest = page.partition(opening)
        _, _, tail = rest.partition(closing)
        body = "\n".join(html.escape(line, quote=False) for line in lines)
        page = head + opening + body + closing + tail

    # A slot the program never filled would ship with an empty pane.
    for name in ["read", "spaces", "construct", "gamut", "mix", "contrast",
                 "difference", "adjust", "names", "terminal", "none", "errors"]:
        if not chapters.get(name):
            sys.exit(f"the program printed nothing for the chapter {name!r}")
    return page


def main() -> None:
    check = "--check" in sys.argv[1:]
    chapters = transcript()
    before = PAGE.read_text(encoding="utf-8")
    after = fill(before, chapters)

    if check:
        if before != after:
            sys.exit("docs/guide.html does not match the program's output; "
                     "run python scripts/guide.py")
        print("docs/guide.html matches")
        return

    PAGE.write_text(after, encoding="utf-8", newline="\n")
    print(f"{sum(len(v) for v in chapters.values())} lines written from "
          f"{len(chapters)} chapters")


if __name__ == "__main__":
    main()
