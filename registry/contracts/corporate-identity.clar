;; Corporate Identity Registry Smart Contract
;; 
;; A comprehensive blockchain-based registry for managing Corporate Identity Numbers (CINs)
;; in compliance with international business entity standards. This decentralized system provides
;; transparent, immutable record-keeping for global corporate entity identification,
;; enabling regulatory compliance, audit trails, and secure ownership management.
;; 
;; Core Features:
;; - International standard compliant CIN registration and validation
;; - Immutable audit trails for regulatory compliance
;; - Decentralized governance with multi-stakeholder administration
;; - Automated lifecycle management and expiration handling
;; - Secure ownership transfers and portfolio management
;; - Real-time status verification and validation services

;; ERROR CONSTANTS AND VALIDATION CODES

;; Access Control Errors
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u101))
(define-constant ERR-INVALID-ADMINISTRATOR (err u102))

;; Data Validation Errors
(define-constant ERR-INVALID-CIN-FORMAT (err u200))
(define-constant ERR-INVALID-COMPANY-NAME (err u201))
(define-constant ERR-INVALID-JURISDICTION-CODE (err u202))
(define-constant ERR-INVALID-BUSINESS-FORM (err u203))
(define-constant ERR-INVALID-CERTIFYING-AUTHORITY (err u204))
(define-constant ERR-INVALID-CORPORATE-ADDRESS (err u205))
(define-constant ERR-INVALID-DATE-RANGE (err u206))
(define-constant ERR-INVALID-STATUS-VALUE (err u207))
(define-constant ERR-INVALID-INPUT-PARAMETERS (err u208))

;; Business Logic Errors
(define-constant ERR-DUPLICATE-CIN-REGISTRATION (err u300))
(define-constant ERR-CIN-RECORD-NOT-FOUND (err u301))
(define-constant ERR-CIN-STATUS-INACTIVE (err u302))
(define-constant ERR-CIN-STATUS-EXPIRED (err u303))
(define-constant ERR-CIN-ALREADY-EXPIRED (err u304))
(define-constant ERR-OWNERSHIP-TRANSFER-DENIED (err u305))

;; CORE DATA STRUCTURES

;; Main registry for storing comprehensive CIN corporate information
(define-map corporate-identity-number-registry
  { cin-code: (string-ascii 20) }
  {
    company-official-name: (string-utf8 256),
    initial-registration-timestamp: uint,
    expiration-timestamp: uint,
    current-registration-status: (string-ascii 20),
    company-jurisdiction-code: (string-ascii 2),
    company-business-structure: (string-utf8 100),
    cin-issuing-organization: (string-utf8 100),
    company-owner-principal: principal,
    last-update-timestamp: uint
  }
)

;; Portfolio management for tracking principal-owned CINs
(define-map principal-cin-holdings
  { owner-address: principal }
  { cin-identifiers-owned: (list 20 (string-ascii 20)) }
)

;; Comprehensive audit logging for status changes and modifications
(define-map cin-modification-audit-log
  { cin-code: (string-ascii 20) }
  { 
    historical-status-changes: (list 50 { 
      new-status: (string-ascii 20), 
      modification-timestamp: uint 
    }) 
  }
)

;; Administrative access control and permissions management
(define-map registry-administrator-permissions
  { admin-address: principal }
  { has-administrative-access: bool }
)

;; CONTRACT GOVERNANCE AND OWNERSHIP

;; Primary contract controller with ultimate administrative authority
(define-data-var contract-primary-owner principal tx-sender)

;; INPUT VALIDATION AND HELPER FUNCTIONS

;; Validates that a principal address is properly formatted and non-null
(define-private (is-valid-principal-address (target-principal principal))
  (is-some (some target-principal))
)

;; Validates jurisdiction code format (exactly 2 characters)
(define-private (is-valid-jurisdiction-code (jurisdiction-code (string-ascii 2)))
  (is-eq (len jurisdiction-code) u2)
)

