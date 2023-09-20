FROM golang:1.18 AS build
WORKDIR /go/src/github.com/youscan/dcgm-exporter

COPY go.mod go.sum ./
RUN go mod download

ARG DOCKER_METADATA_OUTPUT_VERSION
COPY . .
RUN cd cmd/dcgm-exporter && \
    go build -ldflags "-X main.BuildVersion=${DOCKER_METADATA_OUTPUT_VERSION}" && \
    test $(gofmt -l pkg | tee /dev/stderr | wc -l) -eq 0 && \
    test $(gofmt -l cmd | tee /dev/stderr | wc -l) -eq 0

FROM nvcr.io/nvidia/cuda:12.2.0-base-ubuntu20.04

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,compat32
ENV NVIDIA_DISABLE_REQUIRE="true"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NO_SETCAP=

RUN apt-get update && \
    apt-get install -y --no-install-recommends datacenter-gpu-manager=1:3.2.5 libcap2-bin && \
    apt-get purge --autoremove -y openssl && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

COPY entrypoint.sh /usr/local/dcgm/entrypoint.sh
RUN chmod +x /usr/local/dcgm/entrypoint.sh
COPY etc /etc/dcgm-exporter
COPY --from=build /go/src/github.com/youscan/dcgm-exporter/cmd/dcgm-exporter/dcgm-exporter /usr/bin/

ENTRYPOINT ["/usr/local/dcgm/entrypoint.sh"]
