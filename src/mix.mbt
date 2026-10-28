// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Mixing two colours, and nudging one.
//
// `color-mix()` is not a weighted average of RGB triples. CSS Color 5 says where
// the average is taken — the interpolation space decides, and Oklab, the
// default, is the one that keeps a red-to-blue mix from going through mud. It
// says how alpha takes part: premultiplied, so that a colour at 10% opacity
// pulls a tenth as hard as an opaque one rather than dragging the hue of the
// result with it. And in a polar space it says which way round the hue circle to
// travel, because halfway between 350° and 10° is not 180°.
//
// The adjustments at the bottom are the same arithmetic with one end fixed:
// lighten is a mix towards white in the space's own lightness, and saturate is a
// mix towards more chroma.

///|
/// Which way round the hue circle an interpolation travels.
pub(all) enum Hue {
  /// The way that is at most half a turn: 350° to 10° goes through 0°.
  Shorter
  /// The way that is at least half a turn.
  Longer
  /// Always increasing, so 350° to 10° goes through 360°.
  Increasing
  /// Always decreasing.
  Decreasing
} derive(Eq, Debug)

///|
pub extend Hue with Eq::{equal, not_equal}

///|
pub extend Hue with Debug::{to_repr}

///|
/// A direction writes itself the way `color-mix()` spells it.
pub impl Show for Hue with fn output(self, logger) {
  logger.write_string(
    match self {
      Shorter => "shorter"
      Longer => "longer"
      Increasing => "increasing"
      Decreasing => "decreasing"
    },
  )
}

///|
pub extend Hue with Show::{to_string, output}

///|
/// Where a space keeps its hue, if it has one.
fn Space::hue_index(self : Space) -> Int32? {
  match self {
    Hsl | Hsv | Hwb => Some(0)
    Lch | Oklch => Some(2)
    _ => None
  }
}

///|
/// The top of a space's lightness scale, which is what an adjustment of `0.1`
/// means a tenth of.
fn Space::lightness_range(self : Space) -> Double {
  match self {
    Lab | Lch => 100.0
    _ => 1.0
  }
}

///|
/// The chroma a space calls full, which is what an adjustment of `0.1` means a
/// tenth of. `lch()` writes 150 and `oklch()` 0.4 as the chroma of a colour at
/// the edge of what people can see.
fn Space::chroma_range(self : Space) -> Double {
  match self {
    Lch => 150.0
    Oklch => 0.4
    _ => 1.0
  }
}

///|
/// One component of a triple, by index.
fn component_of(triple : (Double, Double, Double), index : Int32) -> Double {
  match index {
    0 => triple.0
    1 => triple.1
    _ => triple.2
  }
}

///|
/// The hue halfway between two, in the direction asked for.
fn interpolate_hue(
  first : Double,
  second : Double,
  weight : Double,
  hue : Hue,
) -> Double {
  if first.is_nan() || second.is_nan() {
    return @double.not_a_number
  }
  let first = hue_of(first)
  let second = hue_of(second)
  let forward = match hue {
    Shorter =>
      if second - first > 180.0 {
        second - 360.0
      } else if second - first < -180.0 {
        second + 360.0
      } else {
        second
      }
    Longer =>
      if second - first > 0.0 && second - first < 180.0 {
        second - 360.0
      } else if second - first > -180.0 && second - first <= 0.0 {
        second + 360.0
      } else {
        second
      }
    Increasing => if second < first { second + 360.0 } else { second }
    Decreasing => if second > first { second - 360.0 } else { second }
  }
  let mixed = first * weight + forward * (1.0 - weight)
  let wrapped = mixed % 360.0
  if wrapped < 0.0 {
    wrapped + 360.0
  } else {
    wrapped
  }
}

///|
/// One component of the mix: premultiplied where the space allows it, so that a
/// nearly transparent colour does not drag the result towards its own hue.
fn mix_component(
  first : Double,
  second : Double,
  weight : Double,
  first_alpha : Double,
  second_alpha : Double,
  premultiply : Bool,
) -> Double {
  if premultiply {
    first * first_alpha * weight + second * second_alpha * (1.0 - weight)
  } else {
    first * weight + second * (1.0 - weight)
  }
}

