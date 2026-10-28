// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Reading a colour from CSS.
//
// One recursive-descent parser over the two syntaxes CSS Color 4 defines: the
// legacy comma form, which dates from CSS Color 3 and is a different grammar
// with different rules, and the modern space form. They are not variants of one
// another — `rgb(10%, 50%, 0)` is invalid because a legacy argument list may not
// mix numbers and percentages, while `rgb(10% 50 0)` is valid — so the parser
// decides which one it is reading at the first separator it meets, and applies
// that one's rules to everything after.
//
// What is not here: `calc()`, `var()`, `env()` and the rest of CSS Values.
// Those need a cascade to resolve, and a colour library that guessed at them
// would produce values that look right and are not. A value containing them is
// refused like any other unknown function. Nor are the system colours
// (`Canvas`, `ButtonText`): their values come from the user's settings.

///|
/// Why a string is not a CSS colour.
pub(all) suberror Refused {
  /// The text did not continue the way the syntax required, at this offset.
  Unexpected(at~ : Int32, got~ : String, want~ : String)
  /// A function or keyword that is valid CSS but not a colour this library
  /// knows, at this offset.
  Unknown(at~ : Int32, got~ : String)
} derive(Eq, Debug)

///|
pub impl Show for Refused with fn output(self, logger) {
  match self {
    Unexpected(at~, got~, want~) =>
      logger.write_string("at \{at}: got \{got}, want \{want}")
    Unknown(at~, got~) => logger.write_string("at \{at}: unknown \{got}")
  }
}

///|
pub extend Refused with Debug::{to_repr}

///|
pub extend Refused with Show::{to_string, output}

///|
pub extend Refused with Eq::{equal, not_equal}

///|
/// Where the parser has got to. Offsets are code points from the start of the
/// input, so that an error can say where without the caller holding the string.
priv struct Cursor {
  text : StringView
  length : Int32
  mut at : Int32
}

///|
fn Cursor::new(text : StringView) -> Cursor {
  { text, length: text.length(), at: 0, }
}

///|
fn Cursor::done(self : Cursor) -> Bool {
  self.at >= self.length
}

///|
fn Cursor::peek(self : Cursor) -> Int32 {
  if self.done() {
    -1
  } else {
    self.text.unsafe_get(self.at).to_int()
  }
}

///|
fn Cursor::bump(self : Cursor) -> Unit {
  if !self.done() {
    self.at = self.at + 1
  }
}

///|
fn Cursor::eat(self : Cursor, code : Int32) -> Bool {
  if self.peek() == code {
    self.bump()
    true
  } else {
    false
  }
}

///|
/// The offset, as an error wants it.
fn Cursor::offset(self : Cursor) -> Int32 {
  self.at
}

///|
/// What was found at the cursor, for an error message: a short run of the input,
/// or the end of it.
fn Cursor::got(self : Cursor) -> String {
  if self.done() {
    return "end of input"
  }
  let stop = if self.at + 12 < self.length { self.at + 12 } else { self.length }
  self.text.clamped_view(start=self.at, end=stop).to_owned()
}

///|
fn Cursor::unexpected(self : Cursor, want : String) -> Refused {
  Unexpected(at=self.offset(), got=self.got(), want~)
}

///|
fn Cursor::unknown(self : Cursor, got : String) -> Refused {
  Unknown(at=self.offset(), got~)
}

///|
fn is_space(code : Int32) -> Bool {
  code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0x0C
}

///|
fn is_digit(code : Int32) -> Bool {
  code >= 0x30 && code <= 0x39
}

///|
fn is_name_start(code : Int32) -> Bool {
  (code >= 0x61 && code <= 0x7A) ||
  (code >= 0x41 && code <= 0x5A) ||
  code == 0x5F
}

///|
fn is_name_char(code : Int32) -> Bool {
  is_name_start(code) || is_digit(code) || code == 0x2D
}

