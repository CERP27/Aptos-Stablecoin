module stablecoin::asset {
    use aptos_framework::event;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset, FungibleStore,
        burn
    };
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::{utf8, String};

    const EUNAUTHORIZED: u64 = 1;
    const EPAUSED: u64 = 2;
    const EALREADY_MINTER: u64 = 3;
    const ENOT_MINTER: u64 = 4;
    const EBLACKLISTED: u64 = 5;
    const EUNEXISTANTPRIMARYSTORE: u64 = 6;
    const EASSETALREADYEXIST: u64 = 7;
    const EASSETNOTINITIALIZED: u64 = 8;

    const NO_ASSET_ADDR: address = @0x0;
    const ACTION_ADD: vector<u8> = b"add";
    const ACTION_REMOVE: vector<u8> = b"remove";

    #[event]
    struct Mint has drop, store {
        minter: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct Burn has drop, store {
        minter: address,
        from: address,
        store: Object<FungibleStore>,
        amount: u64,
    }

    #[event]
    struct Denylist has drop, store {
        denylister: address,
        account: address,
        action: String
    }

    #[event]
    struct Pause has drop, store {
        pauser: address,
        is_paused: bool
    }

    #[event]
    struct Transfer has drop, store {
        from: address,
        to: address,
        amount: u64
    }

    #[event]
    struct Minter has drop, store {
        master_minter: address,
        minter: address,
        action: String
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Roles has key {
        master_minter: address,
        minters: vector<address>,
        denylister: address,
        pauser: address,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Management has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct State has key {
        paused: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Asset has key {
        is_created: bool,
        address: address,
        symbol: vector<u8>,
        name: vector<u8>,
        decimals: u8
    }

    fun assert_is_not_minter(minter: address) acquires Roles, Asset {
        let role = borrow_global<Roles>(get_asset_address());
        assert!(!role.minters.contains(&minter), EALREADY_MINTER)
    }

    fun assert_is_minter(minter: address) acquires Roles, Asset {
        let role = borrow_global<Roles>(get_asset_address());
        assert!(minter == role.master_minter || role.minters.contains(&minter), ENOT_MINTER)
    }

    fun assert_is_denylisted(address: address) acquires Asset {
        let metadata = get_metadata().extract();

        let store_exists = primary_fungible_store::primary_store_exists_inlined(address, metadata);

        if (store_exists) {
            let store = primary_fungible_store::primary_store_inlined(address, metadata);
            assert!(!fungible_asset::is_frozen(store), EBLACKLISTED)
        }
    }

    fun assert_not_paused() acquires State, Asset {
        let state = borrow_global<State>(get_asset_address());
        assert!(!state.paused, EPAUSED)
    }

    fun assert_is_pauser(pauser: address) acquires Roles, Asset {
        let roles = borrow_global<Roles>(get_asset_address());
        assert!(pauser == roles.pauser, EUNAUTHORIZED);
    }

    fun assert_is_denylister(denylister: address) acquires Roles, Asset {
        let roles = borrow_global<Roles>(get_asset_address());
        assert!(denylister == roles.denylister, EUNAUTHORIZED);
    }

    fun assert_is_master_minter(master_minter: address) {
        let master_minter_addr: address = @admin;
        assert!(master_minter == master_minter_addr, EUNAUTHORIZED);
    }

    fun assert_asset_not_initialized() {
        let asset_exists = exists<Asset>(@admin);
        assert!(!asset_exists, EASSETALREADYEXIST);
    }

    fun assert_is_asset_initialized() {
        let asset_exists = exists<Asset>(@admin);
        assert!(asset_exists, EASSETNOTINITIALIZED);
    }

    fun asset_exists(): bool {
        exists<Asset>(@admin)
    }

    #[view]
    public fun get_asset_address(): address acquires Asset {
        if (asset_exists()) {
            let asset = borrow_global<Asset>(@admin);
            asset.address
        } else {
            NO_ASSET_ADDR
        }
    }

    #[view]
    public fun get_metadata(): Option<Object<Metadata>> acquires Asset {
        let asset_addr = get_asset_address();
        if (asset_addr == NO_ASSET_ADDR) {
            option::none<Object<Metadata>>()
        } else {
            option::some(object::address_to_object(asset_addr))
        }
    }

    #[view]
    public fun total_assets_minted(): u128 acquires Asset {
        if (get_metadata().is_some()) {
            fungible_asset::supply(get_metadata().extract()).extract()
        } else {
            0
        }
    }

    #[view]
    public fun get_asset_name(): String acquires Asset {
        if (asset_exists()) {
            let asset_name = borrow_global<Asset>(@admin).name;
            utf8(asset_name)
        } else {
            utf8(vector[])
        }
    }

    #[view]
    public fun get_asset_symbol(): String acquires Asset {
        if (asset_exists()) {
            let asset_symbol = borrow_global<Asset>(@admin).symbol;
            utf8(asset_symbol) //devolverlo como string no como hex
        } else {
            utf8(vector[])
        }
    }

    #[view]
    public fun get_asset_decimals(): u8 acquires Asset {
        if (asset_exists()) {
            let asset_decimals = borrow_global<Asset>(@admin).decimals;
            asset_decimals
        } else {
            0
        }
    }

    #[view]
    public fun asset_balance(account: address): u64 acquires Asset {
        let metadata_opt = get_metadata();
        if (metadata_opt.is_none()) return 0;
        let metadata = metadata_opt.extract();
        if (!primary_fungible_store::primary_store_exists_inlined(account, metadata)) {
            0
        } else {
            primary_fungible_store::balance(account, metadata)
        }
    }

    #[view]
    public fun get_minters(): vector<address> acquires Roles, Asset {
        if (asset_exists()) {
            let asset_addr = get_asset_address();
            let minters = borrow_global<Roles>(asset_addr).minters;
            minters
        } else {
            vector[]
        }
    }

    public entry fun init_asset(
        creator: &signer,
        symbol: vector<u8>,
        name: vector<u8>,
        icon_url: vector<u8>,
        project_url: vector<u8>,
        decimals: u8,
        max_supply: u128
    ) {
        assert_is_master_minter(signer::address_of(creator));
        assert_asset_not_initialized();

        let constructor_ref = &object::create_named_object(creator, symbol);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(max_supply),
            utf8(name),
            utf8(symbol),
            decimals,
            utf8(icon_url),
            utf8(project_url)
        );

        fungible_asset::set_untransferable(constructor_ref);
        let metadata_object_signer = &object::generate_signer(constructor_ref);

        move_to(metadata_object_signer, Roles {
            master_minter: @admin,
            minters: vector[],
            denylister: @admin,
            pauser: @admin
        });

        move_to(metadata_object_signer, Management {
            extend_ref: object::generate_extend_ref(constructor_ref),
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref)
        });

        move_to(metadata_object_signer, State {
            paused: false
        });

        let asset_addr = object::address_from_constructor_ref(constructor_ref);
        move_to(creator, Asset {
            is_created: true,
            address: asset_addr,
            symbol,
            name,
            decimals
        })
    }

    fun deposit<T: key>(
        token: FungibleAsset,
        store: Object<T>,
        transfer_ref: &TransferRef
    ): () acquires State, Asset {
        assert_not_paused();
        assert_is_denylisted(object::owner(store));
        fungible_asset::deposit_with_ref(transfer_ref, store, token)
    }

    public entry fun mint_to(minter: &signer, to: address, amount: u64) acquires Management, Roles, State, Asset {
        assert_is_asset_initialized();
        assert_is_minter(signer::address_of(minter));
        assert_is_denylisted(to);

        let management = borrow_global<Management>(get_asset_address());
        let tokens = fungible_asset::mint(&management.mint_ref, amount);
        let store = primary_fungible_store::ensure_primary_store_exists(to, get_metadata().extract());

        deposit(tokens, store, &management.transfer_ref);

        event::emit(Mint {
            minter: signer::address_of(minter),
            to,
            amount
        });
    }

    public entry fun burn_from(minter: &signer, from: address, amount: u64) acquires State, Management, Roles, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_minter(signer::address_of(minter));

        let management = borrow_global<Management>(get_asset_address());
        let store = primary_fungible_store::ensure_primary_store_exists(from, get_metadata().extract());

        let tokens = fungible_asset::withdraw_with_ref(
            &management.transfer_ref,
            store,
            amount
        );

        burn(&management.burn_ref, tokens);

        event::emit(Burn {
            minter: signer::address_of(minter),
            from,
            store,
            amount
        });
    }

    public entry fun transfer_to(from: &signer, to: address, amount: u64) acquires State, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_denylisted(to);
        assert_is_denylisted(signer::address_of(from));

        let metadata_object = get_metadata().extract();
        let from_addr = signer::address_of(from);

        let from_wallet = primary_fungible_store::primary_store(from_addr, metadata_object);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, metadata_object);

        fungible_asset::transfer(from, from_wallet, to_wallet, amount);

        event::emit(Transfer {
            from: from_addr,
            to,
            amount
        })
    }

    public entry fun set_pause(pauser: &signer) acquires State, Roles, Asset {
        assert_is_asset_initialized();
        assert_is_pauser(signer::address_of(pauser));

        let state = borrow_global_mut<State>(get_asset_address());

        let new_pause_state = !state.paused;

        state.paused = new_pause_state;

        event::emit(Pause {
            pauser: signer::address_of(pauser),
            is_paused: new_pause_state
        })
    }

    fun froze_account_store(
        freeze_ref: &TransferRef,
        account: address,
        froze: bool
    ) {
        primary_fungible_store::set_frozen_flag(freeze_ref, account, froze);
    }

    public entry fun add_to_denylist(denylister: &signer, account: address) acquires Management, Roles, State, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_denylister(signer::address_of(denylister));
        assert_is_denylisted(account);

        let freeze_ref = &borrow_global<Management>(get_asset_address()).transfer_ref;
        froze_account_store(freeze_ref, account, true);

        event::emit(Denylist {
            denylister: signer::address_of(denylister),
            account,
            action: utf8(ACTION_ADD)
        })
    }

    public entry fun remove_from_denylist(
        denylister: &signer,
        account: address
    ) acquires Management, Roles, State, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_denylister(signer::address_of(denylister));

        let freeze_ref = &borrow_global<Management>(get_asset_address()).transfer_ref;
        froze_account_store(freeze_ref, account, false);

        event::emit(Denylist {
            denylister: signer::address_of(denylister),
            account,
            action: utf8(ACTION_REMOVE)
        })
    }

    public entry fun add_minter(master_minter: &signer, minter: address) acquires Roles, State, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_master_minter(signer::address_of(master_minter));
        assert_is_not_minter(minter);

        let minters = &mut borrow_global_mut<Roles>(get_asset_address()).minters;
        minters.push_back(minter);

        event::emit(Minter {
            master_minter: signer::address_of(master_minter),
            minter,
            action: utf8(ACTION_ADD)
        })
    }

    public entry fun remove_minter(master_minter: &signer, minter: address) acquires Roles, State, Asset {
        assert_is_asset_initialized();
        assert_not_paused();
        assert_is_master_minter(signer::address_of(master_minter));
        assert_is_minter(minter);

        let minters = &mut borrow_global_mut<Roles>(get_asset_address()).minters;
        minters.remove_value(&minter);

        event::emit(Minter {
            master_minter: signer::address_of(master_minter),
            minter,
            action: utf8(ACTION_REMOVE)
        })
    }
}
