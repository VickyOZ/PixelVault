;; PixelQuest Gaming Platform
;; A decentralized gaming platform that manages in-game assets, achievements, and rewards

;; Constants and Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-EXISTS (err u101))
(define-constant ERR-INVALID-PARAMS (err u102))
(define-constant ERR-ASSET-NOT-FOUND (err u103))
(define-constant ERR-SCORE-TOO-HIGH (err u104))

;; Define game administrator
(define-data-var contract-owner principal tx-sender)

;; Token for in-game rewards
(define-fungible-token pixel-token)

;; NFT for in-game assets
(define-non-fungible-token game-asset { id: uint })

;; Data Maps
(define-map asset-details
    { asset-id: uint }
    {
        name: (string-ascii 50),
        rarity: uint,
        power: uint,
        owner: principal
    }
)

(define-map player-achievements
    { player: principal }
    {
        achievement-count: uint,
        total-score: uint,
        last-achievement: uint
    }
)

(define-map player-rewards
    { player: principal }
    { balance: uint }
)

;; Data validation functions
(define-private (is-valid-asset-id (asset-id uint))
    (and 
        (>= asset-id u1)
        (<= asset-id u10000)
    )
)

(define-private (is-valid-rarity (rarity uint))
    (and 
        (>= rarity u1)
        (<= rarity u5)
    )
)

(define-private (is-valid-power (power uint))
    (and 
        (>= power u1)
        (<= power u100)
    )
)

(define-private (is-valid-score (score uint))
    (and 
        (>= score u1)
        (<= score u1000)
    )
)

;; Mint new game asset NFT
(define-public (mint-game-asset (asset-id uint) (name (string-ascii 50)) (rarity uint) (power uint))
    (let ((asset-owner tx-sender))
        (begin
            ;; Check authorization
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            
            ;; Validate parameters
            (asserts! (is-valid-asset-id asset-id) ERR-INVALID-PARAMS)
            (asserts! (is-valid-rarity rarity) ERR-INVALID-PARAMS)
            (asserts! (is-valid-power power) ERR-INVALID-PARAMS)
            
            ;; Check if asset already exists
            (asserts! (is-none (map-get? asset-details { asset-id: asset-id })) ERR-ASSET-EXISTS)
            
            ;; Mint NFT
            (try! (nft-mint? game-asset { id: asset-id } asset-owner))
            
            ;; Store asset details
            (map-set asset-details
                { asset-id: asset-id }
                {
                    name: name,
                    rarity: rarity,
                    power: power,
                    owner: asset-owner
                }
            )
            (ok true)
        )
    )
)

;; Record player achievement
(define-public (record-achievement (achievement-id uint) (score uint))
    (let (
        (current-achievements (default-to { achievement-count: u0, total-score: u0, last-achievement: u0 }
            (map-get? player-achievements { player: tx-sender })))
    )
        (begin
            ;; Validate score
            (asserts! (is-valid-score score) ERR-INVALID-PARAMS)
            
            ;; Update achievements
            (map-set player-achievements
                { player: tx-sender }
                {
                    achievement-count: (+ (get achievement-count current-achievements) u1),
                    total-score: (+ (get total-score current-achievements) score),
                    last-achievement: achievement-id
                }
            )
            
            ;; Calculate and mint rewards
            (let ((reward-amount (* score u10)))
                (asserts! (<= reward-amount u10000) ERR-SCORE-TOO-HIGH)
                (try! (mint-reward tx-sender reward-amount))
            )
            (ok true)
        )
    )
)

;; Mint reward tokens
(define-private (mint-reward (player principal) (amount uint))
    (ft-mint? pixel-token amount player)
)

;; Transfer game asset
(define-public (transfer-asset (asset-id uint) (recipient principal))
    (begin
        ;; Validate asset ID
        (asserts! (is-valid-asset-id asset-id) ERR-INVALID-PARAMS)
        
        ;; Check asset exists and get details
        (let ((asset-info (unwrap! (map-get? asset-details { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
            (begin
                ;; Verify ownership
                (asserts! (is-eq (get owner asset-info) tx-sender) ERR-NOT-AUTHORIZED)
                
                ;; Transfer NFT
                (try! (nft-transfer? game-asset { id: asset-id } tx-sender recipient))
                
                ;; Update ownership records
                (map-set asset-details
                    { asset-id: asset-id }
                    (merge asset-info { owner: recipient })
                )
                (ok true)
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-player-achievements (player principal))
    (map-get? player-achievements { player: player })
)

(define-read-only (get-asset-details (asset-id uint))
    (map-get? asset-details { asset-id: asset-id })
)

;; Contract initialization
(begin
    ;; Initialize contract state if needed
    (try! (ft-mint? pixel-token u1000000 (var-get contract-owner)))
    (ok true)
)