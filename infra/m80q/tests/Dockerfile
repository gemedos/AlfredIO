# Imagen para ./check.sh: mismas herramientas que el M80q (Debian 13) más shellcheck y bats.
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends bats shellcheck jq curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home tester
USER tester
WORKDIR /repo
