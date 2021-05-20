const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');

const Staking = artifacts.require('./Staking.sol');
const Token = artifacts.require('./Token.sol');
const Pool = artifacts.require('./Pool.sol');

require('chai')
    .use(require('chai-as-promised'))
    .should();

    contract('Staking', (accounts) => {
        let instance, token;
        const totalSupply = 200000000000000000000;
        before(async() => {
            token = await Token.new("SFUND", "LP", 18, totalSupply.toString(), accounts[0]);
            instance = await Staking.new(token.address, 90); //Adjust the start block according to your local testing
            pool = await Pool.new(instance.address, token.address);
        })

        describe('Deployment', async() => {
            it('deploys successfully', async() => {
                const address = instance.address;
                assert.notEqual(address, 0x0);
                assert.notEqual(address, '');
                assert.notEqual(address, null);
                assert.notEqual(address, undefined);
            })

            it('has a token address', async() => {
                const tokenAddress = await instance.tokenAddress();
                tokenAddress.should.equal(token.address, "Wrong token address");
            })

            it('has a name', async() => {
                const name = await instance.name();
                name.should.equal("Staking contract", "Wrong name");
            })

            it('has epoch period', async() => {
                const epoch = await instance.startBlock();
                epoch.toString().should.equal('90', "Wrong epoch");
            })
        })

        describe('Staking', async() => {
            it('should not allow user to stake 0 amount', async() => {
                const currentBlock = await instance.currentBlock();
                const epoch = await instance.startBlock();
                for(let i=currentBlock; i< epoch; i++) {
                    await instance.increaseBlock();
                }
                console.log(await instance.currentBlock());
                await instance.increaseBlock();
                await truffleAssert.reverts(instance.stake(0), "Zero stake amount");
            })


            it('should allow users to stake', async() => {
                const stake = 10000000000000000000;
                await token.approve(instance.address, stake.toString());
                await instance.stake(stake.toString());
                const userDeposit = await instance.userDeposits(accounts[0]);
                userDeposit[0].toString().should.equal(stake.toString(),"Staking error")
                const totalStaking = await instance.totalStaked();
                totalStaking.toString().should.equal(stake.toString(), "Total Staked value error");
            })

            it('should not allow users to stake less than allowance', async() => {
                const stake = 5000000000000000000;
                await truffleAssert.reverts(instance.stake(stake.toString()), "Make sure to add enough allowance");
            })

            it('should allow users to add staking', async() => {
                const stake = 10000000000000000000;
                await token.approve(instance.address, stake.toString());
                const prevDeposit = await instance.userDeposits(accounts[0]);
                await instance.stake(stake.toString());
                const userDeposit = await instance.userDeposits(accounts[0]);
                const newAmount = 20000000000000000000;
                // console.log(newAmount)
                userDeposit[0].toString().should.equal(newAmount.toString(),"Staking error")
            })

        })

        describe('Withdraw', async() => {
            
            it('should not allow users to withdraw more than deposit', async() => {
                const stake = 40000000000000000000;
                await truffleAssert.reverts(instance.withdraw(stake.toString()), "Insufficient stake");
            })

            it('should allow users to withdraw', async() => {
                const stake = 10000000000000000000;
                // const prevBalance = await instance.userDeposits(accounts[0]);
                await instance.withdraw(stake.toString());
                const newBalance = await instance.userDeposits(accounts[0]);
                newBalance[0].toString().should.equal(stake.toString(), "Withdraw error");
            })
        })

        describe('Deployment', async() => {
            it('deploys successfully', async() => {
                const address = pool.address;
                assert.notEqual(address, 0x0);
                assert.notEqual(address, '');
                assert.notEqual(address, null);
                assert.notEqual(address, undefined);
            })
    
            it('has a token address', async() => {
                const tokenAddress = await pool.tokenAddress();
                tokenAddress.should.equal(token.address, "Wrong token address");
            })
    
            it('has staking master address', async() => {
                const stakingMaster = await pool.stakingMaster();
                stakingMaster.should.equal(instance.address, "Wrong staking address");
            })
        })

        describe('Adding rewards', async() => {
            it('should allow to add Rewards', async() => {
                const stake = 10000000000000000000;
                await token.approve(pool.address, stake.toString());
                await pool.addReward(stake.toString());
                const rewardAmount = await pool.rewardAmount();
                rewardAmount.toString().should.equal(stake.toString(), "Rewards set error");
            })
        })

        describe('Claiming', async() => {
            it('should allow stakers to claim rewards', async() => {
                // const prevBalance = await token.balanceOf(accounts[0]);
                await pool.claim();
                const newT = 190000000000000000000;
                const newBalance = await token.balanceOf(accounts[0]);
                newBalance.toString().should.equal(newT.toString(), "Error");
            })
        })

    })