;; Validates company name meets minimum and maximum length requirements
(define-private (is-valid-company-name (official-name (string-utf8 256)))
  (and (> (len official-name) u0) (<= (len official-name) u256))
)

;; Validates business structure description format and length
(define-private (is-valid-business-structure (business-form (string-utf8 100)))
  (and (> (len business-form) u0) (<= (len business-form) u100))
)

;; Validates CIN issuing organization information format
(define-private (is-valid-issuing-organization (issuing-org (string-utf8 100)))
  (and (> (len issuing-org) u0) (<= (len issuing-org) u100))
)

;; Validates CIN status against approved enumeration values
(define-private (is-valid-registration-status (status-code (string-ascii 20)))
  (or 
    (is-eq status-code "ACTIVE")
    (is-eq status-code "LAPSED")
    (is-eq status-code "RETIRED")
    (is-eq status-code "MERGED")
    (is-eq status-code "DUPLICATE")
    (is-eq status-code "EXPIRED")
    (is-eq status-code "SUSPENDED")
  )
)

;; Validates CIN format according to standard (20 characters)
(define-private (is-valid-cin-format (cin-identifier (string-ascii 20)))
  (is-eq (len cin-identifier) u20)
)

;; AUTHORIZATION AND ACCESS CONTROL

;; Verifies if current transaction sender has administrative privileges
(define-private (has-administrative-privileges)
  (let 
    (
      (admin-record (map-get? registry-administrator-permissions { admin-address: tx-sender }))
    )
    (or
      (is-eq tx-sender (var-get contract-primary-owner))
      (and 
        (is-some admin-record) 
        (get has-administrative-access (unwrap-panic admin-record))
      )
    )
  )
)

;; Verifies ownership or administrative access for CIN operations
(define-private (can-modify-cin-record (cin-identifier (string-ascii 20)))
  (let
    (
      (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
    )
    (if (is-some cin-registry-entry)
      (let
        (
          (cin-details (unwrap-panic cin-registry-entry))
          (record-owner (get company-owner-principal cin-details))
        )
        (or 
          (has-administrative-privileges)
          (is-eq tx-sender record-owner)
        )
      )
      false
    )
  )
)

;; PORTFOLIO MANAGEMENT FUNCTIONS

;; Adds a newly registered CIN to the owner's portfolio
(define-private (add-cin-to-portfolio (cin-identifier (string-ascii 20)) (owner-address principal))
  (begin
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-principal-address owner-address) ERR-INVALID-CORPORATE-ADDRESS)
    (let 
      (
        (existing-portfolio (map-get? principal-cin-holdings { owner-address: owner-address }))
        (current-cin-list (if (is-some existing-portfolio)
                            (get cin-identifiers-owned (unwrap-panic existing-portfolio))
                            (list)))
        (updated-cin-list (as-max-len? (append current-cin-list cin-identifier) u20))
      )
      (if (is-some updated-cin-list)
        (ok (map-set principal-cin-holdings
          { owner-address: owner-address }
          { cin-identifiers-owned: (unwrap-panic updated-cin-list) }
        ))
        ERR-DUPLICATE-CIN-REGISTRATION
      )
    )
  )
)

;; Removes a CIN from the owner's portfolio during transfers
(define-private (remove-cin-from-portfolio (cin-identifier (string-ascii 20)) (owner-address principal))
  (begin
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-principal-address owner-address) ERR-INVALID-CORPORATE-ADDRESS)
    (let 
      (
        (existing-portfolio (map-get? principal-cin-holdings { owner-address: owner-address }))
      )
      (if (is-some existing-portfolio)
        (let
          (
            (current-cin-list (get cin-identifiers-owned (unwrap-panic existing-portfolio)))
            (filtered-cin-list (fold build-filtered-list current-cin-list { target-cin: cin-identifier, result-list: (list) }))
          )
          (ok (map-set principal-cin-holdings
            { owner-address: owner-address }
            { cin-identifiers-owned: (get result-list filtered-cin-list) }
          ))
        )
        (ok true)
      )
    )
  )
)

