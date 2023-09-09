use alloy_primitives::{Address, U256};
use revm::{
    primitives::{AccountInfo, TxEnv, B160},
    InMemoryDB, EVM,
};

use std::{fs::File, io::Write, path::Path, fs};

// This payload should be generalized to include all the pre-state for each
// simulation.
#[derive(serde::Deserialize)]
struct Payload {
    sender: Address,
    amount: U256,
}

fn main() -> eyre::Result<()> {
    // Read from the untrusted host via a Gramine-mapped file
    let data: Payload = serde_json::from_reader(File::open("/var/sgx-revm-data/input")?)?;

    simulate(data)?;

    // Attestation available    
    if Path::new("/dev/attestation/quote").exists() {
        /*  TODO: make the user data include a meaningful statement
            For example, it could include the hash of the block and the transaction 
            being evaluated.
         */
        
        // Write some user report data
        let mut f = File::create("/dev/attestation/user_report_data")?;
        f.write_all(&b"\xde\xad\xbe\xef".repeat(32))?;
        drop(f);
       
        // Get the extracted attestation quote
        let quote = fs::read("/dev/attestation/quote")?;

        // Copy the attestation quote to our output directory
        fs::write("/var/sgx-revm-data/quote", &quote)?;
    } else {
        //Not found
        panic!("/dev/attestation/quote not found - is this in running in gramine with ra_type set?");
    };
    
    Ok(())
}

fn simulate(payload: Payload) -> eyre::Result<()> {
    let mut db = InMemoryDB::default();
    let receiver = payload.sender;
    let value = payload.amount;

    let balance = U256::from(111);
    // this is a random address
    let address = "0x4838b106fce9647bdf1e7877bf73ce8b0bad5f97".parse()?;
    let info = AccountInfo {
        balance,
        ..Default::default()
    };

    // Populate the DB pre-state,
    // TODO: Make this data witnessed via merkle patricia proofs.
    db.insert_account_info(address, info);
    // For storage insertions:
    // db.insert_account_storage(address, slot, value)

    // Setup the EVM with the configured DB
    // The EVM will ONLY be able to access the witnessed state, and
    // any simulation that tries to use state outside of the provided data
    // will fail.
    let mut evm = EVM::new();
    evm.database(db);

    evm.env.tx = TxEnv {
        caller: address,
        transact_to: revm::primitives::TransactTo::Call(B160::from(receiver.0 .0)),
        value,
        ..Default::default()
    };

    let result = evm.transact_ref()?;

    assert_eq!(
        result.state.get(&address).unwrap().info.balance,
        U256::from(69)
    );

    dbg!(&result);

    Ok(())
}
