// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The conversion table checked against two references at once.
//
// The fixture in `vectors_wbtest.mbt` holds rows computed by the sample code
// CSS Color 4 ships and by colorjs.io, for the same six random samples of every
// space pair. Neither reference shares a line with this library, so a row that
// disagrees is this library's mistake — or, where the two references disagree
// with each other, an ambiguity worth writing down.
//
// Tolerances are stated where they are used and are tight enough that a wrong
// matrix, a wrong white point or a swapped coefficient cannot hide inside them:
// the observed worst case is a few units in the last place of a double.

///|
/// One tab-separated row of the fixture, split into its fields.
fn row_fields(row : String) -> Array[StringView] {
  let out : Array[StringView] = []
  for field in row.split("\t") {
    out.push(field)
  }
  out
}

///|
/// A decimal number as the fixture writes it, `nan` included.
///
/// Written out rather than taken from the core library because the fixture is
/// generated text and a parser that refuses `nan` would turn a legitimate
/// "this grey has no hue" into a test failure.
fn row_number(field : StringView) -> Double {
  if field.equal("nan") {
    return @double.not_a_number
  }
  let mut index = 0
  let length = field.length()
  let mut sign = 1.0
  if length > 0 && (field.at(0) == 'u' || field.at(0) == 'U') {
    index = 1
    if length > 1 && (field.at(1) == 'l' || field.at(1) == 'L') {
      index = 2
    }
  }
  if index < length && (field.at(index) == '-' || field.at(index) == '+') {
    if field.at(index) == '-' {
      sign = -1.0
    }
    index = index + 1
  }
  let mut value = 0.0
  let mut exponent = 0
  let mut after_point = false
  let mut scale = 1.0
  while index < length {
    let code = field.at(index).to_int()
    if code >= 48 && code <= 57 {
      let digit = (code - 48).to_double()
      if after_point {
        scale = scale / 10.0
        value = value + digit * scale
      } else {
        value = value * 10.0 + digit
      }
    } else if code == 46 && !after_point {
      after_point = true
    } else if code == 101 || code == 69 {
      index = index + 1
      let mut negative = false
      if index < length && (field.at(index) == '-' || field.at(index) == '+') {
        negative = field.at(index) == '-'
        index = index + 1
      }
      while index < length {
        let code = field.at(index).to_int()
        if code >= 48 && code <= 57 {
          exponent = exponent * 10 + (code - 48)
        }
        index = index + 1
      }
      if negative {
        exponent = -exponent
      }
      break
    }
    index = index + 1
  }
  let value = sign * value
  if exponent == 0 {
    value
  } else {
    value * @math.pow(10.0, exponent.to_double())
  }
}

///|
/// Whether a value is within `absolute` plus `relative` times the expected
/// magnitude of the reference. The relative part is there because a chroma of
/// 0.0001 carries the same relative error as a lightness of 100.
fn close_enough(
  got : Double,
  want : Double,
  absolute : Double,
  relative : Double,
) -> Bool {
  if want.is_nan() {
    return got.is_nan()
  }
  if got.is_nan() {
    return false
  }
  (got - want).abs() <= absolute + relative * want.abs()
}

///|
/// The worst disagreement, kept as a ratio against the tolerance so that the
/// test can report how much room is left rather than just pass or fail.
fn worst_of(
  rows : Array[String],
  absolute : Double,
  relative : Double,
) -> (Double, String) {
  let mut worst = 0.0
  let mut failure = ""
  for row in rows {
    let fields = row_fields(row)
    let source = Space::of(fields[1]).unwrap()
    let target = Space::of(fields[2]).unwrap()
    let color = {
      let space = source
      {
        space,
        x: row_number(fields[3]),
        y: row_number(fields[4]),
        z: row_number(fields[5]),
        alpha: 1.0,
      }
    }
    let got = color.to_space(target).components()
    let want = (
      row_number(fields[6]),
      row_number(fields[7]),
      row_number(fields[8]),
    )
    for index in 0..<3 {
      let pair = match index {
        0 => (got.0, want.0)
        1 => (got.1, want.1)
        _ => (got.2, want.2)
      }
      let (got, want) = pair
      let slack = absolute + relative * want.abs()
      let ratio = if want.is_nan() {
        if got.is_nan() {
          0.0
        } else {
          1.0e9
        }
      } else if got.is_nan() {
        1.0e9
      } else {
        (got - want).abs() / slack
      }
      if ratio > worst {
        worst = ratio
        failure = row
      }
    }
  }
  (worst, failure)
}

///|
/// Rows from one reference only, as the fixture marks them.
fn rows_from(reference : String) -> Array[String] {
  let out : Array[String] = []
  for row in vectors {
    if row.has_prefix(reference) {
      out.push(row)
    }
  }
  out
}

///|
/// Six random samples of every space pair, against the sample code CSS Color 4
/// prints. The code and this library use the same matrices and the same order of
/// operations, so anything above a rounding error is a mistake in one of them.
///
/// `relative` is 1e-13 because a double carries about 2.2e-16 and a conversion
/// is a handful of multiplications and a cube root; `absolute` covers the
/// components that sit near zero, where the relative term says almost nothing.
test "the sample code CSS Color 4 prints agrees to a rounding error" {
  let rows = rows_from("spec")
  assert_true(rows.length() > 400)
  let (worst, failure) = worst_of(rows, 1.0e-12, 1.0e-13)
  if worst > 1.0 {
    fail("worst disagreement is \{worst} times the tolerance: \{failure}")
  }
}

