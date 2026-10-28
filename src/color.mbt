// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The space a colour's three components are read in.
///
/// | `space` | `x` | `y` | `z` |
/// |:--|:--|:--|:--|
/// | `Srgb`, `SrgbLinear`, `DisplayP3`, `Rec2020`, `A98Rgb`, `ProPhoto` | red | green | blue |
/// | `Hsl` | hue, degrees | saturation | lightness |
/// | `Hsv` | hue, degrees | saturation | value |
/// | `Hwb` | hue, degrees | whiteness | blackness |
/// | `Lab` | lightness, 0–100 | a | b |
/// | `Lch` | lightness, 0–100 | chroma | hue, degrees |
/// | `Oklab` | lightness, 0–1 | a | b |
/// | `Oklch` | lightness, 0–1 | chroma | hue, degrees |
/// | `XyzD50`, `XyzD65` | X | Y | Z |
/// | `YCbCr` | luma | blue difference | red difference |
/// | `Current` | — | — | — |
///
/// Component ranges are the ones the format itself uses, not a common scale:
/// `Lab` lightness is 0–100 because that is what `lab()` writes, while `Oklab`
/// lightness is 0–1 because that is what `oklab()` writes. A colour out of its
/// space's range is still a valid value — CSS Color 4 lets a colour be outside
/// its gamut and leaves clipping to the moment it is painted.
pub(all) enum Space {
  /// Gamma-encoded sRGB, components 0–1. The one space every screen has.
  Srgb
  /// Linear-light sRGB, components 0–1: sRGB without the transfer curve.
  SrgbLinear
  /// Hue in degrees, saturation and lightness 0–1.
  Hsl
  /// Hue in degrees, saturation and value 0–1. No CSS syntax of its own.
  Hsv
  /// Hue in degrees, whiteness and blackness 0–1.
  Hwb
  /// CIE Lab, D50. Lightness 0–100, a and b roughly ±125.
  Lab
  /// CIE LCh, D50: Lab in polar form, hue in degrees.
  Lch
  /// Oklab. Lightness 0–1, a and b roughly ±0.4.
  Oklab
  /// OkLCh: Oklab in polar form, hue in degrees.
  Oklch
  /// CIE XYZ relative to D50, Y = 1 for white.
  XyzD50
  /// CIE XYZ relative to D65, Y = 1 for white. What `color(xyz ...)` writes.
  XyzD65
  /// Display P3, components 0–1, sRGB's transfer curve with wider primaries.
  DisplayP3
  /// Linear-light Display P3: P3 without the transfer curve.
  DisplayP3Linear
  /// Rec. 2020, components 0–1.
  Rec2020
  /// Adobe RGB (1998), components 0–1.
  A98Rgb
  /// ProPhoto RGB, components 0–1, D50 white.
  ProPhoto
  /// A luma/chroma pair as BT.601, BT.709 or BT.2020 define it. Luma 0–1,
  /// chroma −0.5–0.5. No CSS syntax.
  YCbCr(Luma)
  /// Not a space: the `currentcolor` keyword, which stands for whatever colour
  /// the element it is painted on already has. Carried in a `Color` so that a
  /// declaration can be read and written back unchanged; resolve it before
  /// converting, with `Color::resolve`.
  Current
} derive(Eq, Debug)

///|
pub extend Space with Eq::{equal, not_equal}

///|
pub extend Space with Debug::{to_repr}

///|
/// Which luma coefficients a `YCbCr` colour uses.
///
/// The three differ only in how much of each primary counts as brightness, and
/// a value converted with the wrong one is visibly off, so the choice is part of
/// the value rather than a global setting.
pub(all) enum Luma {
  /// BT.601: the coefficients of SD television.
  Bt601
  /// BT.709: the coefficients of HD television, and of sRGB in practice.
  Bt709
  /// BT.2020: the coefficients of UHD television, on wider primaries.
  Bt2020
} derive(Eq, Debug)

///|
pub extend Luma with Eq::{equal, not_equal}

///|
pub extend Luma with Debug::{to_repr}

///|
/// A colour: three components in a named space, and an alpha.
///
/// Alpha is kept apart from the components because it is not a colour: it says
/// how much of what is behind shows through, and it survives a change of space
/// untouched.
///
/// A component may be `none`, which CSS writes as the `none` keyword and which
/// this library carries as a NaN — "this space did not say", which interpolation
/// then fills in from the other side. Ordinary arithmetic on such a component
/// gives NaN back, which is the honest answer.
pub(all) struct Color {
  space : Space
  x : Double
  y : Double
  z : Double
  alpha : Double
} derive(Debug)

///|
pub extend Color with Debug::{to_repr}

///|
/// A colour in any space, from components already in that space's own units.
///
/// The named constructors below cover the common spaces; this one is for the
/// rest, and for code that picks a space at run time.
pub fn Color::of(
  space : Space,
  x : Double,
  y : Double,
  z : Double,
  alpha? : Double,
) -> Color {
  { space, x, y, z, alpha: alpha.unwrap_or(1.0), }
}

