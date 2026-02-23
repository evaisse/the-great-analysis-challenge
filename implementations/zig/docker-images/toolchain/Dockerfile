ARG ZIG_IMAGE=ziglings/ziglang:latest
ARG MAKE_IMAGE=buildpack-deps:bookworm
FROM ${MAKE_IMAGE} AS make
FROM ${ZIG_IMAGE}
RUN mkdir -p /lib/x86_64-linux-gnu
COPY --from=make /usr/bin/make /usr/bin/make
COPY --from=make /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
RUN if [ ! -e /lib/x86_64-linux-gnu/libc.so.6 ]; then 
ln -s /lib/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6; 
fi
WORKDIR /app
