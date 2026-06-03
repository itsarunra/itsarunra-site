# itsarunra.com

This repository contains the source for my personal website:

https://itsarunra.com

The site is a simple, static archive of writing focused on:

* concrete and construction
* manufacturing and automation
* building things in the real world

## Structure

* `index.html` — homepage
* `posts/` — posts index and individual articles

* `frames/` - frames page
* `public/frames/` - frame images
* `data/frames.json` - frame metadata
* `data/posts.json` - generated post metadata
* `scripts/build-posts-data.ps1` - regenerates post metadata from article dates

The site is intentionally minimal. No frameworks, no build system, no dependencies.

## Adding frames

1. Export the image at a web-friendly size.
2. Add it to `public/frames/`.
3. Add one metadata entry to `data/frames.json`.
4. Commit and deploy.

Example:

```json
{
  "slug": "ladder-container-weather",
  "title": "Ladder, Container, Weather",
  "date": "2026-06-03",
  "image": "/public/frames/ladder-container-weather.jpg",
  "caption": "The work before the work.",
  "location": "Sydney, NSW",
  "camera": "Ricoh GR IV Monochrome"
}
```

## Deployment

Hosted using GitHub Pages.

## Notes

This is a personal writing archive, not a software project.
