// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A theme from one seed colour: a scale, a second series mixed from the first,
/// text colours picked by contrast, and the same palette for a terminal.
///
/// This is the shape a theme generator has — one colour in, a hundred out — and
/// each step is one of the operations this library exists for.
fn main raise {
  let seed = @moonrgba.Color::decode("#0891b2")
  let accent = @moonrgba.Color::decode("#f59e0b")
  let background = seed.mix(
    @moonrgba.Color::white(),
    space=@moonrgba.Space::Oklch,
    weight=0.94,
  )
  let surface = seed.mix(
    @moonrgba.Color::white(),
    space=@moonrgba.Space::Oklch,
    weight=0.88,
  )
  let ink = seed.mix(
    @moonrgba.Color::black(),
    space=@moonrgba.Space::Oklch,
    weight=0.2,
  )

  println("/* the seed colours */")
  println("--brand:      " + seed.encode())
  println("--accent:     " + accent.encode())
  println("")

  // A scale: the seed's hue and chroma at ten lightnesses, each one brought into
  // sRGB. The two ends leave the gamut first, which is why `to_gamut` is here:
  // written as hexadecimal without it, the dark end would clip and lose its hue.
  println("/* --brand-0 is the lightest, --brand-9 the darkest */")
  for step in 0..<10 {
    let lightness = 0.95 - 0.09 * step.to_double()
    let base = seed.to_oklch()
    let color = base.with_components(lightness, base.y, base.z)
    let color = color.to_gamut(space=@moonrgba.Space::Srgb)
    println(
      "--brand-" +
      step.to_string() +
      ": " +
      color.encode(format=@moonrgba.Format::Hex) +
      "  " +
      describe(color),
    )
  }
  println("")

  // A second series halfway between the two brand colours, which is what a chart
  // needs when it has four series and two brand colours.
  // A weight is how much of the first colour the mix has, so these two are the
  // same pair of colours pulled towards each other. Halfway between two hues
  // this far apart is grey — mixing in Oklab keeps a mix *useful* by keeping it
  // even, not by inventing a hue that neither colour had.
  println("/* the brand pulled towards the accent, and back the other way */")
  let toward_accent = seed.mix(
    accent,
    space=@moonrgba.Space::Oklab,
    weight=0.75,
  )
  let toward_brand = seed.mix(accent, space=@moonrgba.Space::Oklab, weight=0.25)
  println(
    "--blend:      " +
    hex_of(toward_accent) +
    "  /* " +
    toward_accent.encode() +
    " */",
  )
  println(
    "--blend-soft: " +
    hex_of(toward_brand) +
    "  /* " +
    toward_brand.encode() +
    " */",
  )
  println("")

  // Text on each background: whichever of black and white reads better, then
  // nudged towards the background so that it is not pure contrast.
  println("/* text on a background, by WCAG 2 contrast */")
  for
    pair in [("background", background), ("surface", surface), ("brand", seed)] {
    let (label, color) = pair
    let on_white = @moonrgba.Color::white().contrast(color)
    let on_black = @moonrgba.Color::black().contrast(color)
    let (chosen, ratio) = if on_black >= on_white {
      (ink, on_black)
    } else {
      (
        color.mix(
          @moonrgba.Color::white(),
          space=@moonrgba.Space::Oklch,
          weight=0.06,
        ),
        on_white,
      )
    }
    println(
      "--on-" +
      pad(label, 11) +
      hex_of(chosen) +
      "  /* " +
      round_ratio(ratio) +
      " */",
    )
  }
  println("")

  // The same palette for a terminal that has sixteen colours and no more.
  println("/* the terminal's palette, nearest slot by OK colour difference */")
  println(
    "--ansi-brand:  " +
    seed.to_ansi16().to_string() +
    " (" +
    seed.to_ansi256().to_string() +
    " in 256)",
  )
  println(
    "--ansi-accent: " +
    accent.to_ansi16().to_string() +
    " (" +
    accent.to_ansi256().to_string() +
    " in 256)",
  )
  let (r, g, b) = seed.rgb8()
  println(
    "--ansi-true:   " +
    r.to_string() +
    ";" +
    g.to_string() +
    ";" +
    b.to_string(),
  )
}

///|
/// The colour as a theme file would carry it: sRGB, in a byte per channel, with
/// the gamut mapping in front so that a colour from a wider space arrives here
/// as something a screen can show rather than as a clipped version of itself.
fn hex_of(color : @moonrgba.Color) -> String {
  color
  .to_gamut(space=@moonrgba.Space::Srgb)
  .encode(format=@moonrgba.Format::Hex)
}

///|
/// What a person would call the colour, for a comment beside the value.
fn describe(color : @moonrgba.Color) -> String {
  let oklch = color.to_oklch()
  let chroma = if oklch.y < 0.02 {
    "grey"
  } else if oklch.z < 45.0 || oklch.z >= 345.0 {
    "red"
  } else if oklch.z < 90.0 {
    "orange"
  } else if oklch.z < 150.0 {
    "yellow"
  } else if oklch.z < 200.0 {
    "green"
  } else if oklch.z < 260.0 {
    "cyan"
  } else if oklch.z < 300.0 {
    "blue"
  } else {
    "purple"
  }
  "/* " + chroma + ", L " + round_two(oklch.x * 100.0) + " */"
}

///|
fn round_two(value : Double) -> String {
  let hundredths = 0.01
  let scaled = value / hundredths
  let rounded = if scaled >= 0.0 { scaled + 0.5 } else { scaled - 0.5 }
  (rounded.to_int().to_double() * hundredths).to_string()
}

///|
fn round_ratio(value : Double) -> String {
  round_two_hundredths(value) + ":1"
}

///|
fn round_two_hundredths(value : Double) -> String {
  let scaled = value * 100.0
  let rounded = if scaled >= 0.0 { scaled + 0.5 } else { scaled - 0.5 }
  let whole = rounded.to_int()
  (whole / 100).to_string() + "." + pad((whole % 100).to_string(), 2)
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
