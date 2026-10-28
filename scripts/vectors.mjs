// Generates the conversion vectors the tests compare against.
//
// Two independent references, so that a mistake in one shows up as a
// disagreement rather than as agreement:
//
//   * conversions.js — the sample code CSS Color 4 ships with the
//     specification, fetched from the CSS WG repository when this runs.
//   * colorjs.io — a mature implementation of the same specification, written
//     by people who were not looking at this one.
//
// Usage, from the repository root:
//
//   npm install colorjs.io
//   node scripts/vectors.mjs vectors.txt
//
// The output is tab-separated: source space, destination space, three source
// components, three destination components, all in the units this library uses
// (HSL and HWB saturation/lightness/whiteness/blackness in 0–1, not 0–100).
// `scripts/vectors_table.py` turns it into `src/vectors_wbtest.mbt`.
//
// Determinism matters: the generator is seeded, so re-running it produces the
// same file and a diff in the tests means a real change.

import { writeFileSync } from "node:fs";

const OUT = process.argv[2] ?? "vectors.txt";
import { execFileSync } from "node:child_process";
import Color from "colorjs.io";

const SPEC_BASE = "https://raw.githubusercontent.com/w3c/csswg-drafts/main/css-color-4/";

const SPACES = [
  "srgb",
  "srgb-linear",
  "hsl",
  "hsv",
  "hwb",
  "lab",
  "lch",
  "oklab",
  "oklch",
  "xyz-d50",
  "xyz-d65",
  "display-p3",
  "rec2020",
  "a98-rgb",
  "prophoto-rgb",
];

// The natural range of each space, which is where a random sample is drawn
// from. Sampling outside it would test clipping, which is a separate question.
const RANGES = {
  srgb: [[0, 1], [0, 1], [0, 1]],
  "srgb-linear": [[0, 1], [0, 1], [0, 1]],
  hsl: [[0, 360], [0, 1], [0, 1]],
  hsv: [[0, 360], [0, 1], [0, 1]],
  hwb: [[0, 360], [0, 0.5], [0, 0.5]],
  lab: [[0, 100], [-110, 110], [-110, 110]],
  lch: [[0, 100], [0, 140], [0, 360]],
  oklab: [[0, 1], [-0.35, 0.35], [-0.35, 0.35]],
  oklch: [[0, 1], [0, 0.4], [0, 360]],
  "xyz-d50": [[0, 1], [0, 1], [0, 1]],
  "xyz-d65": [[0, 1], [0, 1], [0, 1]],
  "display-p3": [[0, 1], [0, 1], [0, 1]],
  rec2020: [[0, 1], [0, 1], [0, 1]],
  "a98-rgb": [[0, 1], [0, 1], [0, 1]],
  "prophoto-rgb": [[0, 1], [0, 1], [0, 1]],
};

// Pairs worth checking. Every space is checked into and out of both hubs, plus
// the polar/rectangular pairs and the RGB spaces against each other; that
// covers every route the conversion table can take without a full product.
const PAIRS = [];
for (const space of SPACES) {
  for (const hub of ["xyz-d65", "srgb", "oklab"]) {
    if (space !== hub) PAIRS.push([space, hub], [hub, space]);
  }
}
PAIRS.push(
  ["srgb", "srgb-linear"],
  ["srgb-linear", "srgb"],
  ["hsl", "hsv"],
  ["hsv", "hwb"],
  ["hwb", "hsl"],
  ["lab", "lch"],
  ["lch", "lab"],
  ["oklab", "oklch"],
  ["oklch", "oklab"],
  ["xyz-d50", "xyz-d65"],
  ["xyz-d65", "xyz-d50"],
  ["display-p3", "rec2020"],
  ["prophoto-rgb", "lab"],
);

const SAMPLES = 6;

// mulberry32: small, seeded, and good enough to scatter points.
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

const rand = random(20261028);

function sample(space) {
  return RANGES[space].map(([low, high]) => low + rand() * (high - low));
}

// colorjs keeps HSL and HWB percentages as 0–100; this library keeps them as
// 0–1, as CSS Color 4's own arithmetic does.
const toColorjs = (space, coords) => {
  if (space === "hsl" || space === "hsv" || space === "hwb") {
    return [coords[0], coords[1] * 100, coords[2] * 100];
  }
  return coords.slice();
};
const fromColorjs = (space, coords) => {
  if (space === "hsl" || space === "hsv" || space === "hwb") {
    return [coords[0], coords[1] / 100, coords[2] / 100];
  }
  return coords.slice();
};

const colorjsName = (space) =>
  space === "display-p3" ? "p3" : space === "a98-rgb" ? "a98rgb" : space === "prophoto-rgb" ? "prophoto" : space;

function viaColorjs(from, to, coords) {
  const color = new Color(colorjsName(from), toColorjs(from, coords));
  return fromColorjs(to, color.to(colorjsName(to)).coords);
}

