// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// How far apart two colours are, as one number.
//
// Four answers, because the question has four accepted ones. ΔE 76 is the
// straight-line distance in Lab and is wrong in the blues; ΔE 94 and ΔE 2000 add
// the corrections that make it agree with what people see, at the cost of
// weights that assume a use — graphic arts or textiles. ΔE OK is the same idea
// in Oklab, and is the cheapest of the four and the most even across hues.
//
// They are not interchangeable and the numbers are not comparable between them:
// a ΔE of 2 is barely visible under 2000 and clearly visible under 76.

///|
/// Which colour difference to measure. The name is the question, not the space:
/// three of these are computed in Lab and one in Oklab.
pub(all) enum Delta {
  /// CIE76: the Euclidean distance in Lab, which is 1976's answer.
  E76
  /// CIE94, with the graphic-arts weights: 1 for lightness, 1 for chroma, 1 for
  /// hue. The textile weights (2, 1, 1) are a different question.
  E94
  /// CIEDE2000, the current CIE recommendation, with all three weights at 1.
  E2000
  /// The Euclidean distance in Oklab, which needs no weights to be even.
  Ok
} derive(Eq, Debug)

///|
pub extend Delta with Eq::{equal, not_equal}

///|
pub extend Delta with Debug::{to_repr}

///|
/// The measure writes itself with the name it is known by.
pub impl Show for Delta with fn output(self, logger) {
  match self {
    E76 => logger.write_string("ΔE 76")
    E94 => logger.write_string("ΔE 94")
    E2000 => logger.write_string("ΔE 2000")
    Ok => logger.write_string("ΔE OK")
  }
}

///|
pub extend Delta with Show::{to_string, output}

///|
/// The distance between two colours, by the chosen measure.
///
/// Colours in any space are converted to the one the measure is defined on, so
/// `delta_e` answers about the colours, not about where they are written. Opaque
/// alpha plays no part: this is a distance between colours, and a colour at 10%
/// opacity is the same colour as one at 100%.
pub fn Color::delta_e(self : Color, other : Color, delta? : Delta) -> Double {
  match delta.unwrap_or(E2000) {
    E76 => {
      let (l1, a1, b1) = self.to_lab().components()
      let (l2, a2, b2) = other.to_lab().components()
      @math.hypot(@math.hypot(l1 - l2, a1 - a2), b1 - b2)
    }
    E94 => delta_e_94(self.to_lab(), other.to_lab())
    E2000 => delta_e_2000(self.to_lab(), other.to_lab())
    Ok => {
      let (l1, a1, b1) = self.to_oklab().components()
      let (l2, a2, b2) = other.to_oklab().components()
      // Oklab's lightness runs 0–1 rather than 0–100, so this is a hundredth of
      // the size of the same distance written in Lab. The just-noticeable
      // difference is 0.02 here, which is 2 there.
      @math.hypot(@math.hypot(l1 - l2, a1 - a2), b1 - b2)
    }
  }
}

///|
/// The square root, which the core library spells as a method on the number and
/// the measures below call a dozen times between them.
fn root(value : Double) -> Double {
  value.sqrt()
}

///|
/// CIE94, graphic arts: lightness counts fully, and chroma and hue count for less
/// as the chroma of the reference grows, because the eye is less sensitive to
/// them in saturated colours.
fn delta_e_94(first : Color, second : Color) -> Double {
  let (l1, a1, b1) = first.components()
  let (l2, a2, b2) = second.components()
  let c1 = @math.hypot(a1, b1)
  let c2 = @math.hypot(a2, b2)
  let delta_l = l1 - l2
  let delta_c = c1 - c2
  let delta_a = a1 - a2
  let delta_b = b1 - b2
  let delta_h_squared = delta_a * delta_a +
    delta_b * delta_b -
    delta_c * delta_c
  let delta_h = if delta_h_squared <= 0.0 { 0.0 } else { root(delta_h_squared) }
  let scale_l = 1.0
  let scale_c = 1.0 + 0.045 * c1
  let scale_h = 1.0 + 0.015 * c1
  let term_l = delta_l / scale_l
  let term_c = delta_c / scale_c
  let term_h = delta_h / scale_h
  root(term_l * term_l + term_c * term_c + term_h * term_h)
}

