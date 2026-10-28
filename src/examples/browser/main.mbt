// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Everything the documentation page shows about one CSS colour, as JSON.
///
/// The page hands over whatever the reader typed or dragged, and gets back the
/// spellings, the components in every space, both contrast measures and the
/// terminal slots. All of it comes from this library: the page does no colour
/// arithmetic of its own, so what it shows is what the package does.
///
/// An unreadable value answers `{"ok": false}`, which is the page's cue to say
/// so rather than to guess.
pub fn facts(css : String) -> String {
  let color = match @moonrgba.Color::decode_opt(css) {
    Some(color) => color
    None => return Json({ "ok": Json(false) }).stringify()
  }
  let json : Json = {
    "ok": Json(true),
    "read": Json(css),
    "shortest": Json(color.encode()),
    "hex": Json(color.encode(format=@moonrgba.Format::Hex)),
    "name": match color.name() {
      Some(name) => Json(name)
      None => Json::null()
    },
    "alpha": Json(trim(color.alpha)),
    "spellings": Json(spellings(color)),
    "spaces": Json(space_rows(color)),
    "contrast": Json(contrast(color)),
    "terminal": Json(terminal(color)),
    "gamut": Json(gamut(color)),
  }
  json.stringify()
}

///|
/// A number as the page prints it: six places, no trailing zeros, and `none`
/// where the library has a missing component.
fn trim(value : Double) -> String {
  if value.is_nan() {
    return "none"
  }
  let rounded = @math.round(value * 1000000.0) / 1000000.0
  if rounded == 0.0 {
    return "0"
  }
  rounded.to_string()
}

///|
fn percent(value : Double) -> String {
  let text = trim(value * 100.0)
  if text == "none" {
    text
  } else {
    text + "%"
  }
}

///|
/// The colour written every way CSS can write it.
fn spellings(color : @moonrgba.Color) -> Json {
  let rows : Array[Json] = []
  let add = fn(label : String, text : String) {
    rows.push(Json({ "label": Json(label), "css": Json(text) }))
  }
  add("hex", color.encode(format=@moonrgba.Format::Hex))
  add("rgb", color.encode(format=@moonrgba.Format::Rgb))
  add("hsl", color.encode(format=@moonrgba.Format::Hsl))
  add("hwb", color.encode(format=@moonrgba.Format::Hwb))
  add("lab", color.encode(format=@moonrgba.Format::Lab))
  add("lch", color.encode(format=@moonrgba.Format::Lch))
  add("oklab", color.encode(format=@moonrgba.Format::Oklab))
  add("oklch", color.encode(format=@moonrgba.Format::Oklch))
  add("color(srgb)", color.encode(format=@moonrgba.Format::Color))
  add("color(display-p3)", color.to_display_p3().encode())
  add("color(rec2020)", color.to_rec2020().encode())
  add("color(a98-rgb)", color.to_a98_rgb().encode())
  add("color(prophoto-rgb)", color.to_prophoto().encode())
  add("color(xyz-d65)", color.to_xyz_d65().encode())
  add("color(xyz-d50)", color.to_xyz_d50().encode())
  Json(rows)
}

