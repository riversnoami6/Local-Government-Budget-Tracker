(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BUDGET-NOT-FOUND (err u101))
(define-constant ERR-DEPARTMENT-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-BUDGET (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-ALREADY-APPROVED (err u105))
(define-constant ERR-BUDGET-EXPIRED (err u106))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u107))
(define-constant ERR-TRANSFER-NOT-FOUND (err u108))
(define-constant ERR-INSUFFICIENT-AVAILABLE-BUDGET (err u109))
(define-constant ERR-SAME-DEPARTMENT-TRANSFER (err u110))

(define-data-var contract-owner principal tx-sender)
(define-data-var next-budget-id uint u1)
(define-data-var next-department-id uint u1)
(define-data-var next-expense-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-transfer-id uint u1)

(define-map budgets
    { budget-id: uint }
    {
        department-id: uint,
        allocated-amount: uint,
        spent-amount: uint,
        fiscal-year: uint,
        created-at: uint,
        expires-at: uint,
        is-approved: bool,
        approved-by: (optional principal),
    }
)

(define-map departments
    { department-id: uint }
    {
        name: (string-ascii 50),
        head: principal,
        created-at: uint,
        is-active: bool,
    }
)

(define-map expenses
    { expense-id: uint }
    {
        budget-id: uint,
        amount: uint,
        description: (string-ascii 200),
        recipient: principal,
        submitted-by: principal,
        submitted-at: uint,
        is-approved: bool,
        approved-by: (optional principal),
        approved-at: (optional uint),
    }
)

(define-map budget-proposals
    { proposal-id: uint }
    {
        department-id: uint,
        requested-amount: uint,
        fiscal-year: uint,
        description: (string-ascii 500),
        proposed-by: principal,
        proposed-at: uint,
        votes-for: uint,
        votes-against: uint,
        is-finalized: bool,
    }
)

(define-map proposal-votes
    {
        proposal-id: uint,
        voter: principal,
    }
    {
        vote: bool,
        voted-at: uint,
    }
)

(define-map authorized-officials
    { official: principal }
    {
        is-authorized: bool,
        role: (string-ascii 30),
    }
)

(define-map budget-transfers
    { transfer-id: uint }
    {
        from-budget-id: uint,
        to-budget-id: uint,
        amount: uint,
        reason: (string-ascii 200),
        requested-by: principal,
        requested-at: uint,
        is-approved: bool,
        approved-by: (optional principal),
        approved-at: (optional uint),
    }
)

(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set authorized-officials { official: tx-sender } {
            is-authorized: true,
            role: "admin",
        })
        (ok true)
    )
)

(define-public (add-authorized-official
        (official principal)
        (role (string-ascii 30))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set authorized-officials { official: official } {
            is-authorized: true,
            role: role,
        })
        (ok true)
    )
)

(define-public (create-department
        (name (string-ascii 50))
        (head principal)
    )
    (let ((department-id (var-get next-department-id)))
        (asserts! (is-authorized-official tx-sender) ERR-NOT-AUTHORIZED)
        (map-set departments { department-id: department-id } {
            name: name,
            head: head,
            created-at: stacks-block-height,
            is-active: true,
        })
        (var-set next-department-id (+ department-id u1))
        (ok department-id)
    )
)

