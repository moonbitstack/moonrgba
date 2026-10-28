"""Writes `docs/api.html` from the interface file and the `///` comments.

    python scripts/gen_api.py            regenerate the page
    python scripts/gen_api.py --check    exit 1 if the page is out of date

The list of what is public comes from `src/pkg.generated.mbti`, because that is
the only file that knows for certain. The words come from the doc comments in
`src/*.mbt`, and the signatures from the source too, since the interface file
drops the parameter names and a reference without them is hard to call from.

Trait plumbing — `equal`, `to_string`, `output`, `to_repr` and their generated
friends — is left out: it is on the page the reader needs, not on this one.
"""

import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src"
PAGE = ROOT / "docs" / "api.html"
TEMPLATE = ROOT / "scripts" / "api.template.html"

# Signature noise that is really the compiler's business.
NOISE = {"equal", "not_equal", "output", "to_string", "to_repr", "to_json",
         "from_json", "hash", "hash_combine", "compare"}

DECL = re.compile(
    r"^pub(?:\((?:all|open)\))?\s+(fn|let|struct|enum|suberror)\s+"
    r"([A-Za-z_]\w*(?:::[A-Za-z_]\w*)?)")
SIG = re.compile(r"^pub(?:\(all\))?\s+fn\s+([A-Za-z_]\w*(?:::[A-Za-z_]\w*)?)\s*\(")

# `Color`'s methods are the bands below rather than members of its entry: there
# are seventy of them, and a list that long under one heading is a wall.
METHODS_IN_BANDS = {"Color"}

# Where each thing belongs. Order inside a band is the order written here: the
# constructors in the order a person would try them, the conversions in the
# order of the space list, and so on.
BANDS = [
    ("types", "Types", "The values a colour is made of, and the other types the "
     "functions return.",
     ["Color", "Space", "Format", "Delta", "Hue", "Luma", "Cmyk", "Ansi16",
      "Ansi256", "Refused"], "type"),
    ("make", "Making a colour",
     "One constructor per space, each taking that space's own units. The colour "
     "stays in the space it was made in, so it is written back in that space.",
     ["Color::black", "Color::white", "Color::transparent", "Color::current",
      "Color::rgb", "Color::srgb", "Color::srgb_linear", "Color::hsl",
      "Color::hsv", "Color::hwb", "Color::lab", "Color::lch", "Color::oklab",
      "Color::oklch", "Color::display_p3", "Color::rec2020", "Color::a98_rgb",
      "Color::prophoto", "Color::xyz_d50", "Color::xyz_d65", "Color::ycbcr",
      "Color::of"],
     "fn"),
    ("read", "Reading and writing", "CSS in, CSS out, and the name table in both "
     "directions.", ["Color::decode", "Color::decode_opt", "Color::encode",
      "Color::of_name", "Color::name"], "fn"),
    ("convert", "Converting",
     "One method per destination space, and `to_space` for a space known only at "
     "run time. A conversion is exact in both directions.",
     ["Color::to_srgb", "Color::to_srgb_linear", "Color::to_hsl",
      "Color::to_hsv", "Color::to_hwb", "Color::to_oklab", "Color::to_oklch",
      "Color::to_lab", "Color::to_lch", "Color::to_xyz_d65", "Color::to_xyz_d50",
      "Color::to_display_p3", "Color::to_rec2020", "Color::to_a98_rgb",
      "Color::to_prophoto", "Color::to_cmyk", "Color::to_ycbcr",
      "Color::to_space"], "fn"),
    ("parts", "Components",
     "The three numbers, read and replaced. A colour keeps its space, so reading "
     "a component gives the number that space uses.",
     ["Color::components", "Color::with_components", "Color::with_alpha",
      "Color::hue", "Color::lightness", "Color::saturation", "Color::chroma",
      "Color::is_current", "Color::resolve"], "fn"),
    ("gamut", "Gamut",
     "Whether a colour fits, and what to do about it when it does not.",
     ["Color::in_gamut", "Color::to_gamut", "Color::clip"], "fn"),
    ("mix", "Mixing and adjusting",
     "`color-mix()` and the four verbs that move one quantity.",
     ["Color::mix", "Color::lighten", "Color::darken", "Color::saturate",
      "Color::desaturate", "Color::fade"], "fn"),
    ("measure", "Measuring",
     "Two contrast measures and four colour differences, each on its own scale.",
     ["Color::contrast", "Color::apca", "Color::luminance", "Color::delta_e"],
     "fn"),
    ("terminal", "A terminal",
     "The nearest named colour, the nearest slot of the 256, and the three bytes "
     "of true colour.", ["Color::to_ansi16", "Color::to_ansi256", "Color::rgb8"],
     "fn"),
    ("names", "The name table",
     "The 148 names CSS defines, in the order the table keeps them.",
     ["names_all", "names_count"], "fn"),
]


# ——— what the sources say ———————————————————————————————————————————