///|
/// sRGB from components in 0–1.
pub fn Color::srgb(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: Srgb, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// sRGB from bytes, 0–255, which is how a colour usually arrives from a file,
/// a theme or a terminal.
pub fn Color::rgb(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha? : Double,
) -> Color {
  {
    space: Srgb,
    x: red.to_double() / 255.0,
    y: green.to_double() / 255.0,
    z: blue.to_double() / 255.0,
    alpha: alpha.unwrap_or(1.0),
  }
}

///|
/// Linear-light sRGB from components in 0–1.
pub fn Color::srgb_linear(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: SrgbLinear, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// HSL: hue in degrees, saturation and lightness in 0–1.
pub fn Color::hsl(h : Double, s : Double, l : Double, alpha? : Double) -> Color {
  { space: Hsl, x: h, y: s, z: l, alpha: alpha.unwrap_or(1.0), }
}

///|
/// HSV: hue in degrees, saturation and value in 0–1.
pub fn Color::hsv(h : Double, s : Double, v : Double, alpha? : Double) -> Color {
  { space: Hsv, x: h, y: s, z: v, alpha: alpha.unwrap_or(1.0), }
}

///|
/// HWB: hue in degrees, whiteness and blackness in 0–1.
pub fn Color::hwb(h : Double, w : Double, b : Double, alpha? : Double) -> Color {
  { space: Hwb, x: h, y: w, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// CIE Lab with a D50 white: lightness 0–100.
pub fn Color::lab(l : Double, a : Double, b : Double, alpha? : Double) -> Color {
  { space: Lab, x: l, y: a, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// CIE LCh with a D50 white: lightness 0–100, hue in degrees.
pub fn Color::lch(l : Double, c : Double, h : Double, alpha? : Double) -> Color {
  { space: Lch, x: l, y: c, z: h, alpha: alpha.unwrap_or(1.0), }
}

///|
/// Oklab: lightness 0–1.
pub fn Color::oklab(
  l : Double,
  a : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: Oklab, x: l, y: a, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// OkLCh: lightness 0–1, hue in degrees.
pub fn Color::oklch(
  l : Double,
  c : Double,
  h : Double,
  alpha? : Double,
) -> Color {
  { space: Oklch, x: l, y: c, z: h, alpha: alpha.unwrap_or(1.0), }
}

///|
/// CIE XYZ relative to D65, Y = 1 for white.
pub fn Color::xyz_d65(
  x : Double,
  y : Double,
  z : Double,
  alpha? : Double,
) -> Color {
  { space: XyzD65, x, y, z, alpha: alpha.unwrap_or(1.0), }
}

///|
/// CIE XYZ relative to D50, Y = 1 for white.
pub fn Color::xyz_d50(
  x : Double,
  y : Double,
  z : Double,
  alpha? : Double,
) -> Color {
  { space: XyzD50, x, y, z, alpha: alpha.unwrap_or(1.0), }
}

///|
/// Display P3, components in 0–1.
pub fn Color::display_p3(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: DisplayP3, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// Rec. 2020, components in 0–1.
pub fn Color::rec2020(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: Rec2020, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// Adobe RGB (1998), components in 0–1.
pub fn Color::a98_rgb(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: A98Rgb, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// ProPhoto RGB, components in 0–1, D50 white.
pub fn Color::prophoto(
  r : Double,
  g : Double,
  b : Double,
  alpha? : Double,
) -> Color {
  { space: ProPhoto, x: r, y: g, z: b, alpha: alpha.unwrap_or(1.0), }
}

///|
/// YCbCr: luma in 0–1, chroma in −0.5–0.5.
pub fn Color::ycbcr(
  y : Double,
  cb : Double,
  cr : Double,
  luma? : Luma,
  alpha? : Double,
) -> Color {
  {
    space: YCbCr(luma.unwrap_or(Luma::Bt709)),
    x: y,
    y: cb,
    z: cr,
    alpha: alpha.unwrap_or(1.0),
  }
}

///|
/// The `currentcolor` keyword.
pub fn Color::current() -> Color {
  { space: Current, x: 0.0, y: 0.0, z: 0.0, alpha: 1.0, }
}

///|
/// `transparent`: black with no alpha at all. Not a space of its own, because
/// what shows through is decided by the backdrop, not by the colour.
pub fn Color::transparent() -> Color {
  { space: Srgb, x: 0.0, y: 0.0, z: 0.0, alpha: 0.0, }
}

///|
/// Black in sRGB.
pub fn Color::black() -> Color {
  { space: Srgb, x: 0.0, y: 0.0, z: 0.0, alpha: 1.0, }
}

///|
/// White in sRGB.
pub fn Color::white() -> Color {
  { space: Srgb, x: 1.0, y: 1.0, z: 1.0, alpha: 1.0, }
}

///|
/// The three components, in the order the space writes them.
pub fn Color::components(self : Color) -> (Double, Double, Double) {
  (self.x, self.y, self.z)
}

///|
/// The same colour with different components, in the same space.
pub fn Color::with_components(
  self : Color,
  x : Double,
  y : Double,
  z : Double,
) -> Color {
  { ..self, x, y, z, }
}

///|
/// The same colour at a different alpha.
pub fn Color::with_alpha(self : Color, alpha : Double) -> Color {
  { ..self, alpha, }
}

///|
/// Whether this is the unresolved `currentcolor` keyword.
pub fn Color::is_current(self : Color) -> Bool {
  self.space is Current
}

///|
/// Substitute the colour that `currentcolor` stands for. Anything else is
/// returned unchanged, so this is safe to call on every colour.
pub fn Color::resolve(self : Color, current : Color) -> Color {
  if self.space is Current {
    current
  } else {
    self
  }
}

///|
/// Whether the space writes a hue in its third component (`Hsl`, `Hsv`, `Hwb`)
/// or in its third of a polar pair (`Lch`, `Oklch`).
pub fn Space::is_polar(self : Space) -> Bool {
  match self {
    Hsl | Hsv | Hwb | Lch | Oklch => true
    _ => false
  }
}

///|
/// The hue in degrees, or NaN where the space has none.
pub fn Color::hue(self : Color) -> Double {
  match self.space {
    // The hue is the first component in the HSL family and the last in the
    // polar Lab family; there is no single place to look.
    Hsl | Hsv | Hwb => self.x
    Lch | Oklch => self.z
    _ => @double.not_a_number
  }
}

///|
/// The chroma, or NaN where the space has none.
pub fn Color::chroma(self : Color) -> Double {
  match self.space {
    Lch | Oklch => self.y
    _ => @double.not_a_number
  }
}

///|
/// The lightness, or NaN where the space has none.
pub fn Color::lightness(self : Color) -> Double {
  match self.space {
    Lab | Lch => self.x
    Oklab | Oklch => self.x
    Hsl | Hwb => self.z
    Hsv => self.z
    _ => @double.not_a_number
  }
}

///|
/// The saturation, or NaN where the space has none.
pub fn Color::saturation(self : Color) -> Double {
  match self.space {
    Hsl | Hsv => self.y
    _ => @double.not_a_number
  }
}

///|
/// A space writes itself with the identifier CSS uses for it, or the one this
/// library uses where CSS has no name for it.
pub impl Show for Space with fn output(self, logger) {
  logger.write_string(self.code())
}

///|
pub extend Space with Show::{to_string, output}

///|
/// The identifier this space is written with in CSS, or the one this library
/// uses where CSS has no syntax for it.
pub fn Space::code(self : Space) -> String {
  match self {
    Srgb => "srgb"
    SrgbLinear => "srgb-linear"
    Hsl => "hsl"
    Hsv => "hsv"
    Hwb => "hwb"
    Lab => "lab"
    Lch => "lch"
    Oklab => "oklab"
    Oklch => "oklch"
    XyzD50 => "xyz-d50"
    XyzD65 => "xyz-d65"
    DisplayP3 => "display-p3"
    DisplayP3Linear => "display-p3-linear"
    Rec2020 => "rec2020"
    A98Rgb => "a98-rgb"
    ProPhoto => "prophoto-rgb"
    YCbCr(luma) =>
      match luma {
        Bt601 => "ycbcr-601"
        Bt709 => "ycbcr-709"
        Bt2020 => "ycbcr-2020"
      }
    Current => "currentcolor"
  }
}

///|
/// The space an identifier names, if any.
pub fn Space::of(code : StringView) -> Space? {
  match code.to_lower() {
    "srgb" => Some(Srgb)
    "srgb-linear" => Some(SrgbLinear)
    "hsl" => Some(Hsl)
    "hsv" => Some(Hsv)
    "hwb" => Some(Hwb)
    "lab" => Some(Lab)
    "lch" => Some(Lch)
    "oklab" => Some(Oklab)
    "oklch" => Some(Oklch)
    "xyz" | "xyz-d65" => Some(XyzD65)
    "xyz-d50" => Some(XyzD50)
    "display-p3" => Some(DisplayP3)
    "display-p3-linear" => Some(DisplayP3Linear)
    "rec2020" => Some(Rec2020)
    "a98-rgb" => Some(A98Rgb)
    "prophoto-rgb" => Some(ProPhoto)
    "ycbcr-601" => Some(YCbCr(Bt601))
    "ycbcr-709" => Some(YCbCr(Bt709))
    "ycbcr-2020" => Some(YCbCr(Bt2020))
    "currentcolor" => Some(Current)
    _ => None
  }
}

///|
/// Whether this space can be written inside CSS's `color()`.
pub fn Space::is_predefined(self : Space) -> Bool {
  match self {
    Srgb
    | SrgbLinear
    | DisplayP3
    | DisplayP3Linear
    | Rec2020
    | A98Rgb
    | ProPhoto
    | XyzD50
    | XyzD65 => true
    _ => false
  }
}
