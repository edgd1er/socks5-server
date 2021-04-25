ARG GOLANG_VERSION="1.12"

FROM golang:$GOLANG_VERSION-alpine as builder
WORKDIR /go/src/github.com/olebedev/socks5
COPY . .
RUN echo "Building with go version ${GOLANG_VERSION}" && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-s' -o ./socks5

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /go/src/github.com/olebedev/socks5/socks5 /
ENTRYPOINT ["/socks5"]
