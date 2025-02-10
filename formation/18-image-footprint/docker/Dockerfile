FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y golang-go=2:1.13~1ubuntu2
COPY app.go .
RUN CGO_ENABLED=0 go build app.go

FROM alpine:3.12.1
RUN chmod a-w /etc
RUN addgroup -S appgroup -g 1000 && adduser -S appuser -G appgroup -u 1000 -h /home/appuser
RUN rm -rf /bin/*
COPY --from=0 /app /home/appuser/app
WORKDIR /home/appuser
USER appuser:appgroup
CMD ["./app"]