///|
/// A mix of two colours, as `color-mix()` defines one.
///
/// `weight` is how much of this colour the result has: 0.3 means three parts of
/// this and seven of `other`, which is what `color-mix(in oklab, this 30%,
/// other)` writes. It defaults to half.
///
/// The result is in the interpolation space, not in the space either colour
/// came from: mixing in Oklab and then converting back to sRGB would lose the
/// out-of-gamut values the mix produced, and `to_gamut` is the caller's decision
/// to make.
///
/// A missing component — `none` — takes the other colour's value before the
/// mix, so that `oklch(none 0.1 200)` mixed with a colour that has a lightness
/// interpolates that lightness rather than treating the gap as zero.
///
/// `currentcolor` is not mixed: it stands for a colour nobody has resolved yet,
/// and the result would be a colour that pretends to know.
pub fn Color::mix(
  self : Color,
  other : Color,
  space? : Space,
  hue? : Hue,
  weight? : Double,
) -> Color {
  let target = space.unwrap_or(Oklab)
  let direction = hue.unwrap_or(Shorter)
  let weight = clamp01(weight.unwrap_or(0.5))
  if self.is_current() || other.is_current() {
    return Color::current()
  }
  let first = self.to_space(target)
  let second = other.to_space(target)
  // A component missing on one side takes the other side's value; missing on
  // both, it stays missing.
  let fill = fn(a : Double, b : Double) { if a.is_nan() { b } else { a } }
  let (first_x, first_y, first_z) = (
    fill(first.x, second.x),
    fill(first.y, second.y),
    fill(first.z, second.z),
  )
  let (second_x, second_y, second_z) = (
    fill(second.x, first.x),
    fill(second.y, first.y),
    fill(second.z, first.z),
  )
  let first_alpha = fill(first.alpha, second.alpha)
  let second_alpha = fill(second.alpha, first.alpha)
  let alpha = first_alpha * weight + second_alpha * (1.0 - weight)
  // Premultiplication skips the hue, which is an angle rather than a quantity:
  // scaling it by opacity would move the colour around the circle.
  let hue_index = target.hue_index()
  let premultiplied = fn(index : Int32) {
    match hue_index {
      Some(hue_index) => hue_index != index
      None => true
    }
  }
  let blend = fn(first : Double, second : Double, index : Int32) {
    mix_component(
      first,
      second,
      weight,
      first_alpha,
      second_alpha,
      premultiplied(index),
    )
  }
  let mut x = blend(first_x, second_x, 0)
  let mut y = blend(first_y, second_y, 1)
  let mut z = blend(first_z, second_z, 2)
  match hue_index {
    Some(index) => {
      // The hue sits in a different component in each family, so it is taken by
      // index rather than assumed to be the last one.
      let mixed_hue = interpolate_hue(
        component_of((first_x, first_y, first_z), index),
        component_of((second_x, second_y, second_z), index),
        weight,
        direction,
      )
      if index == 0 {
        x = mixed_hue
      } else {
        z = mixed_hue
      }
    }
    None => ()
  }
  // Undo the premultiplication. A result with no alpha left has no colour to
  // recover, and dividing by zero would turn it into infinities.
  if alpha != 0.0 && !alpha.is_nan() {
    if premultiplied(0) {
      x = x / alpha
    }
    if premultiplied(1) {
      y = y / alpha
    }
    if premultiplied(2) {
      z = z / alpha
    }
  }
  Color::of(target, x, y, z, alpha~)
}

///|
/// Where a space keeps its lightness: first in the Lab family, last in the HSL
/// family, which is why the index has to be asked for rather than assumed.
fn Space::lightness_index(self : Space) -> Int32? {
  match self {
    Lab | Lch | Oklab | Oklch => Some(0)
    Hsl | Hsv | Hwb => Some(2)
    _ => None
  }
}

///|
/// The space this colour's lightness belongs to, which is its own if it has one
/// and OkLCh otherwise.
fn Color::lightness_space(self : Color) -> Space {
  match self.space {
    Hsl | Hsv | Hwb | Lab | Lch | Oklab | Oklch => self.space
    _ => Oklch
  }
}

///|
/// The space this colour's saturation belongs to: HSL and HSV saturate, and the
/// polar Lab spaces have chroma, which is the same idea under another name.
fn Color::saturation_space(self : Color) -> Space {
  match self.space {
    Hsl | Hsv | Lch | Oklch => self.space
    _ => Oklch
  }
}

///|
fn component_at(color : Color, index : Int32) -> Double {
  match index {
    0 => color.x
    1 => color.y
    _ => color.z
  }
}

///|
fn component_set(color : Color, index : Int32, value : Double) -> Color {
  match index {
    0 => color.with_components(value, color.y, color.z)
    1 => color.with_components(color.x, value, color.z)
    _ => color.with_components(color.x, color.y, value)
  }
}

///|
/// Move the colour towards white by `amount`, a fraction of its space's
/// lightness scale: 0.1 in HSL is a tenth of the way to white, 10 in Lab is ten
/// units of lightness.
///
/// Hue and chroma are kept, so this is not the same as mixing with white: a mix
/// with white washes the chroma out as well.
pub fn Color::lighten(self : Color, amount : Double) -> Color {
  let space = self.lightness_space()
  let color = self.to_space(space)
  let range = space.lightness_range()
  let index = match space.lightness_index() {
    Some(index) => index
    None => 0
  }
  let lightness = clamp01(
    (or_zero(component_at(color, index)) + amount * range) / range,
  )
  component_set(color, index, lightness * range)
}

///|
/// Move the colour towards black by `amount`, a fraction of its space's
/// lightness scale.
pub fn Color::darken(self : Color, amount : Double) -> Color {
  self.lighten(-amount)
}

///|
/// Add chroma, by `amount` of the space's chroma scale: 0.1 is a tenth of the
/// chroma a colour can have before it leaves what people can see.
///
/// A colour already at the edge of its gamut gains nothing visible from this;
/// `to_gamut` afterwards is what says so.
pub fn Color::saturate(self : Color, amount : Double) -> Color {
  let space = self.saturation_space()
  let color = self.to_space(space)
  let range = space.chroma_range()
  let chroma = or_zero(color.y) + amount * range
  let chroma = if chroma < 0.0 { 0.0 } else { chroma }
  // HSL and HSV saturate to a point and stop; chroma does not have an end.
  let chroma = match space {
    Hsl | Hsv => clamp01(chroma)
    _ => chroma
  }
  component_set(color, 1, chroma)
}

///|
/// Take chroma away, by `amount` of the space's chroma scale. At 1 the colour is
/// grey.
pub fn Color::desaturate(self : Color, amount : Double) -> Color {
  self.saturate(-amount)
}

///|
/// The same colour with less alpha, by `amount` of what it has: 0.25 leaves
/// three quarters.
pub fn Color::fade(self : Color, amount : Double) -> Color {
  let alpha = if self.alpha.is_nan() { 1.0 } else { self.alpha }
  self.with_alpha(clamp01(alpha * (1.0 - amount)))
}
