# Upstream's Dockerfile, but built from PR #590 (revoked AppSync token) with
# PR #585 (fractional ratingsSum) applied on top. Neither is merged and a
# compose git context can only point at one ref, so pin #590's head commit —
# the patch is generated against it — and apply #585 as a patch.
# https://github.com/blampe/rreading-glasses/pull/590
# https://github.com/blampe/rreading-glasses/pull/585
FROM golang:1.26.0-alpine AS build

WORKDIR /app
ADD https://github.com/Faustvii/rreading-glasses.git#63b2cdf5272df6a5fa7789cf8d3ce8fa7a9bb433 .
COPY fractional-ratings-sum.patch /tmp/
RUN apk add --no-cache patch && patch -p1 < /tmp/fractional-ratings-sum.patch

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -o /app/main -ldflags="-w -s" ./cmd/rggr

FROM gcr.io/distroless/static:nonroot
COPY --from=build /app/main /main
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8788
CMD ["/main"]
