// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Helpers for the tests that read a fixture.
//
// The tests written against the fixtures are whitebox tests, because a fixture
// is a private table of the package; the ones written against the public
// interface are blackbox and keep their own copy of these two functions. The
// duplication is deliberate: the blackbox tests are the ones that prove the
// interface is usable from outside, and they cannot see this file.

///|
/// A component equal to what is expected, to the precision the test states.
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
  got : Color,
  want : (Double, Double, Double),
  tolerance : Double,
) -> Bool {
  let (x, y, z) = got.components()
  near(x, want.0, tolerance) &&
  near(y, want.1, tolerance) &&
  near(z, want.2, tolerance)
}
