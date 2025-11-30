# ================================
# 1. BUILD FRONTEND (VITE) STAGE
# ================================
FROM node:20.19.0 AS frontend

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install

COPY . .
RUN pnpm build


# ================================
# 2. BUILD PHP BACKEND STAGE
# ================================
FROM php:8.2-fpm-bullseye AS backend

# Install system dependencies for Laravel
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libzip-dev libonig-dev libxml2-dev zip nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql zip

WORKDIR /var/www/html

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

# Copy backend source
COPY . .

# Copy frontend build output
COPY --from=frontend /app/public/build ./public/build

# Laravel cache
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# ================================
# 3. RUNTIME STAGE WITH NGINX + PHP-FPM
# ================================
FROM php:8.2-fpm-bullseye

# Install nginx
RUN apt-get update && apt-get install -y nginx

WORKDIR /var/www/html

COPY --from=backend /var/www/html /var/www/html

# Copy custom nginx conf
COPY ./deploy/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD service nginx start && php-fpm
