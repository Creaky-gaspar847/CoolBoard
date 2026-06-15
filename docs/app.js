const canvas = document.querySelector("[data-pixel-field]");
const hero = document.querySelector(".hero");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const context = canvas instanceof HTMLCanvasElement ? canvas.getContext("2d", { alpha: true }) : null;

if (canvas instanceof HTMLCanvasElement && context && hero) {
  const baseCanvas = document.createElement("canvas");
  const baseContext = baseCanvas.getContext("2d", { alpha: true });
  let bounds = { width: 0, height: 0, left: 0, top: 0 };
  let dpr = 1;
  let pixelSize = 3;
  let pixelGap = 5;
  let stride = 8;
  let columns = 0;
  let rows = 0;
  let animationFrame = 0;
  let previousPoint = null;
  let splashes = [];

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

  const snap = (value) => Math.round(value / stride) * stride;

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
    const rect = canvas.getBoundingClientRect();
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    bounds = {
      width: Math.max(1, rect.width),
      height: Math.max(1, rect.height),
      left: rect.left,
      top: rect.top
    };
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
    drawBaseGrid();
    draw();
  };

  const makeDrops = (x, y, direction) => {
    const count = Math.min(132, Math.max(68, Math.round(bounds.width / 12)));
    const radius = Math.min(320, Math.max(150, bounds.width * 0.23));
    const drops = [];

    for (let index = 0; index < count; index += 1) {
      const seed = Math.random();
      const sideSpray = (Math.random() - 0.5) * Math.PI * 1.18;
      const reverseSpray = Math.random() > 0.74 ? Math.PI + (Math.random() - 0.5) * 0.9 : 0;
      const angle = direction + sideSpray + reverseSpray;
      const reach = (0.08 + Math.pow(Math.random(), 1.7) * 0.92) * radius;
      const skew = 0.5 + Math.random() * 0.75;
      drops.push({
        dx: Math.cos(angle) * reach,
        dy: Math.sin(angle) * reach * skew,
        delay: Math.random() * 120,
        alpha: 0.48 + seed * 0.52,
        size: seed > 0.84 ? pixelSize * 2.2 : pixelSize * 1.2,
        hold: 980 + Math.random() * 520
      });
    }

    drops.push(
      { dx: 0, dy: 0, delay: 0, alpha: 0.96, size: pixelSize * 2.4, hold: 640 },
      { dx: stride * 2, dy: -stride, delay: 24, alpha: 0.86, size: pixelSize * 1.6, hold: 760 },
      { dx: -stride, dy: stride * 2, delay: 44, alpha: 0.78, size: pixelSize * 1.5, hold: 760 }
    );

    return drops;
  };

  const addSplash = (event) => {
    const now = performance.now();
    const x = event.clientX - bounds.left;
    const y = event.clientY - bounds.top;
    if (x < -40 || y < -40 || x > bounds.width + 40 || y > bounds.height + 40) return;

    const previous = previousPoint || { x: bounds.width * 0.5, y: bounds.height * 0.5, at: now - 80 };
    const moved = Math.hypot(x - previous.x, y - previous.y);
    if (now - previous.at < 36 && moved < 34) return;

    const direction = moved > 4
      ? Math.atan2(y - previous.y, x - previous.x)
      : Math.atan2(y - bounds.height * 0.5, x - bounds.width * 0.5);

    previousPoint = { x, y, at: now };
    splashes.push({ x, y, at: now, drops: makeDrops(x, y, direction) });
    splashes = splashes.slice(-5);

    if (!animationFrame) {
      animationFrame = requestAnimationFrame(draw);
    }
  };

  const draw = (now = performance.now()) => {
    context.clearRect(0, 0, bounds.width, bounds.height);
    context.drawImage(baseCanvas, 0, 0, bounds.width, bounds.height);

    if (!reducedMotion) {
      splashes.forEach((splash) => {
        splash.drops.forEach((drop) => {
          const age = now - splash.at - drop.delay;
          if (age < 0 || age > drop.hold) return;

          const progress = age / drop.hold;
          const easeOut = 1 - Math.pow(1 - progress, 2.6);
          const fade = Math.pow(1 - progress, 1.9);
          const x = snap(splash.x + drop.dx * easeOut);
          const y = snap(splash.y + drop.dy * easeOut);
          if (x < 0 || y < 0 || x > bounds.width || y > bounds.height) return;

          context.fillStyle = `rgba(255, 255, 255, ${(drop.alpha * fade).toFixed(3)})`;
          context.fillRect(x, y, drop.size, drop.size);
        });
      });
    }

    splashes = splashes.filter((splash) => now - splash.at <= 1640);
    if (splashes.length > 0) {
      animationFrame = requestAnimationFrame(draw);
    } else {
      animationFrame = 0;
    }
  };

  resizeCanvas();
  window.addEventListener("resize", resizeCanvas, { passive: true });

  if (!reducedMotion) {
    hero.addEventListener("pointermove", addSplash, { passive: true });
  }
}
