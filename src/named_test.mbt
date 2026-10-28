// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The 148 names, both ways round.

///|
test "there are exactly 148 names, and they are in order" {
  assert_eq(@moonrgba.names_count(), 148)
  let all = @moonrgba.names_all()
  let mut previous : StringView = ""
  for name in all {
    let ordered = previous.is_empty() || previous.lexical_compare(name) < 0
    assert_true(ordered, msg="\{previous} before \{name}")
    previous = name
  }
  // The eight that people look for first, and the two spellings that differ.
  for
    name in [
      "black", "white", "red", "rebeccapurple", "gray", "grey", "aqua", "cyan",
    ] {
    assert_true(@moonrgba.Color::of_name(name) is Some(_), msg=name)
  }
}

///|
/// Every name reads to the colour the table holds, and writes back to a name.
test "every name round-trips through the parser and the writer" {
  for name in @moonrgba.names_all() {
    let color = match @moonrgba.Color::of_name(name) {
      Some(color) => color
      None => abort("no colour for " + name.to_owned())
    }
    // Reading the name gives the same colour the table does.
    let read_back = read(name)
    assert_true(near_components(read_back, color.components(), 0.0), msg=name)
    // And writing it as a name gives a name for the same colour, which is not
    // necessarily the same name: `grey` is `gray` spelled the other way.
    let written = match color.name() {
      Some(written) => written
      None => abort("no name for " + name.to_owned())
    }
    let again = read(written)
    assert_true(near_components(again, color.components(), 0.0), msg=name)
    // The keyword is case insensitive at both ends.
    assert_true(@moonrgba.Color::of_name(name.to_upper()) is Some(_), msg=name)
  }
}

///|
/// Where several names share a colour, the shortest wins, and a tie goes to the
/// one that comes first in the table.
test "the shortest name for a colour wins" {
  // aqua and cyan are the same colour and the same length.
  assert_eq(@moonrgba.Color::rgb(0, 255, 255).name(), Some("aqua"))
  // gray and grey likewise.
  assert_eq(@moonrgba.Color::rgb(128, 128, 128).name(), Some("gray"))
  // fuchsia and magenta are both seven letters.
  assert_eq(@moonrgba.Color::rgb(255, 0, 255).name(), Some("fuchsia"))
  assert_eq(@moonrgba.Color::rgb(255, 0, 0).name(), Some("red"))
  assert_eq(@moonrgba.Color::rgb(0, 0, 0).name(), Some("black"))
}

///|
/// A name is one of 148 exact colours, not a neighbourhood: a colour one byte
/// away has no name, and neither has a transparent one.
test "a colour has a name only when it is exactly that colour" {
  assert_eq(@moonrgba.Color::rgb(254, 0, 0).name(), None)
  assert_eq(@moonrgba.Color::rgb(255, 0, 0, alpha=0.5).name(), None)
  // The same colour in another space does have the name: it is the colour that
  // is named, not the way it is written.
  assert_eq(@moonrgba.Color::rgb(255, 0, 0).to_oklch().name(), Some("red"))
  assert_eq(@moonrgba.Color::lab(50.0, 0.0, 0.0).name(), None)
}

///|
test "a name is not a colour when it is not one of the 148" {
  for name in ["", "reddish", "light-red", "current-colour", "0xff0000", "rgb"] {
    assert_true(@moonrgba.Color::of_name(name) is None, msg=name)
  }
}
