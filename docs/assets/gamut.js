// The gamut page.
//
// The surface, the boundary, the mapped colour and the ΔE curve all come from
// the library compiled to JavaScript: the page asks `slice(lightness)` for
// 1,080 colours and 180 boundary chromas, and `section(css)` for what happened
// to one colour on its way into the gamut. Nothing here converts a colour; the
// only arithmetic is turning chroma into pixels.

const engine = await import("../engine/moonrgba.js").catch(() => null);

// The plot's outer edge, in chroma. sRGB never reaches 0.4 anywhere, so a point
// inside the sliders is always inside the frame, and the empty rim reads as the
// room a gauge has beyond its last mark.
const SCALE = 0.4;
const MARGIN = 18;

const state = { l: 0.7, c: 0.4, h: 30 };

const el = (id) => document.getElementById(id);
const surface = el("surface");
const marks = el("marks");
const curve = el("delta");
const input = el("css");
const root = document.documentElement;

let face = null;
let section = null;
let pending = 0;

if (!engine) {
  const warn = document.createElement("p");
  warn.className = "warn";
  warn.textContent =
    "The compiled library did not load, so the plot is empty. Build it with scripts/engine.sh and reload.";
  document.querySelector(".plot").after(warn);
} else {
  start();
}

function fit(canvas) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const box = canvas.getBoundingClientRect();
  const width = Math.max(1, Math.round(box.width));
  const height = Math.max(1, Math.round(box.height));
  if (canvas.width !== width * dpr || canvas.height !== height * dpr) {
    canvas.width = width * dpr;
    canvas.height = height * dpr;
  }
  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, width, height };
}

function ink(alpha) {
  const value = getComputedStyle(root).getPropertyValue("--ink").trim() || "#2a2722";
  return value.startsWith("#") ? value + Math.round(alpha * 255).toString(16).padStart(2, "0") : value;
}

function geometry(width, height) {
  return { cx: width / 2, cy: height / 2, radius: Math.min(width, height) / 2 - MARGIN };
}

