#!/bin/bash
# ====================================================================================
if [ -z "$UPLOAD_USER" ] || [ -z "$UPLOAD_PASS" ]; then
    echo "Missing UPLOAD_USER or UPLOAD_PASS"
    exit 1
fi
# ====================================================================================
TOTAL_CORES=$(nproc)
if [[ "$BUILD_CORES" =~ ^[0-9]+$ ]] && [ "$BUILD_CORES" -le 100 ]; then
  CORES=$(( TOTAL_CORES * BUILD_CORES / 100 ))
  [ "$CORES" -lt 1 ] && CORES=1
else
  CORES=${BUILD_CORES:-$TOTAL_CORES}
fi
# ====================================================================================
export LDFLAGS="-static-libgcc"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
# ====================================================================================
echo "Updating..." && apt-get update -y > /dev/null 2>&1
echo "Upgrading..." && apt-get upgrade -y > /dev/null 2>&1
echo "Installing curl..." && apt-get install curl jq -y > /dev/null 2>&1
# ====================================================================================
DEB_PACKAGE_NAME="raweb-php84"
DEB_ARCH="amd64"
LATEST_PHP_VERSION=$(curl -s "https://www.php.net/releases/index.php?json&version=${PHP_VERSION_MAJOR}" | jq -r '.version')
DEB_VERSION="$LATEST_PHP_VERSION"
DEB_DIST="$BUILD_CODE"
# ====================================================================================
DEB_PACKAGE_FILE_NAME="${DEB_PACKAGE_NAME}_${DEB_VERSION}_${DEB_DIST}_${DEB_ARCH}.deb"
DEB_REPO_URL="https://$DOMAIN/$UPLOAD_USER/$BUILD_REPO/${DEB_DIST}/"
if curl -s "$DEB_REPO_URL" | grep -q "$DEB_PACKAGE_FILE_NAME"; then
    echo "✅ Package $DEB_PACKAGE_FILE_NAME already exists. Skipping build."
    exit 0
fi
# ====================================================================================
DEBIAN_FRONTEND=noninteractive apt-get install -y \
                                       build-essential wget libcurl4-openssl-dev libsqlite3-dev libssl-dev \
                                       zlib1g-dev libbz2-dev libjpeg-dev libpng-dev libwebp-dev \
                                       libfreetype6-dev libxslt1-dev libzip-dev libonig-dev \
                                       libsodium-dev libgmp-dev libicu-dev pkg-config ruby ruby-dev sudo wget curl zip unzip jq rsync >/dev/null 2>&1
# ====================================================================================
mkdir -p $GITHUB_WORKSPACE/build; cd $GITHUB_WORKSPACE/build; wget https://www.php.net/distributions/php-${LATEST_PHP_VERSION}.tar.gz > /dev/null 2>&1; tar -xzf php-${LATEST_PHP_VERSION}.tar.gz > /dev/null 2>&1; rm -rf php-${LATEST_PHP_VERSION}.tar.gz
cd $GITHUB_WORKSPACE/build/php-${LATEST_PHP_VERSION}; useradd raweb
# ====================================================================================
./configure --prefix=/raweb/apps/php84 \
            --with-config-file-path=/raweb/apps/php84/etc \
            --with-config-file-scan-dir=/raweb/apps/php84/etc/conf.d \
            --with-fpm-user=raweb \
            --with-fpm-group=raweb \
            --enable-mbstring \
            --enable-fpm \
            --with-zlib \
            --with-bz2 \
            --with-iconv \
            --with-curl \
            --with-zip \
            --with-mysqli \
            --with-pdo-mysql \
            --with-jpeg \
            --with-webp \
            --with-freetype \
            --with-xsl \
            --with-gettext \
            --with-pear \
            --with-sodium \
            --with-openssl \
            --with-gmp \
            --enable-bcmath \
            --enable-sockets \
            --enable-pcntl \
            --enable-sysvshm \
            --enable-sysvsem \
            --enable-sysvmsg \
            --enable-shmop \
            --enable-exif \
            --enable-calendar \
            --enable-pdo \
            --enable-mbregex \
            --enable-ctype \
            --enable-session \
            --enable-filter \
            --enable-xml \
            --enable-dom \
            --enable-simplexml \
            --enable-tokenizer \
            --enable-ftp \
            --enable-xmlreader \
            --enable-xmlwriter \
            --enable-phar \
            --enable-intl \
            --enable-soap \
            --without-sqlite3 \
            --without-pdo-sqlite \
            --with-libdir=/lib64 \
            --disable-rpath > /dev/null 2>&1
