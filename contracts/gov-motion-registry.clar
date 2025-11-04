(define-constant ERR_EXISTS u100)
(define-constant ERR_NOT_FOUND u101)
(define-constant ERR_UNAUTHORIZED u102)
(define-constant ROLE_PROPOSER u"proposer")

(define-map spaces
  { name: (string-utf8 32) }
  { controller: principal }
)
(define-map roles
  {
    name: (string-utf8 32),
    role: (string-utf8 32),
    account: principal,
  }
  { enabled: bool }
)
(define-map motions
  {
    name: (string-utf8 32),
    motion-id: uint,
  }
  {
    proposer: principal,
    hash: (buff 32),
    title: (string-utf8 48),
    uri: (string-utf8 128),
    created-at: uint,
  }
)

(define-public (create-space (name (string-utf8 32)))
  (if (is-some (map-get? spaces { name: name }))
    (err ERR_EXISTS)
    (begin
      (map-set spaces { name: name } { controller: tx-sender })
      (ok true)
    )
  )
)

(define-public (transfer-space
    (name (string-utf8 32))
    (new-controller principal)
  )
  (match (map-get? spaces { name: name })
    entry (if (is-eq tx-sender (get controller entry))
      (begin
        (map-set spaces { name: name } { controller: new-controller })
        (ok true)
      )
      (err ERR_UNAUTHORIZED)
    )
    (err ERR_NOT_FOUND)
  )
)

(define-public (set-role
    (name (string-utf8 32))
    (role (string-utf8 32))
    (account principal)
    (enabled bool)
  )
  (match (map-get? spaces { name: name })
    entry (if (is-eq tx-sender (get controller entry))
      (begin
        (map-set roles {
          name: name,
          role: role,
          account: account,
        } { enabled: enabled }
        )
        (ok true)
      )
      (err ERR_UNAUTHORIZED)
    )
    (err ERR_NOT_FOUND)
  )
)

(define-public (create-motion
    (name (string-utf8 32))
    (motion-id uint)
    (hash (buff 32))
    (title (string-utf8 48))
    (uri (string-utf8 128))
  )
  (if (not (can-propose name tx-sender))
    (err ERR_UNAUTHORIZED)
    (if (is-some (map-get? motions {
        name: name,
        motion-id: motion-id,
      }))
      (err ERR_EXISTS)
      (begin
        (map-set motions {
          name: name,
          motion-id: motion-id,
        } {
          proposer: tx-sender,
          hash: hash,
          title: title,
          uri: uri,
          created-at: block-height,
        })
        (ok true)
      )
    )
  )
)

(define-read-only (get-space-controller (name (string-utf8 32)))
  (match (map-get? spaces { name: name })
    entry (some (get controller entry))
    none
  )
)

(define-read-only (has-role
    (name (string-utf8 32))
    (role (string-utf8 32))
    (account principal)
  )
  (match (map-get? roles {
    name: name,
    role: role,
    account: account,
  })
    entry (get enabled entry)
    false
  )
)

(define-read-only (can-propose
    (name (string-utf8 32))
    (account principal)
  )
  (match (map-get? spaces { name: name })
    entry (or (is-eq account (get controller entry)) (has-role name ROLE_PROPOSER account))
    false
  )
)

(define-read-only (get-motion
    (name (string-utf8 32))
    (motion-id uint)
  )
  (map-get? motions {
    name: name,
    motion-id: motion-id,
  })
)