// The surface: six rings of 180 library colours, drawn as 2° wedges. No
// gradient — every pixel is a colour the library computed at this lightness.
function paintSurface() {
  const { ctx, width, height } = fit(surface);
  const { cx, cy, radius } = geometry(width, height);
  ctx.clearRect(0, 0, width, height);

  // The graticule goes down first and the surface on top of it, so the scale
  // shows where nothing is painted and disappears under the colour: graph paper
  // with a shape drawn on it, rather than a shape ruled over.
  ctx.lineWidth = 1;
  for (const ring of [0.1, 0.2, 0.3]) {
    ctx.strokeStyle = ink(0.16);
    ctx.beginPath();
    ctx.arc(cx, cy, (ring / SCALE) * radius, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.strokeStyle = ink(0.08);
  for (let spoke = 0; spoke < 12; spoke++) {
    const angle = (spoke * Math.PI) / 6;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(angle) * radius, cy - Math.sin(angle) * radius);
    ctx.stroke();
  }


  const count = face.bands.length;
  // Wedges are drawn as quads between neighbouring boundary points rather than
  // as arcs: an arc per degree leaves a sawtooth where the radius changes, and
  // the boundary is a polygon of 180 points anyway.
  const at = (radius, angle) => [cx + Math.cos(angle) * radius, cy - Math.sin(angle) * radius];

  for (let band = 0; band < count; band++) {
    const outer = 1 - band / count;
    const inner = 1 - (band + 1) / count;
    const row = face.bands[band];
    for (let index = 0; index < 180; index++) {
      const next = (index + 1) % 180;
      // Each quad runs past its share on every side — a fifth of a degree of
      // angle, a pixel of radius — so that neighbouring fills overlap instead of
      // leaving the hairline that canvas antialiasing puts between them.
      const angle = ((index * 2 - 0.4) * Math.PI) / 180;
      const angleNext = ((next * 2 + 0.4) * Math.PI) / 180;
      const outerNow = (face.chroma[index] * outer) / SCALE * radius + 0.75;
      const outerNext = (face.chroma[next] * outer) / SCALE * radius + 0.75;
      const innerNow = Math.max(0, (face.chroma[index] * inner) / SCALE * radius - 0.75);
      const innerNext = Math.max(0, (face.chroma[next] * inner) / SCALE * radius - 0.75);

      const a = at(outerNow, angle);
      const b = at(outerNext, angleNext);
      const c = at(innerNext, angleNext);
      const d = at(innerNow, angle);

      ctx.beginPath();
      ctx.moveTo(a[0], a[1]);
      ctx.lineTo(b[0], b[1]);
      ctx.lineTo(c[0], c[1]);
      ctx.lineTo(d[0], d[1]);
      ctx.closePath();
      ctx.fillStyle = row[index];
      ctx.fill();
    }
  }

  // The outline itself, once, so the shape has an edge rather than a fringe.
  ctx.beginPath();
  for (let index = 0; index < 180; index++) {
    const angle = (index * 2 * Math.PI) / 180;
    const edge = (face.chroma[index] / SCALE) * radius;
    const [x, y] = at(edge, angle);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
  ctx.strokeStyle = ink(0.22);
  ctx.lineWidth = 1;
  ctx.stroke();

}

// The measurement: where the colour is, where clipping would put it, and what
// the library actually returns.
function paintMarks() {
  const { ctx, width, height } = fit(marks);
  const { cx, cy, radius } = geometry(width, height);
  ctx.clearRect(0, 0, width, height);

  const angle = (state.h * Math.PI) / 180;
  const edge = (section.edge / SCALE) * radius;
  const asked = (state.c / SCALE) * radius;
  const mapped = (section.mapped.c / SCALE) * radius;
  const mappedAngle = (section.mapped.h * Math.PI) / 180;

  // The line the reduction travels along: constant lightness, constant hue.
  ctx.strokeStyle = ink(0.35);
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.lineTo(cx + Math.cos(angle) * radius, cy - Math.sin(angle) * radius);
  ctx.stroke();

  // Where the boundary is on that line.
  ctx.strokeStyle = ink(0.55);
  ctx.beginPath();
  ctx.moveTo(cx + Math.cos(angle) * (edge - 4), cy - Math.sin(angle) * (edge - 4));
  ctx.lineTo(cx + Math.cos(angle) * (edge + 4), cy - Math.sin(angle) * (edge + 4));
  ctx.stroke();

  // The colour asked for: hollow when no screen can show it, filled when one can.
  const px = cx + Math.cos(angle) * asked;
  const py = cy - Math.sin(angle) * asked;
  ctx.beginPath();
  ctx.arc(px, py, 5, 0, Math.PI * 2);
  ctx.fillStyle = section.inside ? section.mapped.hex : "rgba(0,0,0,0)";
  ctx.fill();
  ctx.strokeStyle = ink(0.75);
  ctx.lineWidth = section.inside ? 1 : 1.5;
  ctx.stroke();

  // What the library returns: a square, filled with the colour itself.
  const mx = cx + Math.cos(mappedAngle) * mapped;
  const my = cy - Math.sin(mappedAngle) * mapped;
  ctx.fillStyle = section.mapped.hex;
  ctx.strokeStyle = ink(0.85);
  ctx.lineWidth = 1.25;
  ctx.beginPath();
  ctx.rect(mx - 4, my - 4, 8, 8);
  ctx.fill();
  ctx.stroke();
}

// ΔE OK between a candidate and the colour clipping would give, sampled along
// the line. The 0.02 rule the algorithm uses is drawn as a rule, so the page
// shows the test instead of describing it.
function paintCurve() {
  const { ctx, width, height } = fit(curve);
  ctx.clearRect(0, 0, width, height);

  const left = 4;
  const right = width - 30;
  const bottom = height - 12;
  const top = 8;
  const points = section.curve;
  const reach = points[points.length - 1].c || 1;
  const peak = Math.max(0.05, ...points.map((point) => point.de));

  const x = (c) => left + (c / reach) * (right - left);
  const y = (de) => bottom - (de / peak) * (bottom - top);

  ctx.strokeStyle = ink(0.12);
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(left, bottom + 0.5);
  ctx.lineTo(right, bottom + 0.5);
  ctx.stroke();

  // The just-noticeable difference.
  ctx.setLineDash([3, 3]);
  ctx.strokeStyle = ink(0.35);
  ctx.beginPath();
  ctx.moveTo(left, y(0.02) + 0.5);
  ctx.lineTo(right, y(0.02) + 0.5);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = ink(0.5);
  ctx.font = "9px 'JetBrains Mono', monospace";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("0.02", right + 4, y(0.02));
  ctx.textAlign = "right";
  ctx.fillText(peak.toFixed(2), left + 18, top + 4);

  // The curve, in the colour under inspection.
  const swatch = getComputedStyle(root).getPropertyValue("--swatch").trim();
  ctx.strokeStyle = swatch;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  points.forEach((point, index) => {
    const px = x(point.c);
    const py = y(point.de);
    if (index === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  });
  ctx.stroke();

  // Where this colour sits on that curve.
  const at = x(Math.min(state.c, reach));
  const value = interpolate(points, state.c);
  ctx.beginPath();
  ctx.arc(at, y(value), 2.6, 0, Math.PI * 2);
  ctx.fillStyle = swatch;
  ctx.fill();
  ctx.strokeStyle = ink(0.6);
  ctx.lineWidth = 1;
  ctx.stroke();
}

function interpolate(points, c) {
  for (let index = 1; index < points.length; index++) {
    if (c <= points[index].c) {
      const a = points[index - 1];
      const b = points[index];
      const span = b.c - a.c || 1;
      return a.de + ((c - a.c) / span) * (b.de - a.de);
    }
  }
  return points[points.length - 1].de;
}

function show() {
  const outside = !section.inside;
  el("state").textContent = outside ? "outside sRGB" : "inside sRGB";
  el("state").dataset.out = outside ? "1" : "0";
  el("moved").textContent = section.delta.toFixed(4);
  el("rl").textContent = section.l.toFixed(4);
  el("rc").textContent = section.c.toFixed(4);
  el("rh").textContent = section.h.toFixed(2) + "°";
  el("re").textContent = section.edge.toFixed(4);
  el("mappedHex").textContent = section.mapped.hex;
  el("mappedLch").textContent =
    `oklch(${section.mapped.l} ${section.mapped.c} ${section.mapped.h})`;
  el("mappedSwatch").style.background = section.mapped.hex;
  root.style.setProperty("--swatch", section.mapped.hex);

  el("sl").value = String(state.l);
  el("sc").value = String(state.c);
  el("sh").value = String(state.h);
  el("slOut").textContent = state.l.toFixed(3);
  el("scOut").textContent = state.c.toFixed(3);
  el("shOut").textContent = Math.round(state.h) + "°";

  paintMarks();
  paintCurve();
}

function update(remapFace) {
  if (remapFace) {
    face = JSON.parse(engine.slice(state.l));
    paintSurface();
  }
  section = JSON.parse(engine.section(`oklch(${state.l} ${state.c} ${state.h})`));
  if (!section.ok) return;
  show();
}

function schedule(remapFace) {
  if (pending) cancelAnimationFrame(pending);
  pending = requestAnimationFrame(() => {
    pending = 0;
    update(remapFace);
  });
}

function start() {
  // Where the point sits, from a pointer over the plot: the angle is the hue,
  // the distance is the chroma. Dragging never changes the lightness — that is
  // the slider's job, because it is the axis the plot does not have.
  const place = (event) => {
    const box = marks.getBoundingClientRect();
    const cx = box.left + box.width / 2;
    const cy = box.top + box.height / 2;
    const radius = Math.min(box.width, box.height) / 2 - MARGIN;
    const dx = event.clientX - cx;
    const dy = event.clientY - cy;
    const hue = ((Math.atan2(-dy, dx) * 180) / Math.PI + 360) % 360;
    const chroma = Math.min(0.4, (Math.hypot(dx, dy) / radius) * SCALE);
    state.h = hue;
    state.c = Math.max(0, chroma);
    schedule(false);
  };

  let dragging = false;
  marks.addEventListener("pointerdown", (event) => {
    dragging = true;
    marks.setPointerCapture(event.pointerId);
    place(event);
  });
  marks.addEventListener("pointermove", (event) => {
    if (dragging) place(event);
  });
  for (const done of ["pointerup", "pointercancel"]) {
    marks.addEventListener(done, () => {
      dragging = false;
    });
  }

  el("sl").addEventListener("input", (event) => {
    state.l = Number(event.target.value);
    schedule(true);
  });
  el("sc").addEventListener("input", (event) => {
    state.c = Number(event.target.value);
    schedule(false);
  });
  el("sh").addEventListener("input", (event) => {
    state.h = Number(event.target.value);
    schedule(false);
  });

  const adopt = () => {
    const value = input.value.trim();
    const read = JSON.parse(engine.section(value));
    if (!read.ok) {
      input.setAttribute("aria-invalid", "true");
      return;
    }
    input.removeAttribute("aria-invalid");
    state.l = read.l;
    state.c = Math.min(0.4, Math.max(0, read.c));
    state.h = read.h;
    schedule(true);
  };
  input.addEventListener("change", adopt);
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      adopt();
      input.blur();
    }
  });

  const linked = new URLSearchParams(location.search).get("c");
  if (linked) input.value = linked;
  if (linked) adopt();
  else schedule(true);

  // A resize changes the canvas size, and with it every radius, so the surface
  // is painted again rather than stretched.
  let resize = 0;
  addEventListener("resize", () => {
    cancelAnimationFrame(resize);
    resize = requestAnimationFrame(() => update(true));
  });
}
