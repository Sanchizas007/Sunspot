# The App Store screenshot set

Everything in this folder is produced by `../Tools/screenshots.sh`. The images themselves are
not committed — they are large, and one command brings them back. This file is committed,
because it is needed exactly when they have not been brought back yet.

    ../Tools/screenshots.sh            # English, the set that goes to the store
    ../Tools/screenshots.sh de fr      # the other two languages, if a listing ever wants them

## What goes where in App Store Connect

The six numbered frames go in the **iPhone 6.9" Display** slot, in the order they are
numbered — that order is the selling order, not the order of the tabs in the app.

| File | What it shows |
| --- | --- |
| `en/01-today-the-answer-in-hours.png` | The number the whole app exists to produce |
| `en/02-sky-trace-the-skyline.png` | Tracing the roofs and trees — the thing nobody else does |
| `en/03-year-when-full-sun-starts-and-ends.png` | The season in a sentence, then the curve |
| `en/04-plants-what-will-grow-here.png` | The question behind the question |
| `en/05-map-where-the-sun-comes-from.png` | Arrives from, leaves towards, and where it is now |
| `en/06-compare-which-spot-is-better.png` | Three spots ranked, which is half of what is sold |

`in-app-purchase-review-screenshot.png` is **not part of the listing.** It belongs in the
"Review Screenshot" field of the in-app purchase itself, in App Store Connect under
*Monetization → In-App Purchases → Sunspot Full*. It is kept out of the numbered set on
purpose: it carries a price, and anything shown to a buyer with a price on it needs a fresh
review every time that price moves.

## What Apple checks, and what this set already satisfies

- **1320 × 2868**, the 6.9" size. Apple accepts a single 6.9" set and scales it down for the
  smaller devices, so this is the only set that has to exist.
- **No alpha channel.** A PNG with one is refused, and the refusal blames the dimensions
  rather than the transparency. Every frame is flattened to RGB as it is taken and the whole
  folder is checked again at the end of the run.
- **A plausible status bar** — full battery with no charging bolt, no carrier called
  "Simulator", and a clock that agrees with the clock inside the app.

## One frame is worth retaking by hand

`02-sky-trace-the-skyline.png` is the app's only real difference from everything else in the
category, and it is the weakest frame in the set. On a phone there is a garden behind that
overlay; in a simulator there is no camera, so there is a plain gradient behind it instead.
The arc, the sun and the traced skyline are all real and all correct — but the frame sells an
empty blue rectangle.

Take it on the phone, in a garden, on the Sky tab with a skyline already traced, and drop it
in here under the same name. Everything else in the set can be regenerated; that one cannot,
so it is the one worth keeping a copy of somewhere else too.
