import Foundation
import Observation
import StoreKit

enum AppLab {
    static var enabled: Bool {
        #if DEBUG
        true
        #else
        // TestFlight also uses sandbox receipts; only Debug builds expose lab tools.
        false
        #endif
    }
}

@Observable
@MainActor
final class Entitlements {
    static let shared = Entitlements()
    static let yearlyId = "halfcam.yearly"
    static let lifetimeId = "halfcam.unlock"
    static let skipPack3Id = "halfcam.skip.3"
    static let skipProductIds: Set<String> = [skipPack3Id]

    var storeTier: MembershipTier = .free
    var yearlyProduct: Product?
    var lifetimeProduct: Product?
    var skipPack3: Product?
    var skipProducts: [Product] { [skipPack3].compactMap { $0 } }
    var skipProduct: Product? { skipPack3 }
    var purchasing = false
    var note = ""
    var onSkipPackGranted: ((Int) -> Void)? {
        didSet {
            if let onSkipPackGranted, pendingSkipGrant > 0 {
                onSkipPackGranted(pendingSkipGrant)
                pendingSkipGrant = 0
            }
        }
    }
    private var skipTxCounts: [String: Int] = [:]
    private var skipRevokedIds: [String] = []
    private var pendingSkipGrant = 0
    private var skipTxCloudReady = false

    var debugTier: MembershipTier? {
        didSet { persistDebug() }
    }

    var tier: MembershipTier {
        AppLab.enabled ? (debugTier ?? storeTier) : storeTier
    }

