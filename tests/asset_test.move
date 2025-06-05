#[test_only]
module stablecoin::asset_test {
    use std::string::utf8;
    use aptos_framework::account::create_signer_for_test;
    use aptos_framework::event::emitted_events;
    use stablecoin::asset::{Self, Mint, Burn, Transfer, Denylist, Pause, Minter};

    const EUNAUTHORIZED: u64 = 1;
    const EPAUSED: u64 = 2;
    const EALREADY_MINTER: u64 = 3;
    const ENOT_MINTER: u64 = 4;
    const EBLACKLISTED: u64 = 5;
    const EUNEXISTANTPRIMARYSTORE: u64 = 6;
    const EASSETALREADYEXIST: u64 = 7;
    const EASSETNOTINITIALIZED: u64 = 8;
    const EASSETNOTMINTEDPROPERLY: u64 = 9;
    const EASSETNAMEMISSMATCH: u64 = 10;
    const EASSETSYMBOLMISSMATCH: u64 = 11;
    const EASSETDECIMALSMISSMATCH: u64 = 12;
    const EMINTERNOTADDED: u64 = 13;
    const EASSETTRANSFERERROR: u64 = 14;
    const EEVENTNOTEMITED: u64 = 15;

    fun setup_initialized_asset(admin: &signer, symbol: vector<u8>) {
        stablecoin::asset::init_asset(
            admin,
            symbol,
            b"USD Kilo",
            b"https://usdk.io/icon",
            b"https://usdk.io",
            6,
            100_000_000
        );
    }

    #[test]
    fun test_get_asset_address_pre_asset_init() {
        let asset_addr = asset::get_asset_address();
        assert!(asset_addr == @0x0, EASSETALREADYEXIST)
    }

    #[test]
    fun test_get_total_assets_minted_pre_asset_init() {
        let total_assets_minted = asset::total_assets_minted();
        assert!(total_assets_minted == 0, EASSETALREADYEXIST)
    }

    #[test]
    fun test_get_asset_metadata_pre_asset_init() {
        let asset_metadata = asset::get_metadata();
        assert!(asset_metadata.is_none(), EASSETALREADYEXIST)
    }

    #[test]
    fun test_get_asset_name_pre_asset_init() {
        let asset_name = asset::get_asset_name();
        assert!(asset_name == utf8(b""), EASSETALREADYEXIST)
    }

    #[test]
    fun test_get_asset_symbol_pre_asset_init() {
        let asset_symbol = asset::get_asset_symbol();
        assert!(asset_symbol == utf8(b""), EASSETALREADYEXIST)
    }

    #[test]
    fun test_get_minters_pre_asset_init() {
        let minters = asset::get_minters();
        assert!(minters.length() == 0, EASSETALREADYEXIST)
    }

