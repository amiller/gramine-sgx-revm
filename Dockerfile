FROM gramineproject/gramine:v1.5

RUN apt-get update && apt-get install -y jq build-essential

# For DCAP support
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y tzdata
RUN apt-get install -y npm
RUN npm install npm@latest -g && \
    npm install n -g && \
    n latest
RUN apt-get install -y python3 cracklib-runtime expect
RUN apt-get install -y libsgx-dcap-ql libsgx-dcap-default-qpl
RUN mkdir /etc/init
RUN mkdir -p /opt/intel/sgx-dcap-pccs/config/
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y sgx-dcap-pccs

# Setup rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup toolchain install 1.72.0

# Gramine private key (necessary, not an important key though)
RUN gramine-sgx-gen-private-key

WORKDIR /workdir

# This should be associated with an acive IAS SPID in order for
# gramine tools like gramine-sgx-ias-request and gramine-sgx-ias-verify
ENV RA_CLIENT_SPID=51CAF5A48B450D624AEFE3286D314894
ENV RA_CLIENT_LINKABLE=1

# Build just the dependencies (shorcut)
COPY Cargo.lock Cargo.toml ./
RUN mkdir src && touch src/lib.rs
RUN cargo build --release
RUN rm src/lib.rs

# Now add our actual source
COPY Makefile README.md sgx-revm.manifest.template ./
COPY src/main.rs ./src/
COPY sample/ ./sample/

# Build with rust
RUN cargo build --release

# Make and sign the gramine manifest
RUN make SGX=1 RA_TYPE=dcap

CMD [ "gramine-sgx-sigstruct-view sgx-revm.sig" ]
