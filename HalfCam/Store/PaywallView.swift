import SwiftUI
import UIKit

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    private var store: Entitlements { model.membership }
    @State private var pick: MembershipTier = .lifetime

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.055).ignoresSafeArea()
            VStack(spacing: 0) {
                HatchBar(title: L("会员"), close: close) {
                    EntitlementMark(title: store.tier.title, paid: store.tier != .free)
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        statusLine
                        if store.tier != .lifetime {
                            plans
                        }
                        tierExplain
                        skipExplain
                        if store.tier != .lifetime {
                            note(L("年卡按年自动续订，费用从 Apple ID 扣除。到期前 24 小时可在系统设置里取消。买断一次付清，之后不再扣费。"))
                        }
                        if store.tier == .yearly {
                            note(L("购买买断不会自动取消现有年卡。请在系统设置中取消年卡续订，以免继续扣费。"))
                        }
                        if !store.note.isEmpty {
                            note(store.note)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                if store.tier != .lifetime {
                    buyBar
                }
                HStack(spacing: 18) {
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text(store.restoring ? L("正在恢复") : L("恢复购买"))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color(white: 0.62))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.purchasing)
                    Button {
                        Haptics.shared.chrome()
                        UIApplication.shared.open(Legal.page)
                    } label: {
                        Text(L("法律信息 · 隐私政策"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(white: 0.62))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task { await store.refresh() }
    }

    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(store.tier.title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Color(white: 0.88))
            Text(monthValue)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.90))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            planCard(.free)
            if store.tier == .free {
                planCard(.yearly)
            }
            planCard(.lifetime)
        }
    }

    private func planCard(_ tier: MembershipTier) -> some View {
        let on = pick == tier
        let current = store.tier == tier
        return Button {
            pick = tier
            Haptics.shared.chrome()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tier.title)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(white: on ? 0.92 : 0.72))
                    if current {
                        Text(L("当前"))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: on ? 0.72 : 0.48))
                    }
                    Spacer(minLength: 6)
                    Text(price(tier))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(white: on ? 0.72 : 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(perkLines(tier), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color(white: on ? 0.82 : 0.52))
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: on
                                ? [Color(white: 0.18), Color(white: 0.09)]
                                : [Color(white: 0.12), Color(white: 0.07)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(white: on ? 0.48 : 0.22), lineWidth: on ? 1 : 0.8)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(on ? 0.14 : 0.06), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private func perkLines(_ tier: MembershipTier) -> [String] {
        let cap = AppConst.allowedCapacities(tier).max() ?? 12
        let skip = AppConst.monthlySkipGrant(tier)
        let month: String
        if let n = AppConst.monthlyLimit(tier) {
            month = L("一个月 \(n) 卷")
        } else {
            month = L("不限卷")
        }
        return [
            month,
            L("一卷最多 \(cap) 格"),
            L("每月赠 \(skip) 张加急券"),
        ]
    }

    private var tierExplain: some View {
        VStack(alignment: .leading, spacing: 8) {
            note(L("免费：一个月 3 卷，一卷最多 12 格。每月赠 1 张加急券。"))
            note(L("年卡：一个月 9 卷，一卷最多 36 格。每月赠 3 张加急券。按年续订。"))
            note(L("买断：不限卷，一卷最多 72 格。每月赠 6 张加急券。一次付清。"))
        }
    }

    private var skipExplain: some View {
        VStack(alignment: .leading, spacing: 8) {
            note(L("加急一张，立刻洗完这一卷。三档都要等，加急只是把等待清掉。"))
            note(L("每月赠的加急券，按你当时的档位发放：免费 1 张，年卡 3 张，买断 6 张。到下个月初清掉，用不完作废。"))
            note(L("另买的加急券留下，不过月，并跟 iCloud 走。"))
        }
    }

    private var buyBar: some View {
        VStack(spacing: 10) {
            if pick == store.tier {
                ChromePlate(title: L("当前就是这一档"), prominent: false)
            } else if pick == .free {
                ChromePlate(title: L("对照档，不用买"), prominent: false)
            } else if store.tier == .free {
                Button {
                    Haptics.shared.chrome()
                    Task { await buy(pick) }
                } label: {
                    ChromePlate(title: busyTitle ?? (pick == .yearly ? yearlyTitle : lifetimeTitle), prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(store.purchasing)
            } else {
                Button {
                    Haptics.shared.chrome()
                    Task { await buyLifetime() }
                } label: {
                    ChromePlate(title: busyTitle ?? lifetimeTitle, prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(store.purchasing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var monthValue: String {
        if let cap = AppConst.monthlyLimit(store.tier) {
            return String(format: "%02d / %02d", model.loadsThisMonth, cap)
        }
        return L("不限")
    }

    private var busyTitle: String? {
        if store.restoring { return L("正在恢复") }
        if store.purchasing { return L("正在购买") }
        return nil
    }

    private func price(_ tier: MembershipTier) -> String {
        if store.tier == tier { return L("当前") }
        switch tier {
        case .yearly:
            return store.yearlyProduct?.displayPrice ?? ""
        case .lifetime:
            return store.lifetimeProduct?.displayPrice ?? ""
        case .free:
            return L("免费")
        }
    }

    private var yearlyTitle: String {
        if let price = store.yearlyProduct?.displayPrice {
            return L("年卡 · \(price)")
        }
        return L("年卡")
    }

    private var lifetimeTitle: String {
        if let price = store.lifetimeProduct?.displayPrice {
            return L("买断 · \(price)")
        }
        return L("买断")
    }

    private func buy(_ tier: MembershipTier) async {
        if tier == .yearly {
            await buyYearly()
        } else {
            await buyLifetime()
        }
    }

    private func buyYearly() async {
        await store.buyYearly()
        if store.storeTier != .free {
            model.syncSkipGrant()
            close()
        }
    }

    private func buyLifetime() async {
        await store.buyLifetime()
        if store.storeTier == .lifetime {
            model.syncSkipGrant()
            close()
        }
    }

    private func close() {
        model.showPaywall = false
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color(white: 0.62))
            .fixedSize(horizontal: false, vertical: true)
    }
}
