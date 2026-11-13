// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The colour value itself: what the constructors put in it, what the accessors
// take out, and what survives a change of space.

///|
test "components keep the units of the space they are written in" {
  let hsl = @moonrgba.Color::hsl(210.0, 0.5, 0.4)
  assert_eq(hsl.components(), (210.0, 0.5, 0.4))
  let lab = @moonrgba.Color::lab(50.0, 20.0, -30.0)
  assert_eq(lab.components(), (50.0, 20.0, -30.0))
  let oklch = @moonrgba.Color::oklch(0.7, 0.15, 200.0)
  assert_eq(oklch.components(), (0.7, 0.15, 200.0))
}

///|
test "every constructor is opaque unless it is told otherwise" {
  let samples = [
    @moonrgba.Color::srgb(0.1, 0.2, 0.3),
    @moonrgba.Color::rgb(1, 2, 3),
    @moonrgba.Color::hsl(1.0, 0.2, 0.3),
    @moonrgba.Color::lab(50.0, 0.0, 0.0),
    @moonrgba.Color::oklch(0.5, 0.1, 10.0),
    @moonrgba.Color::display_p3(0.1, 0.2, 0.3),
    @moonrgba.Color::ycbcr(0.5, 0.0, 0.0),
  ]
  for color in samples {
    assert_eq(color.alpha, 1.0)
  }
  assert_eq(@moonrgba.Color::srgb(0.0, 0.0, 0.0, alpha=0.25).alpha, 0.25)
}

///|
test "bytes become fractions and back" {
  assert_true(
    near_components(
      @moonrgba.Color::rgb(255, 128, 0),
      (1.0, 128.0 / 255.0, 0.0),
      0.0,
    ),
  )
  assert_eq(@moonrgba.Color::rgb(255, 128, 0).rgb8(), (255, 128, 0))
  // Bytes are what a terminal and a hexadecimal colour carry, so this has to
  // come back exactly, not nearly.
  for value in [0, 1, 17, 84, 127, 128, 200, 254, 255] {
    assert_eq(
      @moonrgba.Color::rgb(value, value, value).rgb8(),
      (value, value, value),
    )
  }
}

///|
/// Each accessor looks where its family keeps the component: the hue is first in
/// HSL and last in LCh, and lightness is last in HSL and first in Lab.
test "the accessors find a component wherever the space keeps it" {
  let hsl = @moonrgba.Color::hsl(210.0, 0.5, 0.4)
  assert_eq(hsl.hue(), 210.0)
  assert_eq(hsl.saturation(), 0.5)
  assert_eq(hsl.lightness(), 0.4)
  assert_true(hsl.chroma().is_nan())
  let lch = @moonrgba.Color::lch(60.0, 40.0, 120.0)
  assert_eq(lch.hue(), 120.0)
  assert_eq(lch.chroma(), 40.0)
  assert_eq(lch.lightness(), 60.0)
  assert_true(lch.saturation().is_nan())
  let oklab = @moonrgba.Color::oklab(0.5, 0.1, 0.2)
  assert_eq(oklab.lightness(), 0.5)
  assert_true(oklab.hue().is_nan())
  assert_true(@moonrgba.Color::srgb(1.0, 0.5, 0.0).lightness().is_nan())
}

///|
test "with_alpha and with_components leave the rest alone" {
  let base = @moonrgba.Color::lab(50.0, 10.0, -10.0)
  let faded = base.with_alpha(0.25)
  assert_eq(faded.alpha, 0.25)
  assert_eq(faded.components(), base.components())
  assert_eq(faded.space, base.space)
  let moved = base.with_components(60.0, 0.0, 0.0)
  assert_eq(moved.components(), (60.0, 0.0, 0.0))
  assert_eq(moved.alpha, base.alpha)
}

///|
/// `currentcolor` is not a colour until whoever paints it says which one it is.
/// Keeping it as a value is what lets a declaration be read and written back
/// unchanged, which is the whole point of reading declarations.
test "currentcolor is a value of its own and resolves on demand" {
  let current = @moonrgba.Color::current()
  assert_true(current.is_current())
  assert_false(@moonrgba.Color::srgb(1.0, 0.0, 0.0).is_current())
  let red = @moonrgba.Color::srgb(1.0, 0.0, 0.0)
  assert_eq(current.resolve(red).components(), red.components())
  assert_eq(
    red.resolve(@moonrgba.Color::white()).components(),
    red.components(),
  )
  // Converting it cannot invent components, so it stays what it is.
  assert_true(current.to_srgb().is_current())
  assert_true(current.to_oklch().is_current())
}