///|
fn is_hex_digit(code : Int32) -> Bool {
  is_digit(code) ||
  (code >= 0x61 && code <= 0x66) ||
  (code >= 0x41 && code <= 0x46)
}

///|
fn hex_value(code : Int32) -> Int32 {
  if is_digit(code) {
    code - 0x30
  } else if code >= 0x61 {
    code - 0x61 + 10
  } else {
    code - 0x41 + 10
  }
}

///|
/// Skip whitespace and comments. CSS strips comments before parsing a value, so
/// `/**/#fff` and `#/**/fff` are both `#fff`.
fn Cursor::skip_spaces(self : Cursor) -> Unit {
  while !self.done() {
    if is_space(self.peek()) {
      self.bump()
    } else if self.peek() == '/' &&
      self.at + 1 < self.length &&
      self.text.unsafe_get(self.at + 1).to_int() == 0x2A {
      self.bump()
      self.bump()
      while !self.done() {
        if self.peek() == 0x2A &&
          self.at + 1 < self.length &&
          self.text.unsafe_get(self.at + 1).to_int() == 0x2F {
          self.bump()
          self.bump()
          break
        }
        self.bump()
      }
    } else {
      break
    }
  }
}

///|
/// One component of a function, before the syntax says what it means. The same
/// number means different things in different functions: `50%` is half a
/// lightness in `oklab()` and 62.5 units of `a` in `lab()`, and only the
/// function knows which.
priv enum Term {
  /// The `none` keyword: a component the author left out.
  Missing
  Number(Double)
  Percent(Double)
  /// An angle, already converted to degrees.
  Angle(Double)
}

///|
/// A number as CSS writes one: an optional sign, digits on at least one side of
/// the point, and an optional exponent.
fn parse_number(cursor : Cursor) -> Double raise Refused {
  let start = cursor.at
  let mut sign = 1.0
  if cursor.eat(0x2D) {
    sign = -1.0
  } else {
    ignore(cursor.eat(0x2B))
  }
  let mut value = 0.0
  let mut digits = 0
  while is_digit(cursor.peek()) {
    value = value * 10.0 + (cursor.peek() - 0x30).to_double()
    digits = digits + 1
    cursor.bump()
  }
  if cursor.peek() == 0x2E {
    cursor.bump()
    let mut scale = 0.1
    while is_digit(cursor.peek()) {
      value = value + (cursor.peek() - 0x30).to_double() * scale
      scale = scale / 10.0
      digits = digits + 1
      cursor.bump()
    }
  }
  if digits == 0 {
    cursor.at = start
    raise cursor.unexpected("a number")
  }
  if cursor.peek() == 0x65 || cursor.peek() == 0x45 {
    let mark = cursor.at
    cursor.bump()
    let mut exponent_sign = 1
    if cursor.eat(0x2D) {
      exponent_sign = -1
    } else {
      ignore(cursor.eat(0x2B))
    }
    let mut exponent = 0
    let mut exponent_digits = 0
    while is_digit(cursor.peek()) {
      exponent = exponent * 10 + (cursor.peek() - 0x30)
      exponent_digits = exponent_digits + 1
      cursor.bump()
    }
    if exponent_digits == 0 {
      // `1e` is a number followed by an identifier, not an exponent; leave the
      // `e` for whatever wants to read it.
      cursor.at = mark
    } else {
      value = value * @math.pow(10.0, (exponent * exponent_sign).to_double())
    }
  }
  sign * value
}

///|
fn Cursor::ident(self : Cursor) -> StringView {
  let start = self.at
  while is_name_char(self.peek()) {
    self.bump()
  }
  self.text.clamped_view(start~, end=self.at)
}

