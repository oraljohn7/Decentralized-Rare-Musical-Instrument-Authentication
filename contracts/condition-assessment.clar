;; Condition Assessment Contract
;; Tracks state of preservation and restoration

;; Data Maps
(define-map assessments
  { instrument-id: uint, assessment-id: uint }
  {
    appraiser: principal,
    date: uint,
    condition-rating: uint,  ;; 1-10 scale
    description: (string-utf8 500),
    restoration-details: (optional (string-utf8 500)),
    images-hash: (optional (buff 32))
  }
)

(define-map instrument-assessment-count
  { instrument-id: uint }
  { count: uint }
)

(define-map appraisers
  { principal: principal }
  {
    name: (string-utf8 100),
    credentials: (string-utf8 200),
    authorized: bool
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-NOT-FOUND u102)
(define-constant ERR-NOT-APPRAISER u103)
(define-constant ERR-INVALID-RATING u104)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Functions
(define-public (register-appraiser
    (name (string-utf8 100))
    (credentials (string-utf8 200)))
  (begin
    (map-set appraisers
      { principal: tx-sender }
      {
        name: name,
        credentials: credentials,
        authorized: false  ;; Needs to be authorized by contract owner
      }
    )

    (ok true)
  )
)

(define-public (authorize-appraiser (appraiser-principal principal))
  (begin
    ;; Only contract owner can authorize appraisers
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))

    ;; Check if appraiser exists
    (asserts! (is-some (map-get? appraisers { principal: appraiser-principal })) (err ERR-NOT-FOUND))

    ;; Update authorization status
    (map-set appraisers
      { principal: appraiser-principal }
      (merge (unwrap-panic (map-get? appraisers { principal: appraiser-principal }))
             { authorized: true })
    )

    (ok true)
  )
)

(define-public (create-assessment
    (instrument-id uint)
    (condition-rating uint)
    (description (string-utf8 500))
    (restoration-details (optional (string-utf8 500)))
    (images-hash (optional (buff 32))))
  (let
    (
      (appraiser-info (unwrap! (map-get? appraisers { principal: tx-sender }) (err ERR-NOT-APPRAISER)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (assessment-count (get-assessment-count instrument-id))
      (new-assessment-id (+ assessment-count u1))
    )
    ;; Check if appraiser is authorized
    (asserts! (get authorized appraiser-info) (err ERR-NOT-AUTHORIZED))

    ;; Validate condition rating (1-10)
    (asserts! (and (>= condition-rating u1) (<= condition-rating u10)) (err ERR-INVALID-RATING))

    ;; Create new assessment
    (map-set assessments
      { instrument-id: instrument-id, assessment-id: new-assessment-id }
      {
        appraiser: tx-sender,
        date: current-time,
        condition-rating: condition-rating,
        description: description,
        restoration-details: restoration-details,
        images-hash: images-hash
      }
    )

    ;; Update assessment count
    (map-set instrument-assessment-count
      { instrument-id: instrument-id }
      { count: new-assessment-id }
    )

    (ok new-assessment-id)
  )
)

(define-read-only (get-assessment (instrument-id uint) (assessment-id uint))
  (map-get? assessments { instrument-id: instrument-id, assessment-id: assessment-id })
)

(define-read-only (get-assessment-count (instrument-id uint))
  (match (map-get? instrument-assessment-count { instrument-id: instrument-id })
    count-data (get count count-data)
    u0)
)

(define-read-only (get-latest-assessment (instrument-id uint))
  (let
    ((count (get-assessment-count instrument-id)))
    (if (> count u0)
      (map-get? assessments { instrument-id: instrument-id, assessment-id: count })
      none
    )
  )
)

(define-read-only (is-authorized-appraiser (principal principal))
  (match (map-get? appraisers { principal: principal })
    appraiser (get authorized appraiser)
    false
  )
)