///|
test "a space knows the name it is written with and finds itself by it" {
  let spaces = [
    @moonrgba.Space::Srgb,
    @moonrgba.Space::SrgbLinear,
    @moonrgba.Space::Hsl,
    @moonrgba.Space::Hsv,
    @moonrgba.Space::Hwb,
    @moonrgba.Space::Lab,
    @moonrgba.Space::Lch,
    @moonrgba.Space::Oklab,
    @moonrgba.Space::Oklch,
    @moonrgba.Space::XyzD50,
    @moonrgba.Space::XyzD65,
    @moonrgba.Space::DisplayP3,
    @moonrgba.Space::DisplayP3Linear,
    @moonrgba.Space::Rec2020,
    @moonrgba.Space::A98Rgb,
    @moonrgba.Space::ProPhoto,
    @moonrgba.Space::YCbCr(@moonrgba.Luma::Bt601),
  ]
  for space in spaces {
    match @moonrgba.Space::of(space.code()) {
      Some(found) => assert_eq(found, space)
      None => abort("no space answers to " + space.code())
    }
  }
  // `xyz` is the older spelling of `xyz-d65`.
  assert_eq(@moonrgba.Space::of("xyz"), Some(@moonrgba.Space::XyzD65))
  assert_eq(@moonrgba.Space::of("nonsense"), None)
}

///|
test "a polar space is one whose hue is an angle" {
  assert_true(@moonrgba.Space::Hsl.is_polar())
  assert_true(@moonrgba.Space::Oklch.is_polar())
  assert_false(@moonrgba.Space::Oklab.is_polar())
  assert_false(@moonrgba.Space::Srgb.is_polar())
}

///|
/// The luma coefficients are the standard's, and a full red is the value both
/// BT.601 and BT.709 give it: luma is the red coefficient, and the red
/// difference is a half, because `R − Y` is `1 − Kʳ` and the divisor is twice
/// that.
test "YCbCr gives a red the numbers the standards give it" {
  let red = @moonrgba.Color::rgb(255, 0, 0)
  // The components are luma, blue difference, red difference, in that order.
  let bt709 = red.to_ycbcr(luma=@moonrgba.Luma::Bt709)
  assert_true(near(bt709.x, 0.2126, 1.0e-12), msg="\{bt709.x}")
  assert_true(near(bt709.y, -0.11457210605733965, 1.0e-12), msg="\{bt709.y}")
  assert_true(near(bt709.z, 0.5, 1.0e-12), msg="\{bt709.z}")
  let bt601 = red.to_ycbcr(luma=@moonrgba.Luma::Bt601)
  assert_true(near(bt601.x, 0.299, 1.0e-12), msg="\{bt601.x}")
  assert_true(near(bt601.y, -0.1687358916, 1.0e-9), msg="\{bt601.y}")
  assert_true(near(bt601.z, 0.5, 1.0e-12), msg="\{bt601.z}")
  let bt2020 = red.to_ycbcr(luma=@moonrgba.Luma::Bt2020)
  assert_true(near(bt2020.x, 0.2627, 1.0e-12), msg="\{bt2020.x}")
  // White has luma one and no chroma, whichever coefficients are used.
  for
    luma in [
      @moonrgba.Luma::Bt601,
      @moonrgba.Luma::Bt709,
      @moonrgba.Luma::Bt2020,
    ] {
    let white = @moonrgba.Color::white().to_ycbcr(luma~)
    assert_true(near(white.x, 1.0, 1.0e-12), msg="\{white.x}")
    assert_true(near(white.y, 0.0, 1.0e-12), msg="\{white.y}")
    assert_true(near(white.z, 0.0, 1.0e-12), msg="\{white.z}")
  }
  // And it comes back exactly, coefficients and all.
  let round_trip = bt709.to_srgb()
  assert_true(near_components(round_trip, (1.0, 0.0, 0.0), 1.0e-12))
}

///|
/// CMYK is four inks in a colour type that holds three components, so it is a
/// type of its own. Four inks do not fit in three channels and `to_cmyk` has to
/// choose which of the many ink combinations to return, so what round-trips is
/// the colour, not the inks.
test "CMYK prints the colour it was given, though not always the inks" {
  let inks = @moonrgba.Cmyk::of(0.2, 0.4, 0.6, 0.1)
  let color = inks.to_color()
  // Each channel is what the ink leaves over: the colour ink, then the key.
  assert_true(near_components(color, (0.72, 0.54, 0.36), 1.0e-12))
  let back = color.to_cmyk()
  assert_true(near(back.k, 0.28, 1.0e-12), msg="key came out \{back.k}")
  // The same colour through the inks again is the same colour.
  let again = back.to_color()
  assert_true(near_components(again, (0.72, 0.54, 0.36), 1.0e-12))
  // No ink at all is white, and all key is black.
  assert_true(
    near_components(
      @moonrgba.Cmyk::of(0.0, 0.0, 0.0, 0.0).to_color(),
      (1.0, 1.0, 1.0),
      1.0e-12,
    ),
  )
  assert_true(
    near_components(
      @moonrgba.Color::black().to_cmyk().to_color(),
      (0.0, 0.0, 0.0),
      1.0e-12,
    ),
  )
  assert_true(near(@moonrgba.Color::black().to_cmyk().k, 1.0, 1.0e-12))
}

