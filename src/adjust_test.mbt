// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The adjustments: lighten, darken, saturate, desaturate and fade.
//
// Each is a nudge along one component of the colour's own space, so what these
// check is that the nudge lands where it says, that it stops at the ends, and
// that it leaves the other components and the alpha alone.

///|
test "lighten and darken move lightness in the colour's own units" {
  let base = @moonrgba.Color::hsl(210.0, 0.5, 0.4)
  let lighter = base.lighten(0.1)
  assert_true(near(lighter.lightness(), 0.5, 1.0e-12))
  assert_true(near(lighter.hue(), 210.0, 1.0e-12))
  assert_true(near(lighter.saturation(), 0.5, 1.0e-12))
  let darker = base.darken(0.2)
  assert_true(near(darker.lightness(), 0.2, 1.0e-12))
  // In Lab the scale is 0–100, and the amount is a fraction of it.
  let lab = @moonrgba.Color::lab(40.0, 20.0, -10.0)
  assert_true(near(lab.lighten(0.1).lightness(), 50.0, 1.0e-12))
  assert_true(near(lab.darken(0.1).lightness(), 30.0, 1.0e-12))
  // OkLCh is 0–1 again.
  let oklch = @moonrgba.Color::oklch(0.5, 0.1, 120.0)
  assert_true(near(oklch.lighten(0.25).lightness(), 0.75, 1.0e-12))
}

///|
test "lightness stops at white and black" {
  let color = @moonrgba.Color::hsl(210.0, 0.5, 0.9)
  assert_true(near(color.lighten(0.5).lightness(), 1.0, 1.0e-12))
  // White, to within the round trip through HSL's arithmetic.
  assert_true(
    near_components(color.lighten(0.5).to_srgb(), (1.0, 1.0, 1.0), 1.0e-12),
  )
  let dark = @moonrgba.Color::hsl(210.0, 0.5, 0.1)
  assert_true(near(dark.darken(0.5).lightness(), 0.0, 1.0e-12))
  // A space with no lightness of its own is converted to OkLCh first, and stays
  // there: the answer is a colour, not a colour in the space it started in.
  let srgb = @moonrgba.Color::srgb(0.4, 0.5, 0.6)
  let lightened = srgb.lighten(0.1)
  assert_eq(lightened.space, @moonrgba.Space::Oklch)
  assert_true(lightened.lightness() > srgb.to_oklch().lightness())
}

///|
test "saturate and desaturate move chroma, and stop at grey" {
  let base = @moonrgba.Color::hsl(210.0, 0.5, 0.5)
  let more = base.saturate(0.25)
  assert_true(near(more.saturation(), 0.75, 1.0e-12))
  assert_true(near(more.lightness(), 0.5, 1.0e-12))
  let less = base.desaturate(0.25)
  assert_true(near(less.saturation(), 0.25, 1.0e-12))
  // A saturation cannot go past one or below nothing.
  assert_true(near(base.saturate(1.0).saturation(), 1.0, 1.0e-12))
  assert_true(near(base.desaturate(2.0).saturation(), 0.0, 1.0e-12))
  // Desaturating all the way is a grey, which has no hue left to name.
  let grey = base.desaturate(1.0)
  assert_true(grey.hue().is_nan() || near(grey.hue(), 210.0, 1.0e-12))
  let (r, g, _) = grey.to_srgb().components()
  assert_true(near(r, g, 1.0e-12), msg="\{r} and \{g}")
}

///|
test "fade takes alpha away without touching the colour" {
  let base = @moonrgba.Color::srgb(0.2, 0.4, 0.6)
  assert_true(near(base.fade(0.25).alpha, 0.75, 1.0e-12))
  assert_eq(base.fade(0.25).components(), base.components())
  assert_eq(base.fade(1.0).alpha, 0.0)
  // Fading an already transparent colour does not bring it back.
  assert_eq(base.fade(1.0).fade(0.5).alpha, 0.0)
}
