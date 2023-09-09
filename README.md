# GRAMINE - SGX - REVM

**PoC illustrating the usage of the [Gramine platform](https://gramine.readthedocs.io/) for executing
an EVM message confidentially.**

## How it works

0. User manually provisions an [SGX server, e.g. on Azure](https://learn.microsoft.com/en-us/azure/confidential-computing/quick-create-portal)
1. SGX-enabled server opens up a TCP Socket with TLS Enabled (assumes some kind of Certificate is already generated, see first line in main.rs - ideally there's a productionized way to do Certificate provisioning).
2. User submits a TLS-encrypted payload to the server, ensuring the user and the server only have access to the information being delivered (the server actually doesn't because the socket is opened within the SGX enclave).
3. The Server proceeds to parse the payload into an EVM message and execute it _confidentially_.

The EVM database is expected to be instantiated as _empty_, and the user is expected to provide a payload which contains all the storage slots & values required by their transaction, _including Merkle Patricia Proofs_ for proving that these transactions are part of the actual state. It assumes that there is also a state root available to check against.

## TODO

1. Make the demo unit-testable for CI usage

## How to replicate the MRENCLAVE build on any machine (without SGX)

The best way to replicate the results is through Docker.

```bash
docker build . --tag revm
docker run -it --device /dev/sgx_enclave \
       --device /dev/sgx_provision \
       -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket \
       -v ./data:/workdir/data \
       revm bash
```

## How to replicate the results on an SGX-enabled environment

### Installing the Gramine platform

On an SGX-supported machine (e.g. on Azure, an Intel NUC, Inspiron laptop, etc.), you'll need to install the Gramine library.

Providing a quick-start below:

```bash
# From: https://gramine.readthedocs.io/en/stable/installation.html#ubuntu-22-04-lts-or-20-04-lts
# Install Gramine and Intel SDK Dependencies
sudo curl -fsSLo /usr/share/keyrings/gramine-keyring.gpg https://packages.gramineproject.io/gramine-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/gramine-keyring.gpg] https://packages.gramineproject.io/ $(lsb_release -sc) main" \
| sudo tee /etc/apt/sources.list.d/gramine.list

sudo curl -fsSLo /usr/share/keyrings/intel-sgx-deb.asc https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-sgx-deb.asc] https://download.01.org/intel-sgx/sgx_repo/ubuntu $(lsb_release -sc) main" \
| sudo tee /etc/apt/sources.list.d/intel-sgx.list

sudo apt-get update
sudo apt-get install gramine libsgx-aesm-epid-plugin
```

# Check your SGX setup, all should be green except the `libsgx_enclave_common` maybe.
```bash
is-sgx-available
```

# Generate Gramine mrsigner keys if you haven't yet (we won't use code signing but it's needed)
```bash
gramine-sgx-gen-private-key
```

# Build the rust target. Unlike Fortanix, this doesn't include any custom target.
```bash
cargo build --release
```

# Use Gramine to build a manifest and scoop up the dependencies.
```
make SGX=1 RA_TYPE=epid
```

### Running the demo

On a terminal run:
```
gramine-sgx ./sgx-revm
```

If Gramine is installed then this will output a receipt.
You can change the values in `/data/output` 


docker run --device /dev/sgx_enclave --device /dev/sgx_provision -it gramineproject/gramine