make -j${CORES} > /dev/null
make install
# ====================================================================================
mkdir -p /raweb/apps/php84/etc/; mkdir -p /raweb/apps/php84/etc/php-fpm.d/; rm -rf /raweb/apps/php84/etc/php-fpm.d/*; rm -rf /raweb/apps/php84/etc/php-fpm.conf.default
cp $GITHUB_WORKSPACE/static/php.ini /raweb/apps/php84/etc/php.ini
cp $GITHUB_WORKSPACE/static/pool.conf /raweb/apps/php84/etc/php-fpm.d/panel.conf
cp $GITHUB_WORKSPACE/static/php-fpm.conf /raweb/apps/php84/etc/php-fpm.conf
# ====================================================================================
DEB_PACKAGE_NAME="raweb-php84"
DEB_VERSION="$LATEST_PHP_VERSION"
DEB_ARCH="amd64"
DEB_DIST="$BUILD_CODE"
DEB_BUILD_DIR="$GITHUB_WORKSPACE/debbuild"
DEB_ROOT="$DEB_BUILD_DIR/${DEB_PACKAGE_NAME}_${DEB_VERSION}_${DEB_ARCH}"
# ====================================================================================
rm -rf "$DEB_BUILD_DIR"
mkdir -p "$DEB_ROOT/raweb/apps"
mkdir -p "$DEB_ROOT/etc/systemd/system"
mkdir -p "$DEB_ROOT/DEBIAN"
# ====================================================================================
cp -a /raweb/apps/php84 "$DEB_ROOT/raweb/apps/"
cp $GITHUB_WORKSPACE/static/raweb-php84.service "$DEB_ROOT/etc/systemd/system/"
# ====================================================================================
cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: $DEB_PACKAGE_NAME
Version: $DEB_VERSION
Section: web
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Raweb Panel <cd@julio.al>
Description: Custom compiled PHP $DEB_VERSION for Raweb Panel.
Depends: libxml2, libssl3, libcurl4, libbz2-1.0, libjpeg62-turbo, libpng16-16, libwebp7, libfreetype6, libxslt1.1, libzip4, libonig5, libsodium23, libgmp10, libicu72, default-libmysqlclient-dev, zlib1g, libsqlite3-0
EOF
# ====================================================================================
chmod 755 "$DEB_ROOT/DEBIAN"
chmod 755 "$DEB_ROOT/DEBIAN/control"
# ====================================================================================
DEB_PACKAGE_FILE="$DEB_BUILD_DIR/${DEB_PACKAGE_NAME}_${DEB_VERSION}_${BUILD_CODE}_${DEB_ARCH}.deb"
dpkg-deb --build "$DEB_ROOT" "$DEB_PACKAGE_FILE"
# ====================================================================================
echo "$UPLOAD_PASS" > $GITHUB_WORKSPACE/.rsync
chmod 600 $GITHUB_WORKSPACE/.rsync
rsync -avz --password-file=$GITHUB_WORKSPACE/.rsync $DEB_PACKAGE_FILE rsync://$UPLOAD_USER@$DOMAIN/$BUILD_FOLDER/$BUILD_REPO/$BUILD_CODE/
# ====================================================================================