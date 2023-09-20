FROM golang:1.21 AS builder
WORKDIR /go/src/github.com/youscan/dcgm-exporter

COPY . .

ARG DOCKER_METADATA_OUTPUT_VERSION
RUN cd cmd/dcgm-exporter && \
    go build -ldflags "-X main.BuildVersion=3.2.5-${DOCKER_METADATA_OUTPUT_VERSION}" && \
    test $(gofmt -l pkg | tee /dev/stderr | wc -l) -eq 0 && \
    test $(gofmt -l cmd | tee /dev/stderr | wc -l) -eq 0

FROM nvcr.io/nvidia/cuda:12.2.0-base-ubuntu22.04
LABEL io.k8s.display-name="NVIDIA DCGM Exporter"

COPY --from=builder /go/src/github.com/youscan/dcgm-exporter/cmd/dcgm-exporter/dcgm-exporter /usr/bin/
COPY etc /etc/dcgm-exporter

RUN apt-get update && \
    apt-get install -y --no-install-recommends datacenter-gpu-manager=1:3.2.5 libcap2-bin && \
    apt-get purge --autoremove -y openssl && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,compat32
ENV NVIDIA_DISABLE_REQUIRE="true"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NO_SETCAP=

COPY entrypoint.sh /usr/local/dcgm/entrypoint.sh
RUN chmod +x /usr/local/dcgm/entrypoint.sh

ENTRYPOINT ["/usr/local/dcgm/entrypoint.sh"]
