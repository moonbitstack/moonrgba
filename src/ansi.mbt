// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The colours a terminal has.
//
// Three tiers, and the number that reaches a terminal is the interesting part:
// sixteen named colours that every emulator has, a 256-colour palette that most
// have, and twenty-four-bit colour that the ones in use today have. Reducing a
// colour to a lower tier is a nearest-neighbour search, and the question is what
// "nearest" means.
//
// It means ΔE OK here: the palette is uneven — the sixteen are arbitrary, the
// cube is coarse at the dark end and fine at the light one — and a distance
// measured in Oklab is even across that. Measuring in sRGB would put a colour
// near black further from its neighbours than the same distance near white.
//
// The palette is the one xterm uses, which is what every terminal emulator in
// practice is compatible with. It is not what the original ANSI standard said,
// and the two differ: the standard's blue was darker.

///|
/// The sixteen colours a terminal names, in the order their escape sequences
/// number them.
pub(all) enum Ansi16 {
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
} derive(Eq, Debug)

///|
pub extend Ansi16 with Eq::{equal, not_equal}

///|
pub extend Ansi16 with Debug::{to_repr}

///|
/// A named slot writes itself as the name a theme file would use.
pub impl Show for Ansi16 with fn output(self, logger) {
  logger.write_string(
    match self {
      Black => "black"
      Red => "red"
      Green => "green"
      Yellow => "yellow"
      Blue => "blue"
      Magenta => "magenta"
      Cyan => "cyan"
      White => "white"
      BrightBlack => "bright-black"
      BrightRed => "bright-red"
      BrightGreen => "bright-green"
      BrightYellow => "bright-yellow"
      BrightBlue => "bright-blue"
      BrightMagenta => "bright-magenta"
      BrightCyan => "bright-cyan"
      BrightWhite => "bright-white"
    },
  )
}

///|
pub extend Ansi16 with Show::{to_string, output}

///|
/// Where a named colour sits in the palette, which is also the low nibble of the
/// escape sequence that selects it.
pub fn Ansi16::code(self : Ansi16) -> Int32 {
  match self {
    Black => 0
    Red => 1
    Green => 2
    Yellow => 3
    Blue => 4
    Magenta => 5
    Cyan => 6
    White => 7
    BrightBlack => 8
    BrightRed => 9
    BrightGreen => 10
    BrightYellow => 11
    BrightBlue => 12
    BrightMagenta => 13
    BrightCyan => 14
    BrightWhite => 15
  }
}

///|
/// The colour a palette slot stands for, if the number names one.
pub fn Ansi16::of(code : Int32) -> Ansi16? {
  match code {
    0 => Some(Black)
    1 => Some(Red)
    2 => Some(Green)
    3 => Some(Yellow)
    4 => Some(Blue)
    5 => Some(Magenta)
    6 => Some(Cyan)
    7 => Some(White)
    8 => Some(BrightBlack)
    9 => Some(BrightRed)
    10 => Some(BrightGreen)
    11 => Some(BrightYellow)
    12 => Some(BrightBlue)
    13 => Some(BrightMagenta)
    14 => Some(BrightCyan)
    15 => Some(BrightWhite)
    _ => None
  }
}

///|
/// The sRGB colour of a named slot: xterm's defaults.
pub fn Ansi16::color(self : Ansi16) -> Color {
  match self {
    Black => Color::rgb(0, 0, 0)
    Red => Color::rgb(128, 0, 0)
    Green => Color::rgb(0, 128, 0)
    Yellow => Color::rgb(128, 128, 0)
    Blue => Color::rgb(0, 0, 128)
    Magenta => Color::rgb(128, 0, 128)
    Cyan => Color::rgb(0, 128, 128)
    White => Color::rgb(192, 192, 192)
    BrightBlack => Color::rgb(128, 128, 128)
    BrightRed => Color::rgb(255, 0, 0)
    BrightGreen => Color::rgb(0, 255, 0)
    BrightYellow => Color::rgb(255, 255, 0)
    BrightBlue => Color::rgb(0, 0, 255)
    BrightMagenta => Color::rgb(255, 0, 255)
    BrightCyan => Color::rgb(0, 255, 255)
    BrightWhite => Color::rgb(255, 255, 255)
  }
}

///|
/// A slot in the 256-colour palette: 0–15 are the named colours, 16–231 a 6×6×6
/// cube, and 232–255 a grey ramp.
pub(all) struct Ansi256 {
  /// 0–255. Kept in range by `Ansi256::of`; written by hand it is a number a
  /// terminal would mask, so nothing here trusts it to be inside.
  code : Int32
} derive(Eq, Debug)

