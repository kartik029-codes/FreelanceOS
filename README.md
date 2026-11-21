# FreelanceOS

A dark, monochrome freelance workspace concept with frosted-glass surfaces and a subtle mineral / rocky texture.

## Preview

The project is a static, single-page HTML prototype. Open `index.html` in a modern browser.

## Design direction

- Monochrome palette: black, white and graphite
- Approximately 40% translucent glass surfaces, balanced with solid dark surfaces
- Subtle mineral grain and faceted rocky background details
- Responsive dashboard layout
- No coloured accent lighting

## Current prototype includes

- Overview dashboard and sidebar navigation
- Earnings summary cards and an illustrative SVG chart
- Quick-action entry points for Pricing Studio, Quote Builder and Opportunities
- Recent quote table and activity feed
- Search filtering, keyboard shortcut (Ctrl/Cmd + K), date display and toast feedback

## Important

This is an early frontend prototype. The financial figures and quote records are illustrative demo content. Navigation items outside Overview currently show planned-module feedback; authentication, persistence, backend APIs, real quote generation and live financial calculations are not implemented yet.

## Run locally

No build step is required. Open `index.html` directly, or run a local static server:

```bash
python -m http.server 8000
```

Then visit `http://localhost:8000`.

## Deployment

The repository includes a GitHub Actions workflow for GitHub Pages. In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. The workflow will publish the root directory on pushes to `main`.

## License

No license has been added yet. All rights remain with the repository owner unless a license is added.
