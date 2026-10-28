// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The guide, as a program.
//
// Each chapter prints, in order, the value of each expression printed in
// `docs/guide.html`, so that the listings on the page and what they say cannot
// part company: `scripts/guide.py` runs this file and writes the transcript
// into the page. Nothing here is a demonstration of something the library
// cannot do — every line is the shortest way to do it.

///|
fn chapter(name : String) -> Unit {
  println("@@\{name}")
}

///|
fn main raise {
  chapter("read")
  let brand = @moonrgba.Color::decode("#0891b2")
  println(brand.encode())
  println(@moonrgba.Color::decode("rgb(10 20 30 / 50%)").encode())
  println(@moonrgba.Color::decode("rebeccapurple").encode())
  println(@moonrgba.Color::decode("hsl(190deg 91% 36%)").encode())

  chapter("spaces")
  println(brand.to_oklch().encode())
  println(brand.to_display_p3().encode())
  println(brand.to_xyz_d65().encode())
  let (r, g, b) = brand.to_srgb().components()
  println("\{r}, \{g}, \{b}")
  println(brand.to_cmyk().k)

  chapter("construct")
  println(@moonrgba.Color::rgb(8, 145, 178).encode())
  println(@moonrgba.Color::hsl(190.0, 0.91, 0.36).encode())
  println(@moonrgba.Color::oklch(0.6, 0.11, 222.0).encode())
  println(@moonrgba.Color::rgb(8, 145, 178, alpha=0.4).encode())

  chapter("gamut")
  let wide = @moonrgba.Color::oklch(0.7, 0.4, 30.0)
  println(wide.in_gamut(space=@moonrgba.Space::Srgb))
  println(wide.clip(space=@moonrgba.Space::Srgb).encode())
  println(wide.to_gamut(space=@moonrgba.Space::Srgb).encode())
  println(wide.to_gamut(space=@moonrgba.Space::Srgb).to_oklch().encode())

  chapter("mix")
  println(
    brand.mix(@moonrgba.Color::white(), space=@moonrgba.Space::Oklch).encode(),
  )
  println(
    brand
    .mix(@moonrgba.Color::white(), space=@moonrgba.Space::Oklab, weight=0.25)
    .encode(),
  )
  let red = @moonrgba.Color::hsl(350.0, 1.0, 0.5)
  let orange = @moonrgba.Color::hsl(10.0, 1.0, 0.5)
  println(
    red
    .mix(orange, space=@moonrgba.Space::Hsl, hue=@moonrgba.Hue::Shorter)
    .hue(),
  )
  println(
    red.mix(orange, space=@moonrgba.Space::Hsl, hue=@moonrgba.Hue::Longer).hue(),
  )

  chapter("contrast")
  let paper = @moonrgba.Color::white()
  let ink = @moonrgba.Color::black()
  println(brand.contrast(paper))
  println(brand.apca(paper))
  println(paper.apca(ink))
  println(ink.apca(paper))
  println(brand.luminance())

  chapter("difference")
  let alarm = @moonrgba.Color::rgb(220, 38, 38)
  println(brand.delta_e(alarm, delta=@moonrgba.Delta::E76))
  println(brand.delta_e(alarm, delta=@moonrgba.Delta::E2000))
  println(brand.delta_e(alarm, delta=@moonrgba.Delta::Ok))

  chapter("adjust")
  println(brand.lighten(0.1).encode())
  println(brand.darken(0.1).encode())
  println(brand.saturate(0.2).encode())
  println(brand.fade(0.5).encode())

  chapter("names")
  println(@moonrgba.Color::of_name("RebeccaPurple").unwrap().encode())
  println(brand.name().unwrap_or("no name"))
  println(@moonrgba.Color::rgb(0, 128, 128).name().unwrap())
  println(@moonrgba.names_count())

  chapter("terminal")
  println(brand.to_ansi16().to_string())
  println(brand.to_ansi256().code())
  let (tr, tg, tb) = brand.rgb8()
  println("\{tr}, \{tg}, \{tb}")
  println(@moonrgba.Ansi256::of(196).color().encode())
  println(brand.to_ansi16().color().encode())

  chapter("none")
  let unpainted = @moonrgba.Color::decode("oklch(0.5 0.1 none)")
  println(unpainted.encode())
  println(unpainted.hue())
  println(
    unpainted
    .mix(@moonrgba.Color::oklch(0.8, 0.1, 20.0), space=@moonrgba.Space::Oklch)
    .encode(),
  )
  println(@moonrgba.Color::rgb(128, 128, 128).to_hsl().encode())

  chapter("errors")
  let problem : @moonrgba.Refused = try {
    ignore(@moonrgba.Color::decode("rgb(1 2)"))
    abort("unreachable")
  } catch {
    error => error
  }
  println(problem.to_string())
  match problem {
    @moonrgba.Unexpected(at~, got~, want~) =>
      println("at \{at}, found \{got}, wanted \{want}")
    @moonrgba.Unknown(at~, got~) => println("at \{at}, unknown \{got}")
  }
  println(
    match @moonrgba.Color::decode_opt("rgb(1 2)") {
      Some(_) => "read"
      None => "refused, as an option"
    },
  )
  println(
    match @moonrgba.Color::decode_opt("chucknorris") {
      Some(_) => "read"
      None => "refused, as an option"
    },
  )
}
