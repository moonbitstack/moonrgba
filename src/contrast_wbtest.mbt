// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Contrast against a reference, and against the two numbers everyone quotes.
//
// The fixture pairs are random, which is what catches a mis-transcribed
// coefficient; the hand-written cases are the ones a reader will check first,
// because they are printed in every article about the subject.

///|
fn contrast_pair(row : String) -> (String, Color, Color, Double)? {
  let fields = row_fields(row)
  if fields.length() < 9 {
    return None
  }
  let kind = fields[0].to_owned()
  if kind != "wcag" && kind != "apca" {
    return None
  }
  let first = {
    let space = Space::of(fields[1]).unwrap()
    {
      space,
      x: row_number(fields[2]),
      y: row_number(fields[3]),
      z: row_number(fields[4]),
      alpha: 1.0,
    }
  }
  let second = {
    let space = Space::of(fields[1]).unwrap()
    {
      space,
      x: row_number(fields[5]),
      y: row_number(fields[6]),
      z: row_number(fields[7]),
      alpha: 1.0,
    }
  }
  Some((kind, first, second, row_number(fields[8])))
}

///|
test "contrast ratios agree with colorjs" {
  let mut checked = 0
  let mut problem = ""
  for row in numbers {
    match contrast_pair(row) {
      Some((kind, first, second, want)) => {
        // WCAG's own text defines luminance as 0.2126 R + 0.7152 G + 0.0722 B
        // of linear sRGB, and this follows that; colorjs takes the Y of XYZ
        // instead, which is the same idea through the matrix and differs in the
        // fifth decimal. APCA has one definition and the two agree exactly.
        let (got, tolerance) = if kind == "wcag" {
          (first.contrast(second), 2.0e-4)
        } else {
          (first.apca(second), 1.0e-9)
        }
        if (got - want).abs() > tolerance * (1.0 + want.abs()) {
          problem = "\{kind} of \{first} on \{second} is \{got}, not \{want}"
          break
        }
        checked = checked + 1
      }
      None => ()
    }
  }
  assert_true(problem.is_empty(), msg=problem)
  assert_true(checked > 100, msg="only \{checked} pairs were checked")
}

///|
/// Black on white is the pair every statement of both measures starts with: 21
/// for WCAG, and 106.04 for APCA with the light background behind the text.
test "black and white are the ends of both scales" {
  let black = Color::black()
  let white = Color::white()
  assert_true((black.contrast(white) - 21.0).abs() < 1.0e-12)
  assert_true((black.contrast(black) - 1.0).abs() < 1.0e-12)
  // Dark text on a light background is the positive direction in APCA.
  assert_true((black.apca(white) - 106.04067321268862).abs() < 1.0e-9)
  assert_true((white.apca(black) + 107.88473318309848).abs() < 1.0e-9)
}

///|
/// WCAG's ratio is symmetric and APCA's is not: one measures a ratio of
/// luminances that does not know which is text, the other models the polarity of
/// the pair. A library that made both symmetric would be wrong about one of
/// them.
test "one measure is symmetric and the other is not" {
  let first = Color::srgb(0.9, 0.85, 0.8)
  let second = Color::srgb(0.15, 0.2, 0.35)
  assert_true((first.contrast(second) - second.contrast(first)).abs() < 1.0e-12)
  assert_true((first.apca(second) + second.apca(first)).abs() > 1.0)
}

///|
/// A pair with no lightness difference at all is unreadable under both: 1 is the
/// floor of WCAG's scale, and APCA reports nothing below its own threshold.
test "a colour on itself has no contrast" {
  let color = Color::srgb(0.4, 0.5, 0.6)
  assert_true((color.contrast(color) - 1.0).abs() < 1.0e-12)
  assert_true(color.apca(color) == 0.0)
}
