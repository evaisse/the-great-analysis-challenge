FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .

RUN go build -o chess chess.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/chess .

CMD ["./chess"]