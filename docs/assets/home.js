// The board's behaviour. Every value it prints comes from the library compiled to
// JavaScript, so what the page shows and what the package computes are the same
// thing — the page only decides how to lay it out.

const engine = await import("../engine/moonrgba.js").catch(() => null);

const state = { hue: 210, sat: 60, light: 45 };

const el = (id) => document.getElementById(id);
const dial = el("dial");
const wheel = el("wheel");
const hub = el("hub");
const puck = el("puck");
const input = el("css");
const valueText = el("value");
const swatch = el("swatch");
const swatchLabel = el("swatchLabel");
const note = el("note");
const sat = el("sat");
const light = el("light");
const satOut = el("satOut");
const lightOut = el("lightOut");

const root = document.documentElement;

if (!engine) {
  const warn = document.createElement("p");
  warn.className = "warn";
  warn.textContent =
    "The compiled library did not load, so the dial and the fields are still. " +
    "Build it with scripts/engine.sh and reload; everything else on this page still holds.";
  document.querySelector(".lede").after(warn);
  dial.removeAttribute("tabindex");
} else {
  start();
}

function css() {
  return `hsl(${state.hue} ${state.sat}% ${state.light}%)`;
}

// The wheel turns under a fixed read head: the hue at the head is (360 - rotation).
function paintWheel() {
  wheel.style.transform = `rotate(${-state.hue}deg)`;
  // The puck rides the head; its distance from the hub is the saturation. The
  // hub is 44% wide, so the rim of it sits 22% from the centre, and the rim of
  // the well 44%.
  puck.style.top = `${28 - 22 * (state.sat / 100)}%`;
  dial.setAttribute("aria-valuenow", String(state.hue));
  dial.setAttribute("aria-valuetext", `${state.hue} degrees`);
}

function show(facts) {
  const c = facts.contrast;
  const light = Math.abs(c.apcaWhite) >= Math.abs(c.apcaBlack);
  const ink = light ? "#fffdf8" : "#1b1a17";
  root.style.setProperty("--swatch", facts.hex);
  root.style.setProperty("--swatch-ink", ink);

  // The plate shows what a screen would show: the colour itself when it fits,
  // and the gamut-mapped one when it does not, which is what the label says.
  swatch.style.background = facts.gamut.srgb ? facts.shortest : facts.gamut.mapped;
  hub.style.background = facts.hex;
  hub.style.color = ink;
  el("hubDeg").textContent = `${state.hue}°`;
  el("hubCode").textContent = facts.hex;

  note.hidden = facts.gamut.srgb;
  swatchLabel.textContent = facts.gamut.srgb
    ? facts.name
      ? `${facts.name} · sRGB`
      : "sRGB"
    : `outside sRGB · mapped ${facts.gamut.mapped}`;

  valueText.textContent = facts.shortest;
  el("wcagWhite").textContent = c.wcagWhite.toFixed(2);
  el("wcagBlack").textContent = c.wcagBlack.toFixed(2);
  el("apcaWhite").textContent = signed(c.apcaWhite, 1);
  el("apcaBlack").textContent = signed(c.apcaBlack, 1);
  el("ansi16").textContent = facts.terminal.ansi16;
  el("ansi256").textContent = facts.terminal.ansi256;
  el("rgb8").textContent = facts.terminal.rgb8;
  el("ansiDot").style.setProperty("--slot", facts.terminal.ansi256Hex);

  el("spellings").innerHTML = facts.spellings.map((row) => ledger(row.label, row.css)).join("");
  el("spaces").innerHTML = facts.spaces.map((row) => ledger(row.space, row.value)).join("");
}

// A typographic minus, so a negative contrast reads as a number and not as a
// hyphen between two others.
function signed(value, places) {
  const text = value.toFixed(places);
  return text.startsWith("-") ? `−${text.slice(1)}` : text;
}

function escape(text) {
  return String(text).replace(/[&<>]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[ch]);
}

function ledger(name, value) {
  return `<div class="row"><span class="name">${escape(name)}</span><span class="data">${escape(value)}</span></div>`;
}

