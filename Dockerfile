FROM debian:13.1-slim@sha256:a347fd7510ee31a84387619a492ad6c8eb0af2f2682b916ff3e643eb076f925a

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates clang clang-tidy clang-format lld libc6-dev libstdc++-14-dev \
    cmake ninja-build git glslang-tools python3 pkg-config ccache file gdb \
    qt6-base-dev qt6-base-dev-tools qt6-wayland \
    libgl1-mesa-dev libx11-dev libxcursor-dev libxext-dev libxfixes-dev \
    libxi-dev libxrandr-dev libxss-dev libxtst-dev libxkbcommon-dev \
    libasound2-dev libpulse-dev libudev-dev libdbus-1-dev libwayland-dev wayland-protocols \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 --shell /bin/bash developer \
    && mkdir -p /workspace /build /cache/deps /cache/ccache /logs \
    && chown -R developer:developer /workspace /build /cache /logs
USER developer
ENV CC=clang CXX=clang++ CCACHE_DIR=/cache/ccache CCACHE_MAXSIZE=2G \
    BUILD_ROOT=/build LOG_ROOT=/logs FETCHCONTENT_BASE_DIR=/cache/deps \
    CMAKE_BUILD_PARALLEL_LEVEL=4
RUN git config --global --add safe.directory /workspace
WORKDIR /workspace
CMD ["bash"]
