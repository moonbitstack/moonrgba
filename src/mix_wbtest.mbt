// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// `color-mix()` against colorjs.
//
// The fixture pairs two random colours in each interpolation space, at a random
// weight, with both alphas random and every one of the four hue directions. What
// this catches that a hand-written case cannot: a premultiplication applied to
// a hue, an unwrapped hue between 350° and 10°, and a weight taken at the wrong
// end.

///|
fn mix_case(row : String) -> (Space, Hue, Color, Color, Double, Color)? {
  let fields = row_fields(row)
  if fields.length() < 16 || !fields[0].equal("mix") {
    return None
  }
  let space = Space::of(fields[1]).unwrap()
  let hue = match fields[2].to_owned() {
    "shorter" => Hue::Shorter
    "longer" => Hue::Longer
    "increasing" => Hue::Increasing
    "decreasing" => Hue::Decreasing
    _ => Hue::Shorter
  }
  let first = {
    let space = space
    {
      space,
      x: row_number(fields[3]),
      y: row_number(fields[4]),
      z: row_number(fields[5]),
      alpha: row_number(fields[6]),
    }
  }
  let second = {
    let space = space
    {
      space,
      x: row_number(fields[7]),
      y: row_number(fields[8]),
      z: row_number(fields[9]),
      alpha: row_number(fields[10]),
    }
  }
  let weight = row_number(fields[11])
  let want = {
    let space = space
    {
      space,
      x: row_number(fields[12]),
      y: row_number(fields[13]),
      z: row_number(fields[14]),
      alpha: row_number(fields[15]),
    }
  }
  Some((space, hue, first, second, weight, want))
}

///|
/// Whether two hues are the same angle, which 0 and 360 are: one of the two is
/// written unwrapped, and which one depends on the implementation.
fn same_hue(got : Double, want : Double) -> Bool {
  let difference = (got - want) % 360.0
  difference.abs() < 1.0e-9 || (difference.abs() - 360.0).abs() < 1.0e-9
}

///|
test "mixing agrees with colorjs in every interpolation space" {
  let mut checked = 0
  let mut problem = ""
  for row in numbers {
    match mix_case(row) {
      Some((space, hue, first, second, weight, want)) => {
        let got = first.mix(second, space~, hue~, weight~)
        let (x, y, z) = got.components()
        let (want_x, want_y, want_z) = want.components()
        let hue_index = match space {
          Hsl | Hsv | Hwb => 0
          Lch | Oklch => 2
          _ => -1
        }
        let close = fn(got : Double, want : Double, index : Int32) {
          if index == hue_index {
            same_hue(got, want)
          } else {
            (got - want).abs() < 1.0e-9 * (1.0 + want.abs())
          }
        }
        if !close(x, want_x, 0) || !close(y, want_y, 1) || !close(z, want_z, 2) {
          problem = "\{space.code()} \{hue}: \{got} where colorjs has \{want} at weight \{weight}"
          break
        }
        if (got.alpha - want.alpha).abs() > 1.0e-9 {
          problem = "\{space.code()}: alpha \{got.alpha} where colorjs has \{want.alpha}"
          break
        }
        checked = checked + 1
      }
      None => ()
    }
  }
  assert_true(problem.is_empty(), msg=problem)
  assert_true(checked > 100, msg="only \{checked} mixes were checked")
}

///|
/// Halfway between two opaque colours is the same distance from each, and a
/// weight of one end gives that end back exactly.
test "the ends of a mix are the colours themselves" {
  let red = Color::srgb(1.0, 0.0, 0.0)
  let blue = Color::srgb(0.0, 0.0, 1.0)
  let at_first = red.mix(blue, space=Srgb, weight=1.0)
  let at_second = red.mix(blue, space=Srgb, weight=0.0)
  assert_true((at_first.x - 1.0).abs() < 1.0e-12 && at_first.z.abs() < 1.0e-12)
  assert_true(
    (at_second.z - 1.0).abs() < 1.0e-12 && at_second.x.abs() < 1.0e-12,
  )
  let middle = red.mix(blue, space=Srgb)
  assert_true((middle.x - 0.5).abs() < 1.0e-12)
  assert_true((middle.z - 0.5).abs() < 1.0e-12)
}

///|
/// HSL and OkLCh travel the same way round the hue circle, which is the point of
/// the four directions: the shorter way between 350° and 10° goes through 0, and
/// the longer way through 180.
test "the hue direction decides which side of the circle a mix crosses" {
  let first = Color::hsl(350.0, 1.0, 0.5)
  let second = Color::hsl(10.0, 1.0, 0.5)
  let shorter = first.mix(second, space=Hsl, hue=Shorter).hue()
  let longer = first.mix(second, space=Hsl, hue=Longer).hue()
  assert_true(same_hue(shorter, 0.0), msg="shorter went to \{shorter}")
  assert_true(same_hue(longer, 180.0), msg="longer went to \{longer}")
  // Increasing always comes out between the two in the increasing direction, so
  // from 350° towards 10° it passes 0 rather than 180.
  let increasing = first.mix(second, space=Hsl, hue=Increasing).hue()
  assert_true(same_hue(increasing, 0.0), msg="increasing went to \{increasing}")
  let decreasing = first.mix(second, space=Hsl, hue=Decreasing).hue()
  assert_true(
    same_hue(decreasing, 180.0),
    msg="decreasing went to \{decreasing}",
  )
}

///|
/// A missing component takes the other colour's value rather than counting as
/// zero: mixing a colour with no lightness against one with lightness 0.8 gives
/// 0.8 back at a weight that would otherwise halve it towards nothing.
test "a missing component is filled in from the other colour" {
  let missing = Color::oklch(@double.not_a_number, 0.1, 20.0)
  let complete = Color::oklch(0.8, 0.1, 20.0)
  let mixed = missing.mix(complete, space=Oklch, weight=0.5)
  assert_true(
    (mixed.x - 0.8).abs() < 1.0e-12,
    msg="lightness came out \{mixed.x}",
  )
  // Missing on both sides stays missing.
  let both = Color::oklch(@double.not_a_number, 0.1, 20.0).mix(
    Color::oklch(@double.not_a_number, 0.1, 20.0),
    space=Oklch,
  )
  assert_true(both.x.is_nan())
}

///|
/// `currentcolor` has no value to mix, so mixing it produces one: a colour that
/// claimed to be a mix of a resolved colour and an unresolved one would be a
/// lie about what it knows.
test "mixing an unresolved currentcolor stays unresolved" {
  let mixed = Color::current().mix(Color::srgb(1.0, 0.0, 0.0))
  assert_true(mixed.is_current())
}
