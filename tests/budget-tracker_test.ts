import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Contract initialization works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Check if deployer is admin
        let adminCheck = chain.callReadOnlyFn(
            'budget-tracker',
            'is-department-admin',
            [types.principal(deployer.address)],
            deployer.address
        );
        assertEquals(adminCheck.result.expectBool(), true);
    },
});

Clarinet.test({
    name: "Can create budget allocation successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            Tx.contractCall('budget-tracker', 'create-budget', [
                types.ascii("Public Works"),
                types.ascii("Infrastructure"),
                types.uint(1000000),
                types.uint(2025)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[1].result.expectOk(), types.uint(1));
        
        // Check budget details
        let budget = chain.callReadOnlyFn(
            'budget-tracker',
            'get-budget',
            [types.uint(1)],
            deployer.address
        );
        
        const budgetData = budget.result.expectSome().expectTuple();
        assertEquals(budgetData['department'], "Public Works");
        assertEquals(budgetData['allocated-amount'], types.uint(1000000));
    },
});

Clarinet.test({
    name: "Can submit and vote on proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const voter1 = accounts.get('wallet_1')!;
        const voter2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            Tx.contractCall('budget-tracker', 'submit-proposal', [
                types.ascii("New Park Development"),
                types.ascii("Proposal to develop a new community park with playground equipment"),
                types.uint(500000),
                types.ascii("Parks & Recreation"),
                types.ascii("Development"),
                types.uint(100) // 100 blocks duration
            ], voter1.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[1].result.expectOk(), types.uint(1));
        
        // Vote on proposal
        let voteBlock = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'vote-on-proposal', [
                types.uint(1),
                types.bool(true)
            ], voter1.address),
            Tx.contractCall('budget-tracker', 'vote-on-proposal', [
                types.uint(1),
                types.bool(false)
            ], voter2.address)
        ]);
        
        assertEquals(voteBlock.receipts.length, 2);
        voteBlock.receipts.map(receipt => receipt.result.expectOk());
        
        // Check proposal votes
        let proposal = chain.callReadOnlyFn(
            'budget-tracker',
            'get-proposal',
            [types.uint(1)],
            deployer.address
        );
        
        const proposalData = proposal.result.expectSome().expectTuple();
        assertEquals(proposalData['votes-for'], types.uint(1));
        assertEquals(proposalData['votes-against'], types.uint(1));
    },
});

Clarinet.test({
    name: "Can record expenditures against budget",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            Tx.contractCall('budget-tracker', 'create-budget', [
                types.ascii("IT Department"),
                types.ascii("Equipment"),
                types.uint(100000),
                types.uint(2025)
            ], deployer.address),
            Tx.contractCall('budget-tracker', 'record-expenditure', [
                types.uint(1),
                types.uint(25000),
                types.ascii("Office computers and monitors"),
                types.ascii("TechSupply Corp"),
                types.ascii("abc123def456789")
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 3);
        block.receipts.map(receipt => receipt.result.expectOk());
        
        // Check updated budget
        let budget = chain.callReadOnlyFn(
            'budget-tracker',
            'get-budget',
            [types.uint(1)],
            deployer.address
        );
        
        const budgetData = budget.result.expectSome().expectTuple();
        assertEquals(budgetData['spent-amount'], types.uint(25000));
        assertEquals(budgetData['remaining-amount'], types.uint(75000));
        
        // Check total spent
        let totalSpent = chain.callReadOnlyFn(
            'budget-tracker',
            'get-total-spent',
            [],
            deployer.address
        );
        assertEquals(totalSpent.result.expectUint(), 25000);
    },
});

Clarinet.test({
    name: "Budget utilization calculation works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            Tx.contractCall('budget-tracker', 'create-budget', [
                types.ascii("Health Department"),
                types.ascii("Medical Supplies"),
                types.uint(200000),
                types.uint(2025)
            ], deployer.address),
            Tx.contractCall('budget-tracker', 'record-expenditure', [
                types.uint(1),
                types.uint(50000),
                types.ascii("Medical equipment purchase"),
                types.ascii("MedSupply Inc"),
                types.ascii("med789xyz123")
            ], deployer.address)
        ]);
        
        // Check utilization (50000/200000 * 10000 = 2500 = 25%)
        let utilization = chain.callReadOnlyFn(
            'budget-tracker',
            'calculate-budget-utilization',
            [types.uint(1)],
            deployer.address
        );
        assertEquals(utilization.result.expectUint(), 2500);
    },
});

Clarinet.test({
    name: "Authorization controls work properly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const unauthorizedUser = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            // Unauthorized user tries to create budget
            Tx.contractCall('budget-tracker', 'create-budget', [
                types.ascii("Unauthorized Dept"),
                types.ascii("Test Category"),
                types.uint(50000),
                types.uint(2025)
            ], unauthorizedUser.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), true);
        assertEquals(block.receipts[1].result.expectErr(), types.uint(100)); // ERR_UNAUTHORIZED
    },
});

Clarinet.test({
    name: "Cannot spend more than allocated budget",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('budget-tracker', 'initialize', [], deployer.address),
            Tx.contractCall('budget-tracker', 'create-budget', [
                types.ascii("Small Dept"),
                types.ascii("Limited Budget"),
                types.uint(1000),
                types.uint(2025)
            ], deployer.address),
            // Try to spend more than allocated
            Tx.contractCall('budget-tracker', 'record-expenditure', [
                types.uint(1),
                types.uint(1500),
                types.ascii("Over-budget purchase"),
                types.ascii("Expensive Vendor"),
                types.ascii("over123budget456")
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 3);
        assertEquals(block.receipts[0].result.expectOk(), true);
        assertEquals(block.receipts[1].result.expectOk(), types.uint(1));
        assertEquals(block.receipts[2].result.expectErr(), types.uint(103)); // ERR_INSUFFICIENT_FUNDS
    },
});