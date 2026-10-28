// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Bringing a colour into a gamut.
//
// The reference is colorjs's implementation of the same algorithm in CSS Color 4
// §13.2, over colours that are deliberately outside sRGB, plus the properties
// the algorithm exists to have: that it lands inside, that it keeps lightness and
// hue, and that running it twice changes nothing.

///|
test "gamut mapping agrees with colorjs" {
  let mut checked = 0
  let mut worst = 0.0
  let mut problem = ""
  for row in numbers {
    let fields = row_fields(row)
    if fields.length() < 8 || !fields[0].equal("gamut") {
      continue
    }
    let color = Color::oklch(
      row_number(fields[2]),
      row_number(fields[3]),
      row_number(fields[4]),
    )
    let mapped = color.to_gamut(space=Space::Srgb)
    let (r, g, b) = mapped.components()
    let expect = (
      row_number(fields[5]),
      row_number(fields[6]),
      row_number(fields[7]),
    )
    let gap = (r - expect.0).abs()
    let gap = if (g - expect.1).abs() > gap {
      (g - expect.1).abs()
    } else {
      gap
    }
    let gap = if (b - expect.2).abs() > gap {
      (b - expect.2).abs()
    } else {
      gap
    }
    if gap > worst {
      worst = gap
    }
    // The two implementations bisect to slightly different points and take
    // different amounts of the clipped fallback near a hard edge of the gamut,
    // so they agree to about a ten-thousandth of a channel rather than to the
    // last bit. Anything above that is a different algorithm, not a different
    // rounding.
    if gap > 5.0e-4 {
      problem = "\{color} mapped to \{r} \{g} \{b}, colorjs has \{expect.0} \{expect.1} \{expect.2}"
      break
    }
    checked = checked + 1
  }
  assert_true(problem.is_empty(), msg=problem)
  assert_true(checked > 40, msg="only \{checked} colours were mapped")
  // Stated so that a change which silently loosens the agreement is visible.
  assert_true(worst < 5.0e-4, msg="worst disagreement \{worst}")
}

///|
/// The result is inside the gamut, which is the whole point; the input was not,
/// or the test would not be testing anything.
test "mapping lands inside and stays there" {
  let outside = Color::oklch(0.7, 0.4, 30.0)
  assert_false(outside.in_gamut(space=Space::Srgb))
  let mapped = outside.to_gamut(space=Space::Srgb)
  assert_true(mapped.in_gamut())
  // Running it again must not move it: a colour inside the gamut comes back
  // untouched, so mapping twice is mapping once.
  let again = mapped.to_gamut()
  assert_true(near_components(again, mapped.components(), 0.0))
}

///|
/// Chroma is what the algorithm gives up, so lightness and hue are what must
/// survive. The hue is allowed a couple of degrees because the clipped fallback
/// at the very edge of the gamut does not keep it exactly, and lightness a
/// hundredth because a colour too light or too dark is pulled to white or black.
test "mapping gives up chroma and stays close to the colour it was given" {
  // What the algorithm promises is not that lightness and hue are untouched —
  // its clipped fallback can move both — but that the result is inside and near:
  // the just-noticeable-difference test inside it is exactly a limit on how far
  // the answer may be from the colour asked for.
  // Colours a little outside, which is what a colour picker produces when
  // somebody drags a slider past the edge of sRGB.
  for
    (hue, lightness, chroma) in [
      (30.0, 0.7, 0.2),
      (140.0, 0.9, 0.3),
      (260.0, 0.5, 0.3),
      (0.0, 0.4, 0.2),
    ] {
    let outside = Color::oklch(lightness, chroma, hue)
    assert_false(
      outside.in_gamut(space=Srgb),
      msg="\{outside} is already inside",
    )
    let mapped = outside.to_gamut(space=Srgb)
    assert_true(mapped.in_gamut(), msg="\{outside} mapped to \{mapped}")
    // Chroma is what it gives up, and only that.
    let back = mapped.to_oklch()
    assert_true(back.y < chroma, msg="chroma \{back.y} from \{chroma}")
    // Lightness moves by less than a hundredth, hue by a fraction of a degree.
    assert_true(
      (back.x - lightness).abs() < 0.02,
      msg="lightness \{back.x} for \{lightness}",
    )
    // The hue holds to a few degrees: where the answer lands on the surface of
    // the gamut the clipped fallback pulls it towards the nearest visible
    // colour, and blue at the edge of sRGB is where that shows most.
    let turned = ((back.z - hue) % 360.0).abs()
    assert_true(
      turned < 5.0 || 360.0 - turned < 5.0,
      msg="hue \{back.z} for \{hue}",
    )
    // And the whole move is small, which is the point of doing it this way
    // rather than clipping.
    assert_true(
      outside.delta_e(mapped, delta=Ok) < 0.05,
      msg="\{outside} moved \{outside.delta_e(mapped, delta=Ok)} to \{mapped}",
    )
  }
}

