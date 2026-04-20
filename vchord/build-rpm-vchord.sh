#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Сборка VectorChord RPM для PostgreSQL 14-17 на Rocky Linux 8/9
# ============================================

ARCH="amd64"
OUTPUT_DIR="/tmp/vchord_build"
RPM_OUTPUT_DIR="${OUTPUT_DIR}/rpms"

# Версии PostgreSQL для сборки
PG_VERSIONS=(14)

# Версии Rocky Linux для сборки
RHEL_VERSIONS=(8)

# Очистка перед сборкой
echo "===> Очистка старых файлов"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR" "$RPM_OUTPUT_DIR"

if command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
  MOUNT_SUFFIX=":Z"
elif command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
  MOUNT_SUFFIX=""
else
  echo "ERROR: install podman or docker"
  exit 1
fi

echo "===> Runtime: $RUNTIME"
echo "===> Output: $OUTPUT_DIR"

for rhel in "${RHEL_VERSIONS[@]}"; do
  for pg in "${PG_VERSIONS[@]}"; do
    echo ""
    echo "============================================"
    echo "BUILDING VectorChord FOR RHEL${rhel} / PostgreSQL ${pg}"
    echo "============================================"

    "$RUNTIME" run --rm \
      --platform "linux/${ARCH}" \
      -e PG_MAJOR="$pg" \
      -e RHEL_VERSION="$rhel" \
      -e OUTPUT_DIR=/out \
      -e RPM_OUTPUT_DIR=/out/rpms \
      -v "$OUTPUT_DIR:/out${MOUNT_SUFFIX}" \
      "rockylinux:${rhel}" \
      bash -c '
        set -euo pipefail

        PKG_MGR="dnf"
        rhel_version=$RHEL_VERSION
        PG_MAJOR=$PG_MAJOR
        pg_config="/usr/pgsql-${PG_MAJOR}/bin/pg_config"
        export PATH="/usr/pgsql-${PG_MAJOR}/bin:${PATH}"

        echo "===> Installing build deps"
        ${PKG_MGR} install -y \
          ca-certificates \
          clang \
          dnf-plugins-core \
          findutils \
          gcc \
          gcc-c++ \
          git \
          gzip \
          jq \
          llvm \
          make \
          openssl-devel \
          pkgconfig \
          tar \
          curl \
          epel-release \
          rpm-build \
          rpmdevtools

        echo "===> Enabling PowerTools/CRB"
        if [[ "${rhel_version}" == "8" ]]; then
          ${PKG_MGR} config-manager --set-enabled powertools || true
        elif [[ "${rhel_version}" == "9" ]]; then
          ${PKG_MGR} config-manager --set-enabled crb || true
        fi

        echo "===> Installing PGDG repo"
        ${PKG_MGR} install -y \
          "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${rhel_version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

        echo "===> Disabling distro PostgreSQL module"
        ${PKG_MGR} -qy module disable postgresql || true

        echo "===> Installing PostgreSQL dev packages"
        ${PKG_MGR} install -y "postgresql${PG_MAJOR}-devel"

        # Проверяем pg_config
        if [[ ! -x "${pg_config}" ]]; then
          echo "ERROR: pg_config not found at ${pg_config}"
          exit 1
        fi

        echo "===> Installing Rust"
        curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "${HOME}/.cargo/env"

        echo "===> Cloning VectorChord"
        cd /tmp
        git clone --depth 1 https://github.com/tensorchord/VectorChord.git
        cd /tmp/VectorChord

        echo "===> Installing cargo-pgrx"
        cargo install --locked cargo-pgrx --version 0.17.0

        echo "===> Initializing pgrx"
        cargo pgrx init "--pg${PG_MAJOR}=${pg_config}"

        echo "===> Building extension"
        export PG_CONFIG="${pg_config}"
        export PGRX_PG_CONFIG_PATH="${pg_config}"
        cargo pgrx install --release

        echo "===> Collecting artifacts"
        out="/out/rhel${rhel_version}/pg${PG_MAJOR}"
        libdir="$(${pg_config} --pkglibdir)"
        sharedir="$(${pg_config} --sharedir)/extension"

        mkdir -p "${out}/lib" "${out}/extension"

        cp "${libdir}"/vchord.so "${out}/lib/"
        cp "${sharedir}"/vchord* "${out}/extension/"

        echo "===> Fixing version in control file"
        sed -i "s/default_version = .*/default_version = '\''1.1.1'\''/" "${out}/extension/vchord.control"

        echo "===> Creating SQL file for version 1.1.1"
        cd "${out}/extension"
        cp vchord--0.0.0.sql vchord--1.1.1.sql

        echo "===> Building RPM package"
        cd /root
        rpmdev-setuptree

        cat > /root/rpmbuild/SPECS/vchord.spec << EOF
Name:           vchord_${PG_MAJOR}
Version:        1.1.1
Release:        1.el${rhel_version}
Summary:        VectorChord vector search for PostgreSQL ${PG_MAJOR}
License:        Apache-2.0
BuildArch:      x86_64
Requires:       postgresql${PG_MAJOR}-server

%description
VectorChord provides high-performance vector search for PostgreSQL

%install
mkdir -p %{buildroot}/usr/pgsql-${PG_MAJOR}/lib
mkdir -p %{buildroot}/usr/pgsql-${PG_MAJOR}/share/extension
cp -r /out/rhel${rhel_version}/pg${PG_MAJOR}/lib/* %{buildroot}/usr/pgsql-${PG_MAJOR}/lib/
cp -r /out/rhel${rhel_version}/pg${PG_MAJOR}/extension/* %{buildroot}/usr/pgsql-${PG_MAJOR}/share/extension/

%files
/usr/pgsql-${PG_MAJOR}/lib/vchord.so
/usr/pgsql-${PG_MAJOR}/share/extension/vchord*
EOF

        rpmbuild -bb /root/rpmbuild/SPECS/vchord.spec

        mkdir -p "${RPM_OUTPUT_DIR}/el${rhel_version}/pg${PG_MAJOR}"
        cp /root/rpmbuild/RPMS/x86_64/vchord_${PG_MAJOR}-1.1.1-1.el${rhel_version}.x86_64.rpm \
           "${RPM_OUTPUT_DIR}/el${rhel_version}/pg${PG_MAJOR}/" 2>/dev/null || true

        echo "===> DONE: RHEL${rhel_version} PG${PG_MAJOR}"
      '
  done
done

echo ""
echo "============================================"
echo "ALL BUILDS COMPLETED"
echo "RPM OUTPUT: ${RPM_OUTPUT_DIR}/el8/pg14/"
echo "============================================"