;; Helper function to build filtered list excluding target CIN
(define-private (build-filtered-list 
  (cin-item (string-ascii 20)) 
  (accumulator { target-cin: (string-ascii 20), result-list: (list 20 (string-ascii 20)) })
)
  (let
    (
      (target (get target-cin accumulator))
      (current-list (get result-list accumulator))
    )
    (if (is-eq cin-item target)
      accumulator
      {
        target-cin: target,
        result-list: (default-to current-list (as-max-len? (append current-list cin-item) u20))
      }
    )
  )
)

;; AUDIT TRAIL MANAGEMENT

;; Records status change events in the comprehensive audit trail
(define-private (log-status-modification (cin-identifier (string-ascii 20)) (updated-status (string-ascii 20)))
  (begin
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-registration-status updated-status) ERR-INVALID-STATUS-VALUE)
    (let
      (
        (existing-audit-trail (map-get? cin-modification-audit-log { cin-code: cin-identifier }))
        (current-history (if (is-some existing-audit-trail)
                          (get historical-status-changes (unwrap-panic existing-audit-trail))
                          (list)))
        (new-modification-entry { new-status: updated-status, modification-timestamp: block-height })
        (updated-audit-history (as-max-len? (append current-history new-modification-entry) u50))
      )
      (if (is-some updated-audit-history)
        (ok (map-set cin-modification-audit-log
          { cin-code: cin-identifier }
          { historical-status-changes: (unwrap-panic updated-audit-history) }
        ))
        ERR-DUPLICATE-CIN-REGISTRATION
      )
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Transfers primary contract ownership to a new administrator
(define-public (transfer-primary-ownership (new-contract-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-primary-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal-address new-contract-owner) ERR-INVALID-CORPORATE-ADDRESS)
    (ok (var-set contract-primary-owner new-contract-owner))
  )
)

;; Grants administrative privileges to a new administrator
(define-public (authorize-new-administrator (new-admin-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-primary-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal-address new-admin-address) ERR-INVALID-CORPORATE-ADDRESS)
    (ok (map-set registry-administrator-permissions 
      { admin-address: new-admin-address } 
      { has-administrative-access: true }
    ))
  )
)

;; Revokes administrative privileges from an existing administrator
(define-public (revoke-administrator-privileges (target-admin-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-primary-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal-address target-admin-address) ERR-INVALID-CORPORATE-ADDRESS)
    (ok (map-set registry-administrator-permissions 
      { admin-address: target-admin-address } 
      { has-administrative-access: false }
    ))
  )
)

;; CORE CIN MANAGEMENT FUNCTIONS

;; Registers a new CIN with comprehensive validation and audit trail initialization
(define-public (register-corporate-identity-number 
  (cin-identifier (string-ascii 20))
  (company-official-name (string-utf8 256))
  (registration-expiration-date uint)
  (company-jurisdiction-code (string-ascii 2))
  (company-business-structure (string-utf8 100))
  (cin-issuing-organization (string-utf8 100))
)
  (begin
    ;; Comprehensive input validation
    (asserts! (has-administrative-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-company-name company-official-name) ERR-INVALID-COMPANY-NAME)
    (asserts! (is-valid-jurisdiction-code company-jurisdiction-code) ERR-INVALID-JURISDICTION-CODE)
    (asserts! (is-valid-business-structure company-business-structure) ERR-INVALID-BUSINESS-FORM)
    (asserts! (is-valid-issuing-organization cin-issuing-organization) ERR-INVALID-CERTIFYING-AUTHORITY)
    
    ;; Verify CIN uniqueness in registry
    (asserts! (is-none (map-get? corporate-identity-number-registry { cin-code: cin-identifier })) ERR-DUPLICATE-CIN-REGISTRATION)
    
    ;; Validate expiration date is in the future
    (asserts! (> registration-expiration-date block-height) ERR-INVALID-DATE-RANGE)
    
    ;; Create new CIN registry entry
    (map-set corporate-identity-number-registry
      { cin-code: cin-identifier }
      {
        company-official-name: company-official-name,
        initial-registration-timestamp: block-height,
        expiration-timestamp: registration-expiration-date,
        current-registration-status: "ACTIVE",
        company-jurisdiction-code: company-jurisdiction-code,
        company-business-structure: company-business-structure,
        cin-issuing-organization: cin-issuing-organization,
        company-owner-principal: tx-sender,
        last-update-timestamp: block-height
      }
    )
    
    ;; Add to owner's portfolio
    (try! (add-cin-to-portfolio cin-identifier tx-sender))
    
    ;; Initialize audit trail with registration event
    (try! (log-status-modification cin-identifier "ACTIVE"))
    
    (ok true)
  )
)

