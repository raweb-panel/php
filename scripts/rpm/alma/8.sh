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
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
export LDFLAGS="-static-libgcc -pie"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
# ====================================================================================
echo "Updating..." && dnf -y update > /dev/null 2>&1
echo "Installing curl..." && dnf install --allowerasing -y epel-release curl jq > /dev/null 2>&1
# ====================================================================================
RPM_PACKAGE_NAME="raweb-php84"
RPM_ARCH="x86_64"
RPM_DIST="$BUILD_CODE"
LATEST_PHP_VERSION=$(curl -s "https://www.php.net/releases/index.php?json&version=${PHP_VERSION_MAJOR}" | jq -r '.version')
RPM_PACKAGE_FILE_NAME="${RPM_PACKAGE_NAME}-${LATEST_PHP_VERSION}-${RPM_DIST}.${RPM_ARCH}.rpm"
RPM_REPO_URL="https://$DOMAIN/$UPLOAD_USER/$BUILD_REPO/${RPM_DIST}/"
# ====================================================================================
if curl -s "$RPM_REPO_URL" | grep -q "$RPM_PACKAGE_FILE_NAME"; then
    echo "✅ Package $RPM_PACKAGE_FILE_NAME already exists. Skipping build."
    exit 0
fi
# ====================================================================================
dnf install -y epel-release dnf-plugins-core > /dev/null 2>&1
dnf module enable -y ruby:3.0
dnf config-manager --set-enabled powertools
echo "Makecache..." && dnf clean all; dnf makecache; yum -y update > /dev/null 2>&1
echo "Installing dev tools..." && dnf groupinstall -y "Development Tools" > /dev/null 2>&1
# ====================================================================================
echo "Installing reqs..." && dnf install -y --allowerasing \
            wget libcurl-devel sqlite-devel openssl-devel \
            zlib-devel bzip2-devel libjpeg-turbo-devel libpng-devel \
            libwebp-devel freetype-devel libxslt-devel \
            libzip-devel oniguruma-devel libsodium-devel \
            gmp-devel libicu-devel pkgconf ruby ruby-devel curl jq zip unzip rpm-build rsync > /dev/null 2>&1
# ====================================================================================
mkdir -p $GITHUB_WORKSPACE/build; cd $GITHUB_WORKSPACE/build; wget https://www.php.net/distributions/php-${LATEST_PHP_VERSION}.tar.gz; tar -xzf php-${LATEST_PHP_VERSION}.tar.gz; rm -rf php-${LATEST_PHP_VERSION}.tar.gz
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
make -j${CORES} > /dev/null 2>&1
make install > /dev/null 2>&1
# ====================================================================================
mkdir -p /raweb/apps/php84/etc/; mkdir -p /raweb/apps/php84/etc/php-fpm.d/; rm -rf /raweb/apps/php84/etc/php-fpm.d/*; rm -rf /raweb/apps/php84/etc/php-fpm.conf.default
cp $GITHUB_WORKSPACE/static/php.ini /raweb/apps/php84/etc/php.ini
cp $GITHUB_WORKSPACE/static/pool.conf /raweb/apps/php84/etc/php-fpm.d/panel.conf
cp $GITHUB_WORKSPACE/static/php-fpm.conf /raweb/apps/php84/etc/php-fpm.conf
# ====================================================================================
RPMBUILD_ROOT=$GITHUB_WORKSPACE/rpmbuild
mkdir -p $RPMBUILD_ROOT/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
export VERSION="$LATEST_PHP_VERSION"
# ====================================================================================
cat > $GITHUB_WORKSPACE/rpmbuild/SPECS/raweb-php84.spec <<EOF
Name:           raweb-php84
Version:        $LATEST_PHP_VERSION
Release:        $BUILD_CODE
Summary:        Raweb PHP $LATEST_PHP_VERSION for AlmaLinux

License:        PHP
URL:            https://www.php.net/
BuildArch:      x86_64
Requires:       glibc, libxml2, openssl-libs, bzip2-libs, libjpeg-turbo, libpng, libwebp, freetype, libxslt, libzip, oniguruma, gmp, libicu, mysql-libs, zlib, sqlite

%description
Custom compiled PHP $LATEST_PHP_VERSION for Raweb Panel.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/raweb
cp -a /raweb/apps %{buildroot}/raweb/
mkdir -p %{buildroot}/etc/systemd/system
cp $GITHUB_WORKSPACE/static/raweb-php84.service %{buildroot}/etc/systemd/system/

%files
/raweb/apps/php84
/etc/systemd/system/raweb-php84.service

%pre
if ! id raweb &>/dev/null; then
    useradd -r -s /bin/false raweb
fi

%preun
if command -v systemctl >/dev/null 2>&1; then
    if [ \$1 -eq 0 ]; then
        # Uninstall: stop and disable
        systemctl stop raweb-php84.service || true
        systemctl disable raweb-php84.service || true
    elif [ \$1 -eq 1 ]; then
        # Upgrade: stop only
        systemctl stop raweb-php84.service || true
    fi
fi

%postun
if command -v systemctl >/dev/null 2>&1; then
    if [ \$1 -eq 1 ]; then
        # Upgrade: start again
        systemctl start raweb-php84.service || true
        systemctl status raweb-php84.service
    fi
fi

%post
mkdir -p /raweb/apps/logs
chown -R raweb:raweb /raweb
chown -R raweb:raweb /raweb/*
chmod -R 755 /raweb/apps/php84
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable --now raweb-php84.service
fi

%changelog
* $(date "+%a %b %d %Y") GitHub Actions <cd@julio.al> - $LATEST_PHP_VERSION
- Automated build of PHP $LATEST_PHP_VERSION
EOF
# ====================================================================================
BUILDROOT="$RPMBUILD_ROOT/BUILDROOT"
mkdir -p "$BUILDROOT"
# ====================================================================================
rpmbuild --define "_topdir $RPMBUILD_ROOT" \
         --define "version $VERSION" \
         --buildroot="$BUILDROOT" \
         -bb $RPMBUILD_ROOT/SPECS/raweb-php84.spec
# ====================================================================================
PACKAGE_FILE="$RPMBUILD_ROOT/RPMS/x86_64/raweb-php84-$LATEST_PHP_VERSION-$BUILD_CODE.x86_64.rpm"
# ====================================================================================
echo "$UPLOAD_PASS" > $GITHUB_WORKSPACE/.rsync
chmod 600 $GITHUB_WORKSPACE/.rsync
rsync -avz --password-file=$GITHUB_WORKSPACE/.rsync $DEB_PACKAGE_FILE rsync://$UPLOAD_USER@$DOMAIN/$BUILD_FOLDER/$BUILD_REPO/$BUILD_CODE/
# ====================================================================================