    #[test]
    fun test_init_asset() {
        let symbol = b"TEST";
        let admin = create_signer_for_test(@admin);
        setup_initialized_asset(&admin, symbol);

        let asset_addr = asset::get_asset_address();
        assert!(asset_addr != @0x0, EASSETNOTINITIALIZED);

        let asset_name = asset::get_asset_name();
        assert!(asset_name == utf8(b"USD Kilo"), EASSETNAMEMISSMATCH);

        let asset_symbol = asset::get_asset_symbol();
        assert!(asset_symbol == utf8(symbol), EASSETSYMBOLMISSMATCH);

        let asset_decimals = asset::get_asset_decimals();
        assert!(asset_decimals == 6, EASSETDECIMALSMISSMATCH);

        let asset_metadata = asset::get_metadata();
        assert!(asset_metadata.is_some(), EASSETNOTINITIALIZED)
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = asset)]
    fun test_init_asset_with_unauthorized_account() {
        let admin = create_signer_for_test(@0xF4153);
        setup_initialized_asset(&admin, b"FAIL");
    }

    #[test]
    #[expected_failure(abort_code = EASSETALREADYEXIST, location = asset)]
    fun test_init_asset_twice() {
        let admin = create_signer_for_test(@admin);
        setup_initialized_asset(&admin, b"TEST");
        setup_initialized_asset(&admin, b"FAIL");
    }

    #[test]
    fun test_mint_to_works() {
        let admin = @admin;
        let minter = @0xB;
        let receiver = @0xC;

        let admin_signer = create_signer_for_test(admin);
        setup_initialized_asset(&admin_signer, b"COIN");

        asset::add_minter(&admin_signer, minter);
        let minter_signer = create_signer_for_test(minter);
        let minters = asset::get_minters();
        assert!(minters.contains(&minter), EMINTERNOTADDED);

        asset::mint_to(&minter_signer, receiver, 1000);

        let balance = asset::asset_balance(receiver);
        assert!(balance == 1000, EASSETNOTMINTEDPROPERLY);

        let events = emitted_events<Mint>();
        assert!(events.length() != 0, EEVENTNOTEMITED);

        let total_asset_minted = asset::total_assets_minted();
        assert!(total_asset_minted == 1000, EASSETNOTMINTEDPROPERLY);
    }

    #[test]
    #[expected_failure(abort_code = EASSETNOTINITIALIZED, location = asset)]
    fun test_mint_to_before_asset_initializes() {
        let minter = create_signer_for_test(@0xB);
        let receiver = @0xC;
        asset::mint_to(&minter, receiver, 1000);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_MINTER, location = asset)]
    fun test_mint_to_with_unauthorized_minter() {
        let admin_signer = create_signer_for_test(@admin);
        let minter = create_signer_for_test(@0xB);
        let receiver = @0xC;

        setup_initialized_asset(&admin_signer, b"COIN");
        asset::mint_to(&minter, receiver, 1000);
    }

    #[test]
    #[expected_failure(abort_code = EBLACKLISTED, location = asset)]
    fun test_mint_to_denylisted_account() {
        let admin_signer = create_signer_for_test(@admin);
        let receiver = @0xC;

        setup_initialized_asset(&admin_signer, b"COIN");
        asset::add_to_denylist(&admin_signer, receiver);
        asset::mint_to(&admin_signer, receiver, 1000);
    }

    #[test]
    #[expected_failure(abort_code = EPAUSED, location = asset)]
    fun test_mint_to_with_paused_asset() {
        let admin_signer = create_signer_for_test(@admin);
        let receiver = @0xC;

        setup_initialized_asset(&admin_signer, b"COIN");
        asset::set_pause(&admin_signer);
        asset::mint_to(&admin_signer, receiver, 1000);
    }

    #[test]
    fun test_burn_from() {
        let admin = @admin;
        let receiver = @0xC;
        let mint_amount: u64 = 50000;
        let burn_amount: u64 = 10000;

        let admin_signer = create_signer_for_test(admin);
        setup_initialized_asset(&admin_signer, b"COIN");
        asset::mint_to(&admin_signer, receiver, mint_amount);

        let balance = asset::asset_balance(receiver);
        assert!(balance == mint_amount, EASSETNOTMINTEDPROPERLY);

        asset::burn_from(&admin_signer, receiver, burn_amount);

        let events = emitted_events<Burn>();
        assert!(events.length() != 0, EEVENTNOTEMITED);

        let balance = asset::asset_balance(receiver);
        assert!(balance == mint_amount - burn_amount, EASSETNOTMINTEDPROPERLY);
    }

    #[test]
    #[expected_failure(abort_code = EASSETNOTINITIALIZED, location = asset)]
    fun test_burn_from_before_asset_initializes() {
        let admin = create_signer_for_test(@admin);
        let receiver = @0xC;
        let burn_amount: u64 = 10000;

        asset::burn_from(&admin, receiver, burn_amount);
    }

    #[test]
    #[expected_failure(abort_code = EPAUSED, location = asset)]
    fun test_burn_from_with_asset_paused() {
        let admin = create_signer_for_test(@admin);
        let receiver = @0xC;
        let mint_amount: u64 = 50000;
        let burn_amount: u64 = 10000;

        setup_initialized_asset(&admin, b"COIN");
        asset::mint_to(&admin, receiver, mint_amount);
        asset::set_pause(&admin);
        asset::burn_from(&admin, receiver, burn_amount);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_MINTER, location = asset)]
    fun test_burn_from_with_an_unauthorized_minter() {
        let admin = create_signer_for_test(@admin);
        let minter = create_signer_for_test(@0xF4153);
        let receiver = @0xC;
        let mint_amount: u64 = 50000;
        let burn_amount: u64 = 10000;

        setup_initialized_asset(&admin, b"COIN");
        asset::mint_to(&admin, receiver, mint_amount);
        asset::burn_from(&minter, receiver, burn_amount);
    }

    #[test]
    #[expected_failure]
    fun test_burn_from_without_assets() {
        let admin = create_signer_for_test(@admin);
        let receiver = @0xC;
        let burn_amount: u64 = 10000;

        setup_initialized_asset(&admin, b"COIN");
        asset::burn_from(&admin, receiver, burn_amount);
    }

    #[test]
    fun test_transfer_to() {
        let admin = create_signer_for_test(@admin);
        let from = @0xF7;
        let from_signer = create_signer_for_test(from);
        let to = @0x70;
        let mint_amount = 100000;
        let transfer_amount = 50000;

        setup_initialized_asset(&admin, b"COIN");
        asset::mint_to(&admin, from, mint_amount);
        asset::transfer_to(&from_signer, to, transfer_amount);

        let events = emitted_events<Transfer>();
        assert!(events.length() != 0, EEVENTNOTEMITED);

        let to_balance = asset::asset_balance(to);
        assert!(to_balance == transfer_amount, EASSETTRANSFERERROR)
    }

    #[test]
    #[expected_failure]
    fun test_transfer_to_without_enough_balance() {
        let admin = create_signer_for_test(@admin);
        let from = @0xF7;
        let from_signer = create_signer_for_test(from);
        let to = @0x70;
        let transfer_amount = 50000;

        setup_initialized_asset(&admin, b"COIN");
        asset::transfer_to(&from_signer, to, transfer_amount);
    }

    #[test]
    #[expected_failure(abort_code = EASSETNOTINITIALIZED, location = asset)]
    fun test_transfer_to_before_asset_initialized() {
        let from = create_signer_for_test(@0xF7);
        let to = @0x70;
        let transfer_amount = 50000;

        asset::transfer_to(&from, to, transfer_amount);
    }

    #[test]
    #[expected_failure(abort_code = EPAUSED, location = asset)]
    fun test_transfer_to_when_paused_asset() {
        let admin = create_signer_for_test(@admin);
        let from = @0xF7;
        let from_signer = create_signer_for_test(from);
        let to = @0x70;
        let transfer_amount = 50000;

        setup_initialized_asset(&admin, b"COIN");
        asset::set_pause(&admin);
        asset::transfer_to(&from_signer, to, transfer_amount);
    }

    #[test]
    #[expected_failure(abort_code = EBLACKLISTED, location = asset)]
    fun test_transfer_to_when_any_of_the_accounts_is_denylisted() {
        let admin = create_signer_for_test(@admin);
        let from = @0xF7;
        let from_signer = create_signer_for_test(from);
        let to = @0x70;
        let transfer_amount = 50000;

        setup_initialized_asset(&admin, b"COIN");
        asset::add_to_denylist(&admin, to);
        asset::transfer_to(&from_signer, to, transfer_amount);
    }

    #[test]
    fun test_set_pause() {
        let admin = create_signer_for_test(@admin);
        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&admin);
    }

    #[test]
    #[expected_failure(abort_code= EASSETNOTINITIALIZED, location = asset)]
    fun test_set_pause_before_asset_initializes() {
        let admin = create_signer_for_test(@admin);
        asset::set_pause(&admin);
        let events = emitted_events<Pause>();
        assert!(events.length() != 0, EEVENTNOTEMITED);
    }

    #[test]
    #[expected_failure(abort_code= EUNAUTHORIZED, location = asset)]
    fun test_set_pause_with_unauthorized_pauser() {
        let admin = create_signer_for_test(@admin);
        let pauser = create_signer_for_test(@0x7);

        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&pauser);
    }

    #[test]
    fun test_add_to_denylist() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_to_denylist(&admin, account);
        let events = emitted_events<Denylist>();
        assert!(events.length() != 0, EEVENTNOTEMITED);
    }

    #[test]
    #[expected_failure(abort_code= EASSETNOTINITIALIZED, location = asset)]
    fun test_add_to_denylist_before_asset_initializes() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        asset::add_to_denylist(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EPAUSED, location = asset)]
    fun test_add_to_denylist_with_asset_paused() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&admin);
        asset::add_to_denylist(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EUNAUTHORIZED, location = asset)]
    fun test_add_to_denylist_when_denylister_is_unauthorized() {
        let admin = create_signer_for_test(@admin);
        let denylister = create_signer_for_test(@0x56);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_to_denylist(&denylister, account);
    }

    #[test]
    #[expected_failure(abort_code= EBLACKLISTED, location = asset)]
    fun test_add_to_denylist_when_account_is_already_denylisted() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_to_denylist(&admin, account);
        asset::add_to_denylist(&admin, account);
    }

    #[test]
    fun test_remove_from_denylist() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_to_denylist(&admin, account);
        asset::remove_from_denylist(&admin, account);

        let events = emitted_events<Denylist>();
        assert!(events.length() == 2, EEVENTNOTEMITED);
    }

    #[test]
    #[expected_failure(abort_code= EASSETNOTINITIALIZED, location = asset)]
    fun test_remove_from_denylist_when_asset_not_initialized() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        asset::remove_from_denylist(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EPAUSED, location = asset)]
    fun test_remove_from_denylist_when_asset_is_paused() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&admin);
        asset::remove_from_denylist(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EUNAUTHORIZED, location = asset)]
    fun test_remove_from_denylist_if_denylister_is_unauthorized() {
        let admin = create_signer_for_test(@admin);
        let denylister = create_signer_for_test(@0x45);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_to_denylist(&admin, account);
        asset::remove_from_denylist(&denylister, account);
    }

    #[test]
    fun test_add_minter() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_minter(&admin, account);

        let events = emitted_events<Minter>();
        assert!(events.length() != 0, EEVENTNOTEMITED);
    }

    #[test]
    #[expected_failure(abort_code= EASSETNOTINITIALIZED, location = asset)]
    fun test_add_minter_before_asset_initializes() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        asset::add_minter(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EPAUSED, location = asset)]
    fun test_add_minter_is_asset_is_paused() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&admin);
        asset::add_minter(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EUNAUTHORIZED, location = asset)]
    fun test_add_minter_when_master_minter_is_unauthorized() {
        let admin = create_signer_for_test(@admin);
        let master_minter = create_signer_for_test(@0x34);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_minter(&master_minter, account);
    }

    #[test]
    #[expected_failure(abort_code= EALREADY_MINTER, location = asset)]
    fun test_add_minter_if_the_new_minter_is_already_a_minter() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_minter(&admin, account);
        asset::add_minter(&admin, account);
    }

    #[test]
    fun test_remove_minter() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::add_minter(&admin, account);

        let minters = asset::get_minters();
        assert!(minters.contains(&account), ENOT_MINTER);

        asset::remove_minter(&admin, account);

        let minters = asset::get_minters();
        assert!(!minters.contains(&account), ENOT_MINTER);

        let events = emitted_events<Minter>();
        assert!(events.length() == 2, EEVENTNOTEMITED);
    }

    #[test]
    #[expected_failure(abort_code= EASSETNOTINITIALIZED, location = asset)]
    fun test_remove_minter_before_asset_is_not_initialized() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        asset::remove_minter(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= EPAUSED, location = asset)]
    fun test_remove_minter_when_asset_is_paused() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::set_pause(&admin);
        asset::remove_minter(&admin, account);
    }

    #[test]
    #[expected_failure(abort_code= ENOT_MINTER, location = asset)]
    fun test_remove_minter_if_account_is_not_a_minter() {
        let admin = create_signer_for_test(@admin);
        let account = @0x33;

        setup_initialized_asset(&admin, b"TEST");
        asset::remove_minter(&admin, account);
    }
}
