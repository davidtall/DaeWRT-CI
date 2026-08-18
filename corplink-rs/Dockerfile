# Dockerfile
FROM golang:1.26-bookworm AS go

FROM rust:1-bookworm AS builder

COPY --from=go /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang \
        git \
        libclang-dev \
        libssl-dev \
        make \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# --recurse-submodules 会取 corplink-rs 固定的 wireguard-go 版本
RUN git clone --depth=1 --recurse-submodules --shallow-submodules \
      https://github.com/PinkD/corplink-rs.git

WORKDIR /src/corplink-rs/libwg
ARG WIREGUARD_GO_COMMIT=491cec86522a313d90c88d68865d99bcde780e80

RUN rm -rf wireguard-go \
    && git clone --depth=1 --branch libwg \
        https://github.com/PinkD/wireguard-go.git wireguard-go \
    && test "$(git -C wireguard-go rev-parse HEAD)" = "${WIREGUARD_GO_COMMIT}" \
    && sed -i 's/git describe --dirty/git describe --always --dirty/g' wireguard-go/Makefile \
    && ./build.sh

WORKDIR /src/corplink-rs
RUN cargo build --release --locked


FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        iproute2 \
        iputils-ping \
        libgcc-s1 \
        libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/corplink-rs/target/release/corplink-rs /usr/local/bin/corplink-rs

ENTRYPOINT ["/usr/local/bin/corplink-rs"]
CMD ["/etc/corplink/config.json"]
