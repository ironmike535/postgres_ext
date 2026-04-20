#!/usr/bin/env bash
set -euo pipefail

# Установка Docker на Rocky Linux 8.9

echo "===> Удаление старых версий Docker"
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true

echo "===> Установка зависимостей"
dnf install -y dnf-utils device-mapper-persistent-data lvm2

echo "===> Добавление официального репозитория Docker"
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "===> Установка Docker"
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "===> Запуск и добавление в автозагрузку"
systemctl enable docker
systemctl start docker

echo "===> Проверка статуса"
systemctl status docker --no-pager

echo "===> Проверка версии"
docker --version

echo "✅ Docker установлен и запущен"
