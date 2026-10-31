# How GLSL turns code into a hamburger

The key idea is: **a fragment shader calculates a colour for each pixel. All those coloured pixels together become the image.**

For a hamburger drawn entirely in GLSL, the code describes shapes and colours that we recognise as bread, lettuce, and meat.

Imagine each pixel asking:

> “Where am I? Am I inside the bun? The lettuce? The patty? What colour should I be?”

The GPU runs the same little program for each pixel, with a different position each time.

## Start with positions

We often use two numbers called `uv` to describe where a pixel is:

```text
(0, 1) ───────────────── (1, 1)
       │                │
       │    (0.5, 0.5)   │
       │     centre     │
(0, 0) ───────────────── (1, 0)
```

Here, `uv.x` means left-to-right position, and `uv.y` means bottom-to-top position. This example uses that orientation; some environments flip the vertical direction.

We can colour a rectangular strip brown:

```glsl
if (uv.x > 0.2 && uv.x < 0.8 &&
    uv.y > 0.3 && uv.y < 0.4) {
    colour = vec3(0.3, 0.12, 0.05);
}
```

Read that as:

> “If this pixel is between 20% and 80% across, and between 30% and 40% up, make it brown.”

**That strip becomes the hamburger patty.** There is no special “draw meat” instruction—just a rule that makes a particular area brown.

`vec3` holds three numbers: red, green, and blue. Typically, `0.0` means none of that colour, and `1.0` means full strength.

## Build the hamburger from shapes

Imagine stacking several shapes:

```text
           __________
         /            \       ← golden half-ellipse: top bun
        /______________\
        ~~~~~~~~~~~~~~~~      ← green strip: lettuce
        ================      ← yellow strip: cheese
        ████████████████      ← brown rectangle: patty
        ________________      ← golden rectangle: bottom bun
```

Here is a deliberately simple GLSL function that does that. The lettuce is a straight strip in this version; waves can be added later.

```glsl
vec3 hamburger(vec2 uv) {
    // Start every pixel with the background colour.
    vec3 colour = vec3(0.12, 0.15, 0.20);

    // These layers all occupy the same horizontal width.
    bool acrossBurger = uv.x > 0.2 && uv.x < 0.8;

    if (acrossBurger) {
        if (uv.y > 0.20 && uv.y < 0.29)
            colour = vec3(0.85, 0.48, 0.16); // Bottom bun

        if (uv.y > 0.30 && uv.y < 0.40)
            colour = vec3(0.30, 0.12, 0.05); // Patty

        if (uv.y > 0.40 && uv.y < 0.43)
            colour = vec3(1.00, 0.80, 0.10); // Cheese

        if (uv.y > 0.43 && uv.y < 0.48)
            colour = vec3(0.25, 0.65, 0.12); // Lettuce
    }

    // An ellipse centred at (0.5, 0.5).
    vec2 p = (uv - vec2(0.5, 0.5)) / vec2(0.3, 0.2);

    // Keep only its upper half to make the top bun.
    if (length(p) < 1.0 && uv.y > 0.5)
        colour = vec3(0.90, 0.55, 0.20);

    return colour;
}
```

This is a helper function, rather than a complete standalone shader. The surrounding shader supplies `uv`, calls `hamburger(uv)`, and writes the returned colour to its output.

## Understand the curved bun

The most mathematical-looking line is this one:

```glsl
vec2 p = (uv - vec2(0.5, 0.5)) / vec2(0.3, 0.2);
```

It means: **measure this pixel’s position relative to the bun’s centre, using the bun’s horizontal and vertical radii as the measuring scale.**

- `vec2` holds two numbers, here representing horizontal and vertical position.
- Subtracting `vec2(0.5, 0.5)` makes the bun’s centre the origin of our measurements.
- Dividing by `vec2(0.3, 0.2)` sets the ellipse’s horizontal radius to `0.3` and vertical radius to `0.2`.
- `length(p) < 1.0` asks whether the pixel falls inside that ellipse.
- `uv.y > 0.5` keeps only the upper half.

## Add detail

More detailed images build on those same ideas:

| What you see | What the code does |
|---|---|
| Sesame seeds | Adds tiny pale ellipses |
| Wavy lettuce | Uses `sin()` to make the strip’s edge rise and fall |
| Rounded, shaded bread | Makes some parts of the bun lighter and others darker |
| Soft edges | Blends colours gradually near shape boundaries |
| A bouncing hamburger | Changes the shape’s position using time |

When reading a shader, look for **position → shape test → colour**. Those three pieces are the bridge between the maths and the picture.
