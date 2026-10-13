# Art standard

## Look
Clean, stylized and slightly chunky, like a standard Roblox sports game.
Simple shapes, bold readable silhouettes, matte materials, no tiny detail.
Everything must read clearly from the normal camera distance.

## Colours
- Pitch: one green with a slightly lighter stripe for mowing lines
- Goal/posts: white
- Ball: white with dark panels
- Stadium/props: muted neutrals (greys, soft blues), with one accent colour
- Team colours kept bright and distinct from the pitch

## Geometry
- Every mesh well under 20,000 triangles (Roblox's limit); aim for under 6,000
  for props and under 1,000 for small items like the ball
- Clean edges, no loose or overlapping parts, no hidden geometry
- One mesh per object unless it needs to move separately

## Scale (in studs)
- A standard Roblox avatar is about 5 studs tall; size everything relative to that
- Goal 24 studs wide and 8 studs high (must match goalWidth/goalHeight in src/shared/config.luau)
- Ball may be scaled up from real size so it's easy to see
- Pivot at the bottom centre of each object, front facing +Z (towards the shooter)

## Textures
- 1024x1024 or smaller, one material per object where possible
- Flat or simple colour; no baked-in lighting or text

## Naming and files
- PascalCase names, e.g. Goal, Ball, CornerFlag
- Keep source files in assets/source, exports in assets/export (both committed to git)

## Checklist for every new model
- [ ] Under the triangle budget
- [ ] Correct scale and pivot
- [ ] Clean from all angles (render and check)
- [ ] Matches the palette
- [ ] Imported and viewed in Studio next to the avatar for scale

## First assets
Ball, goal and net, corner flags, pitch lines, simple stadium boards.
