#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Сборка RPM для VectorChord
# ============================================

# Проверка и установка rpm-build
if ! command -v rpmbuild &>/dev/null; then
    echo "===> Установка rpm-build"
    dnf install -y rpm-build rpmdevtools
fi

# Версия Rocky Linux (должна совпадать с той, что в build скрипте)
RHEL_VERSION=9

# Версии PostgreSQL для сборки RPM
PG_VERSIONS=(14 15 16 17)

OUTPUT_DIR="/tmp/vchord_build_rhel${RHEL_VERSION}"
RPM_OUTPUT_DIR="${OUTPUT_DIR}/rpms"

mkdir -p "$RPM_OUTPUT_DIR"

for PGVER in "${PG_VERSIONS[@]}"; do
    FILES_DIR="${OUTPUT_DIR}/rhel${RHEL_VERSION}/pg${PGVER}"

    if [[ ! -d "${FILES_DIR}" ]]; then
        echo "❌ Ошибка: файлы для PostgreSQL ${PGVER} не найдены в ${FILES_DIR}"
        echo "Сначала запусти new_biuld.sh"
        exit 1
    fi

    echo ""
    echo "============================================"
    echo "Сборка RPM для PostgreSQL ${PGVER} (RHEL${RHEL_VERSION})"
    echo "============================================"

    rpmbuild_root="${OUTPUT_DIR}/rpmbuild_${PGVER}"
    mkdir -p "${rpmbuild_root}/BUILD" "${rpmbuild_root}/RPMS" "${rpmbuild_root}/SOURCES"
    mkdir -p "${rpmbuild_root}/SPECS" "${rpmbuild_root}/SRPMS"

    cat > "${rpmbuild_root}/SPECS/vchord.spec" << EOF
Name:           vchord_${PGVER}
Version:        1.1.1
Release:        1.el${RHEL_VERSION}
Summary:        VectorChord vector search for PostgreSQL ${PGVER}
License:        Apache-2.0
BuildArch:      x86_64
Requires:       postgresql${PGVER}-server

%description
VectorChord for PostgreSQL ${PGVER}

%install
mkdir -p %{buildroot}/usr/pgsql-${PGVER}/lib
mkdir -p %{buildroot}/usr/pgsql-${PGVER}/share/extension
cp -r ${FILES_DIR}/lib/* %{buildroot}/usr/pgsql-${PGVER}/lib/
cp -r ${FILES_DIR}/extension/* %{buildroot}/usr/pgsql-${PGVER}/share/extension/

%files
/usr/pgsql-${PGVER}/lib/vchord.so
/usr/pgsql-${PGVER}/share/extension/vchord*
EOF

    rpmbuild --define "_topdir ${rpmbuild_root}" -bb "${rpmbuild_root}/SPECS/vchord.spec"

    mkdir -p "${RPM_OUTPUT_DIR}/el${RHEL_VERSION}/pg${PGVER}"
    cp "${rpmbuild_root}/RPMS/x86_64/vchord_${PGVER}-1.1.1-1.el${RHEL_VERSION}.x86_64.rpm" \
       "${RPM_OUTPUT_DIR}/el${RHEL_VERSION}/pg${PGVER}/" 2>/dev/null || true

    echo "✅ RPM для PostgreSQL ${PGVER} собран"
done

echo ""
echo "============================================"
echo "✅ Сборка RPM завершена"
echo "RPM OUTPUT: ${RPM_OUTPUT_DIR}/el${RHEL_VERSION}/pg{14,15,16,17}/"
echo "============================================"