function start() {
  let frame = 0;

  const update = () => {
    frame = 0;
    satOut.textContent = `${state.sat}%`;
    lightOut.textContent = `${state.light}%`;
    sat.value = String(state.sat);
    light.value = String(state.light);
    paintWheel();
    const facts = JSON.parse(engine.facts(css()));
    if (!facts.ok) return;
    show(facts);
  };

  const schedule = () => {
    if (!frame) frame = requestAnimationFrame(update);
  };

  // Dragging the wheel: whatever hue was under the finger stays under it, so the
  // wheel turns with the hand and the head stays where it is.
  let dragging = null;

  const angleAt = (event) => {
    const box = dial.getBoundingClientRect();
    const dx = event.clientX - (box.left + box.width / 2);
    const dy = event.clientY - (box.top + box.height / 2);
    return (Math.atan2(dx, -dy) * 180) / Math.PI;
  };

  dial.addEventListener("pointerdown", (event) => {
    dragging = { hue: state.hue, angle: angleAt(event) };
    dial.setPointerCapture(event.pointerId);
  });

  dial.addEventListener("pointermove", (event) => {
    if (!dragging) return;
    const turned = angleAt(event) - dragging.angle;
    state.hue = Math.round((((dragging.hue - turned) % 360) + 360) % 360);
    schedule();
  });

  const release = () => {
    dragging = null;
  };
  dial.addEventListener("pointerup", release);
  dial.addEventListener("pointercancel", release);

  dial.addEventListener("keydown", (event) => {
    const step = event.shiftKey ? 10 : 1;
    const moves = {
      ArrowRight: step,
      ArrowUp: step,
      ArrowLeft: -step,
      ArrowDown: -step,
      PageUp: 10,
      PageDown: -10,
    };
    if (event.key in moves) {
      state.hue = (((state.hue + moves[event.key]) % 360) + 360) % 360;
      schedule();
      event.preventDefault();
    } else if (event.key === "Home") {
      state.hue = 0;
      schedule();
      event.preventDefault();
    } else if (event.key === "End") {
      state.hue = 359;
      schedule();
      event.preventDefault();
    }
  });

  sat.addEventListener("input", () => {
    state.sat = Number(sat.value);
    schedule();
  });

  light.addEventListener("input", () => {
    state.light = Number(light.value);
    schedule();
  });

  // Typing a value the library can read moves the wheel to that colour; one it
  // cannot read is refused, and the field says so rather than pretending.
  const adopt = () => {
    const facts = JSON.parse(engine.facts(input.value.trim() || css()));
    if (!facts.ok) {
      input.setAttribute("aria-invalid", "true");
      valueText.textContent = "not a colour";
      swatch.style.background = "var(--bone-2)";
      return;
    }
    input.removeAttribute("aria-invalid");
    const row = facts.spaces.find((entry) => entry.space === "hsl");
    const parts = row.value.split(" ");
    const clamp = (value) => Math.max(0, Math.min(100, Math.round(value)));
    if (parts[0] !== "none") state.hue = Math.round(Number(parts[0])) % 360;
    if (parts[1] !== "none") state.sat = clamp(Number(parts[1].replace("%", "")));
    if (parts[2] !== "none") state.light = clamp(Number(parts[2].replace("%", "")));
    sat.value = String(state.sat);
    light.value = String(state.light);
    satOut.textContent = `${state.sat}%`;
    lightOut.textContent = `${state.light}%`;
    paintWheel();
    show(facts);
  };

  input.addEventListener("change", adopt);
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      adopt();
      input.blur();
    }
  });

  // A colour can be linked to: `?c=oklch(0.7 0.15 200)` opens the board on it,
  // which is also how the page is checked against a value the dial cannot reach.
  const linked = new URLSearchParams(location.search).get("c");
  if (linked) {
    input.value = linked;
    adopt();
  } else {
    update();
  }

  const copy = el("copy");
  copy.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(valueText.textContent);
      copy.textContent = "copied";
      copy.dataset.done = "1";
      setTimeout(() => {
        copy.textContent = "copy";
        delete copy.dataset.done;
      }, 1200);
    } catch {
      copy.textContent = "select it";
    }
  });
}
