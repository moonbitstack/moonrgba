// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Writing a colour: the shortest spelling, and the one each format asks for.

///|
/// Reading the text back must give the same colour, which is the property that
/// makes every other claim about the writer meaningful.
fn round_trips(color : @moonrgba.Color, format : @moonrgba.Format) -> Bool {
  let text = color.encode(format~)
  match @moonrgba.Color::decode_opt(text) {
    Some(again) => {
      // Compared where it was written: the writer rounds to five decimals of
      // that space, and converting back would magnify the rounding wherever the
      // transfer curve is steep.
      let same = near_same_space(again, color.to_space(again.space), 2.0e-5)
      same && near(again.alpha, color.alpha, 1.0e-9)
    }
    None => false
  }
}

///|
test "hexadecimal is as short as it can be and no shorter" {
  assert_eq(@moonrgba.Color::rgb(255, 0, 0).encode(), "#f00")
  assert_eq(@moonrgba.Color::rgb(255, 255, 255).encode(), "#fff")
  assert_eq(@moonrgba.Color::rgb(1, 2, 3).encode(), "#010203")
  assert_eq(@moonrgba.Color::rgb(17, 34, 51).encode(), "#123")
  // A short form is only exact when every channel repeats its digit.
  assert_eq(@moonrgba.Color::rgb(17, 34, 52).encode(), "#112234")
  assert_eq(@moonrgba.Color::rgb(255, 0, 0, alpha=1.0).encode(), "#f00")
  assert_eq(@moonrgba.Color::rgb(0, 0, 0, alpha=0.0).encode(), "#0000")
  assert_eq(@moonrgba.Color::rgb(255, 0, 0, alpha=8.0 / 15.0).encode(), "#f008")
}

///|
/// A channel that is not a whole byte has no exact hexadecimal spelling, so the
/// writer uses `rgb()` rather than rounding the colour away.
test "fractions go out as rgb() rather than as a rounded byte" {
  let color = @moonrgba.Color::srgb(0.5, 0.25, 0.125)
  assert_eq(color.encode(), "rgb(127.5 63.75 31.875)")
  // The forced form is lossy, and that is the caller's decision to make.
  assert_eq(color.encode(format=Hex), "#804020")
}

///|
test "alpha is written only when it is not one" {
  assert_eq(@moonrgba.Color::srgb(0.2, 0.4, 0.6).encode(), "#369")
  assert_eq(
    @moonrgba.Color::srgb(0.21, 0.42, 0.63).encode(),
    "rgb(53.55 107.1 160.65)",
  )
  assert_eq(
    @moonrgba.Color::srgb(0.2, 0.4, 0.6, alpha=0.5).encode(),
    "rgb(51 102 153 / 0.5)",
  )
  assert_eq(@moonrgba.Color::hsl(120.0, 0.5, 0.5).encode(), "hsl(120 50% 50%)")
  assert_eq(
    @moonrgba.Color::hsl(120.0, 0.5, 0.5, alpha=0.25).encode(),
    "hsl(120 50% 50% / 0.25)",
  )
}

///|
test "each format writes the syntax it names" {
  let color = @moonrgba.Color::srgb(0.2, 0.4, 0.6, alpha=0.5)
  assert_eq(color.encode(format=Rgb), "rgb(51 102 153 / 0.5)")
  assert_eq(color.encode(format=Hex), "#33669980")
  assert_eq(color.encode(format=Hsl), "hsl(210 50% 40% / 0.5)")
  assert_eq(color.encode(format=Hwb), "hwb(210 20% 40% / 0.5)")
  assert_eq(color.encode(format=Lab), "lab(41.52082 -4.57309 -33.49419 / 0.5)")
  assert_eq(
    color.encode(format=Oklch),
    "oklch(0.49931 0.09866 250.43306 / 0.5)",
  )
  assert_eq(color.encode(format=Color), "color(srgb 0.2 0.4 0.6 / 0.5)")
  assert_eq(color.encode(format=Named), "#33669980")
}

