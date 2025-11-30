#!/bin/bash

# Run it like this: ./refresh_local_db.sh
# Make sure to set HEROKU_APP_NAME environment variable or update the script below

# Set your Heroku app name here (or export HEROKU_APP_NAME before running)
HEROKU_APP_NAME="${HEROKU_APP_NAME:-framefox-connect}"
DATABASE_NAME="foxconnect_development"

if [ -f latest.dump ]; then
    rm latest.dump
fi

set -e  # Exit immediately if a command fails

echo "📥 Capturing Heroku database backup..."
heroku pg:backups:capture --app "$HEROKU_APP_NAME"

echo "📦 Downloading backup file..."
heroku pg:backups:download --app "$HEROKU_APP_NAME"

echo "🔪 Terminating existing database connections..."
psql -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$DATABASE_NAME' AND pid <> pg_backend_pid();"

echo "🗑️ Dropping and recreating local database..."
bundle exec rake db:drop db:create DISABLE_DATABASE_ENVIRONMENT_CHECK=1

echo "♻️ Restoring database from backup..."
pg_restore --verbose --clean --no-acl --no-owner -h localhost -d "$DATABASE_NAME" latest.dump

echo "🔄 Running database migrations..."
bundle exec rake db:migrate

echo "✅ Database refresh complete!"