// The specification's own sample code, evaluated as one function so that its
// top-level declarations stay out of this module.
// conversions.js multiplies matrices with multiply-matrices.js, so both are
// fetched and evaluated as one script.
const specSource =
  execFileSync("curl", ["-fsSL", SPEC_BASE + "multiply-matrices.js"], {
    encoding: "utf8",
  }) +
  execFileSync("curl", ["-fsSL", SPEC_BASE + "conversions.js"], {
    encoding: "utf8",
  });
const spec = new Function(
  specSource +
    `
return { lin_sRGB, gam_sRGB, lin_P3, gam_P3, lin_2020, gam_2020,
         lin_a98rgb, gam_a98rgb, lin_ProPhoto, gam_ProPhoto,
         lin_sRGB_to_XYZ, XYZ_to_lin_sRGB, lin_P3_to_XYZ, XYZ_to_lin_P3,
         lin_2020_to_XYZ, XYZ_to_lin_2020, lin_a98rgb_to_XYZ, XYZ_to_lin_a98rgb,
         lin_ProPhoto_to_XYZ, XYZ_to_lin_ProPhoto,
         D65_to_D50, D50_to_D65, XYZ_to_Lab, Lab_to_XYZ,
         Lab_to_LCH, LCH_to_Lab, XYZ_to_OKLab, OKLab_to_XYZ,
         OKLab_to_OKLCH, OKLCH_to_OKLab };`,
)();

const specXyz = (from, coords) => {
  switch (from) {
    case "srgb":
      return spec.lin_sRGB_to_XYZ(spec.lin_sRGB(coords));
    case "srgb-linear":
      return spec.lin_sRGB_to_XYZ(coords);
    case "display-p3":
      return spec.lin_P3_to_XYZ(spec.lin_P3(coords));
    case "rec2020":
      return spec.lin_2020_to_XYZ(spec.lin_2020(coords));
    case "a98-rgb":
      return spec.lin_a98rgb_to_XYZ(spec.lin_a98rgb(coords));
    case "prophoto-rgb":
      return spec.D50_to_D65(spec.lin_ProPhoto_to_XYZ(spec.lin_ProPhoto(coords)));
    case "xyz-d65":
      return coords.slice();
    case "xyz-d50":
      return spec.D50_to_D65(coords);
    case "lab":
      return spec.D50_to_D65(spec.Lab_to_XYZ(coords));
    case "lch":
      return spec.D50_to_D65(spec.Lab_to_XYZ(spec.LCH_to_Lab(coords)));
    case "oklab":
      return spec.OKLab_to_XYZ(coords);
    case "oklch":
      return spec.OKLab_to_XYZ(spec.OKLCH_to_OKLab(coords));
    default:
      // HSL, HSV and HWB are defined on sRGB by formulas the spec prints in
      // prose rather than in this sample file, so they are left to colorjs.
      return null;
  }
};

const specOf = (to, xyz) => {
  switch (to) {
    case "srgb":
      return spec.gam_sRGB(spec.XYZ_to_lin_sRGB(xyz));
    case "srgb-linear":
      return spec.XYZ_to_lin_sRGB(xyz);
    case "display-p3":
      return spec.gam_P3(spec.XYZ_to_lin_P3(xyz));
    case "rec2020":
      return spec.gam_2020(spec.XYZ_to_lin_2020(xyz));
    case "a98-rgb":
      return spec.gam_a98rgb(spec.XYZ_to_lin_a98rgb(xyz));
    case "prophoto-rgb":
      return spec.gam_ProPhoto(spec.XYZ_to_lin_ProPhoto(spec.D65_to_D50(xyz)));
    case "xyz-d65":
      return xyz.slice();
    case "xyz-d50":
      return spec.D65_to_D50(xyz);
    case "lab":
      return spec.XYZ_to_Lab(spec.D65_to_D50(xyz));
    case "lch":
      return spec.Lab_to_LCH(spec.XYZ_to_Lab(spec.D65_to_D50(xyz)));
    case "oklab":
      return spec.XYZ_to_OKLab(xyz);
    case "oklch":
      return spec.OKLab_to_OKLCH(spec.XYZ_to_OKLab(xyz));
    default:
      return null;
  }
};

function viaSpec(from, to, coords) {
  const xyz = specXyz(from, coords);
  if (!xyz) return null;
  const out = specOf(to, xyz);
  if (!out) return null;
  // The reference reports a meaningless hue as NaN; this library does the same,
  // and the table keeps it so the test can insist on it.
  return out;
}

const fmt = (value) => (Number.isNaN(value) ? "nan" : String(value));

const lines = [];
for (const [from, to] of PAIRS) {
  for (let i = 0; i < SAMPLES; i++) {
    const coords = sample(from);
    const reference = viaSpec(from, to, coords);
    if (reference) {
      lines.push(["spec", from, to, ...coords, ...reference].map(fmt).join("\t"));
    }
    const other = viaColorjs(from, to, coords);
    lines.push(["colorjs", from, to, ...coords, ...other].map(fmt).join("\t"));
  }
}

writeFileSync(OUT, lines.join("\n") + "\n");
console.log(`${lines.length} vectors written to ${OUT}`);
