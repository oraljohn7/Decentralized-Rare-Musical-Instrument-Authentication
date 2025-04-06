;; Maker Verification Contract
;; Validates attribution to specific craftspeople

;; Data Maps
(define-map makers
  { maker-id: uint }
  {
    name: (string-utf8 100),
    principal: principal,
    specialization: (string-utf8 100),
    established-year: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

(define-map maker-by-principal
  { principal: principal }
  { maker-id: uint }
)

;; Counter for maker IDs
(define-data-var next-maker-id uint u1)

;; Verifier authority
(define-map verifiers
  { principal: principal }
  { authorized: bool }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ALREADY-REGISTERED u101)
(define-constant ERR-NOT-FOUND u102)
(define-constant ERR-NOT-VERIFIER u103)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Functions
(define-public (register-maker
    (name (string-utf8 100))
    (specialization (string-utf8 100))
    (established-year uint))
  (let
    (
      (maker-id (var-get next-maker-id))
      (maker-principal tx-sender)
    )
    ;; Check if maker is already registered
    (asserts! (is-none (map-get? maker-by-principal { principal: maker-principal })) (err ERR-ALREADY-REGISTERED))

    ;; Update next ID
    (var-set next-maker-id (+ maker-id u1))

    ;; Store maker data
    (map-set makers
      { maker-id: maker-id }
      {
        name: name,
        principal: maker-principal,
        specialization: specialization,
        established-year: established-year,
        verified: false,
        verifier: none
      }
    )

    ;; Map principal to maker ID
    (map-set maker-by-principal
      { principal: maker-principal }
      { maker-id: maker-id }
    )

    (ok maker-id)
  )
)

(define-public (add-verifier (verifier-principal principal))
  (begin
    ;; Only contract owner can add verifiers
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))

    (map-set verifiers
      { principal: verifier-principal }
      { authorized: true }
    )

    (ok true)
  )
)

(define-public (verify-maker (maker-id uint))
  (let
    ((maker (unwrap! (map-get? makers { maker-id: maker-id }) (err ERR-NOT-FOUND))))

    ;; Check if sender is an authorized verifier
    (asserts! (is-some (map-get? verifiers { principal: tx-sender })) (err ERR-NOT-VERIFIER))
    (asserts! (get authorized (unwrap-panic (map-get? verifiers { principal: tx-sender }))) (err ERR-NOT-VERIFIER))

    ;; Update maker verification status
    (map-set makers
      { maker-id: maker-id }
      (merge maker {
        verified: true,
        verifier: (some tx-sender)
      })
    )

    (ok true)
  )
)

(define-read-only (get-maker (maker-id uint))
  (map-get? makers { maker-id: maker-id })
)

(define-read-only (get-maker-by-principal (principal principal))
  (match (map-get? maker-by-principal { principal: principal })
    maker-entry (map-get? makers { maker-id: (get maker-id maker-entry) })
    none
  )
)

(define-read-only (is-verified-maker (maker-id uint))
  (match (map-get? makers { maker-id: maker-id })
    maker (get verified maker)
    false
  )
)

