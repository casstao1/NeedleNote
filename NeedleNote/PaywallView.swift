import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let onUnlocked: () -> Void

    var body: some View {
        ZStack {
            KnitTheme.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                header
                benefitsCard
                purchaseControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 28)

            VStack {
                HStack {
                    dismissButton
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 18)
        }
        .task {
            if purchases.products.isEmpty {
                await purchases.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(KnitTheme.roseLight)
                        .frame(width: 76, height: 76)

                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(KnitTheme.rose)
                }

                VStack(spacing: 8) {
                    Text("Create unlimited projects")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(KnitTheme.brown)
                        .multilineTextAlignment(.center)

                    Text("Your first project is free. Unlock unlimited projects when you are ready to keep every pattern organized.")
                        .font(.system(size: 16))
                        .foregroundColor(KnitTheme.taupe)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
        }
    }

    private var dismissButton: some View {
        Button("Not now") {
            dismiss()
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(KnitTheme.rose)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(KnitTheme.warmWhite)
        .clipShape(Capsule())
        .shadow(color: KnitTheme.cardShadow, radius: 8, x: 0, y: 3)
    }

    private var benefitsCard: some View {
        VStack(spacing: 18) {
            benefitRow(icon: "square.stack.3d.up.fill", title: "Unlimited knitting projects", detail: "Track every sweater, scarf, and cardigan separately.")
            benefitRow(icon: "list.number", title: "Row counters stay organized", detail: "Keep counters, ranges, and notes attached to the right project.")
            benefitRow(icon: "doc.richtext.fill", title: "PDF patterns inside projects", detail: "Import each pattern where it belongs.")
        }
        .padding(20)
        .cardStyle()
    }

    private var purchaseControls: some View {
        VStack(spacing: 12) {
            if purchases.isLoadingProducts {
                ProgressView()
                    .tint(KnitTheme.rose)
                    .padding(.vertical, 18)
            } else {
                Button {
                    Task {
                        let unlocked = await purchases.purchaseUnlimitedProjects()
                        guard unlocked else { return }
                        onUnlocked()
                    }
                } label: {
                    Text(primaryButtonTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPrimaryButtonDisabled)
                .opacity(primaryButtonOpacity)
            }

            Button {
                Task {
                    await purchases.restorePurchases()
                    if purchases.hasUnlimitedProjects {
                        onUnlocked()
                    }
                }
            } label: {
                Text("Restore Purchase")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KnitTheme.rose)
            }
            .disabled(purchases.isPurchasing)

            if let errorMessage = visibleErrorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(KnitTheme.taupe)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var primaryButtonTitle: String {
        if purchases.isPurchasing {
            return "Purchasing..."
        }

        if let product = purchases.unlimitedProjectsProduct {
            return "Unlock for \(product.displayPrice)"
        }

        #if DEBUG
        return "Unlock for \(NeedleNoteProducts.debugUnlimitedProjectsDisplayPrice)"
        #else
        return "Purchase Unavailable"
        #endif
    }

    private var isPrimaryButtonDisabled: Bool {
        if purchases.isPurchasing {
            return true
        }

        #if DEBUG
        return false
        #else
        return purchases.unlimitedProjectsProduct == nil
        #endif
    }

    private var primaryButtonOpacity: Double {
        isPrimaryButtonDisabled ? 0.55 : 1
    }

    private var visibleErrorMessage: String? {
        #if DEBUG
        if purchases.unlimitedProjectsProduct == nil {
            return nil
        }
        #endif

        return purchases.errorMessage
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(KnitTheme.rose)
                .frame(width: 36, height: 36)
                .background(KnitTheme.roseLight)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KnitTheme.brown)

                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(KnitTheme.taupe)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
