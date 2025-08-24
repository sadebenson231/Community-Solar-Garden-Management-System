;; Solar Panel Management Contract
;; Manages solar panel registration, ownership, and lifecycle

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PANEL-NOT-FOUND (err u101))
(define-constant ERR-PANEL-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-CAPACITY (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-PANEL-INACTIVE (err u105))

;; Data Variables
(define-data-var next-panel-id uint u1)
(define-data-var total-system-capacity uint u0)
(define-data-var total-panels uint u0)

;; Data Maps
(define-map panels
  { panel-id: uint }
  {
    capacity-watts: uint,
    installation-date: uint,
    location: (string-ascii 100),
    status: (string-ascii 20),
    total-production: uint,
    owner: principal,
    maintenance-due: uint,
    efficiency-rating: uint
  }
)

(define-map panel-owners
  { owner: principal }
  { panel-count: uint, total-capacity: uint }
)

(define-map panel-production-history
  { panel-id: uint, date: uint }
  { production-kwh: uint, weather-factor: uint }
)

;; Read-only functions

(define-read-only (get-panel (panel-id uint))
  (map-get? panels { panel-id: panel-id })
)

(define-read-only (get-panel-owner-info (owner principal))
  (map-get? panel-owners { owner: owner })
)

(define-read-only (get-total-system-capacity)
  (var-get total-system-capacity)
)

(define-read-only (get-total-panels)
  (var-get total-panels)
)

(define-read-only (get-next-panel-id)
  (var-get next-panel-id)
)

(define-read-only (get-panel-production (panel-id uint) (date uint))
  (map-get? panel-production-history { panel-id: panel-id, date: date })
)

(define-read-only (is-panel-active (panel-id uint))
  (match (get-panel panel-id)
    panel-data (is-eq (get status panel-data) "active")
    false
  )
)

(define-read-only (calculate-panel-efficiency (panel-id uint))
  (match (get-panel panel-id)
    panel-data
    (let ((capacity (get capacity-watts panel-data))
          (total-prod (get total-production panel-data)))
      (if (> capacity u0)
        (/ (* total-prod u100) capacity)
        u0))
    u0
  )
)

;; Private functions

(define-private (is-valid-status (status (string-ascii 20)))
  (or (is-eq status "active")
      (is-eq status "maintenance")
      (is-eq status "inactive")
      (is-eq status "decommissioned"))
)

(define-private (update-owner-stats (owner principal) (capacity-change int) (panel-change int))
  (let ((current-stats (default-to { panel-count: u0, total-capacity: u0 }
                                  (get-panel-owner-info owner))))
    (map-set panel-owners
      { owner: owner }
      {
        panel-count: (if (>= panel-change 0)
                       (+ (get panel-count current-stats) (to-uint panel-change))
                       (- (get panel-count current-stats) (to-uint (- panel-change)))),
        total-capacity: (if (>= capacity-change 0)
                         (+ (get total-capacity current-stats) (to-uint capacity-change))
                         (- (get total-capacity current-stats) (to-uint (- capacity-change))))
      }
    )
  )
)

;; Public functions

(define-public (register-panel (capacity-watts uint) (location (string-ascii 100)) (installation-date uint))
  (let ((panel-id (var-get next-panel-id)))
    (asserts! (> capacity-watts u0) ERR-INVALID-CAPACITY)
    (asserts! (is-none (get-panel panel-id)) ERR-PANEL-ALREADY-EXISTS)

    ;; Create the panel record
    (map-set panels
      { panel-id: panel-id }
      {
        capacity-watts: capacity-watts,
        installation-date: installation-date,
        location: location,
        status: "active",
        total-production: u0,
        owner: tx-sender,
        maintenance-due: (+ installation-date u31536000), ;; 1 year from installation
        efficiency-rating: u100
      }
    )

    ;; Update system totals
    (var-set total-system-capacity (+ (var-get total-system-capacity) capacity-watts))
    (var-set total-panels (+ (var-get total-panels) u1))
    (var-set next-panel-id (+ panel-id u1))

    ;; Update owner statistics
    (update-owner-stats tx-sender (to-int capacity-watts) 1)

    (ok panel-id)
  )
)

(define-public (update-panel-status (panel-id uint) (new-status (string-ascii 20)))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)

      (map-set panels
        { panel-id: panel-id }
        (merge panel-data { status: new-status })
      )
      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)

(define-public (record-production (panel-id uint) (production-kwh uint) (date uint) (weather-factor uint))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-panel-active panel-id) ERR-PANEL-INACTIVE)

      ;; Record daily production
      (map-set panel-production-history
        { panel-id: panel-id, date: date }
        { production-kwh: production-kwh, weather-factor: weather-factor }
      )

      ;; Update total production
      (map-set panels
        { panel-id: panel-id }
        (merge panel-data {
          total-production: (+ (get total-production panel-data) production-kwh)
        })
      )

      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)

(define-public (schedule-maintenance (panel-id uint) (maintenance-date uint))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)

      (map-set panels
        { panel-id: panel-id }
        (merge panel-data {
          maintenance-due: maintenance-date,
          status: "maintenance"
        })
      )
      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)

(define-public (complete-maintenance (panel-id uint) (efficiency-rating uint))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (<= efficiency-rating u100) ERR-INVALID-STATUS)

      (map-set panels
        { panel-id: panel-id }
        (merge panel-data {
          status: "active",
          efficiency-rating: efficiency-rating,
          maintenance-due: (+ (get maintenance-due panel-data) u31536000) ;; Next year
        })
      )
      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)

(define-public (transfer-panel-ownership (panel-id uint) (new-owner principal))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)

      ;; Update old owner stats
      (update-owner-stats tx-sender (- (to-int (get capacity-watts panel-data))) -1)

      ;; Update new owner stats
      (update-owner-stats new-owner (to-int (get capacity-watts panel-data)) 1)

      ;; Transfer ownership
      (map-set panels
        { panel-id: panel-id }
        (merge panel-data { owner: new-owner })
      )

      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)

(define-public (decommission-panel (panel-id uint))
  (match (get-panel panel-id)
    panel-data
    (begin
      (asserts! (is-eq (get owner panel-data) tx-sender) ERR-NOT-AUTHORIZED)

      ;; Update system totals
      (var-set total-system-capacity (- (var-get total-system-capacity) (get capacity-watts panel-data)))
      (var-set total-panels (- (var-get total-panels) u1))

      ;; Update owner stats
      (update-owner-stats tx-sender (- (to-int (get capacity-watts panel-data))) -1)

      ;; Mark as decommissioned
      (map-set panels
        { panel-id: panel-id }
        (merge panel-data { status: "decommissioned" })
      )

      (ok true)
    )
    ERR-PANEL-NOT-FOUND
  )
)