(define-public (propose-budget
        (department-id uint)
        (requested-amount uint)
        (fiscal-year uint)
        (description (string-ascii 500))
    )
    (let ((proposal-id (var-get next-proposal-id)))
        (asserts! (> requested-amount u0) ERR-INVALID-AMOUNT)
        (asserts!
            (is-some (map-get? departments { department-id: department-id }))
            ERR-DEPARTMENT-NOT-FOUND
        )
        (map-set budget-proposals { proposal-id: proposal-id } {
            department-id: department-id,
            requested-amount: requested-amount,
            fiscal-year: fiscal-year,
            description: description,
            proposed-by: tx-sender,
            proposed-at: stacks-block-height,
            votes-for: u0,
            votes-against: u0,
            is-finalized: false,
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote bool)
    )
    (let (
            (proposal (unwrap! (map-get? budget-proposals { proposal-id: proposal-id })
                ERR-PROPOSAL-NOT-FOUND
            ))
            (current-votes-for (get votes-for proposal))
            (current-votes-against (get votes-against proposal))
        )
        (asserts! (is-authorized-official tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-finalized proposal)) ERR-ALREADY-APPROVED)
        (asserts!
            (is-none (map-get? proposal-votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
            ERR-ALREADY-APPROVED
        )
        (map-set proposal-votes {
            proposal-id: proposal-id,
            voter: tx-sender,
        } {
            vote: vote,
            voted-at: stacks-block-height,
        })
        (map-set budget-proposals { proposal-id: proposal-id }
            (merge proposal {
                votes-for: (if vote
                    (+ current-votes-for u1)
                    current-votes-for
                ),
                votes-against: (if vote
                    current-votes-against
                    (+ current-votes-against u1)
                ),
            })
        )
        (ok true)
    )
)

(define-public (finalize-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? budget-proposals { proposal-id: proposal-id })
                ERR-PROPOSAL-NOT-FOUND
            ))
            (votes-for (get votes-for proposal))
            (votes-against (get votes-against proposal))
            (is-approved (> votes-for votes-against))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-finalized proposal)) ERR-ALREADY-APPROVED)
        (map-set budget-proposals { proposal-id: proposal-id }
            (merge proposal { is-finalized: true })
        )
        (if is-approved
            (begin
                (unwrap-panic (create-approved-budget proposal))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-private (create-approved-budget (proposal {
    department-id: uint,
    requested-amount: uint,
    fiscal-year: uint,
    description: (string-ascii 500),
    proposed-by: principal,
    proposed-at: uint,
    votes-for: uint,
    votes-against: uint,
    is-finalized: bool,
}))
    (let (
            (budget-id (var-get next-budget-id))
            (expires-at (+ stacks-block-height u52560))
        )
        (map-set budgets { budget-id: budget-id } {
            department-id: (get department-id proposal),
            allocated-amount: (get requested-amount proposal),
            spent-amount: u0,
            fiscal-year: (get fiscal-year proposal),
            created-at: stacks-block-height,
            expires-at: expires-at,
            is-approved: true,
            approved-by: (some tx-sender),
        })
        (var-set next-budget-id (+ budget-id u1))
        (ok true)
    )
)

(define-public (submit-expense
        (budget-id uint)
        (amount uint)
        (description (string-ascii 200))
        (recipient principal)
    )
    (let (
            (budget (unwrap! (map-get? budgets { budget-id: budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (expense-id (var-get next-expense-id))
            (remaining-budget (- (get allocated-amount budget) (get spent-amount budget)))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (get is-approved budget) ERR-NOT-AUTHORIZED)
        (asserts! (< stacks-block-height (get expires-at budget))
            ERR-BUDGET-EXPIRED
        )
        (asserts! (<= amount remaining-budget) ERR-INSUFFICIENT-BUDGET)
        (map-set expenses { expense-id: expense-id } {
            budget-id: budget-id,
            amount: amount,
            description: description,
            recipient: recipient,
            submitted-by: tx-sender,
            submitted-at: stacks-block-height,
            is-approved: false,
            approved-by: none,
            approved-at: none,
        })
        (var-set next-expense-id (+ expense-id u1))
        (ok expense-id)
    )
)

(define-public (approve-expense (expense-id uint))
    (let (
            (expense (unwrap! (map-get? expenses { expense-id: expense-id })
                ERR-PROPOSAL-NOT-FOUND
            ))
            (budget-id (get budget-id expense))
            (budget (unwrap! (map-get? budgets { budget-id: budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (new-spent-amount (+ (get spent-amount budget) (get amount expense)))
        )
        (asserts! (is-authorized-official tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-approved expense)) ERR-ALREADY-APPROVED)
        (asserts! (<= new-spent-amount (get allocated-amount budget))
            ERR-INSUFFICIENT-BUDGET
        )
        (map-set expenses { expense-id: expense-id }
            (merge expense {
                is-approved: true,
                approved-by: (some tx-sender),
                approved-at: (some stacks-block-height),
            })
        )
        (map-set budgets { budget-id: budget-id }
            (merge budget { spent-amount: new-spent-amount })
        )
        (ok true)
    )
)

(define-public (request-budget-transfer
        (from-budget-id uint)
        (to-budget-id uint)
        (amount uint)
        (reason (string-ascii 200))
    )
    (let (
            (from-budget (unwrap! (map-get? budgets { budget-id: from-budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (to-budget (unwrap! (map-get? budgets { budget-id: to-budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (transfer-id (var-get next-transfer-id))
            (available-amount (- (get allocated-amount from-budget) (get spent-amount from-budget)))
        )
        (asserts! (is-authorized-official tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq from-budget-id to-budget-id))
            ERR-SAME-DEPARTMENT-TRANSFER
        )
        (asserts!
            (not (is-eq (get department-id from-budget) (get department-id to-budget)))
            ERR-SAME-DEPARTMENT-TRANSFER
        )
        (asserts! (<= amount available-amount) ERR-INSUFFICIENT-AVAILABLE-BUDGET)
        (asserts! (get is-approved from-budget) ERR-NOT-AUTHORIZED)
        (asserts! (get is-approved to-budget) ERR-NOT-AUTHORIZED)
        (asserts! (< stacks-block-height (get expires-at from-budget))
            ERR-BUDGET-EXPIRED
        )
        (asserts! (< stacks-block-height (get expires-at to-budget))
            ERR-BUDGET-EXPIRED
        )
        (map-set budget-transfers { transfer-id: transfer-id } {
            from-budget-id: from-budget-id,
            to-budget-id: to-budget-id,
            amount: amount,
            reason: reason,
            requested-by: tx-sender,
            requested-at: stacks-block-height,
            is-approved: false,
            approved-by: none,
            approved-at: none,
        })
        (var-set next-transfer-id (+ transfer-id u1))
        (ok transfer-id)
    )
)

(define-public (approve-budget-transfer (transfer-id uint))
    (let (
            (transfer (unwrap! (map-get? budget-transfers { transfer-id: transfer-id })
                ERR-TRANSFER-NOT-FOUND
            ))
            (from-budget-id (get from-budget-id transfer))
            (to-budget-id (get to-budget-id transfer))
            (amount (get amount transfer))
            (from-budget (unwrap! (map-get? budgets { budget-id: from-budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (to-budget (unwrap! (map-get? budgets { budget-id: to-budget-id })
                ERR-BUDGET-NOT-FOUND
            ))
            (available-amount (- (get allocated-amount from-budget) (get spent-amount from-budget)))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-approved transfer)) ERR-ALREADY-APPROVED)
        (asserts! (<= amount available-amount) ERR-INSUFFICIENT-AVAILABLE-BUDGET)
        (map-set budget-transfers { transfer-id: transfer-id }
            (merge transfer {
                is-approved: true,
                approved-by: (some tx-sender),
                approved-at: (some stacks-block-height),
            })
        )
        (map-set budgets { budget-id: from-budget-id }
            (merge from-budget { allocated-amount: (- (get allocated-amount from-budget) amount) })
        )
        (map-set budgets { budget-id: to-budget-id }
            (merge to-budget { allocated-amount: (+ (get allocated-amount to-budget) amount) })
        )
        (ok true)
    )
)

(define-read-only (get-budget (budget-id uint))
    (map-get? budgets { budget-id: budget-id })
)

(define-read-only (get-department (department-id uint))
    (map-get? departments { department-id: department-id })
)

(define-read-only (get-expense (expense-id uint))
    (map-get? expenses { expense-id: expense-id })
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? budget-proposals { proposal-id: proposal-id })
)

(define-read-only (get-budget-utilization (budget-id uint))
    (match (map-get? budgets { budget-id: budget-id })
        budget (let (
                (allocated (get allocated-amount budget))
                (spent (get spent-amount budget))
            )
            (some {
                allocated: allocated,
                spent: spent,
                remaining: (- allocated spent),
                utilization-rate: (if (> allocated u0)
                    (/ (* spent u10000) allocated)
                    u0
                ),
            })
        )
        none
    )
)

(define-read-only (is-authorized-official (official principal))
    (default-to false
        (get is-authorized (map-get? authorized-officials { official: official }))
    )
)

(define-read-only (get-contract-info)
    {
        total-budgets: (- (var-get next-budget-id) u1),
        total-departments: (- (var-get next-department-id) u1),
        total-expenses: (- (var-get next-expense-id) u1),
        total-proposals: (- (var-get next-proposal-id) u1),
        total-transfers: (- (var-get next-transfer-id) u1),
        contract-owner: (var-get contract-owner),
        current-block: stacks-block-height,
    }
)

(define-read-only (get-budget-transfer (transfer-id uint))
    (map-get? budget-transfers { transfer-id: transfer-id })
)

(define-read-only (get-department-budget-summary (department-id uint))
    (let ((department (map-get? departments { department-id: department-id })))
        (match department
            dept (let (
                    (total-allocated u0)
                    (total-spent u0)
                )
                (some {
                    department-name: (get name dept),
                    is-active: (get is-active dept),
                    total-allocated: total-allocated,
                    total-spent: total-spent,
                    available: (- total-allocated total-spent),
                })
            )
            none
        )
    )
)
