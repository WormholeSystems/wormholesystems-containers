#!/bin/sh
set -e

# Ensure Laravel storage directories exist and are writable.
echo "Setting up Laravel storage directories..."
mkdir -p /app/storage/framework/sessions /app/storage/framework/views /app/storage/framework/cache /app/storage/logs /app/bootstrap/cache
chown -R www-data:www-data /app/storage /app/bootstrap/cache
chmod -R 775 /app/storage /app/bootstrap/cache

# Run Laravel migrations
# -----------------------------------------------------------
# Ensure the database schema is up to date.
# -----------------------------------------------------------
echo "Waiting for database to be ready..."

# Wait for DB connectivity using a small PHP PDO probe so we don't rely on extra binaries
max_retries=30
count=0
until php -r 'try { $dsn = "mysql:host=" . getenv("DB_HOST") . ";port=" . (getenv("DB_PORT") ?: 3306) . ";charset=utf8mb4"; new PDO($dsn, getenv("DB_USERNAME"), getenv("DB_PASSWORD"), [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]); } catch (Throwable $e) { exit(1); } exit(0);'; do
	count=$((count+1))
	if [ "$count" -ge "$max_retries" ]; then
		echo "Database not available after $max_retries attempts, exiting."
		exit 1
	fi
	echo "Waiting for DB ($count/$max_retries)..."
	sleep 2
done

echo "Running Laravel migrations..."
php artisan migrate --force

# Clear and cache configurations
# -----------------------------------------------------------
# Improves performance by caching config and routes.
# -----------------------------------------------------------
echo "Clearing and caching Laravel configurations..."
php artisan optimize:clear
php artisan optimize

# Run the default command
echo "Starting the application..."
echo "$@"
exec docker-php-entrypoint "$@"
