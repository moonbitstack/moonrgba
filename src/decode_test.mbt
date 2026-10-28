// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Reading a colour, one syntax at a time.
//
// The web-platform-tests suite covers the grammar in far more detail than this
// file does; what is here is the shape of each syntax, the corners that are easy
// to get wrong, and the errors — which the suite says nothing about, because a
// browser turns a bad declaration into "ignore it" and never has to explain
// itself.

///|
test "the four hexadecimal forms" {
  assert_eq(read("#f00").components(), (1.0, 0.0, 0.0))
  assert_eq(
    read("#123").components(),
    (17.0 / 255.0, 34.0 / 255.0, 51.0 / 255.0),
  )
  assert_eq(read("#ff0000").components(), (1.0, 0.0, 0.0))
  assert_eq(read("#FF0000").components(), (1.0, 0.0, 0.0))
  assert_eq(read("#12345678").alpha, 120.0 / 255.0)
  assert_eq(read("#f008").alpha, 8.0 / 15.0)
  assert_eq(read("#0000").alpha, 0.0)
  // Every length that is not 3, 4, 6 or 8 is not a colour.
  for
    text in [
      "#", "#f", "#ff", "#fffff", "#fffffff", "#fffffffff", "#ggg", "#12g",
    ] {
    assert_true(@moonrgba.Color::decode_opt(text) is None, msg=text)
  }
}

///|
test "the keywords" {
  assert_eq(read("transparent").alpha, 0.0)
  assert_eq(read("TRANSPARENT").alpha, 0.0)
  assert_true(read("currentColor").is_current())
  assert_true(read("currentcolor").is_current())
  assert_eq(read("red").components(), (1.0, 0.0, 0.0))
  assert_eq(read("ReD").components(), (1.0, 0.0, 0.0))
  assert_eq(
    read("rebeccapurple").components(),
    (102.0 / 255.0, 51.0 / 255.0, 153.0 / 255.0),
  )
}

///|
/// The two syntaxes take different arguments, and `rgb()` accepts either. Which
/// one is being read is decided by the first separator, and the rules of that one
/// apply to everything after it.
test "the legacy and modern argument lists" {
  // Legacy: commas, three channels of the same kind, and an optional alpha.
  assert_eq(
    read("rgb(1, 2, 3)").components(),
    (1.0 / 255.0, 2.0 / 255.0, 3.0 / 255.0),
  )
  assert_eq(read("rgba(1, 2, 3, 0.5)").alpha, 0.5)
  assert_eq(read("rgb(10%, 20%, 30%)").components(), (0.1, 0.2, 0.3))
  assert_eq(read("rgba(10%, 20%, 30%, 50%)").alpha, 0.5)
  // Modern: spaces, mixing numbers and percentages, `none`, and a slash.
  assert_eq(
    read("rgb(1 2 3)").components(),
    (1.0 / 255.0, 2.0 / 255.0, 3.0 / 255.0),
  )
  assert_eq(read("rgb(1 2 3 / 0.5)").alpha, 0.5)
  assert_eq(read("rgb(10% 20 30%)").components(), (0.1, 20.0 / 255.0, 0.3))
  assert_true(read("rgb(none 0 0)").x.is_nan())
  assert_true(read("rgb(0 0 0 / none)").alpha.is_nan())
}

///|
test "the legacy list refuses what the modern one allows" {
  // Mixing numbers and percentages was never valid in the comma syntax, and a
  // reader that allowed it would have to guess what the percentages meant.
  for
    text in [
      "rgb(10%, 50%, 0)", "rgb(0, 0 0)", "rgb(0, 0, 0,)", "rgb(, 0, 0)", "rgb(0, 0, 0deg)",
      "rgb(0, 0, light)", "rgb()", "rgb(0, 0)", "rgb(none, none, none)", "rgb(255, 255, 255, none)",
    ] {
    assert_true(@moonrgba.Color::decode_opt(text) is None, msg=text)
  }
}

///|
test "angles are degrees, or a unit that says otherwise" {
  let expected = (210.0, 0.5, 0.4)
  for text in ["hsl(210 50% 40%)", "hsl(210deg 50% 40%)", "hsl(210.0 50% 40%)"] {
    assert_true(near_components(read(text), expected, 1.0e-12), msg=text)
  }
  // A bare number for saturation or lightness means the same as the percentage:
  // `hsl(120 30 50)` is `hsl(120 30% 50%)`, not thirty times as saturated.
  assert_true(near_components(read("hsl(210 50 40)"), expected, 1.0e-12))
  // A third of a turn, a radian's worth and 400 gradians are all one angle.
  assert_true(
    near(read("hsl(0.3333333333333333turn 50% 40%)").hue(), 120.0, 1.0e-9),
  )
  assert_true(
    near(read("hsl(2.0943951023931953rad 50% 40%)").hue(), 120.0, 1.0e-9),
  )
  assert_true(
    near(read("hsl(133.33333333333333grad 50% 40%)").hue(), 120.0, 1.0e-9),
  )
  // Hues wrap into 0–360 rather than being kept as written.
  assert_true(near(read("hsl(-90 50% 40%)").hue(), 270.0, 1.0e-12))
  assert_true(near(read("hsl(450 50% 40%)").hue(), 90.0, 1.0e-12))
}

