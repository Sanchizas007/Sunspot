#!/usr/bin/env python3
"""Builds the pages that must exist before Sunplot can be submitted.

    python3 Tools/build-site.py

Output goes to docs/, which is what GitHub Pages serves from this repository:

    docs/index.html            what the app is
    docs/privacy/index.html    privacy policy   (App Review will not accept a submission
                               without a reachable one)
    docs/support/index.html    support contact
    docs/terms/index.html      terms, pointing at Apple's standard licence

Generated rather than hand-written so the four pages cannot drift apart in wording or
appearance, and so the support address lives in exactly one place.
"""

from pathlib import Path

APP = "Sunplot"
SUPPORT_EMAIL = "zhvnir1345@yahoo.com"
REPO = "https://github.com/Sanchizas007/Sunplot"
# Кто лицензирует приложение. Apple's standard EULA calls this the Application Provider, and
# the store listing, the licence in the repository and these pages must all name the same one.
LICENSOR = "Olexandr Zhovnir"
SITE = "https://sanchizas007.github.io/Sunplot"
UPDATED = "29 August 2026"

# Sampled from the app's own icon.
STYLE = """
:root {
  --ink: #241a12; --muted: #6b5a4c; --rule: #e8ddd2;
  --page: #fffaf4; --card: #ffffff; --accent: #f36511;
}
@media (prefers-color-scheme: dark) {
  :root {
    --ink: #f6ece2; --muted: #b3a294; --rule: #33291f;
    --page: #16110c; --card: #1f1811; --accent: #fda43a;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--page); color: var(--ink);
  font: 17px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  -webkit-text-size-adjust: 100%;
}
.wrap { max-width: 44rem; margin: 0 auto; padding: 3rem 1.25rem 5rem; }
a { color: var(--accent); }
h1 { font-size: clamp(1.9rem, 5vw, 2.6rem); line-height: 1.15; margin: 0 0 .4rem; letter-spacing: -.02em; }
h2 { font-size: 1.2rem; margin: 2.4rem 0 .6rem; letter-spacing: -.01em; }
h3 { font-size: 1.02rem; margin: 1.8rem 0 .4rem; }
p, li { color: var(--ink); }
.lede { font-size: 1.12rem; color: var(--muted); margin: 0 0 2rem; }
.card { background: var(--card); border: 1px solid var(--rule); border-radius: 14px; padding: 1.25rem 1.4rem; margin: 1.5rem 0; }
nav { display: flex; gap: 1.1rem; flex-wrap: wrap; margin-bottom: 2.5rem; font-size: .95rem; }
nav a { color: var(--muted); text-decoration: none; }
nav a:hover, nav a[aria-current] { color: var(--accent); }
footer { margin-top: 3.5rem; padding-top: 1.25rem; border-top: 1px solid var(--rule); color: var(--muted); font-size: .9rem; }
ul { padding-left: 1.15rem; }
li { margin-bottom: .45rem; }
code { background: var(--rule); padding: .1rem .35rem; border-radius: 4px; font-size: .9em; }
"""

def page(slug, title, description, body):
    here = "index.html" if slug == "" else f"{slug}/index.html"
    def link(target, label):
        href = "/Sunplot/" + (f"{target}/" if target else "")
        current = ' aria-current="page"' if target == slug else ""
        return f'<a href="{href}"{current}>{label}</a>'

    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {APP}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{SITE}/{slug + '/' if slug else ''}">
<style>{STYLE}</style>
</head>
<body>
<div class="wrap">
<nav>
  {link("", APP)}
  {link("privacy", "Privacy")}
  {link("support", "Support")}
  {link("terms", "Terms")}
  <a href="{REPO}">Source</a>
</nav>
{body}
<footer>
  <p>{APP} · last updated {UPDATED} · <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></p>
  <p>© 2026 {LICENSOR}. All rights reserved.</p>
</footer>
</div>
</body>
</html>
"""
    out = Path("docs") / here
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    return here


PAGES = [
    ("", "How much sun does this spot get?", "Sunplot works out the hours of direct sun a spot gets on any day of the year, counting the roofs and trees in the way.", """
<h1>How much sun does this spot get?</h1>
<p class="lede">Every seed packet and plant label is written in hours of direct sun. Almost
nobody knows what their own garden, balcony or roof actually gets.</p>

<p>Sunplot answers it with a number. Not where the sun is — that is the easy half — but how
much of it reaches <em>this spot</em>, once the fence, the garage and next door's lime tree
have taken their share.</p>

<div class="card">
<p>Point the camera at the skyline and sweep a finger along the tops of the roofs and trees.
Sunplot walks the day a minute at a time and counts only the light that gets through.</p>
</div>

<h2>What it tells you</h2>
<ul>
<li>Hours of direct sun today, graded the way plant labels are: full sun, part sun, part shade, full shade.</li>
<li>When the sun arrives at the spot and when it leaves, and how the day is broken up.</li>
<li>The whole year: when full sun starts and ends, and the weeks that get none at all.</li>
</ul>

<h2>What it does not do</h2>
<ul>
<li>No account. There is nothing to sign up for.</li>
<li>No servers. Every calculation happens on the phone, and works with no signal at all.</li>
<li>No subscription. One payment unlocks the year view and the widget, for good.</li>
</ul>
"""),

    ("privacy", "Privacy", "Sunplot collects nothing, sends nothing, and has no servers.", """
<h1>Privacy</h1>
<p class="lede">Sunplot has no servers, no accounts and no analytics. Nothing you do in the
app is collected, and nothing leaves your device.</p>

