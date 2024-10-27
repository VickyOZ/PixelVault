;; PixelQuest Gaming Platform
;; A decentralized gaming platform that manages in-game assets, achievements, and rewards

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-EXISTS (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-ASSET-NOT-FOUND (err u103))

;; Define game administrator
(define-data-var contract-owner principal tx-sender)

;; Token for in-game rewards
(define-fungible-token pixel-token)

;; NFT for in-game assets
(define-non-fungible-token game-asset { id: uint })

;; Data structures
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

;; Mint new game asset NFT
(define-public (mint-game-asset (asset-id uint) (name (string-ascii 50)) (rarity uint) (power uint))
    (let ((asset-owner tx-sender))
        (begin
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            (try! (nft-mint? game-asset { id: asset-id } asset-owner))
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
            (map-set player-achievements
                { player: tx-sender }
                {
                    achievement-count: (+ (get achievement-count current-achievements) u1),
                    total-score: (+ (get total-score current-achievements) score),
                    last-achievement: achievement-id
                }
            )
            ;; Reward tokens for achievement
            (try! (mint-reward tx-sender (* score u10)))
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
    (let ((asset-info (unwrap! (map-get? asset-details { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
        (begin
            (asserts! (is-eq (get owner asset-info) tx-sender) ERR-NOT-AUTHORIZED)
            (try! (nft-transfer? game-asset { id: asset-id } tx-sender recipient))
            (map-set asset-details
                { asset-id: asset-id }
                (merge asset-info { owner: recipient })
            )
            (ok true)
        )
    )
)

;; Get player achievements
(define-read-only (get-player-achievements (player principal))
    (map-get? player-achievements { player: player })
)

;; Get asset details
(define-read-only (get-asset-details (asset-id uint))
    (map-get? asset-details { asset-id: asset-id })
)