// CompostDispatchView.swift
// Yard2Yum — "Divergent Dispatch" style Uber-esque compost logistics feature
//
// Lives alongside ContentView.swift and relies on things already defined there:
// Color.y2yBackground, .y2yCard, .y2yAccent, .y2yTan, .y2ySubtext, AppState,
// Y2YPage, Y2YButton, BackButton, LogoutToolbarItem.

import SwiftUI

extension Color {
    static let y2yGold = Color(red: 0.94, green: 0.85, blue: 0.54)
}

// MARK: - Models

enum DispatchRole: String, CaseIterable, Identifiable {
    case restaurant = "Restaurants"
    case hub        = "Compost Hubs"
    case farm       = "Farms"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .hub:        return "arrow.3.trianglepath"
        case .farm:       return "leaf.fill"
        }
    }
    var accent: Color {
        switch self {
        case .restaurant: return Color(red: 0.95, green: 0.58, blue: 0.35)
        case .hub:        return Color.y2yGold
        case .farm:       return Color.y2yAccent
        }
    }
}

struct DispatchFlowStop {
    let stepLabel: String
    let name: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct DispatchQueueItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let eta: String
    let isActive: Bool
}

struct DispatchMarketItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tag: String
}

struct DispatchContent {
    let heroTitle: String
    let heroSummary: String
    let requestTitle: String
    let requestBadge: String
    let origin: DispatchFlowStop
    let hub: DispatchFlowStop
    let destination: DispatchFlowStop
    let metricLoad: String
    let metricDiversion: String
    let metricScore: String
    let routeSignal: String
    let queue: [DispatchQueueItem]
    let marketplaceTitle: String
    let marketplace: [DispatchMarketItem]
    let spotlightTitle: String
    let spotlightTag: String
    let spotlightCopy: String
    let spotlightStatOneLabel: String
    let spotlightStatOne: String
    let spotlightStatTwoLabel: String
    let spotlightStatTwo: String
    let workflowHeadline: String
    let workflowBullets: [String]
}

