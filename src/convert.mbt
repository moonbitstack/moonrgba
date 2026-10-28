// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Conversions between colour spaces.
//
// Every route runs through one of two hubs: D65 XYZ for the spaces defined by
// primaries, and sRGB for the ones defined by a hue. Two hubs rather than one
// because HSL, HSV, HWB and YCbCr are defined on gamma-encoded sRGB itself, and
// routing them through XYZ would add two transfer-curve round trips to every
// conversion.
//
// The matrices, the transfer curves and the white points are the ones CSS
// Color 4 prints in its sample code, to the last digit, so that a value here
// and a value from that code agree to the bit rather than to five places.
//
// Nothing here clips. A colour outside its space's gamut keeps its value, and
// `to_gamut` is where the decision about what to do with it is made.

///|
/// A missing component behaves as zero in conversion (CSS Color 4 §12.2).
fn or_zero(value : Double) -> Double {
  if value.is_nan() {
    0.0
  } else {
    value
  }
}

///|
fn clamp01(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Degrees brought into 0–360, which every hue is before it is used.
fn hue_of(value : Double) -> Double {
  let wrapped = or_zero(value) % 360.0
  if wrapped < 0.0 {
    wrapped + 360.0
  } else {
    wrapped
  }
}

///|
/// The extended sRGB transfer curve: below the linear segment the sign is
/// carried through, so that a component outside 0–1 still means something.
fn srgb_decode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  if magnitude <= 0.04045 {
    value / 12.92
  } else {
    sign * @math.pow((magnitude + 0.055) / 1.055, 2.4)
  }
}

///|
fn srgb_encode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  if magnitude > 0.0031308 {
    sign * (1.055 * @math.pow(magnitude, 1.0 / 2.4) - 0.055)
  } else {
    12.92 * value
  }
}

///|
/// ProPhoto's curve: gamma 1.8 with a linear toe of 1/512.
fn prophoto_decode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  if magnitude <= 16.0 / 512.0 {
    value / 16.0
  } else {
    sign * @math.pow(magnitude, 1.8)
  }
}

///|
fn prophoto_encode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  if magnitude >= 1.0 / 512.0 {
    sign * @math.pow(magnitude, 1.0 / 1.8)
  } else {
    16.0 * value
  }
}

///|
/// Rec. 2020's curve is BT.1886 with no black lift, which is a pure 2.4 power.
fn rec2020_decode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  sign * @math.pow(magnitude, 2.4)
}

///|
fn rec2020_encode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  sign * @math.pow(magnitude, 1.0 / 2.4)
}

///|
/// Adobe RGB's curve is a pure 563/256 power, which is close to but not 2.2.
fn a98_decode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  sign * @math.pow(magnitude, 563.0 / 256.0)
}

///|
fn a98_encode(value : Double) -> Double {
  let magnitude = value.abs()
  let sign = if value < 0.0 { -1.0 } else { 1.0 }
  sign * @math.pow(magnitude, 256.0 / 563.0)
}

// Linear light to D65 XYZ, one function per space. Written out rather than kept
// in a table so that each number stays next to the space it belongs to.

///|
fn lin_srgb_to_xyz(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  (
    0.4123907992659595 * r + 0.35758433938387796 * g + 0.1804807884018343 * b,
    0.21263900587151036 * r + 0.7151686787677559 * g + 0.07219231536073371 * b,
    0.01933081871559185 * r + 0.11919477979462599 * g + 0.9505321522496606 * b,
  )
}

///|
fn xyz_to_lin_srgb(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    3.2409699419045213 * x - 1.5373831775700935 * y - 0.4986107602930033 * z,
    -0.9692436362808798 * x + 1.8759675015077206 * y + 0.04155505740717561 * z,
    0.05563007969699361 * x - 0.20397695888897657 * y + 1.0569715142428786 * z,
  )
}

