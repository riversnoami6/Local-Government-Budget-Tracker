# 🏛️ Local Government Budget Tracker

A comprehensive Clarity smart contract for transparent and accountable local government budget management on the Stacks blockchain.

## 📋 Overview

This smart contract enables local governments to:
- 📊 Track budget allocations across departments
- 💰 Monitor spending and expenses in real-time
- 🗳️ Implement democratic budget approval processes
- 🔒 Ensure transparency and accountability
- 📈 Generate utilization reports

## ✨ Features

### 🏢 Department Management
- Create and manage government departments
- Assign department heads
- Track department status

### 💵 Budget Proposals
- Submit budget requests for fiscal years
- Democratic voting system for budget approval
- Multi-stakeholder authorization process

### 📝 Expense Tracking
- Submit expenses against approved budgets
- Approval workflow for expenditures
- Real-time budget utilization monitoring

### 👥 Authorization System
- Role-based access control
- Authorized officials management
- Administrative oversight

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-repo/Local-Government-Budget-Tracker
cd Local-Government-Budget-Tracker
```

2. Check contract compilation:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## 📖 Usage

### Initialize Contract
```clarity
(contract-call? .Local-Government-Budget-Tracker initialize-contract)
```

### Create Department
```clarity
(contract-call? .Local-Government-Budget-Tracker create-department "Public Works" 'ST1PRINCIPAL...)
```

### Submit Budget Proposal
```clarity
(contract-call? .Local-Government-Budget-Tracker propose-budget u1 u100000 u2024 "Annual infrastructure maintenance")
```

### Vote on Proposals
```clarity
(contract-call? .Local-Government-Budget-Tracker vote-on-proposal u1 true)
```

### Submit Expenses
```clarity
(contract-call? .Local-Government-Budget-Tracker submit-expense u1 u5000 "Road repair materials" 'ST1VENDOR...)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `initialize-contract` | Initialize the contract with admin privileges |
| `add-authorized-official` | Add authorized officials with roles |
| `create-department` | Create new government departments |
| `propose-budget` | Submit budget proposals for departments |
| `vote-on-proposal` | Vote on budget proposals |
| `finalize-proposal` | Finalize and approve budget proposals |
| `submit-expense` | Submit expenses against budgets |
| `approve-expense` | Approve submitted expenses |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-budget` | Retrieve budget information |
| `get-department` | Get department details |
| `get-expense` | View expense information |
| `get-proposal` | Check proposal status |
| `get-budget-utilization` | Calculate budget utilization rates |
| `get-contract-info` | Get contract statistics |

## 📊 Data Structures

### Budget
```clarity
{
  department-id: uint,
  allocated-amount: uint,
  spent-amount: uint,
  fiscal-year: uint,
  created-at: uint,
  expires-at: uint,
  is-approved: bool,
  approved-by: (optional principal)
}
```

### Department
```clarity
{
  name: (string-ascii 50),
  head: principal,
  created-at: uint,
  is-active: bool
}
```

### Expense
```clarity
{
  budget-id: uint,
  amount: uint,
  description: (string-ascii 200),
  recipient: principal,
  submitted-by: principal,
  submitted-at: uint,
  is-approved: bool,
  approved-by: (optional principal),
  approved-at: (optional uint)
}
```

## 🛡️ Security Features

- ✅ Role-based access control
- ✅ Budget limit enforcement
- ✅ Expense approval workflow
- ✅ Time-based budget expiration
- ✅ Democratic voting mechanism

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Check contract syntax:
```bash
clarinet check
```


## 📄 License

This project is licensed under the MIT License.



## 📞 Support

For questions and support, please open an issue in the repository.

---

Made with ❤️ for transparent governance