///|
/// A component: a number, a percentage, an angle, or `none`.
fn parse_term(cursor : Cursor) -> Term raise Refused {
  if is_name_start(cursor.peek()) {
    let start = cursor.at
    let word = cursor.ident()
    if word.equal_ignore_ascii_case("none") {
      return Missing
    }
    cursor.at = start
    raise cursor.unknown(word.to_owned())
  }
  let value = parse_number(cursor)
  if cursor.eat(0x25) {
    return Percent(value)
  }
  if is_name_start(cursor.peek()) {
    let start = cursor.at
    let unit = cursor.ident()
    let factor = if unit.equal_ignore_ascii_case("deg") {
      Some(1.0)
    } else if unit.equal_ignore_ascii_case("grad") {
      Some(0.9)
    } else if unit.equal_ignore_ascii_case("rad") {
      Some(180.0 / @math.PI)
    } else if unit.equal_ignore_ascii_case("turn") {
      Some(360.0)
    } else {
      None
    }
    match factor {
      Some(factor) => return Angle(value * factor)
      None => {
        cursor.at = start
        raise cursor.unknown(unit.to_owned())
      }
    }
  }
  Number(value)
}

///|
/// A percentage of `scale`, or the bare number. `lab(50% 50% 0)` writes `a` as
/// half of 125, so the scale is what tells `50%` from `50`.
fn Term::scaled(self : Term, scale : Double) -> Double raise Refused {
  match self {
    Missing => @double.not_a_number
    Number(value) => value
    Percent(value) => value / 100.0 * scale
    Angle(_) => raise Unexpected(at=0, got="an angle", want="a number")
  }
}

///|
/// A percentage of one: `50%` is `0.5`, and a bare number is already a fraction.
fn Term::fraction(self : Term) -> Double raise Refused {
  match self {
    Missing => @double.not_a_number
    Number(value) => value
    Percent(value) => value / 100.0
    Angle(_) => raise Unexpected(at=0, got="an angle", want="a number")
  }
}

///|
/// A component that CSS defines as a percentage whether or not one is written:
/// `hsl(120 30 50)` and `hsl(120 30% 50%)` are the same colour.
fn Term::percentage(self : Term) -> Double raise Refused {
  match self {
    Missing => @double.not_a_number
    Number(value) => value / 100.0
    Percent(value) => value / 100.0
    Angle(_) => raise Unexpected(at=0, got="an angle", want="a percentage")
  }
}

///|
/// A hue in degrees, wrapped into 0–360. A missing hue stays missing.
fn Term::hue(self : Term) -> Double raise Refused {
  let degrees = match self {
    Missing => return @double.not_a_number
    Number(value) => value
    Angle(value) => value
    Percent(_) =>
      raise Unexpected(at=0, got="a percentage", want="a number or angle")
  }
  let wrapped = degrees % 360.0
  if wrapped < 0.0 {
    wrapped + 360.0
  } else {
    wrapped
  }
}

