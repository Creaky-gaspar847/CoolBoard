const field = document.querySelector("[data-pixel-field]");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (field) {
  const count = 24 * 10;
  const seedIndexes = new Set([12, 37, 58, 83, 109, 132, 157, 181, 214]);
  const pixels = [];

  for (let index = 0; index < count; index += 1) {
    const pixel = document.createElement("span");
    pixel.className = seedIndexes.has(index) ? "pixel is-seed" : "pixel";
    field.appendChild(pixel);
    pixels.push(pixel);
  }

  if (!reducedMotion) {
    field.addEventListener("pointermove", (event) => {
      const rect = field.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;

      pixels.forEach((pixel) => {
        const pixelRect = pixel.getBoundingClientRect();
        const px = pixelRect.left - rect.left + pixelRect.width / 2;
        const py = pixelRect.top - rect.top + pixelRect.height / 2;
        const distance = Math.hypot(px - x, py - y);
        pixel.classList.toggle("is-lit", distance < 76);
      });
    });

    field.addEventListener("pointerleave", () => {
      pixels.forEach((pixel) => pixel.classList.remove("is-lit"));
    });
  }
}
