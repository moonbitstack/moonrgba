// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Bringing a colour into a gamut.
//
// CSS Color 4 §13.2 defines this as a chroma reduction in OkLCh with a
// just-noticeable-difference stop, rather than a clip: clipping turns a colour
// outside the gamut into the nearest point on the surface, which shifts its hue
// and flattens its light and dark ends; reducing chroma at constant lightness
// and hue keeps what the author asked for and gives up only what the display
// cannot show.
//
// The loop is a bisection on chroma. Where the plain reduction would still be
// too far from the original — more than a JND — the result is clipped instead,
// which is the "local-MINDE" step: it keeps a colour that cannot be reached by
// reducing chroma at all, such as a saturated blue in sRGB, from collapsing to
// grey.

///|
/// Whether a space has a bounded gamut at all. XYZ and the polar spaces do not:
/// every triple is a colour, and only the RGB spaces say which ones a display
/// can show.
pub fn Space::has_gamut(self : Space) -> Bool {
  match self {
    Srgb
    | SrgbLinear
    | DisplayP3
    | DisplayP3Linear
    | Rec2020
    | A98Rgb
    | ProPhoto => true
    _ => false
  }
}

///|
/// The largest amount by which a colour may leave the gamut and still count as
/// inside it. Matrices do not land on 1.0 exactly, and a colour that is 1e-17
/// over the edge is not out of gamut in any sense a viewer could see.
let gamut_epsilon : Double = 1.0e-6

///|
/// The difference below which two colours look the same: 0.02 in Oklab, which
/// is the just-noticeable difference CSS Color 4 uses for this algorithm.
let jnd : Double = 0.02

///|
/// The smallest chroma step worth taking; the bisection stops here.
let chroma_step : Double = 0.0001

///|
/// Whether the colour is inside the gamut of its space, or of `space` if one is
/// given.
///
/// A space with no gamut answers `true`: there is nothing for a colour to be
/// outside of.
pub fn Color::in_gamut(self : Color, space? : Space) -> Bool {
  let target = space.unwrap_or(self.space)
  let color = self.to_space(target)
  match target {
    Srgb
    | SrgbLinear
    | DisplayP3
    | DisplayP3Linear
    | Rec2020
    | A98Rgb
    | ProPhoto => {
      let inside = fn(value : Double) {
        // A missing component is not outside anything.
        if value.is_nan() {
          return true
        }
        value >= -gamut_epsilon && value <= 1.0 + gamut_epsilon
      }
      inside(color.x) && inside(color.y) && inside(color.z)
    }
    _ => true
  }
}

///|
/// The colour with every component clamped into 0–1 of its space, which is what
/// a display does with a colour it cannot show.
///
/// Clipping is a blunt instrument: it moves a colour along whichever axis
/// overflows and leaves hue and lightness to follow. `to_gamut` is the answer
/// that keeps them; this is the answer that costs nothing, and the one to use
/// when the colour is already close to the edge.
pub fn Color::clip(self : Color, space? : Space) -> Color {
  let target = space.unwrap_or(self.space)
  let color = self.to_space(target)
  if !target.has_gamut() {
    return color
  }
  let clamp = fn(value : Double) {
    if value.is_nan() {
      value
    } else if value < 0.0 {
      0.0
    } else if value > 1.0 {
      1.0
    } else {
      value
    }
  }
  color.with_components(clamp(color.x), clamp(color.y), clamp(color.z))
}

///|
/// The colour brought into the gamut of its space, or of `space` if one is
/// given, by CSS Color 4's chroma reduction.
///
/// A colour already inside comes back unchanged, in the space asked for. One
/// outside loses chroma at constant lightness and hue until it fits, and only in
/// the cases where that cannot work — a colour too light or too dark to exist at
/// all — falls back to clipping.
pub fn Color::to_gamut(self : Color, space? : Space) -> Color {
  let target = space.unwrap_or(self.space)
  let color = self.to_space(target)
  if !target.has_gamut() || color.in_gamut() {
    return color
  }
  let oklch = color.to_oklch()
  // Nothing at either end of the lightness scale can be shown at all, and the
  // bisection would spend its steps finding that out.
  if oklch.x >= 1.0 {
    return Color::white().to_space(target).with_alpha(color.alpha)
  }
  if oklch.x <= 0.0 {
    return Color::black().to_space(target).with_alpha(color.alpha)
  }
  let mut low = 0.0
  let mut high = oklch.y
  let mut low_is_in_gamut = true
  let mut current = color.clip()
  while high - low > chroma_step {
    let chroma = (low + high) / 2.0
    let candidate = oklch.with_components(oklch.x, chroma, oklch.z)
    let in_target = candidate.to_space(target)
    if low_is_in_gamut && in_target.in_gamut() {
      low = chroma
      current = in_target
    } else {
      let clipped = in_target.clip()
      let error = clipped.delta_e(in_target, delta=Ok)
      if error < jnd {
        if jnd - error < chroma_step {
          return clipped.with_alpha(color.alpha)
        }
        // The clipped colour is closer to the candidate than a JND, so the
        // candidate is inside after all; keep going up.
        low_is_in_gamut = false
        low = chroma
        current = clipped
      } else {
        high = chroma
      }
    }
  }
  current.with_alpha(color.alpha)
}
