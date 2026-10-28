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