///|
/// The same samples against colorjs.io, which was written separately.
///
/// Its matrices carry more digits than the specification's in some places and
/// it rounds differently, so the tolerance is looser than above — but not loose
/// enough to hide a coefficient taken from the wrong primary, which shows up at
/// the first decimal.
test "an independent implementation agrees to nine places" {
  let rows = rows_from("colorjs")
  assert_true(rows.length() > 400)
  let (worst, failure) = worst_of(rows, 1.0e-9, 1.0e-9)
  if worst > 1.0 {
    fail("worst disagreement is \{worst} times the tolerance: \{failure}")
  }
}

///|
/// A conversion that ends where it started has to come back: the round trip is
/// the check that no pair of matrices was built from the other by eye.
test "every space survives a round trip through sRGB and back" {
  let spaces : Array[Space] = [
    Srgb,
    SrgbLinear,
    Hsl,
    Hsv,
    Hwb,
    Lab,
    Lch,
    Oklab,
    Oklch,
    XyzD50,
    XyzD65,
    DisplayP3,
    Rec2020,
    A98Rgb,
    ProPhoto,
    YCbCr(Bt601),
    YCbCr(Bt709),
    YCbCr(Bt2020),
  ]
  for row in vectors {
    if !row.has_prefix("colorjs") {
      continue
    }
    let fields = row_fields(row)
    let space = Space::of(fields[1]).unwrap()
    if !spaces.contains(space) {
      continue
    }
    let color = {
      let space = space
      {
        space,
        x: row_number(fields[3]),
        y: row_number(fields[4]),
        z: row_number(fields[5]),
        alpha: 1.0,
      }
    }
    let back = color.to_space(Srgb).to_space(space)
    let (x, y, z) = back.components()
    let tolerance = if space is Hwb { 1.0e-9 } else { 1.0e-9 }
    assert_true(
      close_enough(x, color.x, tolerance, tolerance),
      msg="round trip in \{space.code()}: x \{x} against \{color.x}",
    )
    assert_true(
      close_enough(y, color.y, tolerance, tolerance),
      msg="round trip in \{space.code()}: y \{y} against \{color.y}",
    )
    assert_true(
      close_enough(z, color.z, tolerance, tolerance),
      msg="round trip in \{space.code()}: z \{z} against \{color.z}",
    )
  }
}

///|
/// The sRGB transfer curve is a straight line below its break and a power above
/// it, and the two meet at 0.04045: a value inside the linear segment has to
/// stay on the straight line, or a dark colour comes out twenty parts per
/// million off its own definition.
test "the sRGB transfer curve keeps a linear segment at the dark end" {
  // 0.00312 is inside the segment on the linear-light side, whose break is
  // 0.0031308; 0.0403 is inside it on the gamma side, whose break is 0.04045.
  let gamma = Color::srgb_linear(0.00312, 0.00312, 0.00312).to_srgb()
  assert_true(
    close_enough(gamma.x, 0.00312 * 12.92, 1.0e-15, 1.0e-15),
    msg="linear to gamma below the break: \{gamma.x}",
  )
  let linear = Color::srgb(0.0403, 0.0403, 0.0403).to_srgb_linear()
  assert_true(
    close_enough(linear.x, 0.0403 / 12.92, 1.0e-15, 1.0e-15),
    msg="gamma to linear below the break: \{linear.x}",
  )
  // Above it the curve is the power every other implementation uses, so that a
  // mid grey is the value a screen expects.
  let above = Color::srgb(0.5, 0.5, 0.5).to_srgb_linear()
  assert_true(
    close_enough(above.x, 0.21404114048223255, 1.0e-12, 1.0e-12),
    msg="mid grey in linear light: \{above.x}",
  )
  // The two segments meet: the value at the break is the same from either side.
  let at_break = Color::srgb_linear(0.0031308, 0.0031308, 0.0031308).to_srgb()
  assert_true(
    close_enough(at_break.x, 0.040449936, 1.0e-9, 1.0e-9),
    msg="the value at the break: \{at_break.x}",
  )
}

///|
/// A hue is an angle, so a constructor may be handed one below zero or beyond a
/// turn; it means what the same angle a turn round means. Reading a value from
/// CSS wraps the angle already, which is why this is easy to leave untested.
test "a hue outside one turn is the angle a turn round from it" {
  let below = Color::hsl(-30.0, 1.0, 0.5).to_srgb()
  let above = Color::hsl(330.0, 1.0, 0.5).to_srgb()
  assert_true(
    close_enough(below.x, above.x, 1.0e-14, 1.0e-14) &&
    close_enough(below.y, above.y, 1.0e-14, 1.0e-14) &&
    close_enough(below.z, above.z, 1.0e-14, 1.0e-14),
    msg="hsl: \{below} against \{above}",
  )
  let beyond = Color::hsv(390.0, 1.0, 1.0).to_srgb()
  let same = Color::hsv(30.0, 1.0, 1.0).to_srgb()
  assert_true(
    close_enough(beyond.x, same.x, 1.0e-14, 1.0e-14) &&
    close_enough(beyond.y, same.y, 1.0e-14, 1.0e-14),
    msg="hsv: \{beyond} against \{same}",
  )
  let negative = Color::lch(50.0, 60.0, -90.0).to_srgb()
  let wrapped = Color::lch(50.0, 60.0, 270.0).to_srgb()
  assert_true(
    close_enough(negative.x, wrapped.x, 1.0e-12, 1.0e-12) &&
    close_enough(negative.y, wrapped.y, 1.0e-12, 1.0e-12) &&
    close_enough(negative.z, wrapped.z, 1.0e-12, 1.0e-12),
    msg="lch: \{negative} against \{wrapped}",
  )
}