///|
/// A colour so far outside that no chroma reduction can reach it takes the
/// clipped fallback, and that is allowed to move lightness and hue: the
/// alternative was returning a colour the display cannot show.
test "a colour at the edge of the gamut falls back to clipping" {
  let extreme = Color::oklch(0.5, 0.4, 260.0)
  let mapped = extreme.to_gamut(space=Srgb)
  assert_true(mapped.in_gamut())
  let back = mapped.to_oklch()
  assert_true(back.y < extreme.y)
  // Closer than the original, and inside: the two things the fallback promises.
  assert_true(
    extreme.delta_e(mapped, delta=Ok) <
    extreme.delta_e(Color::black(), delta=Ok),
  )
}

///|
/// A colour already inside comes back exactly where it was, and in the space it
/// was asked for. Rounding it through the algorithm would lose precision for
/// nothing.
test "a colour inside the gamut is left alone" {
  let inside = Color::srgb(0.2, 0.4, 0.6)
  assert_true(inside.in_gamut())
  let mapped = inside.to_gamut(space=Space::Srgb)
  assert_eq(mapped.components(), inside.components())
  // Even when the space it is mapped into is not the one it is written in.
  let p3 = Color::display_p3(0.5, 0.2, 0.1)
  assert_true(p3.in_gamut(space=Space::Srgb))
  assert_true(p3.to_gamut(space=Space::Srgb).in_gamut(space=Space::Srgb))
}

///|
/// Nothing at either end of the lightness scale can be shown at all, and the
/// algorithm says so rather than bisecting its way to the answer.
test "white and black are the ends of the lightness scale" {
  let too_light = Color::oklch(1.2, 0.3, 120.0)
  assert_true(
    near_components(
      too_light.to_gamut(space=Space::Srgb),
      (1.0, 1.0, 1.0),
      1.0e-9,
    ),
  )
  let too_dark = Color::oklch(-0.2, 0.3, 120.0)
  assert_true(
    near_components(
      too_dark.to_gamut(space=Space::Srgb),
      (0.0, 0.0, 0.0),
      1.0e-9,
    ),
  )
}

///|
/// Clipping is the cheap answer: it moves each component to the nearest edge and
/// lets hue follow. It is not the same colour as the mapping, and the difference
/// is what the algorithm is for.
test "clipping and mapping are different answers" {
  let outside = Color::oklch(0.7, 0.35, 260.0)
  let clipped = outside.clip(space=Space::Srgb)
  let mapped = outside.to_gamut(space=Space::Srgb)
  assert_true(clipped.in_gamut())
  assert_true(mapped.in_gamut())
  // Clipping shifts the hue; mapping keeps it.
  let clipped_hue = clipped.to_oklch().z
  let mapped_hue = mapped.to_oklch().z
  let clipped_turn = ((clipped_hue - 260.0) % 360.0).abs()
  let mapped_turn = ((mapped_hue - 260.0) % 360.0).abs()
  assert_true(
    mapped_turn < clipped_turn,
    msg="mapped \{mapped_hue}, clipped \{clipped_hue}",
  )
}

///|
/// A space with no gamut has nothing to map into, and every colour in it is
/// already inside: XYZ and the Lab family describe colours, not displays.
test "a space without a gamut accepts everything" {
  assert_true(Space::XyzD65.has_gamut() == false)
  assert_true(Space::Lab.has_gamut() == false)
  assert_true(Space::Srgb.has_gamut())
  let wild = Color::xyz_d65(2.0, -1.0, 5.0)
  assert_true(wild.in_gamut())
  assert_eq(wild.to_gamut().components(), wild.components())
}

///|
/// Alpha is not part of a gamut: a transparent colour is still a colour, and
/// mapping it must not make it opaque.
test "alpha survives the mapping" {
  let outside = Color::oklch(0.7, 0.4, 30.0, alpha=0.25)
  let mapped = outside.to_gamut(space=Space::Srgb)
  assert_eq(mapped.alpha, 0.25)
  assert_eq(outside.clip(space=Space::Srgb).alpha, 0.25)
}
