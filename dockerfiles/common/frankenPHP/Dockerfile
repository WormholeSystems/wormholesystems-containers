# Stage 1: Build environment (Composer, Node, Assets)
# Use the CLI image which is suitable for running Composer and Artisan commands.
FROM dunglas/frankenphp:builder-php8.4 AS builder

# Install system dependencies (Node.js/NPM is pre-installed in this FrankenPHP image)
# Install only necessary build dependencies not included in the base image.
# We no longer need supervisor, libfcgi-bin, or procps.
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    unzip \
    libpq-dev \
    libonig-dev \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    libzip-dev \
    nodejs \
    npm \
    wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
# FrankenPHP uses the `install-php-extensions` script.
# `pdo`, `sockets`, `zip`, and `redis` are often pre-installed or easily added.
RUN install-php-extensions \
    pcntl \
    pdo_mysql \
    sockets \
    zip \
    redis \
    && rm -rf /tmp/* /var/tmp/*

# Install Supercronic
RUN arch="$(uname -m)" \
    && case "$arch" in \
    armhf) _cronic_fname='supercronic-linux-arm' ;; \
    aarch64) _cronic_fname='supercronic-linux-arm64' ;; \
    x86_64) _cronic_fname='supercronic-linux-amd64' ;; \
    x86) _cronic_fname='supercronic-linux-386' ;; \
    *) echo >&2 "error: unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.38/${_cronic_fname}" \
    -O /usr/bin/supercronic \
    && chmod +x /usr/bin/supercronic \
    && mkdir -p /etc/supercronic \
    && echo "*/1 * * * * php /app/artisan schedule:run --no-interaction" > /etc/supercronic/laravel

# Set the working directory
WORKDIR /app

# Copy the entire Laravel application code
COPY ./wormhole-systems /app

# Install Composer dependencies
# The `composer` binary is pre-installed in the CLI base image.
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer install --no-dev --prefer-dist --optimize-autoloader

# Generate application routes and build assets
RUN php artisan wayfinder:generate
RUN npm install
RUN php artisan sde:download
RUN php artisan generate:static-data
RUN npm run build

# ---
# Stage 2: Production environment
# Use the lighter `prod` image. It includes Caddy and the PHP runtime.
FROM dunglas/frankenphp:php8.4

# Install only runtime libraries needed in production
# Many runtime dependencies are already included or no longer needed (like libfcgi-bin).
# We only install the required database/utility dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    procps \
    && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy the initialization script
COPY ./dockerfiles/test/frankenPHP/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Install PHP extensions
# FrankenPHP uses the `install-php-extensions` script.
# `pdo`, `sockets`, `zip`, and `redis` are often pre-installed or easily added.
RUN install-php-extensions \
    pcntl \
    pdo_mysql \
    sockets \
    zip \
    redis \
    && rm -rf /tmp/* /var/tmp/*

# Set the working directory
WORKDIR /app

# Copy the application code and dependencies from the build stage
# Note: The Caddy server built into FrankenPHP expects the document root at `/app/public` by default.
# Ensure your Laravel `public` folder is at `/app/public`.
COPY --from=builder /app /app

# Copy supercronic and config from the builder stage
COPY --from=builder /usr/bin/supercronic /usr/bin/supercronic
COPY --from=builder /etc/supercronic/laravel /etc/supercronic/laravel

# Optional: Copy custom PHP configuration if needed (e.g., custom memory limits)
# FrankenPHP defaults to good production settings, making a full `php.ini` replacement unnecessary.
# You can add small configuration snippets here if required.
# COPY ./config/php/custom.ini /usr/local/etc/php/conf.d/zzz-custom.ini

# Ensure correct permissions (FrankenPHP uses the `www-data` user internally)
RUN chown -R www-data:www-data /app

# Set the document root (if different from the default `/app/public`)
# If your Laravel app uses the standard `public` folder, you can omit this.
# ENV DOCUMENT_ROOT /app/public
