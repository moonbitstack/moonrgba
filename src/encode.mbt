// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Writing a colour as CSS.
//
// The rule throughout is the shortest spelling that reads back as the same
// colour. Three decisions follow from it and are worth stating, because each of
// them could go the other way:
//
//   * Integers drop their decimal point, and everything else is rounded to five
//     places with trailing zeros trimmed. Five is where the numbers a colour is
//     made of stop mattering — an 8-bit channel needs two — and it is what the
//     `color()` examples in CSS Color 4 print.
//   * A component that is not a finite number is written as `none`, which is
//     CSS's own way of saying the value does not exist. That is what a missing
//     component is, and encoding must not invent a zero for it.
//   * `rgb()`, `hsl()` and `hwb()` clamp to the range their syntax allows,
//     because a reader would clamp anyway; `lab()`, `oklch()` and `color()`
//     do not, because a colour outside a gamut is a real colour and losing it
//     on the way out would be worse than a long string.

///|
/// How to write a colour out.
pub(all) enum Format {
  /// The shortest spelling the colour's own space allows, falling back to sRGB
  /// for the spaces CSS has no syntax for.
  Shortest
  /// `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`, whichever is shortest and exact.
  /// Always sRGB, so a colour in another space is converted and may be clipped.
  Hex
  /// `rgb(0 0 0)` or `rgb(0 0 0 / 0.5)`, always sRGB.
  Rgb
  /// `hsl(0 0% 0%)`.
  Hsl
  /// `hwb(0 0% 0%)`.
  Hwb
  /// `lab(0 0 0)`.
  Lab
  /// `lch(0 0 0)`.
  Lch
  /// `oklab(0 0 0)`.
  Oklab
  /// `oklch(0 0 0)`.
  Oklch
  /// `color(srgb 0 0 0)` and the rest of the spaces `color()` takes. A space it
  /// cannot name is written in its own syntax instead.
  Color
  /// The name the colour has, or the same string `Hex` would give.
  Named
} derive(Eq, Debug)

///|
pub extend Format with Eq::{equal, not_equal}

///|
pub extend Format with Debug::{to_repr}

///|
/// A format writes itself with the name a caller would use for it.
pub impl Show for Format with fn output(self, logger) {
  logger.write_string(
    match self {
      Shortest => "shortest"
      Hex => "hex"
      Rgb => "rgb"
      Hsl => "hsl"
      Hwb => "hwb"
      Lab => "lab"
      Lch => "lch"
      Oklab => "oklab"
      Oklch => "oklch"
      Color => "color"
      Named => "named"
    },
  )
}

///|
pub extend Format with Show::{to_string, output}

///|
/// Five places, which is where a colour stops changing.
let decimals : Double = 100000.0

///|
/// A decimal number as CSS writes it: no exponent, no trailing zeros, and
/// `none` where there is no number to write.
fn decimal(value : Double) -> String {
  if value.is_nan() ||
    value == @double.infinity ||
    value == @double.neg_infinity {
    return "none"
  }
  let rounded = @math.round(value * decimals) / decimals
  let text = rounded.to_string()
  // Rounding can leave a negative zero behind, and `-0` in a colour reads as a
  // mistake even though it is the same number.
  if text == "-0" {
    "0"
  } else {
    text
  }
}

///|
/// A hue, which is an angle rather than a quantity: rounding 359.999996 must
/// write 0 rather than 360, because 360 is a whole turn and a reader that
/// normalises it would be right to, leaving the two spellings a full turn apart.
fn hue_text(value : Double) -> String {
  let text = decimal(value)
  if text == "360" {
    "0"
  } else {
    text
  }
}

///|
/// A percentage, which is how `hsl()` and `hwb()` write saturation, lightness,
/// whiteness and blackness.
fn percentage(value : Double) -> String {
  let text = decimal(value * 100.0)
  // A missing component is `none`, and `none%` is not a thing.
  if text == "none" {
    text
  } else {
    text + "%"
  }
}

///|
/// One hexadecimal digit.
fn hex_digit(value : Int32) -> Char {
  let digits = "0123456789abcdef"
  digits.unsafe_get(value).unsafe_to_char()
}

///|
/// A component rounded to a channel byte, clamped: a byte has no room outside
/// 0–255 and a hexadecimal colour has no way to say so.
fn byte_of(value : Double) -> Int32 {
  if value.is_nan() {
    return 0
  }
  let scaled = @math.round(value * 255.0)
  if scaled <= 0.0 {
    0
  } else if scaled >= 255.0 {
    255
  } else {
    scaled.to_int()
  }
}

///|
/// Whether a channel is a multiple of 17, which is what lets `#rgb` stand in
/// for `#rrggbb`: the short form repeats each digit.
fn is_short_byte(value : Int32) -> Bool {
  value % 17 == 0
}

