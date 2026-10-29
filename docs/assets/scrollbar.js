// The page's scroll bar shows no thumb while the page is at its top.
const root = document.documentElement;
const sync = () => root.classList.toggle("at-top", scrollY <= 0);
addEventListener("scroll", sync, { passive: true });
sync();