let dispatchContent: [DispatchRole: DispatchContent] = [
    .restaurant: DispatchContent(
        heroTitle: "Route food scraps from your kitchen into farm-ready soil.",
        heroSummary: "Uber-like dispatch, redesigned for compost: bundled pickups, hub handoffs, and farm delivery windows tied to soil demand.",
        requestTitle: "Evening kitchen pickup batch",
        requestBadge: "Truck 08 · 12 min",
        origin: DispatchFlowStop(stepLabel: "Origin", name: "Harbor Bistro cluster", subtitle: "4 restaurants ready for pickup", icon: "1.circle.fill", color: Color(red: 0.95, green: 0.58, blue: 0.35)),
        hub: DispatchFlowStop(stepLabel: "Processing", name: "GreenLoop Compost Hub", subtitle: "Contamination scan + curing intake", icon: "2.circle.fill", color: Color.y2yGold),
        destination: DispatchFlowStop(stepLabel: "Destination", name: "SunPatch Farm", subtitle: "2.4 tons reserved for soil top-up", icon: "3.circle.fill", color: Color.y2yTan),
        metricLoad: "2.4 tons", metricDiversion: "94%", metricScore: "A+",
        routeSignal: "Trucks are bundling 3 restaurant stops before the compost hub handoff.",
        queue: [
            DispatchQueueItem(title: "Truck 08 · Kitchen batch", subtitle: "Harbor district → GreenLoop → SunPatch", eta: "12 min", isActive: true),
            DispatchQueueItem(title: "Truck 12 · Cured compost", subtitle: "Hub reserve → Orchard Ridge", eta: "28 min", isActive: false),
            DispatchQueueItem(title: "Truck 05 · Return leg", subtitle: "Farm bins → City restaurant corridor", eta: "41 min", isActive: false),
        ],
        marketplaceTitle: "Compost marketplace",
        marketplace: [
            DispatchMarketItem(title: "SunPatch Farm", subtitle: "Needs 2.4 tons of cured compost by sunrise", tag: "$420 lot"),
            DispatchMarketItem(title: "GreenLoop Hub", subtitle: "Posting screened compost, low contamination score", tag: "Ready now"),
            DispatchMarketItem(title: "Harbor Bistro Collective", subtitle: "Recurring pickup contract with diversion incentives", tag: "Renewing"),
        ],
        spotlightTitle: "Restaurant control tower",
        spotlightTag: "High-volume kitchens",
        spotlightCopy: "Schedule pickups, monitor contamination, and earn diversion rewards when your bins are grouped into dense truck routes.",
        spotlightStatOneLabel: "Savings unlocked", spotlightStatOne: "$3.2k",
        spotlightStatTwoLabel: "Batches this week", spotlightStatTwo: "18",
        workflowHeadline: "Pickup requests feel instant, but routes stay efficient.",
        workflowBullets: [
            "Schedule recurring food-scrap pickups without phone calls.",
            "See landfill diversion, savings, and reward points in one view.",
            "Join nearby kitchens into a shared truck batch to lower costs.",
        ]
    ),
    .hub: DispatchContent(
        heroTitle: "Orchestrate compost hubs like a live freight exchange.",
        heroSummary: "Balance truck inflow, contamination checks, curing capacity, and outgoing farm deliveries in one dispatch layer.",
        requestTitle: "Hub intake balancing run",
        requestBadge: "Truck 12 · 28 min",
        origin: DispatchFlowStop(stepLabel: "Origin", name: "GreenLoop inbound dock", subtitle: "2 restaurant corridors arriving together", icon: "1.circle.fill", color: Color(red: 0.95, green: 0.58, blue: 0.35)),
        hub: DispatchFlowStop(stepLabel: "Processing", name: "Screening + curing lane", subtitle: "Automated quality triage before lot creation", icon: "2.circle.fill", color: Color.y2yGold),
        destination: DispatchFlowStop(stepLabel: "Destination", name: "Regional farm queue", subtitle: "3 matched buyers waiting on screened compost", icon: "3.circle.fill", color: Color.y2yTan),
        metricLoad: "3.8 tons", metricDiversion: "97%", metricScore: "Balanced",
        routeSignal: "The hub is rerouting two trucks to avoid intake congestion and keep curing lanes full.",
        queue: [
            DispatchQueueItem(title: "Truck 12 · Intake balancing", subtitle: "Restaurant corridor → GreenLoop dock", eta: "28 min", isActive: true),
            DispatchQueueItem(title: "Truck 03 · Screened lot", subtitle: "Curing lane → Farm queue", eta: "35 min", isActive: false),
            DispatchQueueItem(title: "Truck 09 · Overflow", subtitle: "GreenLoop → Secondary hub", eta: "52 min", isActive: false),
        ],
        marketplaceTitle: "Finished-lot exchange",
        marketplace: [
            DispatchMarketItem(title: "Screened Lot #114", subtitle: "Low contamination, ready for farm pickup", tag: "$380 lot"),
            DispatchMarketItem(title: "Curing Lane B", subtitle: "68% capacity available for new intake", tag: "Open"),
            DispatchMarketItem(title: "SunPatch Farm", subtitle: "Standing order for weekly cured compost", tag: "Renewing"),
        ],
        spotlightTitle: "Compost hub command",
        spotlightTag: "Capacity-aware routing",
        spotlightCopy: "Accept incoming loads only when curing space is ready, then list finished compost into a farm-facing marketplace without losing route visibility.",
        spotlightStatOneLabel: "Curing capacity", spotlightStatOne: "68%",
        spotlightStatTwoLabel: "Lots posted", spotlightStatTwo: "24",
        workflowHeadline: "Dispatch based on readiness, quality, and truck capacity.",
        workflowBullets: [
            "Accept incoming organic loads only when curing space is available.",
            "Optimize truck routes around contamination checks and turnaround time.",
            "Post finished compost lots directly into a farm-facing marketplace.",
        ]
    ),
    .farm: DispatchContent(
        heroTitle: "Book compost deliveries with the precision of a produce run.",
        heroSummary: "Reserve soil deliveries, set blend preferences, and subscribe to replenishment windows synced with crop cycles.",
        requestTitle: "Pre-dawn soil replenishment",
        requestBadge: "Truck 05 · 41 min",
        origin: DispatchFlowStop(stepLabel: "Origin", name: "GreenLoop reserve stock", subtitle: "Screened compost pulled for field application", icon: "1.circle.fill", color: Color(red: 0.95, green: 0.58, blue: 0.35)),
        hub: DispatchFlowStop(stepLabel: "Processing", name: "Route staging yard", subtitle: "Loaded by field priority and moisture profile", icon: "2.circle.fill", color: Color.y2yGold),
        destination: DispatchFlowStop(stepLabel: "Destination", name: "Orchard Ridge Farm", subtitle: "4 fields scheduled before irrigation", icon: "3.circle.fill", color: Color.y2yTan),
        metricLoad: "4.1 tons", metricDiversion: "88%", metricScore: "On-time",
        routeSignal: "Farm deliveries are being sequenced by crop windows, starting with the highest-moisture fields.",
        queue: [
            DispatchQueueItem(title: "Truck 05 · Field delivery", subtitle: "Staging yard → Orchard Ridge Farm", eta: "41 min", isActive: true),
            DispatchQueueItem(title: "Truck 07 · Subscription run", subtitle: "GreenLoop reserve → River Bend Farm", eta: "55 min", isActive: false),
            DispatchQueueItem(title: "Truck 02 · Return bins", subtitle: "Orchard Ridge → City restaurant corridor", eta: "1 hr 10 min", isActive: false),
        ],
        marketplaceTitle: "Farm demand board",
        marketplace: [
            DispatchMarketItem(title: "Orchard Ridge Farm", subtitle: "4 fields queued for pre-dawn delivery", tag: "Scheduled"),
            DispatchMarketItem(title: "River Bend Farm", subtitle: "Weekly subscription due tomorrow", tag: "Renewing"),
            DispatchMarketItem(title: "Sunflower Acres", subtitle: "Requesting a custom high-nitrogen blend", tag: "Matching"),
        ],
        spotlightTitle: "Farm replenishment view",
        spotlightTag: "Subscription-ready fields",
        spotlightCopy: "Request exact compost blends, track truck ETAs, and lock in recurring deliveries tied to harvest calendars and field health.",
        spotlightStatOneLabel: "Fields queued", spotlightStatOne: "4",
        spotlightStatTwoLabel: "Next ETA", spotlightStatTwo: "6:40 AM",
        workflowHeadline: "Reserve soil deliveries with the predictability of freight.",
        workflowBullets: [
            "Subscribe to compost replenishment for fields, orchards, and greenhouses.",
            "Match truck deliveries to crop cycles and preferred blend quality.",
            "Build direct relationships with regional restaurants and compost facilities.",
        ]
    ),
]