///|
fn write_hex_pairs(
  out : StringBuilder,
  r : Int32,
  g : Int32,
  b : Int32,
  a : Int32?,
) -> Unit {
  out.write_char(hex_digit(r / 16))
  out.write_char(hex_digit(r % 16))
  out.write_char(hex_digit(g / 16))
  out.write_char(hex_digit(g % 16))
  out.write_char(hex_digit(b / 16))
  out.write_char(hex_digit(b % 16))
  match a {
    Some(a) => {
      out.write_char(hex_digit(a / 16))
      out.write_char(hex_digit(a % 16))
    }
    None => ()
  }
}

///|
/// The shortest hexadecimal spelling that keeps the colour exactly.
///
/// Exactness is what decides between `#f00` and `#ff0000`: the short form means
/// the same only when each channel repeats a digit, and when a channel is not a
/// whole byte at all no hexadecimal spelling is exact — the caller then writes
/// `rgb()` instead.
fn hex_text(color : Color) -> String {
  let srgb = color.to_srgb()
  let (r, g, b) = (byte_of(srgb.x), byte_of(srgb.y), byte_of(srgb.z))
  let alpha = if srgb.alpha >= 1.0 {
    None
  } else if srgb.alpha <= 0.0 {
    Some(0)
  } else {
    Some(byte_of(srgb.alpha))
  }
  let out = StringBuilder()
  out.write_char('#')
  let short = is_short_byte(r) && is_short_byte(g) && is_short_byte(b)
  let short_alpha = match alpha {
    None => true
    Some(a) => is_short_byte(a)
  }
  if short && short_alpha {
    out.write_char(hex_digit(r / 17))
    out.write_char(hex_digit(g / 17))
    out.write_char(hex_digit(b / 17))
    match alpha {
      Some(a) => out.write_char(hex_digit(a / 17))
      None => ()
    }
  } else {
    write_hex_pairs(out, r, g, b, alpha)
  }
  out.to_string()
}

///|
/// Whether every channel and the alpha are whole bytes, and so whether a
/// hexadecimal spelling would keep the colour exactly. `0.5` alpha is not: its
/// byte is 127.5, and `#...80` would be a different colour.
fn is_byte_exact(color : Color) -> Bool {
  let (r, g, b) = color.components()
  let is_whole_byte = fn(value : Double) {
    let scaled = value * 255.0
    (scaled - @math.round(scaled)).abs() < 1.0e-9
  }
  is_whole_byte(r) &&
  is_whole_byte(g) &&
  is_whole_byte(b) &&
  is_whole_byte(color.alpha)
}

///|
/// `rgb()` with the alpha left out when it is one.
fn rgb_text(color : Color) -> String {
  let srgb = color.to_srgb()
  let out = StringBuilder()
  out.write_string("rgb(")
  out.write_string(decimal(clamp01(srgb.x) * 255.0))
  out.write_char(' ')
  out.write_string(decimal(clamp01(srgb.y) * 255.0))
  out.write_char(' ')
  out.write_string(decimal(clamp01(srgb.z) * 255.0))
  write_alpha(out, srgb.alpha)
  out.write_char(')')
  out.to_string()
}

///|
/// The ` / alpha` tail every function syntax shares, or nothing when the colour
/// is opaque.
fn write_alpha(out : StringBuilder, alpha : Double) -> Unit {
  if alpha >= 1.0 {
    return
  }
  out.write_string(" / ")
  out.write_string(decimal(if alpha <= 0.0 { 0.0 } else { alpha }))
}

///|
/// A colour in a function syntax: the name, the three components as already
/// written strings, and the alpha.
fn function_text(
  name : StringView,
  first : String,
  second : String,
  third : String,
  alpha : Double,
) -> String {
  let out = StringBuilder()
  out.write_view(name)
  out.write_char('(')
  out.write_string(first)
  out.write_char(' ')
  out.write_string(second)
  out.write_char(' ')
  out.write_string(third)
  write_alpha(out, alpha)
  out.write_char(')')
  out.to_string()
}

///|
/// `hsl()`, with saturation and lightness clamped because the syntax cannot
/// carry anything else.
fn hsl_text(color : Color) -> String {
  let hsl = color.to_hsl()
  function_text(
    "hsl",
    hue_text(hsl.x),
    percentage(clamp01(hsl.y)),
    percentage(clamp01(hsl.z)),
    hsl.alpha,
  )
}

///|
fn hwb_text(color : Color) -> String {
  let hwb = color.to_hwb()
  function_text(
    "hwb",
    hue_text(hwb.x),
    percentage(clamp01(hwb.y)),
    percentage(clamp01(hwb.z)),
    hwb.alpha,
  )
}

