import Foundation
import StoreKit

enum NeedleNoteProducts {
    static let unlimitedProjects = "com.needlenote.app.unlimitedprojects"
    static let debugUnlimitedProjectsDisplayPrice = "$4.99"
    static let freeProjectLimit = 1
}

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?
    private var hasStarted = false

    var unlimitedProjectsProduct: Product? {
        products.first { $0.id == NeedleNoteProducts.unlimitedProjects }
    }

    var hasUnlimitedProjects: Bool {
        purchasedProductIDs.contains(NeedleNoteProducts.unlimitedProjects)
    }

    func canCreateProject(existingProjectCount: Int) -> Bool {
        hasUnlimitedProjects || existingProjectCount < NeedleNoteProducts.freeProjectLimit
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        transactionUpdatesTask = observeTransactionUpdates()
        await loadProducts()
        await refreshPurchasedProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil

        do {
            products = try await Product.products(for: [NeedleNoteProducts.unlimitedProjects])
            if products.isEmpty {
                #if DEBUG
                errorMessage = "StoreKit did not return Unlimited Projects. In Xcode, choose Edit Scheme > Run > Options > StoreKit Configuration > NeedleNote.storekit."
                #else
                errorMessage = "Unlimited Projects is not available yet. Check the product ID in App Store Connect."
                #endif
            }
        } catch {
            errorMessage = "Unable to load purchase options. Please try again."
        }

        isLoadingProducts = false
    }

    @discardableResult
    func purchaseUnlimitedProjects() async -> Bool {
        if unlimitedProjectsProduct == nil {
            await loadProducts()
        }

        guard let product = unlimitedProjectsProduct else {
            #if DEBUG
            unlockForDebugBuild()
            return true
            #else
            return false
            #endif
        }

        isPurchasing = true
        errorMessage = nil

        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                await refreshPurchasedProducts()
                return true
            case .pending:
                errorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase could not be completed. Please try again."
            return false
        }
    }

    func restorePurchases() async {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()

            if !hasUnlimitedProjects {
                errorMessage = "No Unlimited Projects purchase was found for this Apple ID."
            }
        } catch {
            errorMessage = "Restore could not be completed. Please try again."
        }
    }

    func refreshPurchasedProducts() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID == NeedleNoteProducts.unlimitedProjects {
                activeProductIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = activeProductIDs
    }

    #if DEBUG
    func unlockForDebugBuild() {
        errorMessage = nil
        purchasedProductIDs.insert(NeedleNoteProducts.unlimitedProjects)
    }
    #endif

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.refreshPurchasedProducts()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.failedVerification
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }
}

private enum StoreKitError: Error {
    case failedVerification
}