///|
/// A grey has no hue, in every space whose third component is an angle. A hue of
/// zero is red, so a grey that claimed one would drag an interpolation towards
/// red on its way past.
test "a grey reports no hue" {
  for
    grey in [
      @moonrgba.Color::rgb(0, 0, 0),
      @moonrgba.Color::rgb(128, 128, 128),
      @moonrgba.Color::rgb(255, 255, 255),
    ] {
    assert_true(grey.to_hsl().hue().is_nan(), msg="hsl of \{grey}")
    assert_true(grey.to_hsv().hue().is_nan(), msg="hsv of \{grey}")
    assert_true(grey.to_hwb().hue().is_nan(), msg="hwb of \{grey}")
    assert_true(grey.to_lch().hue().is_nan(), msg="lch of \{grey}")
    assert_true(grey.to_oklch().hue().is_nan(), msg="oklch of \{grey}")
  }
  // A colour that is not grey does have one, so the answer is not always NaN.
  assert_false(@moonrgba.Color::rgb(120, 130, 140).to_hsl().hue().is_nan())
}

///|
/// Lightness is reported for the spaces that have one under that name — HSL's
/// lightness, the Lab family's first component, HSV's value — and not for HWB,
/// whose whiteness and blackness are a different pair of axes.
test "lightness is reported where a space has it" {
  assert_eq(@moonrgba.Color::hsl(210.0, 0.5, 0.4).lightness(), 0.4)
  assert_eq(@moonrgba.Color::hsv(210.0, 0.5, 0.4).lightness(), 0.4)
  assert_eq(@moonrgba.Color::oklch(0.62, 0.1, 200.0).lightness(), 0.62)
  assert_eq(@moonrgba.Color::oklab(0.62, 0.1, -0.1).lightness(), 0.62)
  assert_true(@moonrgba.Color::hwb(210.0, 0.1, 0.2).lightness().is_nan())
  assert_true(@moonrgba.Color::srgb(0.2, 0.4, 0.6).lightness().is_nan())
}

///|
/// Every space answers to the name it writes and to no other, including the luma
/// variants and the keyword that is not a space.
test "every space is found by the name it writes" {
  for
    space in [
      @moonrgba.Space::YCbCr(@moonrgba.Luma::Bt709),
      @moonrgba.Space::YCbCr(@moonrgba.Luma::Bt2020),
      @moonrgba.Space::Current,
    ] {
    assert_eq(@moonrgba.Space::of(space.code()), Some(space))
  }
  assert_eq(
    @moonrgba.Space::of("YCBCR-601"),
    Some(@moonrgba.Space::YCbCr(@moonrgba.Luma::Bt601)),
  )
  // A space with no syntax of its own is not one `color()` accepts.
  assert_false(@moonrgba.Space::Hsv.is_predefined())
  assert_false(@moonrgba.Space::Current.is_predefined())
  assert_true(@moonrgba.Space::XyzD65.is_predefined())
}

///|
/// The enum types write themselves the way a stylesheet or a theme file spells
/// them, which is what makes them safe to put in a log line.
test "the enums write themselves as a reader would spell them" {
  assert_eq(@moonrgba.Space::DisplayP3.to_string(), "display-p3")
  assert_eq(
    @moonrgba.Space::YCbCr(@moonrgba.Luma::Bt2020).to_string(),
    "ycbcr-2020",
  )
  assert_eq(@moonrgba.Format::Oklch.to_string(), "oklch")
  assert_eq(@moonrgba.Format::Shortest.to_string(), "shortest")
  assert_eq(@moonrgba.Hue::Longer.to_string(), "longer")
  assert_eq(@moonrgba.Delta::E2000.to_string(), "ΔE 2000")
  assert_eq(@moonrgba.Ansi16::BrightCyan.to_string(), "bright-cyan")
  assert_eq(@moonrgba.Ansi256::of(196).to_string(), "196")
}
