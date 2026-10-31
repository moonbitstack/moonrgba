// The page scroll bar shows no thumb at the very top and stays from the first
// pixel of scroll.
const root = document.documentElement;
const scrolled = () => root.classList.toggle("scrolled", scrollY > 0);
addEventListener("scroll", scrolled, { passive: true });
scrolled();
