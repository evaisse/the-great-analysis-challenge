FROM rust:1.89

WORKDIR /usr/src/chess

COPY . .

RUN cargo build --release

CMD ["./target/release/chess"]