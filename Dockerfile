FROM gramineproject/gramine:v1.5

RUN apt-get update && apt-get install -y jq build-essential

WORKDIR /workdir

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup toolchain install 1.72.0

RUN gramine-sgx-gen-private-key

# This should be associated with an acive IAS SPID in order for
# gramine tools like gramine-sgx-ias-request and gramine-sgx-ias-verify
ENV RA_CLIENT_SPID=51CAF5A48B450D624AEFE3286D314894
ENV RA_CLIENT_LINKABLE=1

# Build just the dependencies (shorcut)
COPY Cargo.lock Cargo.toml ./
RUN mkdir src && touch src/lib.rs
RUN cargo build
RUN rm src/lib.rs

# Now add our actual source
COPY Makefile sgx-revm.manifest.template ./
COPY src/main.rs ./src/

# Build with rust
RUN cargo build --release

# Make and sign the gramine manifest
RUN make SGX=1 RA_TYPE=epid

CMD gramine-sgx-sigstruct-view sgx-revm.sig
