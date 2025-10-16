;; Local Government Budget Tracker Smart Contract
;; Manages budget proposals, allocations, expenditures, and auditing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_BUDGET_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_STATUS (err u105))
(define-constant ERR_PROPOSAL_EXPIRED (err u106))

;; Data Variables
(define-data-var next-budget-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-allocated uint u0)
(define-data-var total-spent uint u0)

;; Data Maps
(define-map budgets uint {
  department: (string-ascii 50),
  category: (string-ascii 30),
  allocated-amount: uint,
  spent-amount: uint,
  remaining-amount: uint,
  fiscal-year: uint,
  status: (string-ascii 20),
  created-at: uint,
  updated-at: uint
})

(define-map proposals uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  requested-amount: uint,
  department: (string-ascii 50),
  category: (string-ascii 30),
  proposer: principal,
  status: (string-ascii 20),
  votes-for: uint,
  votes-against: uint,
  created-at: uint,
  expires-at: uint
})

(define-map expenditures uint {
  budget-id: uint,
  amount: uint,
  description: (string-ascii 200),
  vendor: (string-ascii 100),
  receipt-hash: (string-ascii 64),
  approved-by: principal,
  created-at: uint
})

(define-map department-admins principal bool)
(define-map proposal-votes {proposal-id: uint, voter: principal} bool)

;; Public Functions

;; Initialize contract with default admin
(define-public (initialize)
  (begin
    (map-set department-admins CONTRACT_OWNER true)
    (ok true)
  )
)

;; Admin function to add department administrators
(define-public (add-department-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set department-admins admin true)
    (ok true)
  )
)

;; Create a new budget allocation
(define-public (create-budget 
  (department (string-ascii 50))
  (category (string-ascii 30))
  (amount uint)
  (fiscal-year uint))
  (let ((budget-id (var-get next-budget-id)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (default-to false (map-get? department-admins tx-sender)) ERR_UNAUTHORIZED)
      
      (map-set budgets budget-id {
        department: department,
        category: category,
        allocated-amount: amount,
        spent-amount: u0,
        remaining-amount: amount,
        fiscal-year: fiscal-year,
        status: "active",
        created-at: stacks-block-height,
        updated-at: stacks-block-height
      })
      
      (var-set next-budget-id (+ budget-id u1))
      (var-set total-allocated (+ (var-get total-allocated) amount))
      (ok budget-id)
    )
  )
)

;; Submit a budget proposal
(define-public (submit-proposal
  (title (string-ascii 100))
  (description (string-ascii 500))
  (amount uint)
  (department (string-ascii 50))
  (category (string-ascii 30))
  (duration-blocks uint))
  (let ((proposal-id (var-get next-proposal-id)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
      
      (map-set proposals proposal-id {
        title: title,
        description: description,
        requested-amount: amount,
        department: department,
        category: category,
        proposer: tx-sender,
        status: "pending",
        votes-for: u0,
        votes-against: u0,
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration-blocks)
      })
      
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id)
    )
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_BUDGET_NOT_FOUND)))
    (begin
      (asserts! (< stacks-block-height (get expires-at proposal)) ERR_PROPOSAL_EXPIRED)
      (asserts! (is-eq (get status proposal) "pending") ERR_INVALID_STATUS)
      (asserts! (is-none (map-get? proposal-votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_EXISTS)
      
      (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} vote-for)
      
      (if vote-for
        (map-set proposals proposal-id 
          (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
        (map-set proposals proposal-id 
          (merge proposal {votes-against: (+ (get votes-against proposal) u1)}))
      )
      
      (ok true)
    )
  )
)

;; Approve or reject proposal (admin only)
(define-public (finalize-proposal (proposal-id uint) (approve bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_BUDGET_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? department-admins tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status proposal) "pending") ERR_INVALID_STATUS)
      
      (map-set proposals proposal-id 
        (merge proposal {
          status: (if approve "approved" "rejected"),
          updated-at: stacks-block-height
        }))
      
      (ok true)
    )
  )
)

;; Record an expenditure against a budget
(define-public (record-expenditure
  (budget-id uint)
  (amount uint)
  (description (string-ascii 200))
  (vendor (string-ascii 100))
  (receipt-hash (string-ascii 64)))
  (let ((budget (unwrap! (map-get? budgets budget-id) ERR_BUDGET_NOT_FOUND))
        (expenditure-id (var-get next-budget-id)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (>= (get remaining-amount budget) amount) ERR_INSUFFICIENT_FUNDS)
      (asserts! (default-to false (map-get? department-admins tx-sender)) ERR_UNAUTHORIZED)
      
      (map-set expenditures expenditure-id {
        budget-id: budget-id,
        amount: amount,
        description: description,
        vendor: vendor,
        receipt-hash: receipt-hash,
        approved-by: tx-sender,
        created-at: stacks-block-height
      })
      
      (map-set budgets budget-id 
        (merge budget {
          spent-amount: (+ (get spent-amount budget) amount),
          remaining-amount: (- (get remaining-amount budget) amount),
          updated-at: stacks-block-height
        }))
      
      (var-set total-spent (+ (var-get total-spent) amount))
      (ok expenditure-id)
    )
  )
)

;; Update budget status
(define-public (update-budget-status (budget-id uint) (new-status (string-ascii 20)))
  (let ((budget (unwrap! (map-get? budgets budget-id) ERR_BUDGET_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? department-admins tx-sender)) ERR_UNAUTHORIZED)
      
      (map-set budgets budget-id 
        (merge budget {
          status: new-status,
          updated-at: stacks-block-height
        }))
      
      (ok true)
    )
  )
)

;; Read-only functions

(define-read-only (get-budget (budget-id uint))
  (map-get? budgets budget-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-expenditure (expenditure-id uint))
  (map-get? expenditures expenditure-id)
)

(define-read-only (get-total-allocated)
  (var-get total-allocated)
)

(define-read-only (get-total-spent)
  (var-get total-spent)
)

(define-read-only (get-remaining-budget)
  (- (var-get total-allocated) (var-get total-spent))
)

(define-read-only (is-department-admin (user principal))
  (default-to false (map-get? department-admins user))
)

(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (calculate-budget-utilization (budget-id uint))
  (match (map-get? budgets budget-id)
    budget (if (> (get allocated-amount budget) u0)
             (/ (* (get spent-amount budget) u10000) (get allocated-amount budget))
             u0)
    u0
  )
)