///|
fn lin_p3_to_xyz(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  (
    0.48657094864821626 * r + 0.26566769316909294 * g + 0.1982172852343625 * b,
    0.22897456406974884 * r + 0.6917385218365062 * g + 0.079286914093745 * b,
    0.045113381858902575 * g + 1.0439443689009757 * b,
  )
}

///|
fn xyz_to_lin_p3(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    2.4934969119414245 * x - 0.9313836179191236 * y - 0.40271078445071684 * z,
    -0.829488969561575 * x + 1.7626640603183468 * y + 0.02362468584194359 * z,
    0.035845830243784335 * x - 0.07617238926804171 * y + 0.9568845240076873 * z,
  )
}

///|
fn lin_2020_to_xyz(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  (
    0.6369580483012913 * r + 0.14461690358620838 * g + 0.16888097516417205 * b,
    0.26270021201126703 * r + 0.677998071518871 * g + 0.059301716469861945 * b,
    0.028072693049087508 * g + 1.0609850577107909 * b,
  )
}

///|
fn xyz_to_lin_2020(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    1.7166511879712676 * x - 0.3556707837763924 * y - 0.2533662813736598 * z,
    -0.666684351832489 * x + 1.616481236634939 * y + 0.01576854581391113 * z,
    0.017639857445310915 * x - 0.042770613257808655 * y + 0.942103121235474 * z,
  )
}

///|
fn lin_a98_to_xyz(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  (
    0.5766690429101308 * r + 0.18555823790654627 * g + 0.18822864623499472 * b,
    0.29734497525053616 * r + 0.627363566255466 * g + 0.07529145849399789 * b,
    0.027031361386412378 * r + 0.07068885253582714 * g + 0.9913375368376389 * b,
  )
}

///|
fn xyz_to_lin_a98(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    2.041587903810746 * x - 0.5650069742788596 * y - 0.3447313507783295 * z,
    -0.9692436362808798 * x + 1.8759675015077206 * y + 0.04155505740717561 * z,
    0.013444280632031024 * x - 0.11836239223101824 * y + 1.0151749943912054 * z,
  )
}

///|
fn lin_prophoto_to_xyz(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  (
    0.7977666449006423 * r + 0.13518129740053308 * g + 0.0313477341283922 * b,
    0.2880748288194013 * r + 0.711835234241873 * g + 0.00008993693872564 * b,
    0.8251046025104602 * b,
  )
}

///|
fn xyz_to_lin_prophoto(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    1.3457868816471583 * x - 0.25557208737979464 * y - 0.05110186497554526 * z,
    -0.5446307051249019 * x + 1.5082477428451468 * y + 0.02052744743642139 * z,
    1.2119675456389452 * z,
  )
}

///|
/// Bradford chromatic adaptation, D65 to D50. Lab and ProPhoto are defined
/// against D50, everything else against D65, so this is on every route between
/// the two halves.
fn d65_to_d50(x : Double, y : Double, z : Double) -> (Double, Double, Double) {
  (
    1.0479297925449969 * x + 0.022946870601609652 * y - 0.05019226628920524 * z,
    0.02962780877005599 * x + 0.9904344267538799 * y - 0.017073799063418826 * z,
    -0.009243040646204504 * x +
    0.015055191490298152 * y +
    0.7518742814281371 * z,
  )
}

///|
fn d50_to_d65(x : Double, y : Double, z : Double) -> (Double, Double, Double) {
  (
    0.955473421488075 * x - 0.02309845494876471 * y + 0.06325924320057072 * z,
    -0.0283697093338637 * x + 1.0099953980813041 * y + 0.021041441191917323 * z,
    0.012314014864481998 * x - 0.020507649298898964 * y + 1.330365926242124 * z,
  )
}

///|
/// The D50 white the Lab and ProPhoto conversions divide by.
let d50 : (Double, Double, Double) = (
  0.9642956764295677, 1.0, 0.8251046025104602,
)

