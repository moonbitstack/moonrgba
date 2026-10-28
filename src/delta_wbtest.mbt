// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The four colour differences, against two references.
//
// ΔE 76, 94 and 2000 come from color-science, which implements CIE's own
// definitions; the published test set for CIEDE2000 is included in the fixture.
// ΔE OK comes from colorjs.io, which implements the measure its authors
// proposed. Where the two references overlap — 76 and 2000 — this library has to
// agree with both, and they agree with each other to eleven places.

///|
fn delta_of(row : String) -> (Delta, Color, Color, Double)? {
  let fields = row_fields(row)
  if fields.length() < 9 {
    return None
  }
  let measure = match fields[0].to_owned() {
    "76" => Delta::E76
    "94" => Delta::E94
    "2000" => Delta::E2000
    "ok" => Delta::Ok
    _ => return None
  }
  let color = {
    let space = Space::of(fields[1]).unwrap()
    {
      space,
      x: row_number(fields[2]),
      y: row_number(fields[3]),
      z: row_number(fields[4]),
      alpha: 1.0,
    }
  }
  let other = {
    let space = Space::of(fields[1]).unwrap()
    {
      space,
      x: row_number(fields[5]),
      y: row_number(fields[6]),
      z: row_number(fields[7]),
      alpha: 1.0,
    }
  }
  Some((measure, color, other, row_number(fields[8])))
}

///|
/// Every row of a fixture, checked against the value its reference computed, and
/// against the row that names the same two colours the other way round.
///
/// A difference is a distance, so the order the colours are named in must not
/// matter. ΔE 94 is the exception in the literature: the first colour is the
/// reference, and swapping them can change the answer, so it is excluded from
/// that half of the check.
fn check_deltas(
  rows : Array[String],
  tolerance : Double,
  label : String,
) -> (Int32, String) {
  let mut checked = 0
  let mut problem = ""
  for row in rows {
    match delta_of(row) {
      Some((measure, first, second, want)) => {
        let got = first.delta_e(second, delta=measure)
        if (got - want).abs() > tolerance * (1.0 + want.abs()) {
          problem = "\{label}: \{measure} of \{first} and \{second} is \{got}, not \{want}"
          break
        }
        if measure is E76 || measure is E2000 || measure is Ok {
          let back = second.delta_e(first, delta=measure)
          if (back - got).abs() > tolerance * (1.0 + got.abs()) {
            problem = "\{label}: \{measure} is asymmetric, \{got} one way and \{back} the other"
            break
          }
        }
        checked = checked + 1
      }
      None => ()
    }
  }
  (checked, problem)
}

///|
/// The random pairs and the published test set, against color-science.
test "colour differences agree with color-science" {
  let (checked, problem) = check_deltas(deltas, 1.0e-9, "colour-science")
  assert_true(problem.is_empty(), msg=problem)
  assert_true(checked > 200, msg="only \{checked} rows were checked")
}

///|
/// The same two measures plus Oklab, against colorjs.io.
test "colour differences agree with colorjs" {
  let (checked, problem) = check_deltas(numbers, 1.0e-9, "colorjs")
  assert_true(problem.is_empty(), msg=problem)
  assert_true(checked > 200, msg="only \{checked} rows were checked")
}

///|
/// A colour has no distance from itself, under any of the four.
test "a colour is zero away from itself" {
  let samples = [
    Color::srgb(0.2, 0.6, 0.9),
    Color::oklch(0.7, 0.2, 40.0),
    Color::lab(50.0, -20.0, 30.0),
    Color::black(),
    Color::white(),
  ]
  for color in samples {
    for measure in [Delta::E76, Delta::E94, Delta::E2000, Delta::Ok] {
      let distance = color.delta_e(color, delta=measure)
      assert_true(
        distance.abs() < 1.0e-10,
        msg="\{measure} of \{color} with itself is \{distance}",
      )
    }
  }
}

///|
/// Every measure agrees that a bigger step is a bigger difference, and that a
/// colour is closer to a near neighbour than to a far one. This is what makes a
/// difference usable for a threshold: without it, "the nearest palette entry"
/// would depend on which measure was asked.
test "a difference grows with the distance under every measure" {
  let base = Color::lab(50.0, 0.0, 0.0)
  for measure in [Delta::E76, Delta::E94, Delta::E2000, Delta::Ok] {
    let near = base.delta_e(Color::lab(50.0, 1.0, 0.0), delta=measure)
    let middle = base.delta_e(Color::lab(50.0, 10.0, 0.0), delta=measure)
    let far = base.delta_e(Color::lab(50.0, 40.0, 0.0), delta=measure)
    assert_true(near > 0.0, msg="\{measure} of a step of one is \{near}")
    assert_true(
      middle > near,
      msg="\{measure} is not monotonic: \{middle} against \{near}",
    )
    assert_true(
      far > middle,
      msg="\{measure} is not monotonic: \{far} against \{middle}",
    )
  }
}

///|
/// ΔE OK is measured in Oklab, so a difference of 0.02 there is the
/// just-noticeable difference the gamut mapping algorithm uses, by definition:
/// two colours 0.02 apart in Oklab must report 0.02.
test "the OK measure is the Oklab distance itself" {
  let base = Color::oklab(0.5, 0.0, 0.0)
  let neighbour = Color::oklab(0.5, 0.02, 0.0)
  let distance = base.delta_e(neighbour, delta=Ok)
  assert_true((distance - 0.02).abs() < 1.0e-12, msg="\{distance}")
  // The same distance written in Lab is a hundred times the number, because
  // Oklab's lightness and axes are on a 0–1 scale and Lab's on 0–100.
  let in_lab = base.to_lab().delta_e(neighbour.to_lab(), delta=E76)
  assert_true(in_lab > 1.0, msg="\{in_lab}")
}
