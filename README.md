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

## How to replicate the MRENCLAVE build using Docker (no SGX Required)

The best way to replicate the results is through Docker. The included Dockerfile begins from the Gramine project's tagged docker image.

At this point you have produced an MRENCLAVE. This should be identical to the MRENCLAVE that would run on an SGX-enabled node.

Next we can validate the sample report, signed from IAS. If the MRENCLAVE doesn't match, this will be reported. The sample report is clearly from an unpatched machine, `--allow-outdated-tcb` is just so it outputs the full report, it's not a policy suggestion.

Even without SGX, we can complete the interactive "quote verification" step. This has to use an API key, but it doesn't have to be the one used from codesigning.
Note that this is one of the flows that is different when using DCAP, and it is not part of the TCB for the verifier.
The significance in this demo is to show that this step doesn't need to be run in an enclave.


```bash
docker build . --tag revm
docker run -it -v ./data:/workdir/data revm bash

gramine-sgx-sigstruct-view sgx-revm.sig
# Expect: mr_enclave: 38592370d0c81f182fc027e8f8afc64f8f1bbe7cf7d59183eb2497c3a27809c3

# Verifying sample reports
export MRENCLAVE=38592370d0c81f182fc027e8f8afc64f8f1bbe7cf7d59183eb2497c3a27809c3
gramine-sgx-ias-verify-report -E $MRENCLAVE -v -r sample/sample.report -s sample/sample.reportsig --allow-outdated-tcb

# Untrusted interaction with IAS
gramine-sgx-quote-view sample/sample.quote
export RA_API_KEY=669244b3e6364b5888289a11d2a1726d
gramine-sgx-ias-request report -k $RA_API_KEY -r data/report -s data/reportsig
gramine-sgx-ias-verify-report -E $MRENCLAVE -v -r data/report -s data/reportsig --allow-outdated-tcb
```

## How to replicate the execution on an SGX-enabled environment (still using Docker)

First set up the docker environment, providing access to the underlying enclave and AESM service,
and mounting the data folder to use for output.
```bash
docker run -it --device /dev/sgx_enclave \
       -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket \
       -v ./data:/workdir/data \
       revm bash
is-sgx-available
gramine-sgx ./sgx-revm
gramine-sgx-quote-view data/quote
```
A quote is now saved in `data/quote`

## How to verify the resulting quote (no SGX required)

Although you do not need SGX, you will need to use an API key from Intel Attestation Services (IAS).
You can register for free here: https://api.portal.trustedservices.intel.com/EPID-attestation

```bash
docker run -it -v ./data:/workdir/data revm bash
gramine-sgx-quote-view data/quote
export RA_API_KEY=669244b3e6364b5888289a11d2a1726d
gramine-sgx-ias-request report -k $RA_API_KEY -q data/quote -r data/report -s data/reportsig
gramine-sgx-ias-verify-report -v -r data/report -s data/reportsig --allow-outdated-tcb
```

The invocation of `gramine-sgx-ias-request report` should respond with something `IAS submission successful`.
Anything else indicates the API key is no longer valid and you should try to register your own.


## Replicating the experiment with Gramine directly, no Docker

This may be more direct if you already have a Gramine instance installed. This folder is meant to be convenient to run from within `gramine/CI-Examples/gramine-sgx-revm`.
However the main drawback is that there will be little chance of reproducing MRENCLAVE exactly system by system

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

# Check your SGX setup, all should be green except the `libsgx_enclave_common` maybe.
is-sgx-available

# Generate Gramine mrsigner keys if you haven't yet (we won't use code signing but it's needed)
gramine-sgx-gen-private-key

# Set up rust
curl https://sh.rustup.rs -sSf | bash
rustup toolchain install nightly

# Build the rust target. Unlike Fortanix, this doesn't include any custom target.
cargo build --release

# Use Gramine to build the manifest and compute the MRENCLAVE
make SGX=1
gramine-sgx-sigstruct-view sgx-revm.sig

# Run Gramine
gramine-sgx sgx-revm
gramine-sgx-quote-view data/quote
export RA_API_KEY=669244b3e6364b5888289a11d2a1726d
gramine-sgx-ias-request report -k $RA_API_KEY -q data/quote -r data/report -s data/reportsig
gramine-sgx-ias-verify-report -v -r data/report -s data/reportsig --allow-outdated-tcb
```
