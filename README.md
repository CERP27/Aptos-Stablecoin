# 🪙 Stablecoin Module

This Move module implements a managed stablecoin system based on the Aptos `fungible_asset` standard. It allows for the
creation, transfer, burning, pausing, and administrative control of a fungible asset, with support for role-based access
control and denylist management.

---

## 📌 Features

- Mint and burn operations controlled by designated roles
- Pause/resume functionality
- Role management (master minter, minters, pauser)
- Denylist to block specific addresses
- Uses the Aptos `fungible_asset` standard
- Composable with other modules and upgradable

---

## 🛠️ Build & Deployment

## ✅ Requirements

- [Aptos CLI](https://aptos.dev/tools/aptos-cli/) installed
- [Rust](https://www.rust-lang.org/tools/install) installed
- Git and Move CLI (included in Aptos toolchain)

## 🔧 Build the Module

```bash
  aptos move compile
```

## 🚀 Deploy the Module

1. Initialize your local Aptos profile:

````bash
  aptos init --profile any_profile_name
````

2. Publish the module:

```bash
  aptos move deploy-object \
    --address-name stablecoin \
    --profile profile-name\
    --assume-yes \
    --named-addresses "admin=@0xANYACCOUNT" //any acount you want to use as an admin
```

## 🧪 Running Tests

To run unit tests for the `stablecoin::asset` module, use:

```bash
  aptos move test --dev
```

## ⚙️ Usage

Below is a summary of how to interact with the `stablecoin::asset` module, along with a description of each entry and
view function.

### ❗Reminder

* Replace `0xSTABLECOIN_ADDRESS` with their deployed contract address.
* Replace placeholder profile names `(like ADMIN_PROFILE_NAME, MINTER_PROFILE_NAME, etc.)` with their actual CLI profile
  names.
* Replace argument placeholders `(like ACCOUNT_ADDRESS, _SYMBOL_HEX, _AMOUNT_U64)` with appropriate values in the
  correct format.

---

### 👀 View

These functions allow you to read data from the contract's state without submitting a transaction.

#### *Get Asset Address*:

Retrieves the address where the fungible asset and its associated resources (Roles, Management, State) are stored.
Returns 0x0 if the asset has not been initialized.

```bash
    aptos move view \
      --function-id "0xSTABLECOIN_ADDRESS::asset::get_asset_address"
```

#### *Get Metadata*

Retrieves the metadata object of the fungible asset. Returns None if the asset has not been initialized.

```bash
    aptos move view \
      --function-id "0xSTABLECOIN_ADDRESS::asset::get_metadata"
```

#### *Get Total Assets Minted*

Returns the total supply of the fungible asset that has been minted. Returns 0 if the asset has not been initialized.

```bash
    aptos move view \
      --function-id "0xSTABLECOIN_ADDRESS::asset::total_assets_minted"
```

#### *Get Asset Name*

Returns the name of the fungible asset as a string (e.g., "My Stablecoin"). Returns an empty string if the asset has not
been initialized.

```bash
    aptos move view \
      --function-id "0xSTABLECOIN_ADDRESS::asset::get_asset_name"
```

#### *Get Asset Symbol*

Returns the symbol of the fungible asset as a string (e.g., "MSC"). Returns an empty string if the asset has not been
initialized.

```bash
  aptos move view \
    --function-id "0xSTABLECOIN_ADDRESS::asset::get_asset_symbol"
```

#### *Get Asset Decimals*

Returns the number of decimals the fungible asset uses. Returns 0 if the asset has not been initialized.

```bash
  aptos move view \
    --function-id "0xSTABLECOIN_ADDRESS::asset::get_asset_decimals"
```

#### *Get Asset Balance*

Returns the balance of the fungible asset for a given account address. Returns 0 if the asset is not initialized or the
account does not have a primary store for this asset.

```bash
  aptos move view \
    --function-id "0xSTABLECOIN_ADDRESS::asset::asset_balance" \
    --args 'address:ACCOUNT_ADDRESS'
```

#### *Get Asset Minters*

Returns a vector of addresses that are authorized minters for the asset. Returns an empty vector if the asset has not
been initialized.

```bash
  aptos move view \
    --function-id "0xSTABLECOIN_ADDRESS::asset::get_minters"
```

---

### 🪙 Entry

These functions modify the contract's state and require a transaction to be submitted by a signer.

#### *Init Asset*

Initializes the fungible asset. This can only be called once by the admin account (master minter). It creates the asset,
sets its metadata, and initializes roles and management structures.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::init_asset" \
    --profile ADMIN_PROFILE_NAME \
    --args \
      "hex:_SYMBOL_HEX" \
      "hex:_NAME_HEX" \
      "hex:_ICON_URL_HEX" \
      "hex:_PROJECT_URL_HEX" \
      "u8:_DECIMALS_U8" \
      "u128:_MAX_SUPPLY_U128" 
```

#### *Mint Asset to account*

Mints a specified amount of the asset to a to address. Can only be called by an authorized minter (master minter or an
address added via add_minter). The recipient address must not be denylisted.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::mint_to" \
    --sender-account MINTER_PROFILE_NAME \
    --args \
      "address:RECIPIENT_ADDRESS" \
      "u64:_AMOUNT_U64"
```

#### *Burn Asset from account*

Burns a specified amount of the asset from a from address's primary store. Can only be called by an authorized minter.
The contract must not be paused.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::burn_from" \
    --sender-account MINTER_PROFILE_NAME \
    --args \
      "address:FROM_ADDRESS" \
      "u64:_AMOUNT_U64"
```

#### *Transfer Asset to*

Transfers a specified amount of the asset from the signer's account (from) to a to address. The contract must not be
paused, and neither the sender nor the recipient can be denylisted.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::transfer_to" \
    --sender-account SENDER_PROFILE_NAME \
    --args \
      "address:RECIPIENT_ADDRESS" \
      "u64:_AMOUNT_U64"
```

#### *Set Pause*

Toggles the paused state of the contract. If paused, most actions like minting, burning, and transferring are disabled.
Can only be called by the designated pauser address (initially the admin).

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::set_pause" \
    --sender-account PAUSER_PROFILE_NAME
```

#### *Add to Deny List*

Adds an account to the denylist (freezes their primary store). Denylisted accounts cannot send or receive assets and
cannot be minted to. Can only be called by the designated denylister address (initially the admin). The contract must
not be paused, and the account must not yet be denylisted.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::add_to_denylist" \
    --sender-account DENYLISTER_PROFILE_NAME \
    --args "address:ACCOUNT_TO_DENYLIST"
```

#### *Remove Denylisted*

Removes an account from the denylist (unfreezes their primary store). Can only be called by the designated denylister
address. The contract must not be paused.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::remove_from_denylist" \
    --sender-account DENYLISTER_PROFILE_NAME \
    --args "address:ACCOUNT_TO_UNDENYLIST"
```

#### *Add Minter*

Adds a new minter address to the list of authorized minters. Can only be called by the master_minter (the admin
address). The contract must not be paused, and the address must not yet be a minter.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::add_minter" \
    --sender-account ADMIN_PROFILE_NAME \
    --args "address:NEW_MINTER_ADDRESS"
```

#### *Remove Minter*

Removes a minter address from the list of authorized minters. Can only be called by the master_minter (the admin
address). The contract must not be paused, and the address must currently be a minter.

```bash
  aptos move run \
    --function-id "0xSTABLECOIN_ADDRESS::asset::remove_minter" \
    --sender-account ADMIN_PROFILE_NAME \
    --args "address:MINTER_TO_REMOVE_ADDRESS"
```
