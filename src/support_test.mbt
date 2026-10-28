// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Helpers the tests share.
//
// All the test files of a package are one package themselves, so a helper
// written here is available in each of them.

///|
/// A component equal to what is expected, to the precision the tests state.
fn near(got : Double, want : Double, tolerance : Double) -> Bool {
  if want.is_nan() {
    got.is_nan()
  } else {
    (got - want).abs() <= tolerance * (1.0 + want.abs())
  }
}

///|
/// Three components of a colour, each near what is expected.
fn near_components(
  got : @moonrgba.Color,
  want : (Double, Double, Double),
  tolerance : Double,
) -> Bool {
  let (x, y, z) = got.components()
  near(x, want.0, tolerance) &&
  near(y, want.1, tolerance) &&
  near(z, want.2, tolerance)
}

///|
/// Whether two colours written in the same space match, with a hue compared as
/// an angle: 0° and 360° are the same direction, and a writer that rounds one to
/// the other is not wrong.
fn near_same_space(
  got : @moonrgba.Color,
  want : @moonrgba.Color,
  tolerance : Double,
) -> Bool {
  let index = match want.space {
    @moonrgba.Space::Hsl | @moonrgba.Space::Hsv | @moonrgba.Space::Hwb => 0
    @moonrgba.Space::Lch | @moonrgba.Space::Oklch => 2
    _ => -1
  }
  let pair = fn(a : Double, b : Double, at : Int32) {
    if at == index && !a.is_nan() && !b.is_nan() {
      let difference = ((a - b) % 360.0).abs()
      difference <= tolerance || 360.0 - difference <= tolerance
    } else {
      near(a, b, tolerance)
    }
  }
  let (x, y, z) = got.components()
  let (want_x, want_y, want_z) = want.components()
  pair(x, want_x, 0) && pair(y, want_y, 1) && pair(z, want_z, 2)
}

///|
/// The colour a string reads as, failing the test if it does not read.
fn read(text : StringView) -> @moonrgba.Color {
  match @moonrgba.Color::decode_opt(text) {
    Some(color) => color
    None => abort("did not read " + text.to_owned())
  }
}

///|
/// The refusal a string provokes, failing the test if it is read instead.
fn refusal_of(text : StringView) -> @moonrgba.Refused {
  try {
    ignore(@moonrgba.Color::decode(text))
    abort("read " + text.to_owned() + ", which should have been refused")
  } catch {
    error => error
  }
}
