"""
Emberkeep sprite frame generator — produces PNG frames that match the
procedural Portrait painter's visual language (portrait.dart).

The procedural Portrait is a vector-like ember creature:
  - Egg-shaped blob body with glassy radial shading
  - Simple flame crest on top (grows with tier)
  - Big round dark eyes with white catchlights
  - Rosy cheeks, gentle smile
  - Tiny stubby feet
  - Soft warm glow halo
  - NO arms, paws, orbs, sparkles, or extra props

This script renders that same character at higher fidelity (anti-aliased
gradients, soft glows) but in the same visual language, so the sprite
frames and the procedural fallback look like the same character.

Output: assets/mascot/<skinId>/s<stage>_<mood>_00.png
Sizes: 256x256 (high enough for crisp rendering at any display size)

Skin palettes are pulled directly from creature_skins.dart values.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

# ── Skin palettes (exact values from creature_skins.dart) ──────────────
SKINS = {
    'ember_amber': {
        'name': 'Ember',
        'colors': [(0xFF, 0xFF, 0xF4, 0xD9), (0xFF, 0xF2, 0xCD, 0x93),
                   (0xFF, 0xC5, 0x8A, 0x4E), (0xFF, 0x6E, 0x45, 0x1F)],
    },
    'rose_quartz': {
        'name': 'Rose Quartz',
        'colors': [(0xFF, 0xFF, 0xE9, 0xEC), (0xFF, 0xF4, 0xB8, 0xC4),
                   (0xFF, 0xD7, 0x7E, 0x96), (0xFF, 0x7E, 0x3A, 0x50)],
    },
    'mint_glass': {
        'name': 'Mint',
        'colors': [(0xFF, 0xE9, 0xFB, 0xEF), (0xFF, 0xAE, 0xE6, 0xC6),
                   (0xFF, 0x6F, 0xC7, 0x9B), (0xFF, 0x2F, 0x6E, 0x55)],
    },
    'periwinkle': {
        'name': 'Periwinkle',
        'colors': [(0xFF, 0xE9, 0xEC, 0xFF), (0xFF, 0xBC, 0xC4, 0xF4),
                   (0xFF, 0x8E, 0x9A, 0xE0), (0xFF, 0x49, 0x50, 0x7E)],
    },
    'lilac': {
        'name': 'Lilac',
        'colors': [(0xFF, 0xF3, 0xE9, 0xFF), (0xFF, 0xD8, 0xBC, 0xF4),
                   (0xFF, 0xB6, 0x8E, 0xE0), (0xFF, 0x60, 0x49, 0x7E)],
    },
    'slate': {
        'name': 'Slate',
        'colors': [(0xFF, 0xED, 0xF1, 0xF4), (0xFF, 0xB8, 0xC2, 0xC9),
                   (0xFF, 0x89, 0x97, 0xA1), (0xFF, 0x47, 0x53, 0x5B)],
    },
    'gilded': {
        'name': 'Gilded',
        'colors': [(0xFF, 0xFF, 0xF6, 0xD9), (0xFF, 0xFF, 0xE0, 0x8A),
                   (0xFF, 0xE8, 0xB4, 0x4E), (0xFF, 0x8A, 0x6A, 0x1E)],
    },
}

# Growth stages (from portrait.dart portraitFrames)
# tier 0 = level 1-4, tier 1 = 5-9, tier 2 = 10-15, tier 3 = 16-23,
# tier 4 = 24-33, tier 5 = 34+
STAGES = [0, 1, 2, 3, 4, 5]
MOODS = ['idle', 'happy']

SIZE = 256
INK = (0x3A, 0x24, 0x10, 0xFF)  # universal warm dark for eyes/mouth

OUTPUT_BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           'assets', 'mascot')


def lerp_color(c1, c2, t):
    """Linear interpolate between two RGBA colors."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def radial_gradient_circle(size, center, radius, colors, stops):
    """Draw a circle filled with a radial gradient."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = img.load()
    cx, cy = center
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy) / radius
            if dist <= 1.0:
                # find the stop range
                for i in range(len(stops) - 1):
                    if stops[i] <= dist <= stops[i + 1]:
                        t = (dist - stops[i]) / (stops[i + 1] - stops[i] + 1e-9)
                        c = lerp_color(colors[i], colors[i + 1], t)
                        pixels[x, y] = c
                        break
    return img


def soft_circle(size, center, radius, color, blur=0):
    """Draw a soft-edged filled circle."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse(
        [center[0] - radius, center[1] - radius,
         center[0] + radius, center[1] + radius],
        fill=color
    )
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def soft_oval(size, center, w, h, color, blur=0):
    """Draw a soft-edged filled oval."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse(
        [center[0] - w / 2, center[1] - h / 2,
         center[0] + w / 2, center[1] + h / 2],
        fill=color
    )
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def draw_flame_crest(base_img, s, cx, body_top, tier, skin_colors, sway=0):
    """Draw the flame crest above the body — grows with tier."""
    cream, honey, amber, rim = skin_colors

    # Flame height scales with tier
    base_h = s * (0.15 + tier * 0.05)
    flick = 1.0  # static frame; the animation handles flicker

    def draw_single_flame(dx, scale, lean):
        fh = base_h * scale * flick
        fw = s * 0.145 * scale
        fx = cx + dx + sway * scale
        base_y = body_top + s * 0.08

        # Heat bloom at base
        bloom = soft_circle(s, (int(fx), int(base_y - fh * 0.3)),
                            int(fw * 1.05),
                            (*honey[:3], int(0.4 * 255)), blur=int(s * 0.055))
        base_img.alpha_composite(bloom)

        # Flame body — teardrop shape
        flame_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        fd = ImageDraw.Draw(flame_img)

        # Build teardrop path
        tip_x = fx + lean
        tip_y = base_y - fh
        points = []
        # Left curve up to tip
        n = 20
        for i in range(n + 1):
            t = i / n
            # quadratic bezier: start -> control -> tip
            start_x = fx - fw / 2
            start_y = base_y
            ctrl_x = fx - fw * 0.62
            ctrl_y = base_y - fh * 0.5
            bx = (1 - t) ** 2 * start_x + 2 * (1 - t) * t * ctrl_x + t ** 2 * (tip_x - fw * 0.14)
            by = (1 - t) ** 2 * start_y + 2 * (1 - t) * t * ctrl_y + t ** 2 * (base_y - fh * 0.82)
            points.append((bx, by))
        # Right curve down from tip
        for i in range(n + 1):
            t = i / n
            start_x = tip_x + fw * 0.14
            start_y = base_y - fh * 0.82
            ctrl_x = fx + fw * 0.62
            ctrl_y = base_y - fh * 0.5
            end_x = fx + fw / 2
            end_y = base_y
            bx = (1 - t) ** 2 * start_x + 2 * (1 - t) * t * ctrl_x + t ** 2 * end_x
            by = (1 - t) ** 2 * start_y + 2 * (1 - t) * t * ctrl_y + t ** 2 * end_y
            points.append((bx, by))
        # Bottom curve back to start
        for i in range(n + 1):
            t = i / n
            bx = (1 - t) * (fx + fw / 2) + t * (fx - fw / 2)
            by = base_y + fh * 0.14 * 4 * t * (1 - t)
            points.append((bx, by))

        # Fill with vertical gradient (amber -> honey -> cream)
        # Draw the flame shape with a gradient
        fd.polygon(points, fill=amber)

        # Apply gradient by drawing horizontal lines
        min_y = base_y - fh
        max_y = base_y + fh * 0.14
        for ly in range(int(min_y), int(max_y) + 1):
            t = (ly - min_y) / (max_y - min_y + 1e-9)
            if t < 0.55:
                ct = t / 0.55
                c = lerp_color(cream, honey, ct)
            else:
                ct = (t - 0.55) / 0.45
                c = lerp_color(honey, amber, ct)
            # Find x range at this y
            xs = [p[0] for p in points if abs(p[1] - ly) < 2]
            if xs:
                fd.line([(min(xs), ly), (max(xs), ly)], fill=c, width=1)

        # Soft the flame edges
        flame_img = flame_img.filter(ImageFilter.GaussianBlur(1))

        # Hot heart — bright core
        core_w = fw * 0.42
        core_h = fh * 0.5
        core = soft_oval(s, (int(fx), int(base_y - core_h * 0.5)),
                         int(core_w * 2), int(core_h * 1.2),
                         (*lerp_color(cream, (255, 255, 255, 255), 0.4)[:3], int(0.7 * 255)),
                         blur=1)
        flame_img.alpha_composite(core)

        base_img.alpha_composite(flame_img)

    # Side flames first (so central sits in front), added by tier
    if tier >= 3:
        draw_single_flame(-s * 0.12, 0.6, -s * 0.02)
    if tier >= 2:
        draw_single_flame(s * 0.12, 0.68, s * 0.02)
    draw_single_flame(0, 1.0, sway * 0.6)


def draw_contact_shadow(img, s, cx, base_y, body_w, lift=0):
    """Soft grounding shadow beneath the body."""
    alpha = int(0.24 * 255 * (1 - 0.35 * lift))
    shadow = soft_oval(s, (int(cx), int(base_y + s * 0.01)),
                       int(body_w * 0.78 * (1 - 0.16 * lift)),
                       int(s * 0.06),
                       (0, 0, 0, alpha), blur=int(s * 0.018))
    img.alpha_composite(shadow)


def draw_feet(img, s, cx, body_c, body_h, skin_colors):
    """Two little stubby feet with radial shading."""
    cream, honey, amber, rim = skin_colors
    for dx in [-0.16, 0.16]:
        fc = (int(cx + dx * s), int(body_c[1] + body_h * 0.46))
        fw = int(s * 0.2)
        fh = int(s * 0.12)
        foot_color = lerp_color(amber, rim, 0.55)
        foot_highlight = lerp_color(amber, cream, 0.35)
        foot = soft_oval(s, fc, fw, fh, foot_color, blur=0)
        foot_hi = soft_oval(s, (fc[0] - fw // 6, fc[1] - fh // 4),
                            fw // 2, fh // 2, foot_highlight, blur=1)
        img.alpha_composite(foot)
        img.alpha_composite(foot_hi)


def draw_body(img, s, cx, body_c, body_w, body_h, skin_colors, happy):
    """The main egg-shaped body with glassy radial shading."""
    cream, honey, amber, rim = skin_colors

    # Build radial gradient body
    body_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    pixels = body_img.load()

    # Radial gradient center offset to upper-left for glassy look
    grad_cx = body_c[0] - body_w * 0.4
    grad_cy = body_c[1] - body_h * 0.55
    grad_r = max(body_w, body_h) * 1.05

    for y in range(s):
        for x in range(s):
            # Check if inside the oval
            ex = (x - body_c[0]) / (body_w / 2)
            ey = (y - body_c[1]) / (body_h / 2)
            if ex * ex + ey * ey <= 1.0:
                # Distance from gradient center
                dx = x - grad_cx
                dy = y - grad_cy
                dist = math.sqrt(dx * dx + dy * dy) / grad_r
                dist = min(dist, 1.0)

                # Map through gradient stops: cream(0), honey(0.34), amber(0.76), rim(1.0)
                if dist < 0.34:
                    t = dist / 0.34
                    c = lerp_color(cream, honey, t)
                elif dist < 0.76:
                    t = (dist - 0.34) / 0.42
                    c = lerp_color(honey, amber, t)
                else:
                    t = (dist - 0.76) / 0.24
                    c = lerp_color(amber, rim, t)
                pixels[x, y] = c

    img.alpha_composite(body_img)

    # Subsurface candle-glow — warm light low inside the body
    glow_color = lerp_color(honey, cream, 0.3)
    glow_alpha = int((0.42 if happy else 0.32) * 255)
    glow = soft_circle(s, (int(cx), int(body_c[1] + body_h * 0.22)),
                       int(body_w * 0.42),
                       (*glow_color[:3], glow_alpha), blur=int(s * 0.06))

    # Clip glow to body shape
    body_mask = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    bm_draw = ImageDraw.Draw(body_mask)
    bm_draw.ellipse(
        [body_c[0] - body_w / 2, body_c[1] - body_h / 2,
         body_c[0] + body_w / 2, body_c[1] + body_h / 2],
        fill=(255, 255, 255, 255)
    )
    glow_clipped = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    glow_clipped.paste(glow, (0, 0), body_mask)
    img.alpha_composite(glow_clipped)

    # Warm back-light rim along lower-right edge
    rim_color = lerp_color(honey, cream, 0.5)
    rim_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim_img)
    rd.arc(
        [body_c[0] - body_w / 2 + s * 0.012, body_c[1] - body_h / 2 + s * 0.012,
         body_c[0] + body_w / 2 - s * 0.012, body_c[1] + body_h / 2 - s * 0.012],
        math.degrees(math.pi * 0.1),
        math.degrees(math.pi * 0.72),
        fill=(*rim_color[:3], int(0.55 * 255)),
        width=int(s * 0.03)
    )
    rim_img = rim_img.filter(ImageFilter.GaussianBlur(int(s * 0.012)))
    # Clip to body
    rim_clipped = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    rim_clipped.paste(rim_img, (0, 0), body_mask)
    img.alpha_composite(rim_clipped)

    # Soft belly highlight
    belly = soft_oval(s, (int(cx), int(body_c[1] + body_h * 0.12)),
                      int(body_w * 0.5), int(body_h * 0.42),
                      (*cream[:3], int(0.16 * 255)), blur=int(s * 0.03))
    belly_clipped = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    belly_clipped.paste(belly, (0, 0), body_mask)
    img.alpha_composite(belly_clipped)

    # Specular highlight (top-left)
    spec = soft_oval(s, (int(cx - body_w * 0.2), int(body_c[1] - body_h * 0.28)),
                     int(body_w * 0.22), int(body_h * 0.16),
                     (*cream[:3], int(0.6 * 255)), blur=int(s * 0.016))
    spec_clipped = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    spec_clipped.paste(spec, (0, 0), body_mask)
    img.alpha_composite(spec_clipped)

    # Tiny near-white hotspot
    hotspot = soft_circle(s, (int(cx - body_w * 0.24), int(body_c[1] - body_h * 0.33)),
                          int(s * 0.02),
                          (*lerp_color(cream, (255, 255, 255, 255), 0.65)[:3], int(0.9 * 255)),
                          blur=0)
    img.alpha_composite(hotspot)


def draw_face(img, s, cx, body_c, body_w, happy, tier):
    """Eyes, cheeks, mouth — the heart of the cuteness."""
    eye_y = body_c[1] - s * 0.02
    eye_dx = s * 0.135

    # Cheeks — soft blush, blooming when happy
    blush_alpha = int((0x66 if happy else 0x44))
    blush_color = (0xD8, 0x8A, 0x8A, blush_alpha)
    for dx in [-0.2, 0.2]:
        cheek = soft_oval(s, (int(cx + dx * s), int(eye_y + s * 0.1)),
                          int(s * 0.13), int(s * 0.085),
                          blush_color, blur=int(s * 0.018))
        img.alpha_composite(cheek)

    # Eyes — big round with catchlights
    eye_r = s * (0.085 if happy else 0.078)
    for dx in [-eye_dx, eye_dx]:
        ec = (int(cx + dx), int(eye_y))
        # Eye base (dark)
        eye = soft_oval(s, ec, int(eye_r * 1.7), int(eye_r * 2.0), INK, blur=0)
        img.alpha_composite(eye)
        # Upper catchlight
        catch = soft_circle(s, (int(ec[0] - eye_r * 0.32), int(ec[1] - eye_r * 0.5)),
                            int(eye_r * 0.42),
                            (255, 255, 255, int(0.95 * 255)), blur=0)
        img.alpha_composite(catch)
        # Lower sparkle
        sparkle = soft_circle(s, (int(ec[0] + eye_r * 0.34), int(ec[1] + eye_r * 0.55)),
                              int(eye_r * 0.2),
                              (255, 255, 255, int(0.7 * 255)), blur=0)
        img.alpha_composite(sparkle)

    # Mouth — gentle smile, wider when happy
    mouth_w = s * (0.24 if happy else 0.17)
    mouth_h = s * (0.17 if happy else 0.10)
    mouth_y = eye_y + s * (0.135 if happy else 0.125)

    mouth_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    md = ImageDraw.Draw(mouth_img)
    # Draw arc as a thick stroke
    md.arc(
        [cx - mouth_w / 2, mouth_y - mouth_h / 2,
         cx + mouth_w / 2, mouth_y + mouth_h / 2],
        math.degrees(math.pi * 0.1),
        math.degrees(math.pi * 0.9),
        fill=INK,
        width=int(s * 0.035)
    )
    mouth_img = mouth_img.filter(ImageFilter.GaussianBlur(0.5))
    img.alpha_composite(mouth_img)


def draw_aura(img, s, cx, body_c, color, happy, tier):
    """Two-layer warm halo around the body — kept tight so it doesn't
    bleed to the image edges and create a visible halo on backgrounds."""
    # Wide bloom — tighter radius so it stays near the body
    bloom_alpha = int(((0.34 if happy else 0.20) + 0.03 * tier) * 255)
    bloom = soft_circle(s, (int(cx), int(body_c[1])), int(s * 0.40),
                        (*color[:3], bloom_alpha), blur=int(s * 0.10))
    img.alpha_composite(bloom)

    # Inner glow
    inner_alpha = int(((0.20 if happy else 0.11) + 0.02 * tier) * 255)
    inner = soft_circle(s, (int(cx), int(body_c[1])), int(s * 0.28),
                        (*color[:3], inner_alpha), blur=int(s * 0.06))
    img.alpha_composite(inner)


def draw_tier_sparkles(img, s, skin_colors, tier):
    """High-tier sparkle motes drifting around the blaze."""
    if tier < 4:
        return
    cream = skin_colors[0]
    positions = [(0.2, 0.28), (0.82, 0.34), (0.74, 0.6)]
    for px, py in positions:
        sp = soft_circle(s, (int(px * s), int(py * s)), int(s * 0.014),
                         (*cream[:3], int(0.85 * 255)), blur=int(s * 0.006))
        img.alpha_composite(sp)


def generate_frame(skin_id, stage, mood, skin_colors):
    """Generate a single sprite frame."""
    s = SIZE
    happy = mood == 'happy'
    cream, honey, amber, rim = skin_colors

    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))

    cx = s * 0.5
    # Body geometry — matches portrait.dart proportions
    excite = 1.03 if happy else 1.0
    rest_y = s * 0.54
    body_c = (cx, rest_y)
    body_w = s * 0.62 * excite
    body_h = s * 0.64 * excite
    body_top = body_c[1] - body_h / 2
    base_y = rest_y + s * 0.64 * excite * 0.5

    # Aura color = honey from the skin
    aura_color = honey

    # Draw layers (back to front, matching portrait.dart order)
    draw_aura(img, s, cx, body_c, aura_color, happy, stage)
    draw_flame_crest(img, s, cx, body_top, stage, skin_colors)
    draw_contact_shadow(img, s, cx, base_y, body_w)
    draw_feet(img, s, cx, body_c, body_h, skin_colors)
    draw_body(img, s, cx, body_c, body_w, body_h, skin_colors, happy)
    draw_face(img, s, cx, body_c, body_w, happy, stage)
    draw_tier_sparkles(img, s, skin_colors, stage)

    # ── Clean up near-zero alpha pixels so the background is truly
    # transparent. The aura's Gaussian blur leaves faint alpha (1-15)
    # at the edges that would show as a halo on any background. ──
    pixels = img.load()
    alpha_threshold = 8  # anything below this is visually invisible
    for y in range(s):
        for x in range(s):
            r, g, b, a = pixels[x, y]
            if a < alpha_threshold:
                pixels[x, y] = (0, 0, 0, 0)
            elif a < 255:
                # Boost slightly so the soft edges stay clean
                pass

    return img


def main():
    total = 0
    for skin_id, skin_data in SKINS.items():
        skin_dir = os.path.join(OUTPUT_BASE, skin_id)
        os.makedirs(skin_dir, exist_ok=True)

        colors = skin_data['colors']
        # Convert to RGBA tuples
        skin_colors = [c for c in colors]

        for stage in STAGES:
            for mood in MOODS:
                img = generate_frame(skin_id, stage, mood, skin_colors)
                filename = f's{stage}_{mood}_00.png'
                filepath = os.path.join(skin_dir, filename)
                img.save(filepath, 'PNG')
                total += 1

    print(f"Generated {total} sprite frames in {OUTPUT_BASE}")
    print(f"  7 skins x 6 stages x 2 moods = {7 * 6 * 2}")


if __name__ == '__main__':
    main()