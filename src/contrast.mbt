// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// How readable one colour is on another.
//
// Two answers, because the field has two. WCAG 2's contrast ratio is the one
// that regulations and audits ask for: a ratio from 1 to 21, symmetric, and
// blunt — it treats a pair of dark colours and a pair of light ones the same way
// round, which is not how eyes work. APCA is its proposed replacement: a
// signed lightness contrast from about −108 to 108, directional, and built from
// a model of how the visual system responds to polarity.
//
// Both start from luminance, and both are defined on sRGB: a colour in a wider
// gamut is converted, and one outside 0–1 is clamped, because the question is
// what a screen shows.

///|
/// Relative luminance per WCAG 2: sRGB made linear, weighted by the eye's
/// sensitivity to each primary, with the components clamped to what a screen can
/// show.
pub fn Color::luminance(self : Color) -> Double {
  let (r, g, b) = self.to_srgb().components()
  let linear = fn(value : Double) -> Double {
    let value = if value.is_nan() {
      0.0
    } else if value < 0.0 {
      0.0
    } else if value > 1.0 {
      1.0
    } else {
      value
    }
    // WCAG writes the break at 0.03928 where the sRGB specification writes
    // 0.04045; the two agree to seven places and the definition is WCAG's.
    if value <= 0.03928 {
      value / 12.92
    } else {
      @math.pow((value + 0.055) / 1.055, 2.4)
    }
  }
  0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}

///|
/// The WCAG 2 contrast ratio between two colours: 1 for the same colour, 21 for
/// black on white.
///
/// The order does not matter — this is the measure that is symmetric, and that
/// is one of the reasons APCA exists.
pub fn Color::contrast(self : Color, other : Color) -> Double {
  let first = self.luminance()
  let second = other.luminance()
  let lighter = if first > second { first } else { second }
  let darker = if first > second { second } else { first }
  (lighter + 0.05) / (darker + 0.05)
}

///|
/// The APCA lightness contrast `Lc` of this colour as text on `background`:
/// positive for dark text on a light background, negative the other way round,
/// and zero when the pair is too close to read at all.
///
/// The constants are APCA 0.98G-4g, the version the SAPC project publishes for
/// web use. A sign-flipped result is not a mistake: it says which way round the
/// pair is, and the thresholds for readable text are different in each
/// direction, so a caller that wants "is this readable" has to ask about a
/// specific way round.
pub fn Color::apca(self : Color, background : Color) -> Double {
  let text = apca_luminance(self)
  let backdrop = apca_luminance(background)
  // A soft clamp near black: what a screen actually emits at the bottom of its
  // range is not linear in the signal, and the model accounts for it.
  let soft = fn(value : Double) {
    if value > 0.022 {
      value
    } else {
      value + @math.pow(0.022 - value, 1.414)
    }
  }
  let text = soft(text)
  let backdrop = soft(backdrop)
  if (backdrop - text).abs() < 0.0005 {
    return 0.0
  }
  if backdrop > text {
    let raw = (@math.pow(backdrop, 0.56) - @math.pow(text, 0.57)) * 1.14
    if raw < 0.1 {
      0.0
    } else {
      (raw - 0.027) * 100.0
    }
  } else {
    let raw = (@math.pow(backdrop, 0.65) - @math.pow(text, 0.62)) * 1.14
    if raw > -0.1 {
      0.0
    } else {
      (raw + 0.027) * 100.0
    }
  }
}

///|
/// APCA's own luminance: a 2.4 power of each sRGB component, without the linear
/// segment WCAG keeps near black. For values that a screen can show the two
/// differ by very little; near black they differ by design.
fn apca_luminance(color : Color) -> Double {
  let (r, g, b) = color.to_srgb().components()
  let channel = fn(value : Double) {
    let value = if value.is_nan() {
      0.0
    } else if value < 0.0 {
      0.0
    } else if value > 1.0 {
      1.0
    } else {
      value
    }
    @math.pow(value, 2.4)
  }
  0.2126729 * channel(r) + 0.7151522 * channel(g) + 0.072175 * channel(b)
}