///|
/// One row per space: the name, and the components in that space's own units.
fn space_rows(color : @moonrgba.Color) -> Json {
  let rows : Array[Json] = []
  let add = fn(name : String, text : String) {
    rows.push(Json({ "space": Json(name), "value": Json(text) }))
  }
  let plain = fn(name : String, space : @moonrgba.Space) {
    let (x, y, z) = color.to_space(space).components()
    add(name, trim(x) + " " + trim(y) + " " + trim(z))
  }
  plain("srgb", @moonrgba.Space::Srgb)
  plain("srgb-linear", @moonrgba.Space::SrgbLinear)
  let hsl = color.to_hsl()
  add("hsl", trim(hsl.x) + " " + percent(hsl.y) + " " + percent(hsl.z))
  let hsv = color.to_hsv()
  add("hsv", trim(hsv.x) + " " + percent(hsv.y) + " " + percent(hsv.z))
  let hwb = color.to_hwb()
  add("hwb", trim(hwb.x) + " " + percent(hwb.y) + " " + percent(hwb.z))
  plain("lab", @moonrgba.Space::Lab)
  let lch = color.to_lch()
  add("lch", trim(lch.x) + " " + trim(lch.y) + " " + trim(lch.z))
  plain("oklab", @moonrgba.Space::Oklab)
  let oklch = color.to_oklch()
  add("oklch", trim(oklch.x) + " " + trim(oklch.y) + " " + trim(oklch.z))
  plain("xyz-d65", @moonrgba.Space::XyzD65)
  plain("xyz-d50", @moonrgba.Space::XyzD50)
  plain("display-p3", @moonrgba.Space::DisplayP3)
  plain("rec2020", @moonrgba.Space::Rec2020)
  plain("a98-rgb", @moonrgba.Space::A98Rgb)
  plain("prophoto-rgb", @moonrgba.Space::ProPhoto)
  let cmyk = color.to_cmyk()
  let inks = percent(cmyk.c) + " " + percent(cmyk.m) + " " + percent(cmyk.y)
  add("cmyk", inks + " " + percent(cmyk.k))
  let ycbcr = color.to_ycbcr(luma=@moonrgba.Luma::Bt709)
  add("ycbcr-709", trim(ycbcr.x) + " " + trim(ycbcr.y) + " " + trim(ycbcr.z))
  Json(rows)
}

///|
/// Both measures against white and against black, with the text first for APCA.
fn contrast(color : @moonrgba.Color) -> Json {
  let white = @moonrgba.Color::white()
  let black = @moonrgba.Color::black()
  let json : Json = {
    "wcagWhite": Json(round(color.contrast(white), 100.0)),
    "wcagBlack": Json(round(color.contrast(black), 100.0)),
    "apcaWhite": Json(round(color.apca(white), 10.0)),
    "apcaBlack": Json(round(color.apca(black), 10.0)),
    "luminance": Json(round(color.luminance(), 10000.0)),
  }
  json
}

///|
fn round(value : Double, scale : Double) -> Double {
  @math.round(value * scale) / scale
}

///|
/// What a terminal would make of the colour: the nearest named slot, the nearest
/// palette slot, and the three bytes of true colour.
fn terminal(color : @moonrgba.Color) -> Json {
  let (r, g, b) = color.rgb8()
  let slot = color.to_ansi256()
  let json : Json = {
    "ansi16": Json(color.to_ansi16().to_string()),
    "ansi256": Json(slot.code()),
    "ansi256Hex": Json(slot.color().encode(format=@moonrgba.Format::Hex)),
    "rgb8": Json(r.to_string() + ", " + g.to_string() + ", " + b.to_string()),
  }
  json
}

///|
/// Which gamuts hold the colour, and what it becomes in the narrowest of them.
fn gamut(color : @moonrgba.Color) -> Json {
  let json : Json = {
    "srgb": Json(color.in_gamut(space=@moonrgba.Space::Srgb)),
    "p3": Json(color.in_gamut(space=@moonrgba.Space::DisplayP3)),
    "rec2020": Json(color.in_gamut(space=@moonrgba.Space::Rec2020)),
    "mapped": Json(
      color
      .to_gamut(space=@moonrgba.Space::Srgb)
      .encode(format=@moonrgba.Format::Hex),
    ),
  }
  json
}