///|
/// A chroma, which cannot be negative: a negative chroma means the hue turned
/// half way round, and the syntax says so with a hue instead.
fn non_negative(value : Double) -> Double {
  if value.is_nan() {
    value
  } else if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
/// An alpha, clamped because there is nothing outside 0–1 to be.
fn Term::alpha(self : Term) -> Double raise Refused {
  match self {
    Missing => @double.not_a_number
    Number(value) => clamp01(value)
    Percent(value) => clamp01(value / 100.0)
    Angle(_) => raise Unexpected(at=0, got="an angle", want="a number")
  }
}

///|
/// The alpha after a slash, if there is one.
fn parse_alpha(cursor : Cursor) -> Double raise Refused {
  cursor.skip_spaces()
  if cursor.eat(0x2F) {
    cursor.skip_spaces()
    let term = parse_term(cursor)
    cursor.skip_spaces()
    return term.alpha()
  }
  1.0
}

///|
/// Whether the argument list uses commas, which is what makes it the legacy
/// syntax even when the function is spelled `rgba()` with a slash in it.
fn Cursor::at_comma(self : Cursor) -> Bool {
  self.skip_spaces()
  self.peek() == 0x2C
}

///|
/// `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`.
fn parse_hex(cursor : Cursor) -> Color raise Refused {
  let start = cursor.at
  cursor.bump()
  let digits_start = cursor.at
  while is_hex_digit(cursor.peek()) {
    cursor.bump()
  }
  let count = cursor.at - digits_start
  if count != 3 && count != 4 && count != 6 && count != 8 {
    cursor.at = start
    raise cursor.unexpected("three, four, six or eight hexadecimal digits")
  }
  let digit = fn(index : Int32) {
    hex_value(cursor.text.unsafe_get(digits_start + index).to_int())
  }
  let pair = fn(index : Int32) { digit(index) * 16 + digit(index + 1) }
  if count == 3 {
    Color::rgb(digit(0) * 17, digit(1) * 17, digit(2) * 17)
  } else if count == 4 {
    Color::rgb(
      digit(0) * 17,
      digit(1) * 17,
      digit(2) * 17,
      alpha=digit(3).to_double() / 15.0,
    )
  } else if count == 6 {
    Color::rgb(pair(0), pair(2), pair(4))
  } else {
    Color::rgb(pair(0), pair(2), pair(4), alpha=pair(6).to_double() / 255.0)
  }
}

///|
/// `rgb()` and `rgba()`, in either syntax.
fn parse_rgb(cursor : Cursor, legacy_name : Bool) -> Color raise Refused {
  let first = parse_term(cursor)
  if first is Angle(_) {
    raise cursor.unexpected("a number or percentage")
  }
  let legacy = cursor.at_comma()
  if legacy {
    if !legacy_name {
      raise cursor.unexpected("a space, because rgb() has no comma syntax")
    }
    return parse_rgb_legacy(cursor, first)
  }
  let second = parse_term_after_space(cursor)
  let third = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  let channel = fn(term : Term) {
    if term is Missing {
      @double.not_a_number
    } else {
      let value = match term {
        Number(value) => value / 255.0
        Percent(value) => value / 100.0
        _ => 0.0
      }
      clamp01(value)
    }
  }
  Color::srgb(channel(first), channel(second), channel(third), alpha~)
}

///|
fn parse_rgb_legacy(cursor : Cursor, first : Term) -> Color raise Refused {
  ignore(cursor.eat(0x2C))
  cursor.skip_spaces()
  let second = parse_term(cursor)
  cursor.skip_spaces()
  if !cursor.eat(0x2C) {
    raise cursor.unexpected("a comma")
  }
  cursor.skip_spaces()
  let third = parse_term(cursor)
  let alpha = if cursor.at_comma() {
    ignore(cursor.eat(0x2C))
    cursor.skip_spaces()
    let term = parse_term(cursor)
    cursor.skip_spaces()
    if term is Missing {
      raise cursor.unexpected(
        "a number for alpha, because `none` is modern syntax",
      )
    }
    term.alpha()
  } else {
    cursor.skip_spaces()
    1.0
  }
  // `none` is a modern-syntax keyword; the legacy grammar predates it.
  if first is Missing || second is Missing || third is Missing {
    raise cursor.unexpected("numbers, because `none` is modern syntax")
  }
  // A legacy argument list is all numbers or all percentages. Mixing them was
  // never valid, and a reader that accepted it would move every later value.
  let all_percent = first is Percent(_) &&
    second is Percent(_) &&
    third is Percent(_)
  let all_number = first is Number(_) &&
    second is Number(_) &&
    third is Number(_)
  if !all_percent && !all_number {
    raise cursor.unexpected("three numbers or three percentages, not a mix")
  }
  let channel = fn(term : Term) {
    let value = match term {
      Number(value) => value / 255.0
      Percent(value) => value / 100.0
      _ => @double.not_a_number
    }
    if value.is_nan() {
      value
    } else {
      clamp01(value)
    }
  }
  Color::srgb(channel(first), channel(second), channel(third), alpha~)
}

///|
fn parse_term_after_space(cursor : Cursor) -> Term raise Refused {
  cursor.skip_spaces()
  parse_term(cursor)
}

///|
/// `hsl()` and `hsla()`.
fn parse_hsl(cursor : Cursor, legacy_name : Bool) -> Color raise Refused {
  let hue = parse_term(cursor)
  if hue is Percent(_) {
    raise cursor.unexpected("a number or angle")
  }
  if cursor.at_comma() {
    if !legacy_name {
      raise cursor.unexpected("a space, because hsl() has no comma syntax")
    }
    ignore(cursor.eat(0x2C))
    cursor.skip_spaces()
    let saturation = parse_term(cursor)
    cursor.skip_spaces()
    if !cursor.eat(0x2C) {
      raise cursor.unexpected("a comma")
    }
    cursor.skip_spaces()
    let lightness = parse_term(cursor)
    // A legacy list requires percentages here, unlike the modern one.
    if !(saturation is Percent(_)) || !(lightness is Percent(_)) {
      raise cursor.unexpected("percentages for saturation and lightness")
    }
    if hue is Missing || saturation is Missing || lightness is Missing {
      raise cursor.unexpected("numbers, because `none` is modern syntax")
    }
    let alpha = if cursor.at_comma() {
      ignore(cursor.eat(0x2C))
      cursor.skip_spaces()
      let term = parse_term(cursor)
      cursor.skip_spaces()
      if term is Missing {
        raise cursor.unexpected(
          "a number for alpha, because `none` is modern syntax",
        )
      }
      term.alpha()
    } else {
      cursor.skip_spaces()
      1.0
    }
    return Color::hsl(
      hue.hue(),
      clamp01(saturation.percentage()),
      clamp01(lightness.percentage()),
      alpha~,
    )
  }
  let saturation = parse_term_after_space(cursor)
  let lightness = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::hsl(
    hue.hue(),
    clamp01(saturation.percentage()),
    clamp01(lightness.percentage()),
    alpha~,
  )
}

///|
/// `hwb()`.
fn parse_hwb(cursor : Cursor) -> Color raise Refused {
  let hue = parse_term(cursor)
  let whiteness = parse_term_after_space(cursor)
  let blackness = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::hwb(
    hue.hue(),
    clamp01(whiteness.percentage()),
    clamp01(blackness.percentage()),
    alpha~,
  )
}

///|
/// `lab()`: lightness 0–100, `a` and `b` unbounded, and 100% of `a` is 125.
fn parse_lab(cursor : Cursor) -> Color raise Refused {
  let lightness = parse_term(cursor)
  let a = parse_term_after_space(cursor)
  let b = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::lab(
    clamp01(lightness.scaled(100.0) / 100.0) * 100.0,
    a.scaled(125.0),
    b.scaled(125.0),
    alpha~,
  )
}

///|
/// `lch()`: lightness 0–100, chroma from 0, and 100% of chroma is 150.
fn parse_lch(cursor : Cursor) -> Color raise Refused {
  let lightness = parse_term(cursor)
  let chroma = parse_term_after_space(cursor)
  let hue = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  let chroma = chroma.scaled(150.0)
  Color::lch(
    clamp01(lightness.scaled(100.0) / 100.0) * 100.0,
    if chroma.is_nan() {
      chroma
    } else if chroma < 0.0 {
      0.0
    } else {
      chroma
    },
    hue.hue(),
    alpha~,
  )
}

///|
/// `oklab()`: lightness 0–1, and 100% of `a` and `b` is 0.4.
fn parse_oklab(cursor : Cursor) -> Color raise Refused {
  let lightness = parse_term(cursor)
  let a = parse_term_after_space(cursor)
  let b = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::oklab(
    clamp01(lightness.fraction()),
    a.scaled(0.4),
    b.scaled(0.4),
    alpha~,
  )
}

///|
/// `oklch()`: lightness 0–1, chroma from 0, and 100% of chroma is 0.4.
fn parse_oklch(cursor : Cursor) -> Color raise Refused {
  let lightness = parse_term(cursor)
  let chroma = parse_term_after_space(cursor)
  let hue = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::oklch(
    clamp01(lightness.fraction()),
    non_negative(chroma.scaled(0.4)),
    hue.hue(),
    alpha~,
  )
}

///|
/// `color(srgb ...)` and the other spaces it takes. Percentages are fractions of
/// one here, and nothing is clamped: a wide-gamut space is allowed to hold a
/// colour outside itself, and clipping it on the way in would lose the value.
fn parse_color_function(cursor : Cursor) -> Color raise Refused {
  cursor.skip_spaces()
  if !is_name_start(cursor.peek()) {
    raise cursor.unexpected("a colour space")
  }
  let name = cursor.ident()
  let space = match Space::of(name) {
    Some(space) =>
      if space.is_predefined() {
        space
      } else {
        raise cursor.unknown(name.to_owned())
      }
    None => raise cursor.unknown(name.to_owned())
  }
  let first = parse_term_after_space(cursor)
  let second = parse_term_after_space(cursor)
  let third = parse_term_after_space(cursor)
  let alpha = parse_alpha(cursor)
  Color::of(
    space,
    first.fraction(),
    second.fraction(),
    third.fraction(),
    alpha~,
  )
}

///|
/// A keyword: `transparent`, `currentcolor`, or one of the 148 names.
fn parse_keyword(word : StringView, at : Int32) -> Color raise Refused {
  if word.equal_ignore_ascii_case("transparent") {
    return Color::transparent()
  }
  if word.equal_ignore_ascii_case("currentcolor") {
    return Color::current()
  }
  match Color::of_name(word) {
    Some(color) => color
    None => raise Unknown(at~, got=word.to_owned())
  }
}

///|
/// A function call, with the name already read and the opening parenthesis next.
fn parse_function(
  cursor : Cursor,
  name : StringView,
  at : Int32,
) -> Color raise Refused {
  // Whitespace and comments may follow the opening parenthesis, so the first
  // component is read after them rather than at the bracket.
  cursor.skip_spaces()
  let key = name.to_lower()
  let color = if key.equal("rgb") || key.equal("rgba") {
    parse_rgb(cursor, true)
  } else if key.equal("hsl") || key.equal("hsla") {
    parse_hsl(cursor, true)
  } else if key.equal("hwb") {
    parse_hwb(cursor)
  } else if key.equal("lab") {
    parse_lab(cursor)
  } else if key.equal("lch") {
    parse_lch(cursor)
  } else if key.equal("oklab") {
    parse_oklab(cursor)
  } else if key.equal("oklch") {
    parse_oklch(cursor)
  } else if key.equal("color") {
    parse_color_function(cursor)
  } else {
    raise Unknown(at~, got=name.to_owned())
  }
  cursor.skip_spaces()
  if !cursor.eat(0x29) {
    raise cursor.unexpected("the closing parenthesis")
  }
  color
}

///|
/// A `<color>`: everything from the first non-blank to the closing bracket.
pub fn Color::decode(text : StringView) -> Color raise Refused {
  let cursor = Cursor::new(text)
  cursor.skip_spaces()
  let color = if cursor.peek() == 0x23 {
    parse_hex(cursor)
  } else if is_name_start(cursor.peek()) {
    // Kept so that a refusal can point at the name rather than at its end.
    let start = cursor.at
    let word = cursor.ident()
    if cursor.peek() == 0x28 {
      cursor.bump()
      parse_function(cursor, word, start)
    } else {
      parse_keyword(word, start)
    }
  } else {
    raise cursor.unexpected("a colour")
  }
  cursor.skip_spaces()
  if !cursor.done() {
    raise cursor.unexpected("end of input")
  }
  color
}

///|
/// Read a colour, or `None` where the text is not one.
pub fn Color::decode_opt(text : StringView) -> Color? {
  Some(Color::decode(text)) catch {
    _ => None
  }
}
