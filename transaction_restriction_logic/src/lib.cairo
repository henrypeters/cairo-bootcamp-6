// /// Interface representing `HelloContract`.
// /// This interface allows modification and retrieval of the contract balance.
// #[starknet::interface]
// pub trait IHelloStarknet<TContractState> {
//     /// Increase contract balance.
//     fn increase_balance(ref self: TContractState, amount: u256);
//     /// Retrieve contract balance.
//     fn get_balance(self: @TContractState) -> u256;
// }

// /// Simple contract for managing balance.
// #[starknet::contract]
// mod HelloStarknet {
//     use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

//     #[storage]
//     struct Storage {
//         balance: u256,
//     }

//     #[abi(embed_v0)]
//     impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
//         fn increase_balance(ref self: ContractState, amount: u256) {
//             assert(amount != 0, 'Amount cannot be 0');
//             self.balance.write(self.balance.read() + amount);
//         }

//         fn get_balance(self: @ContractState) -> u256 {
//             self.balance.read()
//         }
//     }
// }

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERCOToken<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, address: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transferFrom(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256);
    fn revoke_spender(ref self: TContractState, spender: ContractAddress);
    fn burn(ref self: TContractState, user:ContractAddress, amount: u256);
    fn only_admin(self: @TContractState);
}

#[starknet::contract]
pub mod erc20 {
    use starknet::storage::StoragePathEntry;
    use core::num::traits::Zero;
    use starknet::{get_caller_address, contract_address_const};
    use super::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IERCOToken;

    #[storage]
    pub struct Storage{
        name: felt252,
        symbol: felt252,
        decimals: u8,
        max_limit: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        admin: ContractAddress
    }

    // #[event]
    // #[derive(Copy, Drop, PartialEq, starknet::Event)]
    // pub enum Event {

    // }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, decimals: u8, initial_supply: u256, symbol: felt252, admin: ContractAddress) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.max_limit.write(initial_supply);
        self.admin.write(admin)
    }
    
    #[abi(embed_v0)]
    impl IER20Impl of IERCOToken<ContractState>{
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252{
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.max_limit.read()
        }

        fn balance_of(self: @ContractState, address: ContractAddress) -> u256 {
            self.balances.read(address)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount)    
        }

        fn transferFrom(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256,
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) + added_value,
                );
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256,
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) - subtracted_value,
                );
        }

        fn revoke_spender(ref self: ContractState, spender: ContractAddress) {
            let owner = get_caller_address();
            assert(spender.is_non_zero(), 'Zero address');

            self.allowances.entry((owner, spender)).write(0);
        }

        fn burn(ref self: ContractState, user: ContractAddress, amount: u256) {
            self.only_admin();

            assert(amount > 0, 'Invalid amount');
            let balance = self.balances.read(user);
            assert(balance >= amount, 'Insufficient balance');

            self.balances.write(user, balance - amount);

            let supply = self.max_limit.read();

            self.max_limit.write(supply - amount);
        }

        fn only_admin(self: @ContractState) {
            let caller = get_caller_address();

            assert(
                caller == self.admin.read(),
                'Only admin'
            );
        }


    }

    #[generate_trait]
    impl InternalImpl of InternalTrait{
        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            assert(sender.is_non_zero(), 'Transfer from zero');
            assert(recipient.is_non_zero(), 'Transfer to zero');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient,  self.balances.read(recipient) + amount);
        }

        fn spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            let allowance = self.allowances.read((owner, spender));
            self.allowances.write((owner, spender), allowance - amount);
        }

        fn approve_helper(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            assert(spender.is_non_zero(), 'Approval to zero');
            self.allowances.write((owner, spender), amount);
        }
    }
}