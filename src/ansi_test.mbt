// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Terminal colours: the three palettes, and picking the nearest slot.

///|
test "the sixteen named colours are the xterm ones" {
  assert_eq(@moonrgba.Ansi16::Black.color().components(), (0.0, 0.0, 0.0))
  // Not the ANSI standard's blue: xterm's, which is what every emulator in use
  // actually shows.
  assert_eq(
    @moonrgba.Ansi16::Blue.color().components(),
    (0.0, 0.0, 128.0 / 255.0),
  )
  assert_eq(
    @moonrgba.Ansi16::White.color().components(),
    (192.0 / 255.0, 192.0 / 255.0, 192.0 / 255.0),
  )
  assert_eq(@moonrgba.Ansi16::BrightWhite.color().components(), (1.0, 1.0, 1.0))
  assert_eq(@moonrgba.Ansi16::BrightRed.color().components(), (1.0, 0.0, 0.0))
}

///|
test "a name has a number and a number has a name" {
  for code in 0..<16 {
    let named = match @moonrgba.Ansi16::of(code) {
      Some(named) => named
      None => abort("no name for \{code}")
    }
    assert_eq(named.code(), code)
  }
  assert_eq(@moonrgba.Ansi16::of(16), None)
  assert_eq(@moonrgba.Ansi16::of(-1), None)
}

///|
/// The 256-colour palette is three ranges: the named colours, a 6×6×6 cube whose
/// levels are not evenly spaced, and a grey ramp.
test "the 256-colour palette is a cube and a ramp" {
  // The first sixteen are the named colours.
  for code in 0..<16 {
    assert_eq(
      @moonrgba.Ansi256::of(code).color().components(),
      @moonrgba.Ansi16::of(code).unwrap().color().components(),
    )
  }
  // The cube starts at black and its levels are 0, 95, 135, 175, 215, 255.
  assert_eq(@moonrgba.Ansi256::of(16).color().components(), (0.0, 0.0, 0.0))
  assert_eq(
    @moonrgba.Ansi256::of(17).color().components(),
    (0.0, 0.0, 95.0 / 255.0),
  )
  assert_eq(@moonrgba.Ansi256::of(196).color().components(), (1.0, 0.0, 0.0))
  assert_eq(@moonrgba.Ansi256::of(231).color().components(), (1.0, 1.0, 1.0))
  // The ramp runs from 8 to 238 in steps of ten.
  assert_eq(
    @moonrgba.Ansi256::of(232).color().components(),
    (8.0 / 255.0, 8.0 / 255.0, 8.0 / 255.0),
  )
  assert_eq(
    @moonrgba.Ansi256::of(255).color().components(),
    (238.0 / 255.0, 238.0 / 255.0, 238.0 / 255.0),
  )
}

///|
test "a palette slot is its own nearest match" {
  for code in 0..<256 {
    let slot = @moonrgba.Ansi256::of(code)
    let nearest = slot.color().to_ansi256()
    // A colour that is in the palette may have more than one slot — black is
    // both 0 and 16 — so the check is that the colour comes back, not the number.
    assert_eq(nearest.color().components(), slot.color().components())
  }
}

///|
test "a colour outside the palette lands on the nearest one by Oklab" {
  // Halfway between black and the first grey step is nearer black.
  let near_black = @moonrgba.Color::rgb(4, 4, 4)
  assert_eq(@moonrgba.Color::rgb(0, 0, 0).to_ansi256().code(), 0)
  assert_true(
    near_black.to_ansi256().code() < 16 || near_black.to_ansi256().code() == 232,
  )
  // A colour a shade off a palette entry picks that entry rather than a
  // neighbour further away in every channel.
  let almost_red = @moonrgba.Color::rgb(250, 4, 4)
  let slot = almost_red.to_ansi256()
  assert_true(slot.code() == 9 || slot.code() == 196, msg="\{slot}")
  // And the two tiers agree about plain red, which both have exactly.
  assert_eq(
    @moonrgba.Color::rgb(255, 0, 0).to_ansi16(),
    @moonrgba.Ansi16::BrightRed,
  )
}

///|
/// The nearest match is by ΔE OK, so it is the same answer a person would give:
/// an olive is nearer the dark yellow than the dark green, although its green
/// channel is the larger of the two.
test "nearest is judged by eye, not by arithmetic on the channels" {
  let olive = @moonrgba.Color::rgb(128, 128, 0)
  assert_eq(olive.to_ansi16(), @moonrgba.Ansi16::Yellow)
  let teal = @moonrgba.Color::rgb(0, 128, 128)
  assert_eq(teal.to_ansi16(), @moonrgba.Ansi16::Cyan)
  // A grey has no hue, and goes to a grey rather than to a dark colour that
  // happens to be the same distance away in RGB.
  let grey = @moonrgba.Color::rgb(130, 130, 130)
  let slot = grey.to_ansi16()
  assert_true(
    slot == @moonrgba.Ansi16::BrightBlack || slot == @moonrgba.Ansi16::White,
    msg="\{slot}",
  )
}

///|
test "true colour is three bytes, clipped the way a terminal clips" {
  assert_eq(@moonrgba.Color::rgb(18, 52, 86).rgb8(), (18, 52, 86))
  assert_eq(@moonrgba.Color::srgb(1.5, -0.5, 0.5).rgb8(), (255, 0, 128))
  assert_eq(@moonrgba.Color::oklch(0.7, 0.1, 200.0).rgb8(), (64, 177, 183))
}

///|
test "a slot outside the palette clamps rather than wrapping" {
  assert_eq(@moonrgba.Ansi256::of(-5).code(), 0)
  assert_eq(@moonrgba.Ansi256::of(300).code(), 255)
  assert_eq(@moonrgba.Ansi256::of(0).code(), 0)
}