///|
/// A named colour is written as its name only when it has one and the name is
/// asked for: a theme file reads better with names, a computed value with hex.
test "the named format falls back to hex" {
  assert_eq(@moonrgba.Color::rgb(255, 0, 0).encode(format=Named), "red")
  assert_eq(@moonrgba.Color::rgb(255, 0, 0).encode(format=Hex), "#f00")
  assert_eq(@moonrgba.Color::rgb(1, 2, 3).encode(format=Named), "#010203")
}

///|
test "a colour in a wide space stays in it" {
  let p3 = @moonrgba.Color::display_p3(0.5, 0.2, 0.1)
  assert_eq(p3.encode(), "color(display-p3 0.5 0.2 0.1)")
  let xyz = @moonrgba.Color::xyz_d65(0.2, 0.3, 0.4)
  assert_eq(xyz.encode(), "color(xyz-d65 0.2 0.3 0.4)")
  let oklch = @moonrgba.Color::oklch(0.7, 0.4, 30.0)
  assert_eq(oklch.encode(), "oklch(0.7 0.4 30)")
}

///|
/// sRGB has no syntax that can hold a component outside 0–1: `rgb()` would clamp
/// it and a byte would round it. `color(srgb ...)` can, so a colour that is
/// outside its own gamut goes out that way rather than losing the value.
test "an out-of-gamut sRGB colour keeps its value" {
  let wide = @moonrgba.Color::srgb(1.2, -0.1, 0.5)
  assert_eq(wide.encode(), "color(srgb 1.2 -0.1 0.5)")
  // Forcing `rgb()` clips, which is what that syntax does.
  assert_eq(wide.encode(format=Rgb), "rgb(255 0 127.5)")
}

///|
/// HSL, HWB and the Lab family are bounded by their own syntax, so their writers
/// clamp; `color()` and the polar spaces are not, and theirs do not.
test "the bounded syntaxes clamp and the unbounded ones do not" {
  assert_eq(@moonrgba.Color::hsl(120.0, 2.0, -1.0).encode(), "hsl(120 100% 0%)")
  assert_eq(@moonrgba.Color::hwb(120.0, 2.0, -1.0).encode(), "hwb(120 100% 0%)")
  assert_eq(
    @moonrgba.Color::oklch(1.5, -0.1, 400.0).encode(),
    "oklch(1.5 -0.1 400)",
  )
}

///|
/// HSV and YCbCr are spaces CSS never named. Writing them as those names would
/// produce a string no reader accepts, so they go out as sRGB.
test "spaces with no CSS syntax are written as sRGB" {
  let hsv = @moonrgba.Color::hsv(0.0, 1.0, 1.0)
  assert_eq(hsv.encode(), "#f00")
  let ycbcr = @moonrgba.Color::ycbcr(0.5, 0.0, 0.0)
  assert_eq(ycbcr.encode(), "rgb(127.5 127.5 127.5)")
}

///|
test "a missing component is written as none" {
  let color = @moonrgba.Color::oklch(@double.not_a_number, 0.1, 20.0)
  assert_eq(color.encode(), "oklch(none 0.1 20)")
  let hsl = @moonrgba.Color::hsl(
    @double.not_a_number, @double.not_a_number, 0.5,
  )
  assert_eq(hsl.encode(), "hsl(none none 50%)")
  assert_eq(hsl.encode(format=Rgb), "rgb(127.5 127.5 127.5)")
  let faded = @moonrgba.Color::srgb(0.2, 0.4, 0.6, alpha=@double.not_a_number)
  assert_eq(faded.encode(), "rgb(51 102 153 / none)")
}

///|
test "currentcolor is not written as a colour, whatever the format" {
  for
    format in [
      @moonrgba.Format::Shortest,
      @moonrgba.Format::Hex,
      @moonrgba.Format::Rgb,
      @moonrgba.Format::Hsl,
      @moonrgba.Format::Lab,
      @moonrgba.Format::Color,
      @moonrgba.Format::Named,
    ] {
    assert_eq(@moonrgba.Color::current().encode(format~), "currentcolor")
  }
}

