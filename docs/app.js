const canvas = document.querySelector("[data-pixel-field]");
const hero = document.querySelector(".hero");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const context = canvas instanceof HTMLCanvasElement ? canvas.getContext("2d", { alpha: true }) : null;

if (canvas instanceof HTMLCanvasElement && context && hero) {
  const baseCanvas = document.createElement("canvas");
  const baseContext = baseCanvas.getContext("2d", { alpha: true });
  const activePixels = new Map();
  let bounds = { width: 0, height: 0, left: 0, top: 0 };
  let dpr = 1;
  let pixelSize = 3;
  let pixelGap = 5;
  let stride = 8;
  let columns = 0;
  let rows = 0;
  let animationFrame = 0;
  let previousPoint = null;

  const numericStyle = (name, fallback) => {
    const value = Number.parseFloat(getComputedStyle(canvas).getPropertyValue(name));
    return Number.isFinite(value) ? value : fallback;
  };

  const hash = (column, row) => {
    const value = Math.sin(column * 127.1 + row * 311.7) * 43758.5453;
    return value - Math.floor(value);
  };

  const baseAlpha = (column, row) => {
    const value = hash(column, row);
    if (value > 0.985) return 0.18;
    if (value > 0.93) return 0.085;
    return 0.022;
  };

  const refreshBounds = () => {
    const rect = canvas.getBoundingClientRect();
    bounds = {
      width: Math.max(1, rect.width),
      height: Math.max(1, rect.height),
      left: rect.left,
      top: rect.top
    };
  };

  const drawBaseGrid = () => {
    if (!baseContext) return;

    baseContext.clearRect(0, 0, bounds.width, bounds.height);

    for (let row = 0; row < rows; row += 1) {
      for (let column = 0; column < columns; column += 1) {
        const alpha = baseAlpha(column, row);
        if (alpha < 0.024) continue;
        baseContext.fillStyle = `rgba(255, 255, 255, ${alpha.toFixed(3)})`;
        baseContext.fillRect(column * stride, row * stride, pixelSize, pixelSize);
      }
    }
  };

  const resizeCanvas = () => {
    refreshBounds();
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    pixelSize = numericStyle("--pixel-size", 3);
    pixelGap = numericStyle("--pixel-gap", 5);
    stride = pixelSize + pixelGap;
    columns = Math.max(1, Math.floor(bounds.width / stride));
    rows = Math.max(1, Math.floor(bounds.height / stride));

    [canvas, baseCanvas].forEach((surface) => {
      surface.width = Math.floor(bounds.width * dpr);
      surface.height = Math.floor(bounds.height * dpr);
      surface.style.width = `${bounds.width}px`;
      surface.style.height = `${bounds.height}px`;
    });

    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    baseContext?.setTransform(dpr, 0, 0, dpr, 0, 0);
    activePixels.clear();
    drawBaseGrid();
    draw();
  };

  const setActivePixel = (column, row, strength, now) => {
    if (column < 0 || row < 0 || column >= columns || row >= rows) return;

    const key = `${column}:${row}`;
    const noise = hash(column + 19, row + 23);
    const existing = activePixels.get(key);
    const nextStrength = Math.min(1, strength * (0.7 + noise * 0.42));
    const nextPixel = {
      column,
      row,
      startedAt: now,
      delay: noise * 95,
      hold: 620 + noise * 360,
      strength: nextStrength,
      size: nextStrength > 0.82 ? pixelSize * 1.55 : pixelSize
    };

    if (!existing || existing.strength < nextStrength || now - existing.startedAt > 220) {
      activePixels.set(key, nextPixel);
    }
  };

  const activatePixels = (event) => {
    refreshBounds();

    const x = event.clientX - bounds.left;
    const y = event.clientY - bounds.top;
    if (x < 0 || y < 0 || x > bounds.width || y > bounds.height) return;

    const now = performance.now();
    const previous = previousPoint;
    const moved = previous ? Math.hypot(x - previous.x, y - previous.y) : Infinity;
    if (previous && now - previous.at < 48) return;
    if (previous && moved < stride * 1.6) return;

    previousPoint = { x, y, at: now };

    const centerColumn = Math.round(x / stride);
    const centerRow = Math.round(y / stride);
    const radius = window.innerWidth <= 560 ? 5 : 7;

    for (let row = centerRow - radius; row <= centerRow + radius; row += 1) {
      for (let column = centerColumn - radius; column <= centerColumn + radius; column += 1) {
        const dx = column - centerColumn;
        const dy = row - centerRow;
        const distance = Math.hypot(dx * 0.92, dy * 1.08);
        const noise = hash(column * 3 + centerColumn, row * 5 + centerRow);
        const irregularRadius = radius * (0.58 + noise * 0.42);
        const isCore = distance <= 1.35;
        const isBody = distance <= irregularRadius && noise > 0.26;
        const isEdge = distance <= radius && noise > 0.76;

        if (!isCore && !isBody && !isEdge) continue;

        const falloff = Math.max(0, 1 - distance / Math.max(1, radius));
        const strength = isCore ? 0.96 : Math.max(0.28, falloff * (0.64 + noise * 0.36));
        setActivePixel(column, row, strength, now);
      }
    }

    if (!animationFrame) {
      animationFrame = requestAnimationFrame(draw);
    }
  };

  const draw = (now = performance.now()) => {
    context.clearRect(0, 0, bounds.width, bounds.height);
    context.drawImage(baseCanvas, 0, 0, bounds.width, bounds.height);

    if (!reducedMotion) {
      activePixels.forEach((pixel, key) => {
        const age = now - pixel.startedAt - pixel.delay;
        if (age < 0) return;

        if (age > pixel.hold) {
          activePixels.delete(key);
          return;
        }

        const rise = Math.min(1, age / 180);
        const fade = Math.pow(1 - age / pixel.hold, 1.45);
        const alpha = Math.min(0.92, pixel.strength * rise * fade);
        if (alpha <= 0.01) return;

        context.fillStyle = `rgba(255, 255, 255, ${alpha.toFixed(3)})`;
        context.fillRect(pixel.column * stride, pixel.row * stride, pixel.size, pixel.size);
      });
    }

    if (activePixels.size > 0) {
      animationFrame = requestAnimationFrame(draw);
    } else {
      animationFrame = 0;
    }
  };

  resizeCanvas();
  window.addEventListener("resize", resizeCanvas, { passive: true });
  window.addEventListener("scroll", refreshBounds, { passive: true });

  if (!reducedMotion) {
    hero.addEventListener("pointermove", activatePixels, { passive: true });
  }
}
