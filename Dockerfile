ARG GOLANG_VERSION="1.24"

#FROM golang:1.24-alpine as builder
FROM golang:$GOLANG_VERSION-alpine AS builder
ENV GOBIN=/go/bin

WORKDIR /build

#hadolint ignore=DL3018
RUN apk --no-cache add git \
    && echo "Building https://github.com/bobpaul/go-socks5-server with go version ${GOLANG_VERSION}" \
    && git clone -b merge_requests https://github.com/bobpaul/go-socks5-server . \
    #&& CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-s' -o ./sock5server \
    && CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w" -a -installsuffix cgo -o sock5server . \
    && ls -alh .

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/sock5server /
ENTRYPOINT ["/sock5server"]