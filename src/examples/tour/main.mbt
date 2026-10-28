// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One colour, followed from the text that spells it to the numbers a terminal
/// can send, through every space this library converts between.
fn main {
  let text = "#0891b2"
  let color = match @moonrgba.Color::decode_opt(text) {
    Some(color) => color
    None => {
      println("not a colour: " + text)
      return
    }
  }
  println("read        " + text)
  println("as oklch    " + color.encode(format=@moonrgba.Format::Oklch))
  println("writes      " + color.encode())
  println("hex         " + color.encode(format=@moonrgba.Format::Hex))
  println("name        " + color.encode(format=@moonrgba.Format::Named))
  println("")

  // Every space, in the order a palette usually goes.
  let spaces : Array[@moonrgba.Space] = [
    @moonrgba.Space::Srgb,
    @moonrgba.Space::SrgbLinear,
    @moonrgba.Space::Hsl,
    @moonrgba.Space::Hsv,
    @moonrgba.Space::Hwb,
    @moonrgba.Space::Lab,
    @moonrgba.Space::Lch,
    @moonrgba.Space::Oklab,
    @moonrgba.Space::Oklch,
    @moonrgba.Space::XyzD65,
    @moonrgba.Space::XyzD50,
    @moonrgba.Space::DisplayP3,
    @moonrgba.Space::Rec2020,
    @moonrgba.Space::A98Rgb,
    @moonrgba.Space::ProPhoto,
    @moonrgba.Space::YCbCr(@moonrgba.Luma::Bt709),
  ]
  for space in spaces {
    println(pad(space.code(), 14) + color.to_space(space).encode())
  }
  // HSV and YCbCr are spaces without a CSS syntax, so the two rows above are
  // sRGB: writing them under their own names would produce a string no reader
  // accepts.
  println("")

  // The same colour on a wider display: outside sRGB, so it needs a decision.
  let p3 = @moonrgba.Color::display_p3(0.0, 0.8, 0.7)
  println("display-p3  " + p3.encode())
  println("in sRGB?    " + p3.in_gamut(space=@moonrgba.Space::Srgb).to_string())
  println("clipped     " + p3.clip(space=@moonrgba.Space::Srgb).encode())
  println("mapped      " + p3.to_gamut(space=@moonrgba.Space::Srgb).encode())
  println("")

  // Contrast against white and black, under both measures.
  let white = @moonrgba.Color::white()
  let black = @moonrgba.Color::black()
  println(
    "on white    WCAG " +
    round(color.contrast(white)) +
    "  APCA " +
    round(color.apca(white)),
  )
  println(
    "on black    WCAG " +
    round(color.contrast(black)) +
    "  APCA " +
    round(color.apca(black)),
  )
  println("")

  // How far apart two colours are, under each measure.
  let other = @moonrgba.Color::rgb(200, 90, 120)
  println("against     " + other.encode())
  for
    measure in [
      @moonrgba.Delta::E76,
      @moonrgba.Delta::E94,
      @moonrgba.Delta::E2000,
      @moonrgba.Delta::Ok,
    ] {
    println(pad("\{measure}", 10) + round(color.delta_e(other, delta=measure)))
  }
  println("")

  // The terminal: the nearest slot in each palette.
  let slot = color.to_ansi256()
  println("ansi 256    " + slot.to_string() + "  " + slot.color().encode())
  println("ansi 16     " + color.to_ansi16().to_string())
  let (r, g, b) = color.rgb8()
  println(
    "true colour " + r.to_string() + ", " + g.to_string() + ", " + b.to_string(),
  )
}

///|
/// A number as a person reads it rather than as a machine prints it.
fn round(value : Double) -> String {
  let text = (@math.round(value * 100.0) / 100.0).to_string()
  text
}

///|
fn pad(text : String, width : Int32) -> String {
  if text.length() >= width {
    return text
  }
  let out = StringBuilder()
  out.write_string(text)
  for _ in 0..<(width - text.length()) {
    out.write_char(' ')
  }
  out.to_string()
}