///|
fn xyz_d50_to_lab(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  let epsilon = 216.0 / 24389.0
  let kappa = 24389.0 / 27.0
  let fx = {
    let v = x / d50.0
    if v > epsilon {
      @math.cbrt(v)
    } else {
      (kappa * v + 16.0) / 116.0
    }
  }
  let fy = {
    let v = y / d50.1
    if v > epsilon {
      @math.cbrt(v)
    } else {
      (kappa * v + 16.0) / 116.0
    }
  }
  let fz = {
    let v = z / d50.2
    if v > epsilon {
      @math.cbrt(v)
    } else {
      (kappa * v + 16.0) / 116.0
    }
  }
  (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
}

///|
fn lab_to_xyz_d50(
  l : Double,
  a : Double,
  b : Double,
) -> (Double, Double, Double) {
  let kappa = 24389.0 / 27.0
  let epsilon = 216.0 / 24389.0
  // Keeping L out of L + 16 keeps precision near black.
  let lightness = l / 116.0
  let fy = lightness + 16.0 / 116.0
  let fx = fy + a / 500.0
  let fz = fy - b / 200.0
  let x = if fx * fx * fx > epsilon {
    fx * fx * fx
  } else {
    (lightness + a / 500.0) * (116.0 / kappa)
  }
  let y = if l > kappa * epsilon { fy * fy * fy } else { l / kappa }
  let z = if fz * fz * fz > epsilon {
    fz * fz * fz
  } else {
    (lightness - b / 200.0) * (116.0 / kappa)
  }
  (x * d50.0, y * d50.1, z * d50.2)
}

///|
fn xyz_d65_to_oklab(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  let l = 0.819022437996703 * x +
    0.3619062600528904 * y -
    0.1288737815209879 * z
  let m = 0.0329836539323885 * x +
    0.9292868615863434 * y +
    0.0361446663506424 * z
  let s = 0.0481771893596242 * x +
    0.2642395317527308 * y +
    0.6335478284694309 * z
  let l = @math.cbrt(l)
  let m = @math.cbrt(m)
  let s = @math.cbrt(s)
  (
    0.210454268309314 * l + 0.7936177747023054 * m - 0.0040720430116193 * s,
    1.9779985324311684 * l - 2.4285922420485799 * m + 0.450593709617411 * s,
    0.0259040424655478 * l + 0.7827717124575296 * m - 0.8086757549230774 * s,
  )
}

///|
fn oklab_to_xyz_d65(
  l : Double,
  a : Double,
  b : Double,
) -> (Double, Double, Double) {
  let long = l + 0.3963377773761749 * a + 0.2158037573099136 * b
  let medium = l - 0.1055613458156586 * a - 0.0638541728258133 * b
  let short = l - 0.0894841775298119 * a - 1.2914855480194092 * b
  let long = long * long * long
  let medium = medium * medium * medium
  let short = short * short * short
  (
    1.2268798758459243 * long -
    0.5578149944602171 * medium +
    0.2813910456659647 * short,
    -0.0405757452148008 * long +
    1.112286803280317 * medium -
    0.0717110580655164 * short,
    -0.0763729366746601 * long -
    0.4214933324022432 * medium +
    1.5869240198367816 * short,
  )
}

///|
/// The chroma below which a hue is meaningless, so that a grey reports no hue
/// at all rather than the hue of rounding noise.
fn polar_of(a : Double, b : Double, epsilon : Double) -> (Double, Double) {
  let chroma = @math.hypot(a, b)
  let hue = if chroma <= epsilon {
    @double.not_a_number
  } else {
    let degrees = @math.atan2(b, a) * 180.0 / @math.PI
    if degrees < 0.0 {
      degrees + 360.0
    } else {
      degrees
    }
  }
  (chroma, hue)
}

///|
fn max3(a : Double, b : Double, c : Double) -> Double {
  let largest = if a > b { a } else { b }
  if c > largest {
    c
  } else {
    largest
  }
}

///|
fn min3(a : Double, b : Double, c : Double) -> Double {
  let smallest = if a < b { a } else { b }
  if c < smallest {
    c
  } else {
    smallest
  }
}

///|
/// HSL to sRGB, as CSS Color 4 writes it: the hue picks a point on the
/// lightness-dependent hexagon, the saturation the distance from the grey axis.
fn hsl_to_srgb(h : Double, s : Double, l : Double) -> (Double, Double, Double) {
  let h = hue_of(h)
  let s = clamp01(or_zero(s))
  let l = clamp01(or_zero(l))
  let a = s * (if l < 0.5 { l } else { 1.0 - l })
  let channel : (Double) -> Double = fn(n) {
    let k = (n + h / 30.0) % 12.0
    let m = if k - 3.0 < 9.0 - k { k - 3.0 } else { 9.0 - k }
    let m = if m < 1.0 { m } else { 1.0 }
    let m = if m > -1.0 { m } else { -1.0 }
    l - a * m
  }
  (channel(0.0), channel(8.0), channel(4.0))
}

///|
fn srgb_to_hsl(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let maximum = max3(r, g, b)
  let minimum = min3(r, g, b)
  let lightness = (minimum + maximum) / 2.0
  let delta = maximum - minimum
  // A grey has no hue, and saying so is better than saying zero: a hue of zero
  // is red, and interpolating towards it from a real hue would swing through it.
  if delta == 0.0 {
    return (@double.not_a_number, 0.0, lightness)
  }
  let half = if lightness < 0.5 { lightness } else { 1.0 - lightness }
  let mut saturation = if lightness == 0.0 || lightness == 1.0 {
    0.0
  } else {
    (maximum - lightness) / half
  }
  let mut hue = if maximum == r {
    (g - b) / delta + (if g < b { 6.0 } else { 0.0 })
  } else if maximum == g {
    (b - r) / delta + 2.0
  } else {
    (r - g) / delta + 4.0
  }
  hue = hue * 60.0
  if saturation < 0.0 {
    hue = hue + 180.0
    saturation = -saturation
  }
  if hue >= 360.0 {
    hue = hue - 360.0
  }
  (hue, saturation, lightness)
}

///|
fn hsv_to_srgb(h : Double, s : Double, v : Double) -> (Double, Double, Double) {
  let s = clamp01(or_zero(s))
  let v = clamp01(or_zero(v))
  // The fully saturated colour at this hue, scaled down to a value and lifted
  // by the chroma the pair leaves over.
  let (r, g, b) = hsl_to_srgb(h, 1.0, 0.5)
  let chroma = v * s
  let lift = v - chroma
  (r * chroma + lift, g * chroma + lift, b * chroma + lift)
}

///|
fn srgb_to_hsv(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let maximum = max3(r, g, b)
  let minimum = min3(r, g, b)
  let delta = maximum - minimum
  let saturation = if maximum == 0.0 { 0.0 } else { delta / maximum }
  let hue = if delta == 0.0 {
    @double.not_a_number
  } else if maximum == r {
    ((g - b) / delta + (if g < b { 6.0 } else { 0.0 })) * 60.0
  } else if maximum == g {
    ((b - r) / delta + 2.0) * 60.0
  } else {
    ((r - g) / delta + 4.0) * 60.0
  }
  (hue, saturation, maximum)
}

///|
fn hwb_to_srgb(h : Double, w : Double, b : Double) -> (Double, Double, Double) {
  let w = clamp01(or_zero(w))
  let b = clamp01(or_zero(b))
  if w + b >= 1.0 {
    let grey = w / (w + b)
    return (grey, grey, grey)
  }
  let (r, g, bl) = hsl_to_srgb(h, 1.0, 0.5)
  let scale = 1.0 - w - b
  (r * scale + w, g * scale + w, bl * scale + w)
}

///|
fn srgb_to_hwb(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let (hue, _, _) = srgb_to_hsl(r, g, b)
  (hue, min3(r, g, b), 1.0 - max3(r, g, b))
}

///|
/// The luma coefficients of a `YCbCr` space: red, green, blue weights.
fn luma_weights(luma : Luma) -> (Double, Double, Double) {
  match luma {
    Bt601 => (0.299, 0.587, 0.114)
    Bt709 => (0.2126, 0.7152, 0.0722)
    Bt2020 => (0.2627, 0.678, 0.0593)
  }
}

///|
fn srgb_to_ycbcr(
  r : Double,
  g : Double,
  b : Double,
  luma : Luma,
) -> (Double, Double, Double) {
  let (kr, kg, kb) = luma_weights(luma)
  let y = kr * r + kg * g + kb * b
  let cb = (b - y) / (2.0 * (1.0 - kb))
  let cr = (r - y) / (2.0 * (1.0 - kr))
  (y, cb, cr)
}

///|
fn ycbcr_to_srgb(
  y : Double,
  cb : Double,
  cr : Double,
  luma : Luma,
) -> (Double, Double, Double) {
  let (kr, kg, kb) = luma_weights(luma)
  let r = y + 2.0 * (1.0 - kr) * cr
  let b = y + 2.0 * (1.0 - kb) * cb
  let g = (y - kr * r - kb * b) / kg
  (r, g, b)
}

///|
/// The colour as linear-light sRGB, the form luma is defined on. Everything
/// that needs linear light for a different space goes through here or through
/// `xyz_d65`, never both.
fn Color::linear_srgb(self : Color) -> (Double, Double, Double) {
  match self.space {
    Srgb => (srgb_decode(self.x), srgb_decode(self.y), srgb_decode(self.z))
    SrgbLinear => (self.x, self.y, self.z)
    Hsl => {
      let (r, g, b) = hsl_to_srgb(self.x, self.y, self.z)
      (srgb_decode(r), srgb_decode(g), srgb_decode(b))
    }
    Hsv => {
      let (r, g, b) = hsv_to_srgb(self.x, self.y, self.z)
      (srgb_decode(r), srgb_decode(g), srgb_decode(b))
    }
    Hwb => {
      let (r, g, b) = hwb_to_srgb(self.x, self.y, self.z)
      (srgb_decode(r), srgb_decode(g), srgb_decode(b))
    }
    YCbCr(luma) => {
      let (r, g, b) = ycbcr_to_srgb(self.x, self.y, self.z, luma)
      (srgb_decode(r), srgb_decode(g), srgb_decode(b))
    }
    _ => {
      let (x, y, z) = self.xyz65()
      xyz_to_lin_srgb(x, y, z)
    }
  }
}

///|
/// The colour in D65 XYZ, the hub every primaries-based space is reached from.
fn Color::xyz65(self : Color) -> (Double, Double, Double) {
  match self.space {
    XyzD65 => (self.x, self.y, self.z)
    XyzD50 => d50_to_d65(self.x, self.y, self.z)
    Lab => {
      let (x, y, z) = lab_to_xyz_d50(
        or_zero(self.x),
        or_zero(self.y),
        or_zero(self.z),
      )
      d50_to_d65(x, y, z)
    }
    Lch => {
      let (l, c, h) = (or_zero(self.x), or_zero(self.y), hue_of(self.z))
      let radians = h * @math.PI / 180.0
      let (x, y, z) = lab_to_xyz_d50(
        l,
        c * @math.cos(radians),
        c * @math.sin(radians),
      )
      d50_to_d65(x, y, z)
    }
    Oklab => oklab_to_xyz_d65(or_zero(self.x), or_zero(self.y), or_zero(self.z))
    Oklch => {
      let (l, c, h) = (or_zero(self.x), or_zero(self.y), hue_of(self.z))
      let radians = h * @math.PI / 180.0
      oklab_to_xyz_d65(l, c * @math.cos(radians), c * @math.sin(radians))
    }
    DisplayP3 =>
      lin_p3_to_xyz(
        srgb_decode(or_zero(self.x)),
        srgb_decode(or_zero(self.y)),
        srgb_decode(or_zero(self.z)),
      )
    DisplayP3Linear =>
      lin_p3_to_xyz(or_zero(self.x), or_zero(self.y), or_zero(self.z))
    Rec2020 =>
      lin_2020_to_xyz(
        rec2020_decode(or_zero(self.x)),
        rec2020_decode(or_zero(self.y)),
        rec2020_decode(or_zero(self.z)),
      )
    A98Rgb =>
      lin_a98_to_xyz(
        a98_decode(or_zero(self.x)),
        a98_decode(or_zero(self.y)),
        a98_decode(or_zero(self.z)),
      )
    ProPhoto => {
      let (x, y, z) = lin_prophoto_to_xyz(
        prophoto_decode(or_zero(self.x)),
        prophoto_decode(or_zero(self.y)),
        prophoto_decode(or_zero(self.z)),
      )
      d50_to_d65(x, y, z)
    }
    Srgb | SrgbLinear | Hsl | Hsv | Hwb | YCbCr(_) => {
      let (r, g, b) = self.linear_srgb()
      lin_srgb_to_xyz(r, g, b)
    }
    Current => (0.0, 0.0, 0.0)
  }
}

///|
/// A colour from D65 XYZ, in the requested space.
fn of_xyz_d65(
  space : Space,
  x : Double,
  y : Double,
  z : Double,
  alpha : Double,
) -> Color {
  match space {
    XyzD65 => { space, x, y, z, alpha, }
    XyzD50 => {
      let (x, y, z) = d65_to_d50(x, y, z)
      { space: XyzD50, x, y, z, alpha, }
    }
    Lab => {
      let (x, y, z) = d65_to_d50(x, y, z)
      let (l, a, b) = xyz_d50_to_lab(x, y, z)
      { space: Lab, x: l, y: a, z: b, alpha, }
    }
    Lch => {
      let (x, y, z) = d65_to_d50(x, y, z)
      let (l, a, b) = xyz_d50_to_lab(x, y, z)
      let (c, h) = polar_of(a, b, 0.0015)
      { space: Lch, x: l, y: c, z: h, alpha, }
    }
    Oklab => {
      let (l, a, b) = xyz_d65_to_oklab(x, y, z)
      { space: Oklab, x: l, y: a, z: b, alpha, }
    }
    Oklch => {
      let (l, a, b) = xyz_d65_to_oklab(x, y, z)
      let (c, h) = polar_of(a, b, 0.000004)
      { space: Oklch, x: l, y: c, z: h, alpha, }
    }
    DisplayP3Linear => {
      let (r, g, b) = xyz_to_lin_p3(x, y, z)
      { space: DisplayP3Linear, x: r, y: g, z: b, alpha, }
    }
    DisplayP3 => {
      let (r, g, b) = xyz_to_lin_p3(x, y, z)
      {
        space: DisplayP3,
        x: srgb_encode(r),
        y: srgb_encode(g),
        z: srgb_encode(b),
        alpha,
      }
    }
    Rec2020 => {
      let (r, g, b) = xyz_to_lin_2020(x, y, z)
      {
        space: Rec2020,
        x: rec2020_encode(r),
        y: rec2020_encode(g),
        z: rec2020_encode(b),
        alpha,
      }
    }
    A98Rgb => {
      let (r, g, b) = xyz_to_lin_a98(x, y, z)
      {
        space: A98Rgb,
        x: a98_encode(r),
        y: a98_encode(g),
        z: a98_encode(b),
        alpha,
      }
    }
    ProPhoto => {
      let (x, y, z) = d65_to_d50(x, y, z)
      let (r, g, b) = xyz_to_lin_prophoto(x, y, z)
      {
        space: ProPhoto,
        x: prophoto_encode(r),
        y: prophoto_encode(g),
        z: prophoto_encode(b),
        alpha,
      }
    }
    Srgb | SrgbLinear => {
      let (r, g, b) = xyz_to_lin_srgb(x, y, z)
      if space is Srgb {
        {
          space: Srgb,
          x: srgb_encode(r),
          y: srgb_encode(g),
          z: srgb_encode(b),
          alpha,
        }
      } else {
        { space: SrgbLinear, x: r, y: g, z: b, alpha, }
      }
    }
    Hsl => {
      let (r, g, b) = xyz_to_lin_srgb(x, y, z)
      let (h, s, l) = srgb_to_hsl(
        srgb_encode(r),
        srgb_encode(g),
        srgb_encode(b),
      )
      { space: Hsl, x: h, y: s, z: l, alpha, }
    }
    Hsv => {
      let (r, g, b) = xyz_to_lin_srgb(x, y, z)
      let (h, s, v) = srgb_to_hsv(
        srgb_encode(r),
        srgb_encode(g),
        srgb_encode(b),
      )
      { space: Hsv, x: h, y: s, z: v, alpha, }
    }
    Hwb => {
      let (r, g, b) = xyz_to_lin_srgb(x, y, z)
      let (h, w, bl) = srgb_to_hwb(
        srgb_encode(r),
        srgb_encode(g),
        srgb_encode(b),
      )
      { space: Hwb, x: h, y: w, z: bl, alpha, }
    }
    YCbCr(luma) => {
      let (r, g, b) = xyz_to_lin_srgb(x, y, z)
      let (y, cb, cr) = srgb_to_ycbcr(
        srgb_encode(r),
        srgb_encode(g),
        srgb_encode(b),
        luma,
      )
      { space: YCbCr(luma), x: y, y: cb, z: cr, alpha, }
    }
    Current => { space: Current, x: 0.0, y: 0.0, z: 0.0, alpha: 1.0, }
  }
}

///|
/// The same colour in another space.
///
/// This is the one conversion every `to_*` goes through, so that a pair of
/// spaces is only ever defined once. Converting to the space a colour is
/// already in returns it unchanged rather than round-tripping it through a hub,
/// which would otherwise cost a matrix inversion for nothing.
pub fn Color::to_space(self : Color, space : Space) -> Color {
  if self.space is Current || space is Current {
    return self
  }
  if self.space == space {
    return self
  }
  // HSL, HSV, HWB and YCbCr are defined on sRGB rather than on XYZ, so a
  // conversion between two of them goes through sRGB and keeps its exact
  // inverses instead of paying two transfer-curve round trips.
  match (self.space, space) {
    (Hsl | Hsv | Hwb | YCbCr(_), Hsl | Hsv | Hwb | YCbCr(_)) =>
      self.to_space(Srgb).to_space(space)
    _ => {
      let (x, y, z) = self.xyz65()
      of_xyz_d65(space, x, y, z, self.alpha)
    }
  }
}

///|
/// sRGB, components 0–1.
pub fn Color::to_srgb(self : Color) -> Color {
  self.to_space(Srgb)
}

///|
/// Linear-light sRGB, components 0–1.
pub fn Color::to_srgb_linear(self : Color) -> Color {
  self.to_space(SrgbLinear)
}

///|
/// HSL: hue in degrees, saturation and lightness 0–1.
pub fn Color::to_hsl(self : Color) -> Color {
  self.to_space(Hsl)
}

///|
/// HSV: hue in degrees, saturation and value 0–1.
pub fn Color::to_hsv(self : Color) -> Color {
  self.to_space(Hsv)
}

///|
/// HWB: hue in degrees, whiteness and blackness 0–1.
pub fn Color::to_hwb(self : Color) -> Color {
  self.to_space(Hwb)
}

///|
/// CIE Lab relative to D50, lightness 0–100.
pub fn Color::to_lab(self : Color) -> Color {
  self.to_space(Lab)
}

///|
/// CIE LCh relative to D50, lightness 0–100.
pub fn Color::to_lch(self : Color) -> Color {
  self.to_space(Lch)
}

///|
/// Oklab, lightness 0–1.
pub fn Color::to_oklab(self : Color) -> Color {
  self.to_space(Oklab)
}

///|
/// OkLCh, lightness 0–1.
pub fn Color::to_oklch(self : Color) -> Color {
  self.to_space(Oklch)
}

///|
/// CIE XYZ relative to D65, Y = 1 for white.
pub fn Color::to_xyz_d65(self : Color) -> Color {
  self.to_space(XyzD65)
}

///|
/// CIE XYZ relative to D50, Y = 1 for white.
pub fn Color::to_xyz_d50(self : Color) -> Color {
  self.to_space(XyzD50)
}

///|
/// Display P3, components 0–1.
pub fn Color::to_display_p3(self : Color) -> Color {
  self.to_space(DisplayP3)
}

///|
/// Rec. 2020, components 0–1.
pub fn Color::to_rec2020(self : Color) -> Color {
  self.to_space(Rec2020)
}

///|
/// Adobe RGB (1998), components 0–1.
pub fn Color::to_a98_rgb(self : Color) -> Color {
  self.to_space(A98Rgb)
}

///|
/// ProPhoto RGB, components 0–1.
pub fn Color::to_prophoto(self : Color) -> Color {
  self.to_space(ProPhoto)
}

///|
/// YCbCr with the given luma coefficients: luma 0–1, chroma −0.5–0.5.
pub fn Color::to_ycbcr(self : Color, luma~ : Luma) -> Color {
  self.to_space(YCbCr(luma))
}

///|
/// CMYK for print, as four inks in 0–1.
///
/// The conversion is the arithmetic one — full black is all key, and the other
/// three inks spread what is left — not the one an ICC profile for a particular
/// press and paper would give.
///
/// Four inks do not fit in three channels, so the arithmetic has to choose: for
/// one colour there are many ink combinations, and `to_cmyk` returns the one with
/// as much key as possible, which is the usual choice because key ink is cheap
/// and the three colour inks are not. That means a colour survives the round trip
/// but its inks may not: `cmyk(0.2 0.4 0.6 0.1)` prints the same colour as
/// `cmyk(0 0.25 0.5 0.28)`, and only the second comes back.
pub(all) struct Cmyk {
  c : Double
  m : Double
  y : Double
  k : Double
} derive(Eq, Debug)

///|
pub extend Cmyk with Eq::{equal, not_equal}

///|
pub extend Cmyk with Debug::{to_repr}

///|
pub fn Cmyk::of(c : Double, m : Double, y : Double, k : Double) -> Cmyk {
  { c, m, y, k, }
}

///|
pub fn Color::to_cmyk(self : Color) -> Cmyk {
  let (r, g, b) = self.to_srgb().components()
  let (r, g, b) = (
    clamp01(or_zero(r)),
    clamp01(or_zero(g)),
    clamp01(or_zero(b)),
  )
  let k = 1.0 -
    (if r > g { if r > b { r } else { b } } else if g > b { g } else { b })
  if k >= 1.0 {
    return { c: 0.0, m: 0.0, y: 0.0, k: 1.0, }
  }
  {
    c: (1.0 - r - k) / (1.0 - k),
    m: (1.0 - g - k) / (1.0 - k),
    y: (1.0 - b - k) / (1.0 - k),
    k,
  }
}

///|
/// A colour from CMYK inks, in sRGB.
pub fn Cmyk::to_color(self : Cmyk, alpha? : Double) -> Color {
  let k = clamp01(or_zero(self.k))
  let channel = fn(ink : Double) { (1.0 - clamp01(or_zero(ink))) * (1.0 - k) }
  Color::srgb(channel(self.c), channel(self.m), channel(self.y), alpha?)
}
