#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Сборка pgvectorscale RPM для PostgreSQL 14-17 на Rocky Linux 8
# Без зависимости от pgvector и с правильным именем библиотеки
# ============================================

RHEL_VERSION=8
ARCH="amd64"
OUTPUT_DIR="/tmp/pgvectorscale_build"
RPM_OUTPUT_DIR="${OUTPUT_DIR}/rpms"

# Версии PostgreSQL для сборки
PG_VERSIONS=(14 15 16 17)

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

for PGVER in "${PG_VERSIONS[@]}"; do
  echo ""
  echo "============================================"
  echo "BUILDING FOR PostgreSQL ${PGVER}"
  echo "============================================"

  "$RUNTIME" run --rm \
    --platform "linux/${ARCH}" \
    -e PG_MAJOR="$PGVER" \
    -e OUTPUT_DIR=/out \
    -e RPM_OUTPUT_DIR=/out/rpms \
    -v "$OUTPUT_DIR:/out${MOUNT_SUFFIX}" \
    rockylinux:8 \
    bash -c '
      set -euo pipefail

      PKG_MGR="dnf"
      rhel_version="8"
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

      echo "===> Installing PGDG repo"
      ${PKG_MGR} install -y \
        "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${rhel_version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

      echo "===> Enabling PowerTools"
      ${PKG_MGR} config-manager --set-enabled powertools || true

      echo "===> Disabling distro PostgreSQL module"
      ${PKG_MGR} -qy module disable postgresql || true

      echo "===> Installing PostgreSQL dev packages"
      ${PKG_MGR} install -y "postgresql${PG_MAJOR}-devel"

      if [[ ! -x "${pg_config}" ]]; then
        echo "ERROR: pg_config not found"
        exit 1
      fi

      echo "===> Installing Rust"
      curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "${HOME}/.cargo/env"

      echo "===> Cloning pgvectorscale"
      cd /tmp
      git clone --depth 1 https://github.com/timescale/pgvectorscale.git
      cd /tmp/pgvectorscale/pgvectorscale

      echo "===> Installing cargo-pgrx"
      cargo install --locked cargo-pgrx --version 0.16.1

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

      # Копируем библиотеку и создаём правильное имя
      LIB_FILE=$(basename ${libdir}/vectorscale-*.so)
      cp "${libdir}"/vectorscale-*.so "${out}/lib/"
      cd "${out}/lib"
      ln -sf ${LIB_FILE} vectorscale.so

      cp "${sharedir}"/vectorscale* "${out}/extension/"

      echo "===> Building RPM package"
      cd /root
      rpmdev-setuptree

      cat > /root/rpmbuild/SPECS/pgvectorscale.spec << EOF
Name:           pgvectorscale_${PG_MAJOR}
Version:        0.9.0
Release:        1.el8
Summary:        pgvectorscale vector search for PostgreSQL ${PG_MAJOR}
License:        Apache-2.0
BuildArch:      x86_64
Requires:       postgresql${PG_MAJOR}-server

%description
pgvectorscale enhances PostgreSQL with StreamingDiskANN index

%install
mkdir -p %{buildroot}/usr/pgsql-${PG_MAJOR}/lib
mkdir -p %{buildroot}/usr/pgsql-${PG_MAJOR}/share/extension
cp -r /out/rhel8/pg${PG_MAJOR}/lib/* %{buildroot}/usr/pgsql-${PG_MAJOR}/lib/
cp -r /out/rhel8/pg${PG_MAJOR}/extension/* %{buildroot}/usr/pgsql-${PG_MAJOR}/share/extension/

%files
/usr/pgsql-${PG_MAJOR}/lib/vectorscale*
/usr/pgsql-${PG_MAJOR}/share/extension/vectorscale*
EOF

      rpmbuild -bb /root/rpmbuild/SPECS/pgvectorscale.spec

      mkdir -p "${RPM_OUTPUT_DIR}/el8/pg${PG_MAJOR}"
      cp /root/rpmbuild/RPMS/x86_64/pgvectorscale_${PG_MAJOR}-0.9.0-1.el8.x86_64.rpm \
         "${RPM_OUTPUT_DIR}/el8/pg${PG_MAJOR}/" 2>/dev/null || true

      echo "===> DONE: RPM built for PostgreSQL ${PG_MAJOR}"
    '
done

echo ""
echo "============================================"
echo "ALL BUILDS COMPLETED"
echo "RPM OUTPUT: ${RPM_OUTPUT_DIR}/el8/pg{14,15,16,17}/"
echo "============================================"
