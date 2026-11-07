---
name: moonrgba
description: "Work with colour in MoonBit with moonbitstack/moonrgba: read and write every CSS Color 4 syntax, convert between sRGB, HSL, HWB, Display P3, Rec. 2020, Lab, LCh, Oklab, OkLCh, XYZ and YCbCr, bring a colour into a gamut, mix like color-mix(), measure WCAG and APCA contrast and ΔE, and pick the nearest ANSI 16 or 256 terminal colour. Use when parsing a theme or stylesheet colour, building a palette from one seed, checking text is readable, or colouring terminal output."
---

# moonrgba

```bash
moon add moonbitstack/moonrgba
```

```moonbit
// moon.pkg
import {
  "moonbitstack/moonrgba",
}
```

No I/O and no dependencies; every backend.

## Read, convert, write

```moonbit
let brand = @moonrgba.Color::decode("#0891b2")
assert_eq(brand.to_oklch().encode(), "oklch(0.60891 0.11094 221.72312)")
assert_eq(brand.encode(format=Rgb), "rgb(8 145 178)")
assert_eq(@moonrgba.Color::decode_opt("rgb(1 2)") is None, true)
```

`decode` raises `Refused` with the offset it stopped at; `decode_opt` answers `None`. `encode` writes the shortest spelling that reads back as the same colour, in the colour's own space unless a `Format` is given.

## Mix and fit

```moonbit
let brand = @moonrgba.Color::decode("#0891b2")
let tint = brand.mix(@moonrgba.Color::white(), space=Oklch, weight=0.3)
let wide = @moonrgba.Color::oklch(0.7, 0.4, 30.0)
assert_eq(wide.in_gamut(space=Srgb), false)
assert_eq(wide.to_gamut(space=Srgb).encode(), "rgb(255 88.00945 67.46665)")
ignore(tint)
```

Mix in `Oklch` or `Oklab` for even steps; `Srgb` is what older tools do. `to_gamut` lowers chroma the way CSS Color 4 asks; `clip` is cheaper and moves the hue.

## Contrast and terminals

```moonbit
let ink = @moonrgba.Color::black()
let paper = @moonrgba.Color::white()
assert_eq(ink.contrast(paper), 21.0)
assert_eq(@moonrgba.Color::decode("#0891b2").to_ansi256().code(), 31)
```

## Things that catch people out

- Conversions never clip: a colour outside sRGB keeps components below 0 or above 1 until you call `to_gamut` or `clip`.
- `contrast` is WCAG 2, 1 to 21 and symmetric; `apca` is signed, text colour first.
- `delta_e` measures are not comparable with each other: 2 is barely visible under `E2000` and obvious under `E76`.
- `to_ansi256` skips the sixteen named colours, because users re-theme them; pass `named=true` to allow them.
- A missing component (`none` in CSS) is a NaN, and `mix` fills it from the other colour.
