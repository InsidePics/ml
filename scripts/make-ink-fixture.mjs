// Writes `fixtures/ink-cat.json`: the word "cat" handwritten as strokes, for
// the digital ink tests (no licence beyond the repository's):
//
//   node scripts/make-ink-fixture.mjs   (from the repository root)
//
// Each stroke is a list of points `{ x, y, t }`: pixels on a 300×120 writing
// area (y down) and milliseconds, as a finger would draw them.
import { writeFileSync } from 'node:fs';

let t = 0;
const point = (x, y) => ({
  x: Math.round(x * 10) / 10,
  y: Math.round(y * 10) / 10,
  t: (t += 12),
});

/** An arc of the circle at (cx, cy), radius r, from angle a to b (degrees,
 *  counter-clockwise on screen, 0 to the right). */
const arc = (cx, cy, r, a, b, steps = 24) =>
  Array.from({ length: steps + 1 }, (_, i) => {
    const angle = ((a + ((b - a) * i) / steps) * Math.PI) / 180;
    return point(cx + r * Math.cos(angle), cy - r * Math.sin(angle));
  });

const line = (x0, y0, x1, y1, steps = 10) =>
  Array.from({ length: steps + 1 }, (_, i) =>
    point(x0 + ((x1 - x0) * i) / steps, y0 + ((y1 - y0) * i) / steps)
  );

const strokes = [];
// c: open to the right.
strokes.push(arc(60, 80, 22, 45, 315));
t += 200;
// a: a closed bowl, then down its right side.
strokes.push([...arc(130, 80, 22, 30, 390), ...line(150, 58, 152, 102, 8)]);
t += 200;
// t: the stem, then the bar.
strokes.push(line(200, 35, 202, 102, 12));
t += 150;
strokes.push(line(185, 60, 222, 60, 8));

writeFileSync(
  'fixtures/ink-cat.json',
  JSON.stringify({
    writingArea: { width: 300, height: 120 },
    text: 'cat',
    strokes,
  }) + '\n'
);
console.log(`wrote fixtures/ink-cat.json (${strokes.length} strokes)`);
