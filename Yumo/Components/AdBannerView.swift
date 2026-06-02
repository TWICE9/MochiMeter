//
//  AdBannerView.swift
//  Yumo
//

import SwiftUI
import Combine
import GoogleMobileAds

/// Owns a single BannerView UIKit instance and loads ads independently of
/// SwiftUI view lifecycle. Publishes `loadedHeight` so views can
/// conditionally render (and fully remove themselves from layout on fail).
@MainActor
final class AdBannerLoader: NSObject, ObservableObject, BannerViewDelegate {
    @Published var loadedHeight: CGFloat = 0

    let bannerView: BannerView
    private let adUnitID: String
    private var lastLoadedWidth: CGFloat = 0
    private var hasStarted: Bool = false

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        self.bannerView = BannerView()
        super.init()
        bannerView.adUnitID = adUnitID
        bannerView.delegate = self
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        bannerView.rootViewController = Self.getKeyWindow()?.rootViewController
        tryLoad()
    }

    /// If the layout width has changed (e.g. rotation), request a new ad sized for it.
    func refreshIfWidthChanged() {
        tryLoad()
    }

    private func tryLoad() {
        let width = Self.currentWidth()
        guard width > 0, width != lastLoadedWidth else { return }
        lastLoadedWidth = width
        bannerView.adSize = GoogleMobileAds.currentOrientationAnchoredAdaptiveBanner(width: width)
        bannerView.load(Request())
    }

    private static func getKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            ?? scenes.flatMap { $0.windows }.first
    }

    private static func currentWidth() -> CGFloat {
        if let window = getKeyWindow() {
            let w = window.frame.inset(by: window.safeAreaInsets).width
            if w > 0 { return w }
            if window.frame.width > 0 { return window.frame.width }
        }
        let s = UIScreen.main.bounds.width
        return s > 0 ? s : 320
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("🟢 AdMob Banner Loaded (size: \(bannerView.adSize.size.width)x\(bannerView.adSize.size.height))")
        withAnimation(.easeInOut(duration: 0.25)) {
            loadedHeight = bannerView.adSize.size.height
        }
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("🔴 AdMob Banner Failed: \(error.localizedDescription)")
        withAnimation(.easeInOut(duration: 0.25)) {
            loadedHeight = 0
        }
    }
}

/// SwiftUI host that reparents a pre-existing BannerView into its own container view.
private struct AdBannerHost: UIViewRepresentable {
    let bannerView: BannerView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.removeFromSuperview()
        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Conditional ad banner that respects subscription status and load state.
/// Returns no view at all (zero layout footprint) when no ad is loaded.
struct ConditionalAdBanner: View {
    @EnvironmentObject var adManager: AdManager
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var loader: AdBannerLoader

    init(adUnitID: String = AdManager.bannerAdUnitID) {
        _loader = StateObject(wrappedValue: AdBannerLoader(adUnitID: adUnitID))
    }

    private var shouldShowAd: Bool {
        !storeKitManager.isPremium && adManager.shouldShowAds()
    }

    @ViewBuilder
    var body: some View {
        // When `shouldShowAd` is false (premium user, or ads disabled), the
        // entire conditional collapses to nothing. SwiftUI's VStack only
        // applies its spacing between rendered children, so a parent with
        // `VStack(spacing: 24)` no longer reserves 24pt above and below
        // for a hidden placeholder. Going premium → free re-evaluates the
        // body (storeKitManager is an @EnvironmentObject that drives
        // `shouldShowAd`), at which point the loader's `.onAppear` fires.
        if shouldShowAd {
            if loader.loadedHeight > 0 {
                VStack(spacing: 0) {
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

                    Spacer().frame(height: 10)

                    AdBannerHost(bannerView: loader.bannerView)
                        .frame(height: loader.loadedHeight)
                        .background(colorScheme == .dark ? Color.black : Color.white)

                    Spacer().frame(height: 10)
                }
                .animation(.easeInOut(duration: 0.25), value: loader.loadedHeight)
            } else {
                // Eligible-but-not-yet-loaded: keep an invisible mount point
                // so we can kick the loader. Once the banner is ready the
                // branch above takes over.
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        loader.start()
                        loader.refreshIfWidthChanged()
                    }
            }
        }
    }
}