///|
test "saturation and lightness are clamped, and later wrap into gamut" {
  assert_eq(read("hsl(0 150% 50%)").y, 1.0)
  assert_eq(read("hsl(0 -50% 50%)").y, 0.0)
  assert_eq(read("hsl(0 50% 150%)").z, 1.0)
  assert_eq(read("rgb(300 0 0)").x, 1.0)
  assert_eq(read("rgb(-10 0 0)").x, 0.0)
  assert_eq(read("rgba(0, 0, 0, 5)").alpha, 1.0)
  assert_eq(read("rgba(0, 0, 0, -1)").alpha, 0.0)
}

///|
test "hwb takes percentages whether or not they are written" {
  assert_true(
    near_components(read("hwb(120 20% 30%)"), (120.0, 0.2, 0.3), 1.0e-12),
  )
  assert_true(
    near_components(read("hwb(120 20 30)"), (120.0, 0.2, 0.3), 1.0e-12),
  )
  // Whiteness and blackness that add to more than one are a grey, and the grey
  // is their ratio.
  assert_true(
    near_components(
      read("hwb(0 100% 50%)").to_srgb(),
      (170.0 / 255.0, 170.0 / 255.0, 170.0 / 255.0),
      1.0e-9,
    ),
  )
}

///|
test "percentages mean different things in lab and oklab" {
  // 50% of lightness is 50 in lab and 0.5 in oklab; 50% of `a` is 62.5 in lab
  // and 0.2 in oklab, because the two scales are different.
  let lab = read("lab(50% 50% -20%)")
  assert_true(near_components(lab, (50.0, 62.5, -25.0), 1.0e-12))
  let oklab = read("oklab(50% 50% -50%)")
  assert_true(near_components(oklab, (0.5, 0.2, -0.2), 1.0e-12))
  let lch = read("lch(50% 50% 20)")
  assert_true(near_components(lch, (50.0, 75.0, 20.0), 1.0e-12))
  let oklch = read("oklch(50% 50% 20)")
  assert_true(near_components(oklch, (0.5, 0.2, 20.0), 1.0e-12))
  // Lightness is clamped to its own range, and chroma cannot be negative.
  assert_eq(read("lab(400 0 0)").x, 100.0)
  assert_eq(read("oklab(4 0 0)").x, 1.0)
  assert_eq(read("lch(50 -20 0)").y, 0.0)
}

///|
test "color() takes every space it names, and xyz means xyz-d65" {
  let p3 = read("color(display-p3 0.5 0.25 0.125)")
  assert_eq(p3.space, @moonrgba.Space::DisplayP3)
  assert_eq(p3.components(), (0.5, 0.25, 0.125))
  assert_eq(read("color(xyz 0.1 0.2 0.3)").space, @moonrgba.Space::XyzD65)
  assert_eq(read("color(xyz-d50 0.1 0.2 0.3)").space, @moonrgba.Space::XyzD50)
  // Percentages are fractions of one here, and nothing is clamped: a wide-gamut
  // space may hold a colour outside itself.
  assert_eq(read("color(srgb 20% 0 10)").components(), (0.2, 0.0, 10.0))
  assert_eq(
    read("color(srgb 200 -200 0 / 50%)").components(),
    (200.0, -200.0, 0.0),
  )
  assert_eq(read("color(srgb 0 0 0 / 50%)").alpha, 0.5)
  // A space `color()` cannot name is not a colour.
  for text in ["color(hsl 0 0 0)", "color(nonsense 0 0 0)", "color(srgb)"] {
    assert_true(@moonrgba.Color::decode_opt(text) is None, msg=text)
  }
}

///|
/// CSS strips comments before it reads a value, so a comment may sit anywhere
/// whitespace may, including inside a number's place.
test "comments count as whitespace" {
  assert_eq(read("/**/#f00").components(), (1.0, 0.0, 0.0))
  assert_eq(read("#f00/**/").components(), (1.0, 0.0, 0.0))
  assert_eq(
    read("rgb(/**/1 2 3/**/)").components(),
    (1.0 / 255.0, 2.0 / 255.0, 3.0 / 255.0),
  )
  assert_eq(read("  \t\n red \n").components(), (1.0, 0.0, 0.0))
}

///|
/// An error says where it happened and what it found, because a caller reading a
/// theme file has to be able to point at the line.
test "a refusal says where and what" {
  match refusal_of("rgb(1 2)") {
    Unexpected(at~, want~, ..) => {
      // The third argument was never there, so the parser stopped at the closing
      // bracket and asked for a number.
      assert_eq(at, 7)
      assert_eq(want, "a number")
    }
    other => abort("expected a syntax error, got \{other}")
  }
  // An unknown name is a different kind of refusal from a malformed one, and a
  // caller can tell them apart without looking at the message.
  match refusal_of("notacolour") {
    Unknown(at~, got~) => {
      assert_eq(at, 0)
      assert_eq(got, "notacolour")
    }
    other => abort("expected an unknown name, got \{other}")
  }
}

///|
/// Functions this library does not implement are refused as unknown rather than
/// guessed at: a value that needs a cascade to resolve is not a value.
test "a function that needs a cascade is not a colour" {
  for
    text in [
      "color-mix(in oklab, red, blue)", "light-dark(white, black)", "rgb(from red r g b)",
      "device-cmyk(0 0 0 1)", "var(--colour)", "Canvas", "ButtonText",
    ] {
    assert_true(@moonrgba.Color::decode_opt(text) is None, msg=text)
  }
}

///|
test "an empty string is not a colour" {
  assert_true(@moonrgba.Color::decode_opt("") is None)
  assert_true(@moonrgba.Color::decode_opt("   ") is None)
  assert_true(@moonrgba.Color::decode_opt("#f00 #0f0") is None)
}
