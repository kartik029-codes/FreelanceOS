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


## Backend foundation (Supabase)

The first database migration is available at `supabase/migrations/0001_initial_schema.sql`.

### Apply the schema

1. Open your Supabase project.
2. Go to **SQL Editor** and create a new query.
3. Copy the complete contents of `supabase/migrations/0001_initial_schema.sql` from this repository.
4. Run the query.
5. Check **Table Editor** for the new tables.

The migration establishes profiles, workspaces and memberships, clients, projects, opportunities, quotes and quote items, invoices and invoice items, expenses, payments, and workspace settings. Row Level Security is enabled for the business tables, with workspace-scoped access policies.

### Client configuration

The project URL and Supabase publishable key belong in frontend configuration only. Never put a service-role key, secret API key, or database password in browser code or Git. Keep local secrets out of commits. The frontend integration will be added in a later implementation step.

### Product architecture notes

- INR and India are the initial workspace defaults.
- Currency and country are stored per workspace and per financial record where applicable.
- Tax settings and document content are stored as structured JSON snapshots so issued documents can retain the settings and editable draft structure used when they were created.
- Local-only mode is a separate storage mode; it must not silently upload local records to the cloud.