    private init() {
        loadDebug()
        loadSkipTx()
        Task { await listen() }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            var ids: Set<String> = [Self.yearlyId, Self.lifetimeId]
            ids.formUnion(Self.skipProductIds)
            let list = try await Product.products(for: ids)
            yearlyProduct = list.first { $0.id == Self.yearlyId }
            lifetimeProduct = list.first { $0.id == Self.lifetimeId }
            skipPack3 = list.first { $0.id == Self.skipPack3Id }
        } catch {
            yearlyProduct = nil
            lifetimeProduct = nil
            skipPack3 = nil
        }
        await refreshEntitlements()
        await reconcileSkipTransactions()
    }

    func buyYearly() async {
        await buy(yearlyProduct)
    }

    func buyLifetime() async {
        await buy(lifetimeProduct)
    }

    func buySkipPack(_ product: Product? = nil) async {
        await buy(product ?? skipPack3, membership: false)
    }

    static func skipCount(for productId: String) -> Int {
        switch productId {
        case skipPack3Id: 3
        default: 0
        }
    }

    func restore() async {
        purchasing = true
        note = ""
        defer { purchasing = false }
        do {
            try await AppStore.sync()
            NSUbiquitousKeyValueStore.default.synchronize()
            mergeCloudSkipTx()
            persistSkipTx()
            NotificationCenter.default.post(name: .halfcamSkipCloudRestore, object: nil)
            await refresh()
            followStoreAfterPurchase()
            note = L("已恢复")
        } catch {
            note = L("商店不可用")
        }
    }

    func setDebugTier(_ tier: MembershipTier?) {
        guard AppLab.enabled else { return }
        debugTier = tier
    }

    private func buy(_ product: Product?, membership: Bool = true) async {
        guard let product else {
            note = L("商店不可用")
            return
        }
        purchasing = true
        note = ""
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try check(verification)
                applySkip(tx, emitGrant: true)
                await tx.finish()
                await refreshEntitlements()
                if membership { followStoreAfterPurchase() }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            note = L("商店不可用")
        }
    }

    private func listen() async {
        for await result in Transaction.updates {
            if let tx = try? check(result) {
                applySkip(tx, emitGrant: true)
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }

    private func reconcileSkipTransactions() async {
        for await result in Transaction.all {
            guard let tx = try? check(result), Self.skipProductIds.contains(tx.productID) else { continue }
            applySkip(tx, emitGrant: false)
        }
    }

    private func applySkip(_ tx: Transaction, emitGrant: Bool) {
        guard Self.skipProductIds.contains(tx.productID) else { return }
        let id = String(tx.id)
        let count = Self.skipCount(for: tx.productID)
        guard count > 0 else { return }
        if tx.revocationDate != nil {
            revokeSkip(id)
        } else {
            grantSkip(id, count: count, emit: emitGrant)
        }
    }

    private func grantSkip(_ id: String, count: Int, emit: Bool) {
        if skipRevokedIds.contains(id) || skipTxCounts[id] != nil { return }
        skipTxCounts[id] = count
        persistSkipTx()
        if emit { emitSkip(count) }
    }

    private func revokeSkip(_ id: String) {
        if skipRevokedIds.contains(id) { return }
        skipRevokedIds.append(id)
        trim(&skipRevokedIds)
        let granted = skipTxCounts[id]
        skipTxCounts.removeValue(forKey: id)
        persistSkipTx()
        if let granted { emitSkip(-granted) }
    }

    private func emitSkip(_ delta: Int) {
        if let onSkipPackGranted {
            onSkipPackGranted(delta)
        } else {
            pendingSkipGrant += delta
        }
    }

    private func trim(_ ids: inout [String]) {
        if ids.count > 80 { ids.removeFirst(ids.count - 80) }
    }

    private func refreshEntitlements() async {
        var lifetime = false
        var yearly = false
        for await result in Transaction.currentEntitlements {
            guard let tx = try? check(result) else { continue }
            if tx.productID == Self.lifetimeId { lifetime = true }
            if tx.productID == Self.yearlyId { yearly = true }
        }
        if lifetime {
            storeTier = .lifetime
        } else if yearly {
            storeTier = .yearly
        } else {
            storeTier = .free
        }
    }

    private func followStoreAfterPurchase() {
        debugTier = nil
    }

    private func check(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let tx): return tx
        }
    }

    private static let skipTxKey = "halfcam.skipTxIds"
    private static let skipRevokedKey = "halfcam.skipRevokedIds"
    private static let cloudSkipTxKey = "halfcam.cloud.skipTxCounts"
    private static let cloudSkipRevokedKey = "halfcam.cloud.skipRevokedIds"

    private func loadSkipTx() {
        if let data = UserDefaults.standard.data(forKey: Self.skipTxKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            skipTxCounts = counts
        } else if let legacy = UserDefaults.standard.stringArray(forKey: Self.skipTxKey) {
            skipTxCounts = Dictionary(uniqueKeysWithValues: legacy.map { ($0, 3) })
        }
        skipRevokedIds = UserDefaults.standard.stringArray(forKey: Self.skipRevokedKey) ?? []
        NSUbiquitousKeyValueStore.default.synchronize()
        mergeCloudSkipTx()
        persistSkipTx()
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleSkipTxCloudChange(note)
            }
        }
    }

    private func handleSkipTxCloudChange(_ note: Notification) {
        let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        if reason == NSUbiquitousKeyValueStoreInitialSyncChange
            || reason == NSUbiquitousKeyValueStoreServerChange {
            skipTxCloudReady = true
        }
        mergeCloudSkipTx()
        persistSkipTx()
    }

    private func mergeCloudSkipTx() {
        let cloud = NSUbiquitousKeyValueStore.default
        var saw = false
        if let data = cloud.data(forKey: Self.cloudSkipTxKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            saw = true
            for (id, count) in counts where skipTxCounts[id] == nil {
                skipTxCounts[id] = count
            }
        }
        if let remote = cloud.array(forKey: Self.cloudSkipRevokedKey) as? [String] {
            saw = true
            skipRevokedIds = Array(Set(skipRevokedIds + remote))
            trim(&skipRevokedIds)
        }
        if saw { skipTxCloudReady = true }
    }

    private func persistSkipTx() {
        if let data = try? JSONEncoder().encode(skipTxCounts) {
            UserDefaults.standard.set(data, forKey: Self.skipTxKey)
            if skipTxCloudReady {
                NSUbiquitousKeyValueStore.default.set(data, forKey: Self.cloudSkipTxKey)
            }
        }
        UserDefaults.standard.set(skipRevokedIds, forKey: Self.skipRevokedKey)
        if skipTxCloudReady {
            NSUbiquitousKeyValueStore.default.set(skipRevokedIds, forKey: Self.cloudSkipRevokedKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    private static let debugKey = "halfcam.debugTier"

    private func loadDebug() {
        guard AppLab.enabled else { return }
        if let raw = UserDefaults.standard.string(forKey: Self.debugKey) {
            debugTier = MembershipTier(rawValue: raw)
        }
    }

    private func persistDebug() {
        guard AppLab.enabled else { return }
        if let debugTier {
            UserDefaults.standard.set(debugTier.rawValue, forKey: Self.debugKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.debugKey)
        }
    }
}

extension Notification.Name {
    static let halfcamSkipCloudRestore = Notification.Name("halfcam.skipCloudRestore")
}
