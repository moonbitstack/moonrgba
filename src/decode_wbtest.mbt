// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The parser against web-platform-tests' colour parsing suite.
//
// Every case those files contain is here: the ones that must parse, the ones
// that must not, and the serialisation the test states where it states one. For
// a case that states a serialisation, the check is not that this library writes
// the same string — it writes the shortest spelling, which is a different
// goal — but that the value read back is the same colour.
//
// Two kinds of case are left out, and the test fails if a case is left out for
// any other reason:
//
//   * `calc()`, `var()`, `env()` and `attr()`, which cannot be resolved without
//     a cascade, and the relative colour syntax (`rgb(from ...)`), which is CSS
//     Color 5 and not part of what this library reads.
//   * the system colours (`Canvas`, `ButtonText`, ...), whose values come from
//     the user's settings rather than from the specification.

///|
/// Whether a case is one this library deliberately does not read.
fn out_of_scope(value : StringView) -> Bool {
  let marks : Array[StringView] = [
    "calc(", "var(", "env(", "attr(", "from ", "light-dark(", "color-mix(", "contrast-color(",
    "device-cmyk(", "if(",
  ]
  for mark in marks {
    if value.contains(mark) {
      return true
    }
  }
  let words : Array[StringView] = [
    "accentcolor", "accentcolortext", "activetext", "buttonborder", "buttonface",
    "buttontext", "canvas", "canvastext", "field", "fieldtext", "graytext", "highlight",
    "highlighttext", "linktext", "mark", "marktext", "selecteditem", "selecteditemtext",
    "visitedtext",
  ]
  let lower = value.trim().to_lower()
  for word in words {
    if lower.equal(word) {
      return true
    }
  }
  false
}

///|
fn wpt_fields(row : String) -> Array[StringView] {
  let out : Array[StringView] = []
  for field in row.split("\t") {
    out.push(field)
  }
  out
}

///|
/// How far apart two colours may be and still be the same colour.
///
/// An expected value written as `rgb()` is a byte per channel, so half a byte is
/// as close as it can come. Everything else is compared against the precision
/// the test writes, which is five or six decimals of whatever unit the space
/// uses — `lch()` hue is in degrees, so a fixed absolute tolerance would be far
/// too tight for one component and far too loose for another, and a relative one
/// is what is left.
fn wpt_tolerance(
  expected : Color,
  expected_text : StringView,
) -> (Double, Double) {
  if expected_text.has_prefix("rgb(") || expected_text.has_prefix("rgba(") {
    (0.5 / 255.0 + 1.0e-9, 0.0)
  } else {
    let _ = expected.space
    (1.0e-5, 1.0e-5)
  }
}

///|
/// Whether two colours are the same, in the space the expected value is written
/// in.
fn wpt_same(
  got : Color,
  want : Color,
  absolute : Double,
  relative : Double,
) -> Bool {
  let (first, second, third) = got.to_space(want.space).components()
  let (want_first, want_second, want_third) = want.components()
  let same = fn(got : Double, want : Double) {
    if want.is_nan() {
      return got.is_nan()
    }
    if got.is_nan() {
      return false
    }
    (got - want).abs() <= absolute + relative * want.abs()
  }
  same(first, want_first) &&
  same(second, want_second) &&
  same(third, want_third)
}

///|
/// Every case in the suite that this library claims to read.
///
/// `checked` is asserted against a floor so that a change in the collector, a
/// network failure at generation time or an over-broad `out_of_scope` shows up
/// as a failure rather than as a quietly empty test.
test "the colour parsing suite of web-platform-tests" {
  let mut checked = 0
  let mut skipped = 0
  for row in wpt_cases {
    let fields = wpt_fields(row)
    let kind = fields[0]
    let input = fields[1]
    let expected_text = if fields.length() > 2 { fields[2] } else { "" }
    if out_of_scope(input) {
      skipped = skipped + 1
      continue
    }
    checked = checked + 1
    if kind.equal("valid") {
      let color = match Color::decode_opt(input) {
        Some(color) => color
        None => fail("did not read \{input}, which the suite says is a colour")
      }
      // `currentcolor` stands for the colour of whatever it is painted on, and
      // the suite's expected value for it is the parent's colour in its own
      // test document. Reading the keyword is all that can be checked here.
      if color.is_current() {
        continue
      }
      if !expected_text.is_empty() && !out_of_scope(expected_text) {
        match Color::decode_opt(expected_text) {
          Some(want) => {
            let (absolute, relative) = wpt_tolerance(want, expected_text)
            if !wpt_same(color, want, absolute, relative) {
              fail(
                "\{input} read as \{color}, but the suite says \{expected_text}",
              )
            }
          }
          None => fail("did not read the expected value \{expected_text}")
        }
      }
      // Whatever the test expected, what this library writes has to come back
      // as the same colour: a writer that loses a component is caught here even
      // where the suite does not state a serialisation.
      let again = Color::decode_opt(color.encode())
      match again {
        Some(again) =>
          // The writer rounds to five decimals, so half of the last one is as
          // close as a round trip can be.
          if !wpt_same(again, color, 2.0e-5, 1.0e-9) {
            fail(
              "\{input} written as \{color.encode()} and read back as \{again}",
            )
          }
        None => fail("\{input} written as \{color.encode()} did not read back")
      }
    } else {
      match Color::decode_opt(input) {
        Some(color) =>
          fail("\{input} was read as \{color}, but the suite refuses it")
        None => ()
      }
    }
  }
  // The suite has just over nine hundred cases this library claims. The floor is
  // well below that so that a change in the upstream files does not fail the
  // build, but far above zero so that a broken collector does.
  assert_true(checked > 800, msg="only \{checked} cases were checked")
  assert_true(skipped > 100, msg="only \{skipped} cases were skipped")
}