///|
fn lab_text(color : Color) -> String {
  let lab = color.to_lab()
  function_text(
    "lab",
    decimal(lab.x),
    decimal(lab.y),
    decimal(lab.z),
    lab.alpha,
  )
}

///|
fn lch_text(color : Color) -> String {
  let lch = color.to_lch()
  function_text(
    "lch",
    decimal(lch.x),
    decimal(lch.y),
    hue_text(lch.z),
    lch.alpha,
  )
}

///|
fn oklab_text(color : Color) -> String {
  let oklab = color.to_oklab()
  function_text(
    "oklab",
    decimal(oklab.x),
    decimal(oklab.y),
    decimal(oklab.z),
    oklab.alpha,
  )
}

///|
fn oklch_text(color : Color) -> String {
  let oklch = color.to_oklch()
  function_text(
    "oklch",
    decimal(oklch.x),
    decimal(oklch.y),
    hue_text(oklch.z),
    oklch.alpha,
  )
}

///|
/// Whether every component and the alpha are inside 0–1, which is the range the
/// sRGB syntaxes can carry without clamping.
fn is_unit_ranged(color : Color) -> Bool {
  let (r, g, b) = color.components()
  // The same slack the gamut check uses: a conversion that lands a hair over
  // one has not left the gamut, and writing it as `color(srgb 1 0 0)` because of
  // the last bit of a double would be a strange thing to do.
  let inside = fn(value : Double) {
    if value.is_nan() {
      return true
    }
    value >= -1.0e-6 && value <= 1.0 + 1.0e-6
  }
  inside(r) && inside(g) && inside(b) && inside(color.alpha)
}

///|
/// An sRGB colour in whichever spelling is shortest and exact: hex when every
/// channel is a whole byte, `rgb()` when they are fractions, and `color(srgb)`
/// when a component is outside 0–1 and `rgb()` would clamp it away.
fn srgb_text(color : Color) -> String {
  let srgb = color.to_srgb()
  if !is_unit_ranged(srgb) {
    color_syntax(srgb)
  } else if is_byte_exact(srgb) {
    hex_text(srgb)
  } else {
    rgb_text(srgb)
  }
}

///|
/// A colour as CSS, in the shortest spelling that reads back as the same colour.
///
/// Without a format the colour stays in the space it is in, which matters: an
/// OkLCh colour written through sRGB would be clipped to a gamut it never asked
/// for. The spaces CSS cannot spell — HSV, YCbCr — go out as sRGB, and the
/// unresolved `currentcolor` goes out as itself.
pub fn Color::encode(self : Color, format? : Format) -> String {
  // `currentcolor` has no components to write, so no format can apply to it:
  // writing it as a hexadecimal colour would resolve it to black, which is a
  // different declaration.
  if self.space is Current {
    return "currentcolor"
  }
  match format {
    Some(Hex) => hex_text(self)
    Some(Rgb) => rgb_text(self)
    Some(Hsl) => hsl_text(self)
    Some(Hwb) => hwb_text(self)
    Some(Lab) => lab_text(self)
    Some(Lch) => lch_text(self)
    Some(Oklab) => oklab_text(self)
    Some(Oklch) => oklch_text(self)
    Some(Color) =>
      if self.space.is_predefined() {
        color_syntax(self)
      } else {
        self.natural_text()
      }
    Some(Named) =>
      match self.name() {
        Some(name) => name
        None => hex_text(self)
      }
    Some(Shortest) | None => self.natural_text()
  }
}

///|
fn Color::natural_text(self : Color) -> String {
  match self.space {
    Srgb => srgb_text(self)
    Hsl => hsl_text(self)
    Hwb => hwb_text(self)
    Lab => lab_text(self)
    Lch => lch_text(self)
    Oklab => oklab_text(self)
    Oklch => oklch_text(self)
    _ =>
      if self.space.is_predefined() {
        color_syntax(self)
      } else {
        // HSV and YCbCr have no CSS syntax, and inventing one would produce a
        // string no reader accepts; sRGB is the one every consumer understands.
        srgb_text(self)
      }
  }
}

///|
/// `color(<space> c1 c2 c3 / a)`.
fn color_syntax(color : Color) -> String {
  let out = StringBuilder()
  out.write_string("color(")
  out.write_string(color.space.code())
  out.write_char(' ')
  out.write_string(decimal(color.x))
  out.write_char(' ')
  out.write_string(decimal(color.y))
  out.write_char(' ')
  out.write_string(decimal(color.z))
  write_alpha(out, color.alpha)
  out.write_char(')')
  out.to_string()
}

///|
/// A colour writes itself as CSS, so that `\{color}` in a log or an error is
/// something a browser would accept.
pub impl Show for Color with fn output(self, logger) {
  logger.write_string(self.encode())
}

///|
pub extend Color with Show::{to_string, output}