// MARK: - Main View

struct CompostDispatchView: View {
    let onBack: () -> Void
    @State private var selectedRole: DispatchRole
    @State private var dispatched = false
    @State private var heldForBatching = false

    init(initialRole: DispatchRole = .restaurant, onBack: @escaping () -> Void) {
        self.onBack = onBack
        self._selectedRole = State(initialValue: initialRole)
    }

    var content: DispatchContent { dispatchContent[selectedRole]! }

    var body: some View {
        Y2YPage(title: "Divergent Dispatch", subtitle: "Closed-loop compost logistics") {
            roleSwitcher
            heroRequestCard
            routeMeshCard
            truckQueueCard
            marketplaceCard
            spotlightCard
            workflowCard
            BackButton(action: onBack)
        }
        .toolbar { LogoutToolbarItem() }
    }

    // MARK: Role switcher

    private var roleSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(DispatchRole.allCases) { role in
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        selectedRole = role
                        dispatched = false
                        heldForBatching = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: role.icon).font(.system(size: 12, weight: .bold))
                        Text(role.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundColor(selectedRole == role ? Color.y2yCard : Color.y2ySubtext)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedRole == role ? Color.y2yAccent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(6)
        .background(Color.y2yCard.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Hero request card

    private var heroRequestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRUCK-ROUTED COMPOST MARKETPLACE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.y2yAccent)
            Text(content.heroTitle)
                .font(Font.custom("Georgia-Bold", size: 22))
                .foregroundColor(Color.y2yTan)
            Text(content.heroSummary)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color.y2ySubtext)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT DISPATCH")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.y2ySubtext.opacity(0.7))
                        Text(content.requestTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.y2yTan)
                    }
                    Spacer()
                    Text(content.requestBadge)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.y2yAccent)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.y2yAccent.opacity(0.15))
                        .clipShape(Capsule())
                }

                VStack(spacing: 10) {
                    DispatchStopRow(stop: content.origin)
                    DispatchStopRow(stop: content.hub)
                    DispatchStopRow(stop: content.destination)
                }

                HStack(spacing: 10) {
                    DispatchMetricTile(label: "Load", value: content.metricLoad)
                    DispatchMetricTile(label: "Diversion", value: content.metricDiversion)
                    DispatchMetricTile(label: "Route score", value: content.metricScore)
                }

                if dispatched {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(Color.y2yAccent)
                        Text("Truck dispatched — live tracking started.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.y2yTan)
                    }
                    .padding(12).background(Color.y2yBackground.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 14))
                } else if heldForBatching {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill").foregroundColor(Color.y2yGold)
                        Text("Held for batching — waiting on nearby stops.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.y2yTan)
                    }
                    .padding(12).background(Color.y2yBackground.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.4)) { dispatched = true; heldForBatching = false }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Dispatch truck").font(.system(size: 14, weight: .bold, design: .rounded))
                            Image(systemName: "shippingbox.fill").font(.system(size: 12))
                        }
                        .foregroundColor(Color.y2yCard)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.y2yAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Button {
                        withAnimation(.spring(response: 0.4)) { heldForBatching = true; dispatched = false }
                    } label: {
                        Text("Hold for batching")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.y2yTan)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
            .padding(16)
            .background(Color.y2yBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(selectedRole.accent.opacity(0.25), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
    }

    // MARK: Route mesh (simplified vertical timeline standing in for the map)

    private var routeMeshCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE NETWORK").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.7))
                    Text("Route mesh").font(Font.custom("Georgia-Bold", size: 18)).foregroundColor(Color.y2yTan)
                }
                Spacer()
                Text("Batch-optimized")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.y2yAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.y2yAccent.opacity(0.12)).clipShape(Capsule())
            }

            VStack(spacing: 0) {
                DispatchTimelineNode(icon: "circle.fill", color: Color(red: 0.95, green: 0.58, blue: 0.35), title: content.origin.name, subtitle: content.origin.subtitle, showLine: true)
                DispatchTimelineNode(icon: "circle.fill", color: Color.y2yGold, title: content.hub.name, subtitle: content.hub.subtitle, showLine: true)
                DispatchTimelineNode(icon: "circle.fill", color: Color.y2yTan, title: content.destination.name, subtitle: content.destination.subtitle, showLine: false)
            }
            .padding(14)
            .background(Color.y2yBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg").foregroundColor(Color.y2yAccent).font(.system(size: 13))
                Text(content.routeSignal)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color.y2ySubtext)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(Color.y2yBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 16) {
                DispatchLegendDot(label: "Generators", color: Color(red: 0.95, green: 0.58, blue: 0.35))
                DispatchLegendDot(label: "Compost hubs", color: Color.y2yGold)
                DispatchLegendDot(label: "Farms", color: Color.y2yTan)
            }
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    // MARK: Truck queue

    private var truckQueueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DISPATCH BOARD").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.7))
                    Text("Truck queue").font(Font.custom("Georgia-Bold", size: 18)).foregroundColor(Color.y2yTan)
                }
                Spacer()
                Text("\(content.queue.count) active")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
            }
            VStack(spacing: 10) {
                ForEach(content.queue) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                            Text(item.subtitle).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                        Spacer()
                        Text(item.eta).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2yAccent)
                    }
                    .padding(14)
                    .background(item.isActive ? Color.y2yAccent.opacity(0.12) : Color.y2yBackground.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    // MARK: Marketplace

    private var marketplaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MARKET SIGNAL").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.7))
                    Text(content.marketplaceTitle).font(Font.custom("Georgia-Bold", size: 18)).foregroundColor(Color.y2yTan)
                }
                Spacer()
                Text("Live bids")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
            }
            VStack(spacing: 10) {
                ForEach(content.marketplace) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Color.y2yTan)
                            Text(item.subtitle).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
                        }
                        Spacer()
                        Text(item.tag).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color.y2yGold)
                    }
                    .padding(14)
                    .background(Color.y2yBackground.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    // MARK: Spotlight

    private var spotlightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROLE SPOTLIGHT").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(Color.y2ySubtext.opacity(0.7))
                    Text(content.spotlightTitle).font(Font.custom("Georgia-Bold", size: 18)).foregroundColor(Color.y2yTan)
                }
                Spacer()
                Text(content.spotlightTag)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
            }
            Text(content.spotlightCopy)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color.y2ySubtext)
                .lineSpacing(4)
            HStack(spacing: 12) {
                DispatchMetricTile(label: content.spotlightStatOneLabel, value: content.spotlightStatOne)
                DispatchMetricTile(label: content.spotlightStatTwoLabel, value: content.spotlightStatTwo)
            }
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    // MARK: Workflow (per-role explainer)

    private var workflowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedRole.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(selectedRole.accent)
            Text(content.workflowHeadline)
                .font(Font.custom("Georgia-Bold", size: 18))
                .foregroundColor(Color.y2yTan)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(content.workflowBullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(selectedRole.accent).frame(width: 5, height: 5).padding(.top, 6)
                        Text(bullet)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color.y2ySubtext)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.y2yCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(selectedRole.accent.opacity(0.3), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Small helper views

struct DispatchStopRow: View {
    let stop: DispatchFlowStop
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(stop.color.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: stop.icon).foregroundColor(stop.color).font(.system(size: 16, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.stepLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color.y2ySubtext.opacity(0.6))
                Text(stop.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.y2yTan)
                Text(stop.subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Color.y2ySubtext)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DispatchMetricTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.y2ySubtext.opacity(0.65))
            Text(value)
                .font(Font.custom("Georgia-Bold", size: 18))
                .foregroundColor(Color.y2yTan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DispatchLegendDot: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color.y2ySubtext)
        }
    }
}

struct DispatchTimelineNode: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let showLine: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(color).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 4).scaleEffect(1.8))
                if showLine {
                    Rectangle().fill(color.opacity(0.25)).frame(width: 2).frame(minHeight: 34)
                }
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color.y2yTan)
                Text(subtitle).font(.system(size: 11, design: .rounded)).foregroundColor(Color.y2ySubtext)
            }
            .padding(.bottom, showLine ? 16 : 0)
            Spacer()
        }
    }
}