///|
/// The sRGB boundary at one lightness, and the colours inside it.
///
/// `chroma` is the largest chroma that still fits at each hue: 180 values, two
/// degrees apart, starting at hue 0 — the outline of what a screen can show at
/// that lightness. `bands` is the same surface painted: six rings from the
/// boundary inwards, each a row of hex colours, so the page can fill the shape
/// with colours the library computed rather than with a gradient of its own.
///
/// The outline is found by halving the distance between a chroma that fits and
/// one that does not, so it is the boundary rather than an approximation of it.
pub fn slice(lightness : Double) -> String {
  let edges : Array[Double] = []
  for step in 0..<180 {
    edges.push(edge_chroma(lightness, step.to_double() * 2.0))
  }
  let chroma : Array[Json] = []
  for edge in edges {
    chroma.push(Json(round(edge, 10000.0)))
  }
  // Ten rings, outermost first. Six left the steps visible as contours; ten is
  // where the surface reads as a surface and still costs one screen of fills.
  let bands : Array[Json] = []
  for band in 0..<10 {
    let share = 1.0 - band.to_double() / 10.0
    let row : Array[Json] = []
    for step in 0..<180 {
      let hue = step.to_double() * 2.0
      row.push(
        Json(
          @moonrgba.Color::oklch(lightness, edges[step] * share, hue).encode(
            format=@moonrgba.Format::Hex,
          ),
        ),
      )
    }
    bands.push(Json(row))
  }
  let core = @moonrgba.Color::oklch(lightness, 0.0, 0.0).encode(
    format=@moonrgba.Format::Hex,
  )
  let json : Json = {
    "l": Json(round(lightness, 10000.0)),
    "step": Json(2),
    "core": Json(core),
    "chroma": Json(chroma),
    "bands": Json(bands),
  }
  json.stringify()
}

///|
/// The largest chroma that is inside sRGB at this lightness and hue.
fn edge_chroma(lightness : Double, hue : Double) -> Double {
  let mut low = 0.0
  let mut high = 0.5
  for _ in 0..<22 {
    let middle = (low + high) / 2.0
    if @moonrgba.Color::oklch(lightness, middle, hue).in_gamut(
        space=@moonrgba.Space::Srgb,
      ) {
      low = middle
    } else {
      high = middle
    }
  }
  low
}

///|
/// One colour's journey into the gamut: where it sits, where the boundary is at
/// its lightness and hue, what the library maps it to, and how far apart from
/// it the clipped version is along the way.
///
/// `curve` is the decision the mapping makes — ΔE OK between the candidate and
/// the colour clipping would give — sampled from grey out past the boundary. The
/// 0.02 line on that curve is the just-noticeable difference the algorithm
/// compares against, so the page can show the test rather than describe it.
pub fn section(css : String) -> String {
  let color = match @moonrgba.Color::decode_opt(css) {
    Some(color) => color
    None => return Json({ "ok": Json(false) }).stringify()
  }
  let oklch = color.to_oklch()
  let lightness = oklch.x
  let chroma = oklch.y
  let hue = oklch.z
  let edge = edge_chroma(lightness, hue)
  let mapped = color.to_gamut(space=@moonrgba.Space::Srgb)
  let mapped_lch = mapped.to_oklch()
  let reach = if chroma > edge { chroma } else { edge }
  let curve : Array[Json] = []
  for step in 0..<=24 {
    let at = reach * step.to_double() / 24.0
    let candidate = @moonrgba.Color::oklch(lightness, at, hue)
    let clipped = candidate.clip(space=@moonrgba.Space::Srgb)
    curve.push(
      Json({
        "c": Json(round(at, 10000.0)),
        "de": Json(
          round(candidate.delta_e(clipped, delta=@moonrgba.Delta::Ok), 100000.0),
        ),
      }),
    )
  }
  let json : Json = {
    "ok": Json(true),
    "l": Json(round(lightness, 10000.0)),
    "c": Json(round(chroma, 10000.0)),
    "h": Json(round(hue, 10000.0)),
    "inside": Json(color.in_gamut(space=@moonrgba.Space::Srgb)),
    "edge": Json(round(edge, 10000.0)),
    "edgeHex": Json(
      @moonrgba.Color::oklch(lightness, edge, hue).encode(
        format=@moonrgba.Format::Hex,
      ),
    ),
    "mapped": Json({
      "l": Json(round(mapped_lch.x, 10000.0)),
      "c": Json(round(mapped_lch.y, 10000.0)),
      "h": Json(round(mapped_lch.z, 10000.0)),
      "hex": Json(mapped.encode(format=@moonrgba.Format::Hex)),
    }),
    "clipHex": Json(
      color
      .clip(space=@moonrgba.Space::Srgb)
      .encode(format=@moonrgba.Format::Hex),
    ),
    "delta": Json(
      round(color.delta_e(mapped, delta=@moonrgba.Delta::Ok), 100000.0),
    ),
    "curve": Json(curve),
  }
  json.stringify()
}