///|
pub extend Ansi256 with Eq::{equal, not_equal}

///|
pub extend Ansi256 with Debug::{to_repr}

///|
/// The palette slot with this number. Numbers outside 0–255 are clamped rather
/// than wrapped, so that an out-of-range number lands on the nearest end rather
/// than on a colour that is nothing like it.
pub fn Ansi256::of(code : Int32) -> Ansi256 {
  let code = if code < 0 { 0 } else if code > 255 { 255 } else { code }
  { code, }
}

///|
pub impl Show for Ansi256 with fn output(self, logger) {
  logger.write_string(self.code.to_string())
}

///|
pub extend Ansi256 with Show::{to_string, output}

///|
/// The number to put in an escape sequence.
pub fn Ansi256::code(self : Ansi256) -> Int32 {
  self.code
}

///|
/// One of the six levels a cube axis has. Not a linear ramp: the first step is
/// the largest, because the eye needs more of a jump down near black to see the
/// same change.
fn cube_level(index : Int32) -> Int32 {
  if index <= 0 {
    0
  } else {
    55 + 40 * index
  }
}

///|
/// The colour a slot stands for.
pub fn Ansi256::color(self : Ansi256) -> Color {
  let code = self.code
  if code < 16 {
    // A slot in the first sixteen is a named colour; the cast cannot fail
    // because the table covers exactly those numbers.
    match Ansi16::of(code) {
      Some(named) => named.color()
      None => Color::black()
    }
  } else if code < 232 {
    let index = code - 16
    Color::rgb(
      cube_level(index / 36),
      cube_level(index / 6 % 6),
      cube_level(index % 6),
    )
  } else {
    let level = 8 + 10 * (code - 232)
    Color::rgb(level, level, level)
  }
}

///|
/// The whole palette in Oklab, computed once: the nearest-colour search looks at
/// every slot, and converting 256 colours per call would make a per-cell lookup
/// cost more than the drawing around it.
let palette_lab : Array[(Double, Double, Double)] = {
  let out : Array[(Double, Double, Double)] = []
  for code in 0..<256 {
    out.push(Ansi256::of(code).color().to_oklab().components())
  }
  out
}

///|
/// The sixteen named colours in Oklab, for the same reason.
let named_lab : Array[(Double, Double, Double)] = {
  let out : Array[(Double, Double, Double)] = []
  for code in 0..<16 {
    match Ansi16::of(code) {
      Some(named) => out.push(named.color().to_oklab().components())
      None => out.push((0.0, 0.0, 0.0))
    }
  }
  out
}

///|
/// The squared ΔE OK between a colour and a palette entry, squared so that the
/// search needs no square root per candidate.
fn squared_distance(
  first : (Double, Double, Double),
  second : (Double, Double, Double),
) -> Double {
  let dl = first.0 - second.0
  let da = first.1 - second.1
  let db = first.2 - second.2
  dl * dl + da * da + db * db
}

///|
/// The slot of the 256-colour palette closest to this colour by ΔE OK.
pub fn Color::to_ansi256(self : Color) -> Ansi256 {
  let lab = self.to_oklab().components()
  let mut best = 0
  let mut best_distance = @double.infinity
  for code in 0..<256 {
    let distance = squared_distance(lab, palette_lab[code])
    if distance < best_distance {
      best = code
      best_distance = distance
    }
  }
  Ansi256::of(best)
}

///|
/// The named slot closest to this colour by ΔE OK.
pub fn Color::to_ansi16(self : Color) -> Ansi16 {
  let lab = self.to_oklab().components()
  let mut best = 0
  let mut best_distance = @double.infinity
  for code in 0..<16 {
    let distance = squared_distance(lab, named_lab[code])
    if distance < best_distance {
      best = code
      best_distance = distance
    }
  }
  match Ansi16::of(best) {
    Some(named) => named
    None => Ansi16::Black
  }
}

///|
/// The colour as the three bytes a true-colour escape sequence carries,
/// 0–255 each, clipped the way a terminal clips.
pub fn Color::rgb8(self : Color) -> (Int32, Int32, Int32) {
  let srgb = self.to_srgb()
  let byte = fn(value : Double) {
    if value.is_nan() {
      0
    } else {
      byte_of(value)
    }
  }
  (byte(srgb.x), byte(srgb.y), byte(srgb.z))
}