///|
/// The space a format writes in, which decides whether it can hold the colour at
/// all: the sRGB syntaxes clamp, and a colour outside sRGB would lose its
/// components on the way out.
fn format_space(
  color : @moonrgba.Color,
  format : @moonrgba.Format,
) -> @moonrgba.Space {
  match format {
    @moonrgba.Format::Hex
    | @moonrgba.Format::Rgb
    | @moonrgba.Format::Hsl
    | @moonrgba.Format::Hwb => @moonrgba.Space::Srgb
    @moonrgba.Format::Lab => @moonrgba.Space::Lab
    @moonrgba.Format::Lch => @moonrgba.Space::Lch
    @moonrgba.Format::Oklab => @moonrgba.Space::Oklab
    @moonrgba.Format::Oklch => @moonrgba.Space::Oklch
    _ => color.space
  }
}

///|
/// Every colour that comes from a syntax survives being written and read back,
/// which is the property the whole writer exists for.
///
/// A format whose space cannot hold the colour is skipped: `rgb()` clamps by
/// definition, and a test that asked it not to would be asking for the wrong
/// thing.
test "what is written reads back as the same colour" {
  let samples = [
    @moonrgba.Color::rgb(255, 0, 0),
    @moonrgba.Color::rgb(1, 2, 3),
    @moonrgba.Color::srgb(0.2, 0.4, 0.6, alpha=0.5),
    @moonrgba.Color::hsl(210.0, 0.5, 0.4),
    @moonrgba.Color::hwb(120.0, 0.2, 0.3),
    @moonrgba.Color::lab(50.0, 20.0, -30.0),
    @moonrgba.Color::lch(50.0, 36.0, 300.0),
    @moonrgba.Color::oklab(0.5, 0.1, -0.05),
    @moonrgba.Color::oklch(0.7, 0.15, 200.0),
    @moonrgba.Color::display_p3(0.5, 0.2, 0.1),
    @moonrgba.Color::rec2020(0.3, 0.6, 0.2),
    @moonrgba.Color::xyz_d50(0.2, 0.3, 0.4),
  ]
  for color in samples {
    for
      format in [
        @moonrgba.Format::Shortest,
        @moonrgba.Format::Rgb,
        @moonrgba.Format::Hsl,
        @moonrgba.Format::Hwb,
        @moonrgba.Format::Lab,
        @moonrgba.Format::Lch,
        @moonrgba.Format::Oklab,
        @moonrgba.Format::Oklch,
        @moonrgba.Format::Color,
      ] {
      if !color.in_gamut(space=format_space(color, format)) {
        continue
      }
      assert_true(
        round_trips(color, format),
        msg="\{color.space.code()} as \{format} gave \{color.encode(format~)}",
      )
    }
  }
}

///|
/// `Show` is the shortest CSS, so a colour logged or formatted in a message is
/// something a browser would accept.
test "Show writes CSS" {
  let color = @moonrgba.Color::rgb(255, 0, 0)
  assert_eq(color.to_string(), "#f00")
  assert_eq("\{color}", "#f00")
  assert_eq(
    @moonrgba.Color::oklch(0.7, 0.1, 200.0).to_string(),
    "oklch(0.7 0.1 200)",
  )
}

///|
/// Rounding to five places must not leave a trailing zero or a negative zero
/// behind: both are legal CSS and both read as a mistake.
test "numbers are written plainly" {
  assert_eq(
    @moonrgba.Color::oklab(0.5, 0.10000000000000001, 0.0).encode(),
    "oklab(0.5 0.1 0)",
  )
  assert_eq(
    @moonrgba.Color::oklab(1.0 / 3.0, 0.0, 0.0).encode(),
    "oklab(0.33333 0 0)",
  )
  assert_eq(
    @moonrgba.Color::lab(50.0, -0.0, -0.0000001).encode(),
    "lab(50 0 0)",
  )
}