def source_files():
    for path in sorted(SOURCE.glob("*.mbt")):
        if path.name.endswith(("_test.mbt", "_wbtest.mbt")):
            continue
        yield path


def written() -> tuple[dict[str, str], dict[str, str]]:
    """Docs by name, and source signatures by name, from the sources."""
    docs: dict[str, str] = {}
    sigs: dict[str, str] = {}

    for path in source_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        pending: list[str] = []
        body_of = None  # the enum or struct whose variants are being read
        index = 0

        while index < len(lines):
            line = lines[index]
            stripped = line.strip()

            if stripped == "///|":
                pending = []
                index += 1
                continue
            if stripped.startswith("///"):
                pending.append(stripped[3:])
                index += 1
                continue

            match = DECL.match(line)
            if match:
                kind, name = match.group(1), match.group(2)
                if pending:
                    docs[name] = "\n".join(pending).strip("\n")
                if kind == "fn":
                    sig, index = read_signature(lines, index)
                    sigs[name] = sig
                    pending = []
                    continue
                body_of = name if stripped.endswith("{") else None
                pending = []
                index += 1
                continue

            if body_of:
                if stripped == "}":
                    body_of = None
                else:
                    # A variant may carry a payload, as `YCbCr(Luma)` does.
                    field = re.match(r"^\s*([A-Za-z_]\w*)\s*(?::|\(|$)", line)
                    if field and pending:
                        docs[f"{body_of}.{field.group(1)}"] = "\n".join(pending).strip()
            pending = []
            index += 1

    return docs, sigs


def read_signature(lines: list[str], index: int) -> tuple[str, int]:
    """A declaration, joined across the lines it is wrapped over."""
    parts = []
    while index < len(lines):
        parts.append(lines[index].strip())
        if lines[index].rstrip().endswith("{"):
            index += 1
            break
        index += 1
    text = " ".join(parts).rstrip(" {")
    return re.sub(r"\s+", " ", text), index


# ——— what the interface file says is public —————————————————————————


def interface() -> list[dict]:
    """Every public item, in the order `moon info` lists them."""
    items: list[dict] = []
    block = None

    for line in (SOURCE / "pkg.generated.mbti").read_text(encoding="utf-8").splitlines():
        if block is not None:
            if line.startswith("}"):
                items.append(block)
                block = None
            elif line.strip():
                block["members"].append(line.strip())
            continue

        match = re.match(r"pub\(all\)\s+(enum|struct|suberror)\s+(\w+)", line)
        if match:
            block = {"kind": match.group(1), "name": match.group(2),
                     "sig": line.rstrip(" {"), "members": [], "impls": []}
            if not line.rstrip().endswith("{"):
                items.append(block)
                block = None
            continue

        match = re.match(r"pub fn (\w+)::(\w+)", line)
        if match:
            items.append({"kind": "method", "name": match.group(2),
                          "owner": match.group(1), "sig": line})
            continue

        match = re.match(r"pub fn (\w+)", line)
        if match:
            items.append({"kind": "fn", "name": match.group(1), "sig": line})
            continue

        match = re.match(r"pub impl (\w+) for (\w+)", line)
        if match:
            items.append({"kind": "impl", "name": match.group(1),
                          "owner": match.group(2), "sig": line})
    return items


# ——— rendering ——————————————————————————————————————————————————————


def inline(text: str) -> str:
    """One run of doc text: escaped, with backticks turned into code."""
    body = html.escape(" ".join(text.split()), quote=False)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", body)


def table(rows: list[str]) -> str:
    """A pipe table, as a doc comment writes one."""
    def cells(row: str) -> list[str]:
        return [cell.strip() for cell in row.strip().strip("|").split("|")]

    head = cells(rows[0])
    body = [cells(row) for row in rows[2:]]
    out = ['<div class="table-wrap"><table class="doc-table">', "<thead><tr>"]
    out += [f"<th>{inline(cell)}</th>" for cell in head]
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>" + "".join(f"<td>{inline(cell)}</td>" for cell in row) + "</tr>")
    out.append("</tbody></table></div>")
    return "".join(out)


def prose(text: str) -> str:
    """Doc comment text as HTML: backticks are code, blank lines paragraphs,
    and a run of lines that all begin with a pipe is a table."""
    if not text:
        return ""
    out = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = [line for line in block.splitlines() if line.strip()]
        if len(lines) > 2 and all(line.strip().startswith("|") for line in lines):
            out.append(table(lines))
        else:
            out.append(f"<p>{inline(block)}</p>")
    return "\n".join(out)


def signature(text: str) -> str:
    return f'<pre class="sig">{html.escape(text, quote=False)}</pre>'


def anchor(name: str) -> str:
    return name.replace("::", "-")


def key_of(item: dict) -> str:
    return f'{item["owner"]}::{item["name"]}' if item["kind"] == "method" else item["name"]


