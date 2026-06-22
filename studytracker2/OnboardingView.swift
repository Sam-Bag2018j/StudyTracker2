//
//  OnboardingView.swift
//  studytracker2
//
//  Three-page first-run onboarding that highlights the app's key features.
//

import SwiftUI

// One page of the onboarding carousel
private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

struct OnboardingView: View {

    var onDismiss: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "book.closed.fill",
            iconColor: .indigo,
            title: "Track Every Session",
            subtitle: "Log study sessions with our built-in timer, set daily goals per subject, and watch your progress grow day by day."
        ),
        OnboardingPage(
            id: 1,
            icon: "chart.bar.fill",
            iconColor: .teal,
            title: "Visualise Your Effort",
            subtitle: "Interactive bar charts show your weekly and monthly study time, subject breakdown, and grade trends — all in one place."
        ),
        OnboardingPage(
            id: 2,
            icon: "trophy.fill",
            iconColor: .yellow,
            title: "Earn Achievements",
            subtitle: "Unlock badges as you build streaks, hit hour milestones, and master your subjects. Stay motivated and keep the momentum going!"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ─────────────────────────────────────────
            HStack {
                Spacer()
                if currentPage < pages.count - 1 {
                    Button("Skip") { onDismiss() }
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            Spacer()

            // ── Carousel ───────────────────────────────────────
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            .frame(maxHeight: 440)

            // ── Page dots ──────────────────────────────────────
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentPage ? Color.indigo : Color.secondary.opacity(0.35))
                        .frame(width: idx == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.top, 12)

            Spacer()

            // ── CTA Button ─────────────────────────────────────
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onDismiss()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .interactiveDismissDisabled()  // must tap Get Started or Skip
    }
}

// ── Single onboarding page ─────────────────────────────────────────────────

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: page.icon)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(page.iconColor)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    OnboardingView { }
}