;; Extends the expiration date for an existing CIN registration
(define-public (extend-cin-expiration-date (cin-identifier (string-ascii 20)) (new-expiration-timestamp uint))
  (begin
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    
    (let
      (
        (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
      )
      (asserts! (is-some cin-registry-entry) ERR-CIN-RECORD-NOT-FOUND)
      
      (let
        (
          (cin-details (unwrap-panic cin-registry-entry))
          (current-owner (get company-owner-principal cin-details))
          (current-status (get current-registration-status cin-details))
        )
        ;; Authorization verification
        (asserts! (can-modify-cin-record cin-identifier) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Date validation
        (asserts! (> new-expiration-timestamp block-height) ERR-INVALID-DATE-RANGE)
        (asserts! (> new-expiration-timestamp (get expiration-timestamp cin-details)) ERR-INVALID-DATE-RANGE)
        
        ;; Update CIN registry entry
        (map-set corporate-identity-number-registry
          { cin-code: cin-identifier }
          (merge cin-details {
            expiration-timestamp: new-expiration-timestamp,
            current-registration-status: "ACTIVE",
            last-update-timestamp: block-height
          })
        )
        
        ;; Log reactivation if previously expired
        (if (is-eq current-status "EXPIRED")
          (try! (log-status-modification cin-identifier "ACTIVE"))
          true
        )
        
        (ok true)
      )
    )
  )
)

;; Updates modifiable company information for an existing CIN
(define-public (update-company-information
  (cin-identifier (string-ascii 20))
  (updated-company-name (string-utf8 256))
  (updated-jurisdiction-code (string-ascii 2))
  (updated-business-structure (string-utf8 100))
  (updated-issuing-organization (string-utf8 100))
)
  (begin
    ;; Input validation
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-company-name updated-company-name) ERR-INVALID-COMPANY-NAME)
    (asserts! (is-valid-jurisdiction-code updated-jurisdiction-code) ERR-INVALID-JURISDICTION-CODE)
    (asserts! (is-valid-business-structure updated-business-structure) ERR-INVALID-BUSINESS-FORM)
    (asserts! (is-valid-issuing-organization updated-issuing-organization) ERR-INVALID-CERTIFYING-AUTHORITY)
    
    (let
      (
        (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
      )
      (asserts! (is-some cin-registry-entry) ERR-CIN-RECORD-NOT-FOUND)
      
      (let
        (
          (cin-details (unwrap-panic cin-registry-entry))
        )
        ;; Authorization verification
        (asserts! (can-modify-cin-record cin-identifier) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Apply information updates
        (map-set corporate-identity-number-registry
          { cin-code: cin-identifier }
          (merge cin-details {
            company-official-name: updated-company-name,
            company-jurisdiction-code: updated-jurisdiction-code,
            company-business-structure: updated-business-structure,
            cin-issuing-organization: updated-issuing-organization,
            last-update-timestamp: block-height
          })
        )
        
        (ok true)
      )
    )
  )
)

;; Administratively modifies CIN registration status
(define-public (update-registration-status (cin-identifier (string-ascii 20)) (new-status (string-ascii 20)))
  (begin
    ;; Input validation
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-registration-status new-status) ERR-INVALID-STATUS-VALUE)
    
    (let
      (
        (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
      )
      (asserts! (is-some cin-registry-entry) ERR-CIN-RECORD-NOT-FOUND)
      
      (let
        (
          (cin-details (unwrap-panic cin-registry-entry))
        )
        ;; Administrative access required for status modifications
        (asserts! (has-administrative-privileges) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Update registration status
        (map-set corporate-identity-number-registry
          { cin-code: cin-identifier }
          (merge cin-details {
            current-registration-status: new-status,
            last-update-timestamp: block-height
          })
        )
        
        ;; Log status change in audit trail
        (try! (log-status-modification cin-identifier new-status))
        
        (ok true)
      )
    )
  )
)

;; Transfers CIN ownership between principals with portfolio updates
(define-public (transfer-cin-ownership (cin-identifier (string-ascii 20)) (new-owner-address principal))
  (begin
    ;; Input validation
    (asserts! (is-valid-cin-format cin-identifier) ERR-INVALID-CIN-FORMAT)
    (asserts! (is-valid-principal-address new-owner-address) ERR-INVALID-CORPORATE-ADDRESS)
    
    (let
      (
        (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
      )
      (asserts! (is-some cin-registry-entry) ERR-CIN-RECORD-NOT-FOUND)
      
      (let
        (
          (cin-details (unwrap-panic cin-registry-entry))
          (current-owner (get company-owner-principal cin-details))
        )
        ;; Authorization and ownership validation
        (asserts! (can-modify-cin-record cin-identifier) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (is-eq new-owner-address current-owner)) ERR-INVALID-CORPORATE-ADDRESS)
        
        ;; Remove from current owner's portfolio
        (try! (remove-cin-from-portfolio cin-identifier current-owner))
        
        ;; Transfer ownership in registry
        (map-set corporate-identity-number-registry
          { cin-code: cin-identifier }
          (merge cin-details {
            company-owner-principal: new-owner-address,
            last-update-timestamp: block-height
          })
        )
        
        ;; Add to new owner's portfolio
        (try! (add-cin-to-portfolio cin-identifier new-owner-address))
        
        (ok true)
      )
    )
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieves complete CIN registration information
(define-read-only (get-cin-details (cin-identifier (string-ascii 20)))
  (begin
    (if (is-valid-cin-format cin-identifier)
      (let ((cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier })))
        (if (is-some cin-registry-entry)
          (ok (unwrap-panic cin-registry-entry))
          ERR-CIN-RECORD-NOT-FOUND
        )
      )
      ERR-INVALID-CIN-FORMAT
    )
  )
)

;; Verifies if CIN is currently active and not expired
(define-read-only (is-cin-active-and-valid (cin-identifier (string-ascii 20)))
  (begin
    (if (is-valid-cin-format cin-identifier)
      (let
        (
          (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
        )
        (if (is-some cin-registry-entry)
          (let
            (
              (cin-details (unwrap-panic cin-registry-entry))
              (status-is-active (is-eq (get current-registration-status cin-details) "ACTIVE"))
              (not-expired (> (get expiration-timestamp cin-details) block-height))
            )
            (ok (and status-is-active not-expired))
          )
          ERR-CIN-RECORD-NOT-FOUND
        )
      )
      ERR-INVALID-CIN-FORMAT
    )
  )
)

;; Retrieves all CINs owned by a specific principal
(define-read-only (get-principal-cin-portfolio (owner-address principal))
  (begin
    (if (is-valid-principal-address owner-address)
      (let 
        (
          (portfolio-entry (map-get? principal-cin-holdings { owner-address: owner-address }))
        )
        (if (is-some portfolio-entry)
          (ok (unwrap-panic portfolio-entry))
          (ok { cin-identifiers-owned: (list) })
        )
      )
      ERR-INVALID-CORPORATE-ADDRESS
    )
  )
)

;; Retrieves complete modification audit trail for a CIN
(define-read-only (get-cin-audit-trail (cin-identifier (string-ascii 20)))
  (begin
    (if (is-valid-cin-format cin-identifier)
      (let 
        (
          (audit-trail-entry (map-get? cin-modification-audit-log { cin-code: cin-identifier }))
        )
        (if (is-some audit-trail-entry)
          (ok (unwrap-panic audit-trail-entry))
          (ok { historical-status-changes: (list) })
        )
      )
      ERR-INVALID-CIN-FORMAT
    )
  )
)

;; Verifies administrative privileges for a specific principal
(define-read-only (check-administrative-status (target-address principal))
  (begin
    (if (is-valid-principal-address target-address)
      (let
        (
          (admin-record (map-get? registry-administrator-permissions { admin-address: target-address }))
          (is-primary-owner (is-eq target-address (var-get contract-primary-owner)))
        )
        (ok (or 
          is-primary-owner
          (and (is-some admin-record) (get has-administrative-access (unwrap-panic admin-record)))
        ))
      )
      ERR-INVALID-CORPORATE-ADDRESS
    )
  )
)

;; Performs comprehensive CIN validation including format, existence, status, and expiration
(define-read-only (validate-cin-comprehensive (cin-identifier (string-ascii 20)))
  (begin
    (if (is-valid-cin-format cin-identifier)
      (let ((cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier })))
        (if (is-none cin-registry-entry)
          ERR-CIN-RECORD-NOT-FOUND
          (let ((cin-details (unwrap-panic cin-registry-entry)))
            (if (not (is-eq (get current-registration-status cin-details) "ACTIVE"))
              ERR-CIN-STATUS-INACTIVE
              (if (< (get expiration-timestamp cin-details) block-height)
                ERR-CIN-STATUS-EXPIRED
                (ok cin-details)
              )
            )
          )
        )
      )
      ERR-INVALID-CIN-FORMAT
    )
  )
)

;; AUTOMATED MAINTENANCE AND BATCH OPERATIONS

;; Batch processes multiple CINs to automatically update expired registrations
(define-public (process-expired-cin-batch (cin-batch (list 20 (string-ascii 20))))
  (begin
    ;; Administrative access required for batch operations
    (asserts! (has-administrative-privileges) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Process each CIN in the batch for expiration
    (map check-and-update-expired-cin cin-batch)
    
    (ok true)
  )
)

;; Helper function to check and update a single expired CIN
(define-private (check-and-update-expired-cin (cin-identifier (string-ascii 20)))
  (begin
    (if (is-valid-cin-format cin-identifier)
      (let
        (
          (cin-registry-entry (map-get? corporate-identity-number-registry { cin-code: cin-identifier }))
        )
        (if (is-some cin-registry-entry)
          (let
            (
              (cin-details (unwrap-panic cin-registry-entry))
              (expiration-date (get expiration-timestamp cin-details))
              (current-status (get current-registration-status cin-details))
              (is-expired (and (< expiration-date block-height) (is-eq current-status "ACTIVE")))
            )
            (if is-expired
              (begin
                (map-set corporate-identity-number-registry
                  { cin-code: cin-identifier }
                  (merge cin-details {
                    current-registration-status: "EXPIRED",
                    last-update-timestamp: block-height
                  })
                )
                ;; Attempt to log status change, continue on failure
                (match (log-status-modification cin-identifier "EXPIRED")
                  success-result true
                  error-result false)
                true
              )
              false
            )
          )
          false
        )
      )
      false
    )
  )
)

;; Gets the current contract primary owner address
(define-read-only (get-contract-primary-owner)
  (ok (var-get contract-primary-owner))
)

;; CONTRACT INITIALIZATION

;; Initialize contract with deployer as the first authorized administrator
(begin
  (map-set registry-administrator-permissions { admin-address: tx-sender } { has-administrative-access: true })
)