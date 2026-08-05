FROM ubuntu:22.04

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates dbus-x11 file fontconfig libasound2 libegl1 libgbm1 libgtk-3-0 libnss3 xdotool xvfb \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --uid 10001 smoke

COPY smoke-appimage.sh /usr/local/bin/smoke-appimage
RUN chmod 0755 /usr/local/bin/smoke-appimage
USER smoke
ENTRYPOINT ["/usr/local/bin/smoke-appimage"]
