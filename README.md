# moonrgba

Colour for MoonBit: the syntax CSS writes a colour in, the spaces it can be
measured in, and the arithmetic a theme, a chart or a terminal needs to get from
one to the other.

No I/O, no dependencies, all four backends.

```moonbit
let brand = @moonrgba.Color::decode("#0891b2")
brand.to_oklch().encode()                                  // "oklch(0.60891 0.11094 221.72312)"
brand.mix(@moonrgba.Color::white(), space=@moonrgba.Space::Oklch).encode()
                                                           // "oklch(0.80446 0.05547 221.72312)"
brand.contrast(@moonrgba.Color::white())                   // 3.6820433648230324
brand.to_ansi256().code()                                  // 31
```

`moon run src/examples/tour` walks one colour through every space and every
measure; `moon run src/examples/theme` builds a theme from one seed colour.

## Reading and writing CSS

`Color::decode` reads one value — what would sit on the right of `color:` — and
`Color::encode` writes one back. Every syntax CSS Color 4 defines is read,
including both the comma and the space argument lists, `none` for a component
the author left out, and `currentcolor`.

```moonbit
@moonrgba.Color::decode("#123").encode()                   // "#123"
@moonrgba.Color::decode("rgb(10 20 30 / 50%)").encode()    // "rgb(10 20 30 / 0.5)"
@moonrgba.Color::decode("lab(50% 50% -20%)").encode()      // "lab(50 62.5 -25)"
@moonrgba.Color::decode("color(display-p3 .5 .2 .1)").encode()
                                                           // "color(display-p3 0.5 0.2 0.1)"
@moonrgba.Color::decode("currentcolor").encode()           // "currentcolor"
```

Writing is as short as it can be and still read back as the same colour: `#f00`
rather than `#ff0000`, no alpha when it is one, no `deg` on a hue, five decimals
where a channel is a fraction. When no spelling is both short and exact — a
channel of 127.5 has no hexadecimal form — the writer takes the longer one
instead of rounding the colour away.

A colour that cannot be read raises `Refused`, which says where it stopped and
what it wanted:

```moonbit
let refused : @moonrgba.Refused = try {
  ignore(@moonrgba.Color::decode("rgb(1 2)"))
  abort("unreachable")
} catch {
  error => error
}
println("\{refused}")    // at 7: got ), want a number
```

`Unexpected(at~, got~, want~)` is a syntax error and `Unknown(at~, got~)` a name
or function that is not a colour, so a caller reading a theme file can tell them
apart without reading the message. `decode_opt` is the same reader with the
refusal turned into `None`.

| Syntax | Read | Write | Written by `encode()` |
|:--|:--:|:--:|:--|
| `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa` | yes | yes | sRGB that is a whole byte per channel |
| `rgb()` `rgba()`, comma arguments | yes | — | the form belongs to an earlier grammar |
| `rgb()` `rgba()`, space arguments | yes | yes | sRGB that is not a whole byte per channel |
| `hsl()` `hsla()` | yes | yes | a colour written in HSL |
| `hwb()` | yes | yes | a colour written in HWB |
| `lab()`, `lch()` | yes | yes | a colour written in Lab or LCh |
| `oklab()`, `oklch()` | yes | yes | a colour written in Oklab or OkLCh |
| `color(...)` | yes | yes | a colour in one of the eight spaces it names |
| the 148 named colours | yes | with `Format::Named` | |
| `transparent` | yes | as `#0000` | |
| `currentcolor` | yes | yes | |

`encode` takes a `Format` when the caller wants a particular one — `Hex`, `Rgb`,
`Hsl`, `Hwb`, `Lab`, `Lch`, `Oklab`, `Oklch`, `Color`, `Named` — and converts
first if the colour is written in another space.

Not read: `calc()`, `var()`, `env()`, `attr()`, the relative colour syntax
(`rgb(from ...)`) and the system colours (`Canvas`, `ButtonText`). The first four
need a cascade before they are a colour, and the last takes its value from the
user's settings.

## Colour spaces

