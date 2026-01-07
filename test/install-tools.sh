#!/usr/bin/env bash

set -euo pipefail

install_dir=${INSTALL_DIR:-/usr/local/bin}

mkdir -p "$install_dir"

fetch_latest_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | awk -F '"' '/"tag_name"/ { print $4; exit }'
}

install_shellcheck() {
  local tag
  local arch
  local tarball
  local tmp_dir

  tag=$(fetch_latest_tag "koalaman/shellcheck")
  if [[ -z "$tag" ]]; then
    return 1
  fi
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)
      echo "Unsupported architecture for shellcheck: $arch" >&2
      exit 1
      ;;
  esac

  tarball="shellcheck-${tag}.linux.${arch}.tar.xz"
  tmp_dir=$(mktemp -d)
  if ! curl -fsSL -o "${tmp_dir}/${tarball}" \
    "https://github.com/koalaman/shellcheck/releases/download/${tag}/${tarball}"; then
    rm -rf "$tmp_dir"
    return 1
  fi
  tar -xJf "${tmp_dir}/${tarball}" -C "$tmp_dir"
  mv "${tmp_dir}/shellcheck-${tag}/shellcheck" "${install_dir}/shellcheck"
  chmod +x "${install_dir}/shellcheck"
  rm -rf "$tmp_dir"
}

install_hadolint() {
  local tag
  local arch
  local os
  local binary

  tag=$(fetch_latest_tag "hadolint/hadolint")
  if [[ -z "$tag" ]]; then
    return 1
  fi
  os="Linux"
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Unsupported architecture for hadolint: $arch" >&2
      exit 1
      ;;
  esac

  binary="hadolint-${os}-${arch}"
  if ! curl -fsSL -o "${install_dir}/hadolint" \
    "https://github.com/hadolint/hadolint/releases/download/${tag}/${binary}"; then
    return 1
  fi
  chmod +x "${install_dir}/hadolint"
}

if ! install_shellcheck; then
  echo "Falling back to apt for shellcheck" >&2
  apt-get update
  apt-get install -y shellcheck
fi

if ! install_hadolint; then
  echo "Falling back to apt for hadolint" >&2
  apt-get update
  apt-get install -y hadolint
fi

shellcheck --version
hadolint --version
