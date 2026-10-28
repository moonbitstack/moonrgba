// The itinerary marks the chapter you are reading.
//
// No framework and no observer chain: the chapters are in document order, so the
// current one is the last whose top has passed the fold, and that is a loop over
// a handful of elements on scroll.

const links = new Map(
  [...document.querySelectorAll(".itinerary a[href^='#']")].map((link) => [
    link.getAttribute("href").slice(1),
    link,
  ]),
);

const chapters = [...document.querySelectorAll(".chapter[id]")].filter((section) =>
  links.has(section.id),
);

function mark() {
  let current = chapters[0];
  for (const chapter of chapters) {
    if (chapter.getBoundingClientRect().top <= 120) {
      current = chapter;
    }
  }
  for (const [id, link] of links) {
    if (id === current?.id) {
      link.setAttribute("aria-current", "true");
    } else {
      link.removeAttribute("aria-current");
    }
  }
}

if (chapters.length) {
  mark();
  addEventListener("scroll", mark, { passive: true });
  addEventListener("resize", mark);
}