A colour is three components and an alpha, and the space says what the three
mean. `to_*` converts, and comes back total: a colour outside its space's gamut
keeps its value, and nothing is clipped behind the caller's back.

```moonbit
let hsl = @moonrgba.Color::hsl(210.0, 0.5, 0.4)
hsl.to_oklch().encode()      // "oklch(0.49931 0.09866 250.43306)"
hsl.to_srgb().components()   // (0.2, 0.4, 0.6)
```

| Space | Components | Reached through |
|:--|:--|:--|
| `Srgb` | red, green, blue 0–1 | the hub for the HSL family |
| `SrgbLinear` | red, green, blue 0–1 | D65 XYZ |
| `Hsl`, `Hsv`, `Hwb` | hue in degrees, then two fractions | sRGB |
| `DisplayP3`, `DisplayP3Linear`, `Rec2020`, `A98Rgb` | red, green, blue 0–1 | D65 XYZ, own matrix and curve |
| `ProPhoto` | red, green, blue 0–1 | D50 XYZ, then Bradford to D65 |
| `Lab`, `Lch` | lightness 0–100, then a and b or chroma and hue | D50 XYZ |
| `Oklab`, `Oklch` | lightness 0–1, then a and b or chroma and hue | D65 XYZ through LMS |
| `XyzD50`, `XyzD65` | X, Y, Z, Y = 1 for white | Bradford between the two |
| `YCbCr` | luma 0–1, chroma −0.5–0.5 | sRGB, with BT.601, BT.709 or BT.2020 coefficients |
| `Current` | — | the unresolved `currentcolor` keyword |

`YCbCr` keeps the coefficients it was written with, so `to_ycbcr(luma=Bt601)` and
`to_ycbcr(luma=Bt2020)` are different colours and not the same numbers.

CMYK is four inks in a type of its own, because four do not fit in three
components: `Color::to_cmyk` reduces to the ink combination with the most key,
and `Cmyk::to_color` brings it back.

## Bringing a colour into a gamut

`to_gamut` reduces chroma in OkLCh until the colour fits, which is what CSS
Color 4 asks for; `clip` moves each component to the nearest edge, which is
cheaper and changes the colour more.

```moonbit
let wide = @moonrgba.Color::oklch(0.7, 0.4, 30.0)
wide.in_gamut(space=@moonrgba.Space::Srgb)                 // false
wide.to_srgb().encode()                                    // "color(srgb 1.31965 -0.44982 -0.31009)"
wide.clip(space=@moonrgba.Space::Srgb).encode()            // "#f00"
wide.to_gamut(space=@moonrgba.Space::Srgb).encode()        // "rgb(255 88.00945 67.46665)"
wide.to_gamut(space=@moonrgba.Space::Srgb).to_oklch().encode()
                                                           // "oklch(0.6831 0.2062 30.18163)"
```

A colour already inside comes back untouched, so mapping twice is mapping once.
A colour that no amount of chroma reduction can reach — a saturated blue in sRGB
— falls back to clipping, which is the last step of the same algorithm.

## Mixing and adjusting

`mix` is `color-mix()`: the interpolation space decides where the average is
taken, the weight decides how much of each colour it has, and alpha takes part
premultiplied so that a nearly transparent colour does not drag the result
towards its own hue. A missing component takes the other colour's value first.

```moonbit
let red = @moonrgba.Color::rgb(255, 0, 0)
let blue = @moonrgba.Color::rgb(0, 0, 255)
red.mix(blue, space=@moonrgba.Space::Srgb).encode()        // "rgb(127.5 0 127.5)"
red.mix(blue, space=@moonrgba.Space::Oklab, weight=0.3).encode()
                                                           // "oklab(0.5048 0.04474 -0.18032)"
@moonrgba.Color::hsl(350.0, 1.0, 0.5)
  .mix(@moonrgba.Color::hsl(10.0, 1.0, 0.5), space=@moonrgba.Space::Hsl, hue=Longer)
  .hue()                                                   // 180
```

`Hue` is `Shorter`, `Longer`, `Increasing` or `Decreasing`, and decides which way
round the circle a mix travels.