///|
/// CIEDE2000. The published formulae, in the published order; the parts that
/// need the most care are the mean hue at the wrap-around and the rotation term,
/// which is what makes the measure agree with the eye in the blues.
fn delta_e_2000(first : Color, second : Color) -> Double {
  let (l1, a1, b1) = first.components()
  let (l2, a2, b2) = second.components()
  let c1 = @math.hypot(a1, b1)
  let c2 = @math.hypot(a2, b2)
  let mean_c = (c1 + c2) / 2.0
  let mean_c7 = @math.pow(mean_c, 7.0)
  let twenty_five7 = @math.pow(25.0, 7.0)
  let g = 0.5 * (1.0 - root(mean_c7 / (mean_c7 + twenty_five7)))
  let a1p = (1.0 + g) * a1
  let a2p = (1.0 + g) * a2
  let c1p = @math.hypot(a1p, b1)
  let c2p = @math.hypot(a2p, b2)
  let h1p = hue_angle(b1, a1p)
  let h2p = hue_angle(b2, a2p)
  let delta_lp = l2 - l1
  let delta_cp = c2p - c1p
  let delta_hp = if c1p * c2p == 0.0 {
    0.0
  } else {
    let raw = h2p - h1p
    if raw.abs() <= 180.0 {
      raw
    } else if raw > 180.0 {
      raw - 360.0
    } else {
      raw + 360.0
    }
  }
  let delta_big_hp = 2.0 *
    root(c1p * c2p) *
    @math.sin(delta_hp / 2.0 * @math.PI / 180.0)
  let mean_lp = (l1 + l2) / 2.0
  let mean_cp = (c1p + c2p) / 2.0
  let mean_hp = if c1p * c2p == 0.0 {
    h1p + h2p
  } else if (h1p - h2p).abs() <= 180.0 {
    (h1p + h2p) / 2.0
  } else if h1p + h2p < 360.0 {
    (h1p + h2p + 360.0) / 2.0
  } else {
    (h1p + h2p - 360.0) / 2.0
  }
  let radians = mean_hp * @math.PI / 180.0
  let t = 1.0 - 0.17 * @math.cos(radians - 30.0 * @math.PI / 180.0)
  let t = t + 0.24 * @math.cos(2.0 * radians)
  let t = t + 0.32 * @math.cos(3.0 * radians + 6.0 * @math.PI / 180.0)
  let t = t - 0.20 * @math.cos(4.0 * radians - 63.0 * @math.PI / 180.0)
  let delta_theta = 30.0 * @math.exp(-@math.pow((mean_hp - 275.0) / 25.0, 2.0))
  let mean_cp7 = @math.pow(mean_cp, 7.0)
  // The rotation term is negative in the definition, and the sign is what makes
  // the measure agree with the eye in the blues rather than doubling the error
  // there.
  let rotation = -2.0 * root(mean_cp7 / (mean_cp7 + twenty_five7))
  let rotation = rotation * @math.sin(2.0 * delta_theta * @math.PI / 180.0)
  let lightness_term = mean_lp - 50.0
  let spread = root(20.0 + lightness_term * lightness_term)
  let scale_l = 1.0 + 0.015 * lightness_term * lightness_term / spread
  let scale_c = 1.0 + 0.045 * mean_cp
  let scale_h = 1.0 + 0.015 * mean_cp * t
  let term_l = delta_lp / scale_l
  let term_c = delta_cp / scale_c
  let term_h = delta_big_hp / scale_h
  root(
    term_l * term_l +
    term_c * term_c +
    term_h * term_h +
    rotation * term_c * term_h,
  )
}

///|
/// The hue of a point in a Lab plane, in degrees, with zero for the neutral axis
/// where the angle has no meaning.
fn hue_angle(b : Double, a : Double) -> Double {
  if a == 0.0 && b == 0.0 {
    return 0.0
  }
  let degrees = @math.atan2(b, a) * 180.0 / @math.PI
  if degrees < 0.0 {
    degrees + 360.0
  } else {
    degrees
  }
}
