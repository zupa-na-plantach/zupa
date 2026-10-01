# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Zupa na Plantach organization project - a Rails 7 application with React/TypeScript frontend for managing food distribution and support services. The app uses a hybrid architecture with Rails serving API endpoints and React handling the frontend user interface.

## Development Commands

### Setup

#### Version Management (asdf)
This project uses asdf for managing runtime versions. The required versions are specified in `.tool-versions`:
- `asdf install` - Install all required runtime versions (Ruby 3.1.7, Node.js 18.20.8, Yarn 1.22.22)

If you don't have the asdf plugins installed yet:
- `asdf plugin add ruby`
- `asdf plugin add nodejs`
- `asdf plugin add yarn`

#### Dependencies
- `bundle install` - Install Ruby dependencies
- `yarn install` - Install JavaScript dependencies
- `cp .env.development.sample .env.development` - Setup environment variables
- `cp .env.test.sample .env.test` - Setup test environment
- `bin/rails db:create db:migrate db:seed` - Setup database

### Running the Application
- `bin/dev` - Start development server (Rails + frontend build)
- `foreman start -f Procfile-mingw.dev` - Alternative for Windows

### Testing
- `bundle exec rspec` - Run Ruby/Rails tests (entire suite). Do NOT use `bin/rspec`.
- `bundle exec rspec spec/path/to/test_spec.rb` - Run specific Ruby test file
- `yarn test` - Run JavaScript/React unit tests with Jest
- `RAILS_ENV=test SWAGGER_DRY_RUN=0 rails rswag` - Regenerate API documentation

### Code Quality & Building
- `bundle exec standardrb` - Lint Ruby code (follows Standard Ruby style)
- `bundle exec standardrb --fix` - Auto-fix Ruby linting issues
- `yarn build` - Build frontend assets with esbuild
- `yarn ts-check` - TypeScript type checking (watch mode)
- `yarn build:css` - Build SCSS to CSS

### Development Access
- Application: http://localhost:4000
- Admin panel: http://localhost:4000/admin
- API docs: http://localhost:4000/api-docs/index.html
- Feature flipper: http://localhost:4000/admin/flipper

## Architecture

### Backend (Ruby on Rails)
- **API Controllers**: `app/controllers/api/v1/` - REST API endpoints for frontend
- **Admin Controllers**: `app/controllers/admin_area/` - Admin-specific functionality
- **Admin Interface**: Uses Trestle gem for admin panel at `/admin`
- **Authentication**: JWT-based with `app/controllers/api/v1/authentication_controller.rb`
- **Models**: Standard Rails models in `app/models/`
- **Feature Flags**: Uses Flipper gem for feature toggling

### Frontend (React + TypeScript)
- **Entry Point**: `app/javascript/App.tsx` - Main React application
- **Architecture**: Follows Atomic Design methodology
  - `app/javascript/components/atoms/` - Basic UI components
  - `app/javascript/components/molecules/` - Component combinations
  - `app/javascript/components/organisms/` - Complex components
- **Routing**: React Router with protected routes in `utils/ProtectedRoute`
- **State Management**: React Query for server state, Context for app state
- **Styling**: SCSS with BEM methodology, Sass compilation via esbuild

### Hosting
- **Render** (`render.yaml` Blueprint): `main` → `zupa-staging`, `production` → `zupa` (https://zupa.onrender.com); auto-deploys after CI passes. Pushing to `main` deploys staging.
- **Postgres**: single Render instance, databases `zupa_staging` + `zupa_production`
- **Files**: Active Storage on Cloudflare R2 (`cloudflare` service in `config/storage.yml`, selected by `ACTIVE_STORAGE_SERVICE`)
- Migrations run on container boot via `bin/docker-entrypoint`

### Key Integrations
- **Google Drive**: For file storage/management
- **Google Maps**: React Google Maps API for location features
- **Database**: PostgreSQL 13.8

## Code Conventions

### Ruby
- Follow Standard Ruby style guide (enforced by `standardrb`)
- Use `dry-monads` for result handling patterns
- RSpec + FactoryBot for testing

### TypeScript/React
- TypeScript strict mode enabled
- ESLint + Prettier for code formatting
- Jest + React Testing Library for unit tests
- Component typing in `app/javascript/types/`

### Styling
- BEM methodology for CSS class naming
- SCSS files co-located with components
- Sass compilation integrated with esbuild

## Important Notes

- Version management via asdf (see `.tool-versions`)
- Ruby version: 3.1.7
- Node.js version: 18.20.8
- Yarn version: 1.22.22
- Rails version: 7.0.4
- Node.js frontend build via esbuild (not Webpack)
- Feature flags available via Flipper - check `/admin/flipper` before implementing features
- API documentation auto-generated via rswag gem
- Environment variables required for Google integrations