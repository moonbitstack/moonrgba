// Colour differences and contrast ratios, computed by colorjs.io.
//
// The pairs are random Lab and sRGB samples from a seeded generator, so that the
// table is reproducible and covers the space rather than a handful of cases
// somebody thought of.
//
// Usage, from the repository root:
//
//   npm install colorjs.io
//   node scripts/numbers.mjs numbers.tsv
//
// Then `python scripts/fixtures.py numbers numbers.tsv src/numbers_wbtest.mbt`.
//
// Output is tab separated: the measure, the space the pair is written in, six
// components, and the expected value.

import { writeFileSync } from "node:fs";
import Color from "colorjs.io";

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = random(1976);
const between = (low, high) => low + rand() * (high - low);

const rows = [];

// Colour differences: pairs of Lab colours spread over the whole space,
// including the saturated ends where the measures disagree most.
for (let index = 0; index < 80; index++) {
  const first = [between(0, 100), between(-100, 100), between(-100, 100)];
  const second = [between(0, 100), between(-100, 100), between(-100, 100)];
  const a = new Color("lab", first);
  const b = new Color("lab", second);
  for (const [method, name] of [
    ["76", "76"],
    ["2000", "2000"],
    ["ok", "OK"],
  ]) {
    rows.push([method, "lab", ...first, ...second, a.deltaE(b, name)]);
  }
}

// Contrast: pairs of sRGB colours, which is what WCAG and APCA are defined on.
for (let index = 0; index < 60; index++) {
  const first = [between(0, 1), between(0, 1), between(0, 1)];
  const second = [between(0, 1), between(0, 1), between(0, 1)];
  const a = new Color("srgb", first);
  const b = new Color("srgb", second);
  rows.push(["wcag", "srgb", ...first, ...second, a.contrast(b, "WCAG21")]);
  // colorjs treats the first argument of `contrast` as the background and the
  // second as the text, the other way round from this library, so the call is
  // written that way round to keep the row's order text-then-background.
  rows.push(["apca", "srgb", ...first, ...second, b.contrast(a, "APCA")]);
}

// Mixing: `color-mix()` between two colours in a chosen space, with the hue
// direction varied, and premultiplied alpha, which is what CSS Color 5 requires
// and what colorjs does only when asked.
const MIX_SPACES = {
  srgb: [[0, 1], [0, 1], [0, 1]],
  "srgb-linear": [[0, 1], [0, 1], [0, 1]],
  hsl: [[0, 360], [0, 1], [0, 1]],
  hwb: [[0, 360], [0, 0.4], [0, 0.4]],
  lab: [[0, 100], [-80, 80], [-80, 80]],
  lch: [[0, 100], [0, 100], [0, 360]],
  oklab: [[0, 1], [-0.3, 0.3], [-0.3, 0.3]],
  oklch: [[0, 1], [0, 0.3], [0, 360]],
  "xyz-d65": [[0, 1], [0, 1], [0, 1]],
  "display-p3": [[0, 1], [0, 1], [0, 1]],
};
const HUES = ["shorter", "longer", "increasing", "decreasing"];

// colorjs spells two of the spaces differently.
const colorjsName = (space) => (space === "display-p3" ? "p3" : space);

for (const [space, ranges] of Object.entries(MIX_SPACES)) {
  for (let index = 0; index < 12; index++) {
    const coords = () => ranges.map(([low, high]) => low + rand() * (high - low));
    const first = coords();
    const second = coords();
    const alpha = [rand(), rand()];
    const a = new Color(colorjsName(space), first, alpha[0]);
    const b = new Color(colorjsName(space), second, alpha[1]);
    // colorjs weights the second colour; this library weights the first.
    const p = 0.1 + rand() * 0.8;
    const hue = HUES[index % HUES.length];
    const mixed = Color.mix(a, b, p, {
      space: colorjsName(space),
      hue,
      premultiplied: true,
    });
    const zeros = [0, 0, 0];
    const result = mixed.coords ?? zeros;
    const value = mixed.alpha;
    rows.push([
      "mix",
      space,
      hue,
      ...first,
      alpha[0],
      ...second,
      alpha[1],
      1 - p,
      ...result,
      value,
    ]);
  }
}

// Gamut mapping: colours in OkLCh, most of them outside sRGB, mapped into it by
// CSS Color 4's chroma reduction.
for (let index = 0; index < 48; index++) {
  const lightness = 0.1 + rand() * 0.85;
  const chroma = rand() * 0.4;
  const hue = rand() * 360;
  const color = new Color("oklch", [lightness, chroma, hue]);
  const mapped = Color.toGamut(color, { space: "srgb", method: "css" });
  rows.push(["gamut", "oklch", lightness, chroma, hue, ...mapped.to("srgb").coords]);
}

const lines = rows.map((fields) => fields.map(String).join("\t"));
writeFileSync(process.argv[2] ?? "numbers.tsv", lines.join("\n") + "\n");
console.log(`${rows.length} rows written`);