`lighten`, `darken`, `saturate` and `desaturate` nudge one component of the
colour's own space — a tenth of that space's scale — and `fade` takes alpha away.

## Contrast

Two measures, because the field has two. `contrast` is the WCAG 2 ratio, from 1
to 21 and symmetric. `apca` is the signed lightness contrast of APCA 0.98G-4g,
from about −108 to 108, with the text first:

```moonbit
let ink = @moonrgba.Color::black()
let paper = @moonrgba.Color::white()
ink.contrast(paper)      // 21
ink.apca(paper)          // 106.04067321268862
paper.apca(ink)          // -107.88473318309848
```

## Colour difference

`delta_e` measures how far apart two colours are, by one of four accepted
answers. They are not comparable with each other: 2 is barely visible under
`E2000` and obvious under `E76`.

| Measure | Space | Note |
|:--|:--|:--|
| `E76` | Lab | the straight-line distance |
| `E94` | Lab | graphic-arts weights; the first colour is the reference |
| `E2000` | Lab | the current CIE recommendation |
| `Ok` | Oklab | no weights needed; a just-noticeable difference is 0.02 |

## Terminal colours

Three tiers, and a nearest match by ΔE OK rather than by arithmetic on the
channels, because the palette is uneven: the cube is coarse near black and fine
near white, and a distance in sRGB would not know that.

```moonbit
let brand = @moonrgba.Color::decode("#0891b2")
brand.to_ansi16()            // cyan
brand.to_ansi256().code()    // 31
brand.rgb8()                 // (8, 145, 178)
@moonrgba.Ansi256::of(196).color().encode()   // "#f00"
```

The sixteen colours are the ones xterm uses, which is what terminals show.

## The value

```moonbit
pub(all) struct Color {
  space : Space
  x : Double
  y : Double
  z : Double
  alpha : Double
}
```

Alpha is kept apart from the components because it is not a colour: it says how
much of what is behind shows through, and it survives a change of space
untouched. A component may be `none`, carried as a NaN, which is what CSS means
by the keyword and what interpolation then fills in from the other side.

`Show` writes the shortest CSS, so a colour interpolated into a log line or an
error message is something a browser would accept:

```moonbit
println("\{@moonrgba.Color::decode("#0891b2")}")    // #0891b2
```

## Interface

| Call | What it does |
|:--|:--|
| `Color::decode(text)` | read a CSS colour; raises `Refused` |
| `Color::decode_opt(text)` | the same, `None` instead of raising |
| `Color::encode(format?)` | write CSS, in the shortest exact spelling |
| `Color::of(space, x, y, z, alpha?)` | a colour from components already in a space |
| `Color::srgb`, `rgb`, `hsl`, `hwb`, `lab`, `lch`, `oklab`, `oklch`, `xyz_d65`, `xyz_d50`, `display_p3`, `rec2020`, `a98_rgb`, `prophoto`, `ycbcr` | a colour in that space |
| `Color::of_name`, `Color::name` | the 148 names, both ways |
| `Color::to_srgb`, `to_hsl`, `to_lab`, `to_oklch` and the rest, `to_space` | the same colour in another space |
| `Color::in_gamut`, `clip`, `to_gamut` | decide what to do with a colour a display cannot show |
| `Color::mix`, `lighten`, `darken`, `saturate`, `desaturate`, `fade` | combining and nudging |
| `Color::contrast`, `apca`, `luminance` | how readable a pair is |
| `Color::delta_e` | how far apart two colours are |
| `Color::to_ansi16`, `to_ansi256`, `rgb8` | into a terminal's palette |
| `Color::to_cmyk`, `Cmyk::to_color` | into print, and back |
| `Color::components`, `hue`, `chroma`, `lightness`, `saturation`, `with_components`, `with_alpha`, `resolve` | looking inside, and putting it back together |
| `Space::code`, `Space::of`, `is_polar`, `is_predefined`, `has_gamut` | what a space is |

## Licence

Apache-2.0. See [LICENSE](LICENSE).