<h2>What stays on the device</h2>
<ul>
<li><strong>Location.</strong> Used to work out where the sun travels overhead, because the
answer changes with latitude. It is read on the device and never transmitted anywhere.</li>
<li><strong>The camera.</strong> The live view is used so you can trace the skyline. No photo
or video is recorded, saved or sent.</li>
<li><strong>Motion.</strong> The compass and motion sensors tell the app which way the phone
is pointing, so the sun's path lines up with what the camera sees.</li>
<li><strong>Your spots.</strong> The places you save and the skylines you trace are stored in
the app's own storage on the device.</li>
</ul>

<h2>What is not collected</h2>
<p>No identifiers, no usage statistics, no crash reporting, no advertising, no third-party
software development kits of any kind. There is no server to send anything to.</p>

<h2>Purchases</h2>
<p>The one-time purchase is handled entirely by Apple. Sunplot never sees your payment
details, and Apple's own privacy policy covers that transaction.</p>

<h2>Children</h2>
<p>Sunplot collects nothing from anybody, of any age.</p>

<h2>Deleting your data</h2>
<p>Deleting the app removes everything it has stored. There is nothing held elsewhere to
request or erase.</p>

<h2>Changes</h2>
<p>If this policy ever changes, the date at the foot of this page changes with it.</p>
"""),

    ("support", "Support", "How to get help with Sunplot.", f"""
<h1>Support</h1>
<p class="lede">Write to <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>. One person reads
it, usually within a day or two.</p>

<div class="card">
<p>It helps to say which iPhone you have, which version of iOS, and what you were doing when
it went wrong. A screenshot is worth a paragraph.</p>
</div>

<h2>Things worth trying first</h2>

<h3>The sun's arc does not line up with the sky</h3>
<p>That is the compass, not the maths. Wave the phone in a figure of eight, and keep away from
speakers, magnets and car dashboards — all of them pull a magnetometer off true. Sunplot tells
you when it does not trust its own reading rather than drawing a confident line anyway.</p>

<h3>It says my skyline is not enough</h3>
<p>A single tap is not a skyline. Sweep the finger along the rooftops and turn on the spot as
you go; the counter shows how much of the horizon you have covered. Below thirty degrees the
reading would say more about the sky you did not look at than the sky you did, so it is set
aside rather than used.</p>

<h3>I bought it and it is asking me to buy it again</h3>
<p>Tap <em>Already bought it? Restore</em> on the purchase screen. Purchases are tied to the
Apple Account that made them, so make sure you are signed in with the same one.</p>

<h3>Why does it want my location?</h3>
<p>The sun's path depends on latitude far more than people expect — an hour's drive north
changes the answer. The position is used on the device and goes nowhere. See the
<a href="/Sunplot/privacy/">privacy policy</a>.</p>
"""),

    ("terms", "Terms", "Terms of use for Sunplot.", f"""
<h1>Terms</h1>
<p class="lede">Sunplot is licensed, not sold, under Apple's standard licence for applications.</p>

<h2>Who licenses it</h2>
<p>Sunplot is published and licensed by <strong>{LICENSOR}</strong>, who holds the copyright
in the application, its name and its source code. Apple distributes it and is not a party to
this licence. Any question about permissions, reuse or licensing goes to the address at the
foot of this page.</p>

<h2>The licence</h2>
<p>Use of Sunplot is governed by Apple's Licensed Application End User License Agreement,
which you can read at
<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">apple.com/legal/internet-services/itunes/dev/stdeula</a>.</p>

<h2>The purchase</h2>
<p>Sunplot is free to download. One optional purchase unlocks the year view, saving more than
one spot, and the widget. It is a single payment: there is no subscription, nothing renews and
there is nothing to cancel. Refunds are handled by Apple, through the same account the
purchase was made from.</p>

<h2>What the numbers are</h2>
<p>Sunplot computes the sun's position from published astronomical algorithms and subtracts
the skyline you trace. It is accurate to the care taken tracing and to the phone's own compass,
both of which the app reports on. It is a gardening and planning tool, not a survey
instrument: do not use it where a wrong answer would be dangerous or expensive, and check
anything that matters against a professional measurement.</p>

<h2>Source</h2>
<p>The source is published at <a href="{REPO}">{REPO}</a> to be read, not reused. The
repository is public for two reasons: these pages are served from it, and the work can be
inspected. It is not open source.</p>
<p>Copyright in Sunplot — its source code, its name, its icon and the wording of its screens —
is held solely by {LICENSOR}, and all rights are reserved. Publication grants no licence, by
implication or otherwise, to copy any part of it into another project by any means, to use it
in any product or service, to modify or distribute it, to publish a derived or substantially
similar application to any store, or to train machine-learning models on it. The licence in
that repository sets out the whole of what is and is not permitted.</p>

<h2>Contact</h2>
<p><a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></p>
"""),
]

written = [page(slug, title, description, body) for slug, title, description, body in PAGES]

Path("docs/robots.txt").write_text(
    f"User-agent: *\nAllow: /\nSitemap: {SITE}/sitemap.xml\n", encoding="utf-8"
)

urls = "".join(
    f"  <url><loc>{SITE}/{slug + '/' if slug else ''}</loc></url>\n"
    for slug, _, _, _ in PAGES
)
Path("docs/sitemap.xml").write_text(
    f'<?xml version="1.0" encoding="UTF-8"?>\n'
    f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}</urlset>\n',
    encoding="utf-8",
)

# GitHub Pages otherwise runs the output through Jekyll, which ignores folders it does not
# recognise and quietly drops files beginning with an underscore.
Path("docs/.nojekyll").write_text("", encoding="utf-8")

for path in written:
    print(f"docs/{path}")
print("docs/robots.txt\ndocs/sitemap.xml\ndocs/.nojekyll")