def band_of(items: list[dict]) -> dict[str, list[dict]]:
    """Band id -> the items in it, in the order the band declares them."""
    # A type's own methods are printed under the type, in the Types band, so
    # they are not loose items looking for a home. `Color` is the exception:
    # its methods are the bands, and they are listed there by name.
    owned = {item["name"] for item in items
             if item["kind"] in ("enum", "struct", "suberror")} - METHODS_IN_BANDS

    table = {}
    for item in items:
        if item["kind"] == "impl":
            continue
        if item["kind"] == "method" and (item["name"] in NOISE or item["owner"] in owned):
            continue
        table[key_of(item)] = item

    placed: dict[str, list[dict]] = {}
    used: set[str] = set()
    for ident, _, _, names, _ in BANDS:
        placed[ident] = []
        for name in names:
            item = table.get(name)
            if item is None:
                sys.exit(f"{name} is in a band but not in the interface file")
            placed[ident].append(item)
            used.add(name)

    stray = [item for key, item in table.items() if key not in used]
    if stray:
        print("not filed in any band: " + ", ".join(key_of(i) for i in stray),
              file=sys.stderr)
        placed["stray"] = stray
    return placed


def render_entry(item: dict, docs: dict[str, str], sigs: dict[str, str],
                 items: list[dict]) -> str:
    name = item["name"]
    if item["kind"] == "method":
        name = f'{item["owner"]}::{item["name"]}'
        kind = "method"
    else:
        kind = item["kind"]

    lines = [f'<div class="entry" id="{anchor(name)}">']
    lines.append(f'<h3><span class="kind">{kind}</span>{html.escape(name)}</h3>')

    if item["kind"] in ("enum", "struct", "suberror"):
        lines.append(signature(item["sig"]))
        lines.append(prose(docs.get(name, "")))
        if item["members"]:
            rows = []
            for member in item["members"]:
                # `YCbCr(Luma)` and `Unexpected(at~ : Int, …)` carry a payload;
                # the doc comment is attached to the bare name.
                field = re.split(r"[(\s:~]", member, maxsplit=1)[0]
                note = docs.get(f"{name}.{field}", "")
                note = f"<small>{inline(note)}</small>" if note else ""
                rows.append(f"<li>{html.escape(member)}{note}</li>")
            lines.append('<ul class="variants">' + "".join(rows) + "</ul>")
        if name in METHODS_IN_BANDS:
            lines.append("</div>")
            return "\n".join(lines)
        for member in items:
            if member["kind"] != "method" or member.get("owner") != name:
                continue
            if member["name"] in NOISE:
                continue
            full = f"{name}::{member['name']}"
            lines.append('<div class="member">')
            lines.append(f"<h4>{html.escape(full)}</h4>")
            lines.append(signature(sigs.get(full, member["sig"])))
            lines.append(prose(docs.get(full, "")))
            lines.append("</div>")
    else:
        lines.append(signature(sigs.get(name, item["sig"].rstrip())))
        lines.append(prose(docs.get(name, "")))

    lines.append("</div>")
    return "\n".join(lines)


def render() -> str:
    docs, sigs = written()
    items = interface()
    bands = band_of(items)

    nav, body = [], []
    total = 0
    for ident, title, blurb, _, kind in BANDS:
        band = bands.get(ident, [])
        if not band:
            continue
        total += len(band)
        nav.append(f'<li><a href="#band-{ident}">{title}</a></li>')
        body.append(f'<section class="band" id="band-{ident}">')
        body.append('<div class="band-head">')
        body.append(f"<h2>{title}</h2>")
        body.append(f'<span class="count">{len(band)}</span>')
        body.append("</div>")
        body.append(prose(blurb))
        body.append('<div class="jump">')
        for item in band:
            name = (f'{item["owner"]}::{item["name"]}'
                    if item["kind"] == "method" else item["name"])
            body.append(f'<a href="#{anchor(name)}">{html.escape(name)}</a>')
        body.append("</div>")
        for item in band:
            body.append(render_entry(item, docs, sigs, items))
        body.append("</section>")

    if bands.get("stray"):
        body.append('<section class="band" id="band-stray">')
        body.append('<div class="band-head"><h2>Also public</h2>'
                    f'<span class="count">{len(bands["stray"])}</span></div>')
        for item in bands["stray"]:
            body.append(render_entry(item, docs, sigs, items))
        body.append("</section>")

    page = TEMPLATE.read_text(encoding="utf-8")
    page = page.replace("<!-- nav -->", "\n".join(nav))
    page = page.replace("<!-- body -->", "\n".join(body))
    page = page.replace("<!-- total -->", str(total))
    return page


def main() -> None:
    page = render()
    if "--check" in sys.argv[1:]:
        if PAGE.read_text(encoding="utf-8") != page:
            sys.exit("docs/api.html is out of date; run python scripts/gen_api.py")
        print("docs/api.html is up to date")
        return
    PAGE.write_text(page, encoding="utf-8", newline="\n")
    print(f"docs/api.html written, {len(page.splitlines())} lines")


if __name__ == "__main__":
    main()
