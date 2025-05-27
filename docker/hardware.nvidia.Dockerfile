# syntax=docker/dockerfile:labs

# 0. Prepare images
# only debian 13 (trixie) has latest ffmpeg
# https://packages.debian.org/trixie/ffmpeg
ARG GO_VERSION="1.24-bookworm"
ARG CUDA_VERSION="12.9.0"
ARG UBUNTU_VERSION="24.04"
ARG DEBIAN_VERSION="bookworm"

# 1. Build go2rtc binary
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION} AS build
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

ENV GOOS=${TARGETOS}
ENV GOARCH=${TARGETARCH}

WORKDIR /build

# Cache dependencies
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build go mod download

COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 go build -ldflags "-s -w" -trimpath

#--------------------------------
# 2. FFmpeg Builder
# docker run -it --rm --name ffmpeg-nvidia-container-build nvidia/cuda:12.9.0-cudnn-devel-ubuntu24.04 bash 로 아래 build-context 테스트
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION} AS ffmpeg-builder
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt install -y \
    build-essential \
    git \
    nasm \
    yasm \
    cmake \
    libass-dev \
    libfreetype-dev \
    libfontconfig-dev \
    libx264-dev \
    libx265-dev \
    libnuma-dev \
    libvpx-dev \
    libfdk-aac-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    libxvidcore-dev \
    libtool-bin \
    pkg-config

# Install NV-Codec-Headers
RUN git clone https://github.com/FFmpeg/nv-codec-headers.git /usr/src/nv-codec-headers && \
    cd /usr/src/nv-codec-headers && \
    make install

# Build Configure 
RUN git clone https://git.ffmpeg.org/ffmpeg.git /usr/src/ffmpeg && \
    cd /usr/src/ffmpeg && \
    ./configure \
    --prefix="/usr/local/ffmpeg_cuda" \
    --enable-shared \
    --enable-gpl \
    --enable-libx264 \
    --enable-libx265 \
    --enable-nvenc \
    --enable-nvdec \
    --enable-cuda-nvcc \
    --enable-cuvid \
    --enable-nonfree \
    --extra-cflags="-I/usr/local/cuda/include -I/usr/local/include/ffnvcodec" \
    --extra-ldflags="-L/usr/local/cuda/lib64" \
    --disable-static && \
    make -j$(nproc) && \
    make install


#--------------------------------
# 3. Final image
FROM debian:${DEBIAN_VERSION}
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# Prepare apt for buildkit cache
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache

# Install ffmpeg, tini (for signal handling),
# and other common tools for the echo source.
# non-free for Intel QSV support (not used by go2rtc, just for tests)
# mesa-va-drivers for AMD APU
# libasound2-plugins for ALSA support
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    echo 'deb http://deb.debian.org/debian trixie non-free' > /etc/apt/sources.list.d/debian-non-free.list && \
    # apt-get -y update && apt-get -y install ffmpeg tini \
    apt-get -y update && apt-get -y install tini \
        python3 curl jq \
        # intel-media-va-driver-non-free \
        # mesa-va-drivers \
        libasound2-plugins && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/go2rtc /usr/local/bin/
COPY --from=ffmpeg-builder /usr/local/ffmpeg_cuda /usr/local/ffmpeg_cuda

ENTRYPOINT ["/usr/bin/tini", "--"]
VOLUME /config
WORKDIR /config
# https://github.com/NVIDIA/nvidia-docker/wiki/Installation-(Native-GPU-Support)
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility
ENV PATH="/usr/local/ffmpeg_cuda/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/ffmpeg_cuda/lib:$LD_LIBRARY_PATH"

CMD ["go2rtc", "-config", "/config/go2rtc.yaml"]
