# Building
# docker build -t zupa:slim . --build-arg REACT_API_BASE_URL="http://localhost:3000/api/v1"

# Running
# docker run --name zupa --rm --env-file .env -p 3000:3000 zupa:slim

FROM ruby:3.1.7-slim-bookworm AS base

WORKDIR /rails

# Set production environment
ENV NODE_ENV="production" \
    RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

FROM base AS build

# We install packages required for gems native extensions compilation and other build stuff
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev git curl

# We install node to precompile assets (react app among others)
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update -qq && apt-get install -y nodejs && \
    npm install -g yarn

# We copy the Gemfile first so the bundle install step is cached unless we change the gemfile
# We also precompile the bootsnap cache for all our gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Same for package.json - we want to cache yarn install
COPY package.json yarn.lock ./
RUN yarn install

COPY . .

ARG REACT_GTM_ID
ARG REACT_API_BASE_URL

ENV REACT_GTM_ID=$REACT_GTM_ID
ENV REACT_API_BASE_URL=$REACT_API_BASE_URL

# We precompile the assets
RUN SECRET_KEY_BASE="dummy" \
    DATABASE_URL="dummy" \
    DOCKER_BUILDING=true \
    GOOGLE_DRIVE_PRIVATE_KEY_ID="dummy" \
    GOOGLE_DRIVE_PRIVATE_KEY="dummy" \
    GOOGLE_DRIVE_CLIENT_EMAIL="dummy" \
    GOOGLE_DRIVE_CLIENT_ID="dummy" \
    GOOGLE_DRIVE_CLIENT_CERT_URL="dummy" \
    bin/rails assets:precompile

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Remove source files, we are precompiling assets after all
RUN rm -rf node_modules
RUN rm -rf app/assets/fonts app/assets/images app/assets/javascripts app/assets/stylesheets app/assets/templates
RUN rm -rf vendor
RUN rm -rf app/javascript

# Remove useless C gem extensions leftovers
RUN find /usr/local/bundle -name "*.c" -delete
RUN find /usr/local/bundle -name "*.o" -delete

FROM base AS production
# We start from base again to copy only what's neccesary

# Now we install only the packages required for the runtime
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# And now we copy the relevant files from build step
# This has to be chmoded because gem mail-2.8.0 has incorrect
# permissions and rails user didn't have permission to read it's files
COPY --from=build --chmod=775 /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db tmp storage

USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
