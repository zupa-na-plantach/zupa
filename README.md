# Zupa na Plantach

A web application for managing food distribution and support services, built for the [Zupa na Plantach](https://zupanaplantach.pl/) organization.

Rails 7 backend with a React/TypeScript frontend, using a hybrid architecture where Rails serves API endpoints and React handles the user interface.

## Tech Stack

- **Backend:** Ruby on Rails 7, PostgreSQL
- **Frontend:** React, TypeScript, SCSS (Atomic Design + BEM)
- **Testing:** RSpec, FactoryBot, Jest, React Testing Library
- **Auth:** JWT-based authentication
- **Docs:** Swagger/rswag auto-generated API documentation
- **Feature Flags:** Flipper

## Getting Started

### Prerequisites

This project uses [asdf](https://asdf-vm.com/) for managing runtime versions:

```bash
asdf plugin add ruby
asdf plugin add nodejs
asdf plugin add yarn
asdf install
```

You also need **PostgreSQL 13.8+** running locally.

### Setup

```bash
bundle install
yarn install
cp .env.development.sample .env.development
cp .env.test.sample .env.test
bin/rails db:create db:migrate db:seed
```

> **macOS note:** If `bundle install` fails on the `nio4r` gem (Sonoma or newer), run:
> ```bash
> bundle config build.nio4r --with-cflags="-Wno-incompatible-pointer-types"
> ```

### Running

```bash
bin/dev
```

The app will be available at [http://localhost:4000](http://localhost:4000).

Admin panel: [http://localhost:4000/admin](http://localhost:4000/admin)

### Google Integrations

The app integrates with Google Drive and Google Maps. See [docs/google-integration.md](docs/google-integration.md) for setup instructions.

## Testing

```bash
bundle exec rspec                          # Run all Ruby tests
bundle exec rspec spec/path/to/spec.rb     # Run a specific test file
yarn test                                  # Run frontend unit tests
```

Make sure your `.env.test` includes the Google Drive dummy values from `.env.test.sample`. See [docs/google-integration.md](docs/google-integration.md) for details.

### Regenerate API Docs

```bash
RAILS_ENV=test SWAGGER_DRY_RUN=0 rails rswag
```

API documentation is served at `/api-docs/index.html`.

## Code Quality

```bash
bundle exec standardrb          # Lint Ruby code (Standard Ruby)
bundle exec standardrb --fix    # Auto-fix Ruby issues
yarn build                      # Build frontend assets
yarn ts-check                   # TypeScript type checking
```

## Architecture

### Backend

- **API Controllers:** `app/controllers/api/v1/` — REST endpoints for the frontend
- **Admin Controllers:** `app/controllers/admin_area/` — Admin-specific functionality
- **Admin Interface:** [Trestle](https://github.com/TrestleAdmin/trestle) gem at `/admin`
- **Models:** `app/models/`
- **Feature Flags:** Flipper, configurable at `/admin/flipper`

### Frontend

- **Entry Point:** `app/javascript/App.tsx`
- **Component Structure:** [Atomic Design](https://atomicdesign.bradfrost.com/chapter-2/)
  - `app/javascript/components/atoms/` — Basic UI elements
  - `app/javascript/components/molecules/` — Component combinations
  - `app/javascript/components/organisms/` — Complex components
- **Routing:** React Router with protected routes
- **State Management:** React Query (server state) + Context API (app state)
- **Styling:** SCSS with [BEM](https://getbem.com/) methodology

## Deployment

The app is hosted on [Render](https://render.com) (Frankfurt region), configured by the `render.yaml` Blueprint:

| Branch | Service | Database |
|---|---|---|
| `main` | `zupa-staging` | `zupa_staging` |
| `production` | `zupa` (https://zupa.onrender.com) | `zupa_production` |

- A push to a branch deploys it automatically once CI (`.github/workflows/application-tests.yml`) passes.
- Both databases live on the single `zupa-db` Postgres instance.
- Database migrations run on container boot (`bin/docker-entrypoint`).
- Uploaded files (Active Storage) are stored in Cloudflare R2, which is S3-compatible (the `cloudflare` service in `config/storage.yml`). Buckets: `zupa-staging` and `zupa-production`.
- Secrets (`SECRET_KEY_BASE`, Google, R2 credentials) are set per service in the Render dashboard, not in the repo.

To release to production, fast-forward `production` to `main`:

```bash
git push origin main:production
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make sure tests pass (`bundle exec rspec && yarn test`)
4. Make sure code style is correct (`bundle exec standardrb`)
5. Commit your changes
6. Push to the branch
7. Open a Pull Request

## License

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE).

Copyright (C) 2022-2025 [Lunar Logic Sp. z o.o.](https://www.lunarlogic.com/)
