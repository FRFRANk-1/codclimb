// CodClimb/Views/LegalView.swift
import SwiftUI

// MARK: - LegalView

struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Terms of Use & Privacy Policy")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Last updated: May 2026")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                LegalSection(title: "1. About CodClimb") {
                    """
                    CodClimb is an independent app developed and operated by Frank Li ("developer," "I," "me"). It is not affiliated with any climbing organization, land management agency, or commercial entity.

                    By downloading or using CodClimb you agree to these terms. If you do not agree, please uninstall the app.
                    """
                }

                LegalSection(title: "2. Climbing Safety Disclaimer") {
                    """
                    Rock climbing is an inherently dangerous activity that can result in serious injury or death. The weather scores, condition reports, and information provided in this app are for informational purposes only.

                    CodClimb does not guarantee the accuracy, completeness, or timeliness of any condition data. You are solely responsible for assessing whether conditions are safe before climbing. Always use proper equipment, follow local regulations, and make your own independent judgment at the crag.
                    """
                }

                LegalSection(title: "3. Community Reports") {
                    """
                    Condition reports are submitted by app users and reflect personal observations only. CodClimb does not verify or endorse any user-submitted content. Reports may be inaccurate, outdated, or misleading.

                    By posting a report you confirm the content is your own honest observation and does not infringe on any third-party rights. I reserve the right to remove reports that are inappropriate, abusive, or spam.
                    """
                }

                LegalSection(title: "4. Data & Third-Party Services") {
                    """
                    Weather data is provided by Open-Meteo (open-meteo.com) under the Creative Commons Attribution 4.0 license. CodClimb is not responsible for errors or outages in third-party data.

                    Crag location data is independently researched and may not reflect current access restrictions, closures, or hazards. Always check with local land managers before visiting a climbing area.
                    """
                }

                LegalSection(title: "5. Privacy Policy") {
                    """
                    I take your privacy seriously. Here is what CodClimb does and does not do:

                    • Account data: If you create an account, your email address and display name are stored securely in Firebase (Google) for authentication purposes only.

                    • Usage data: CodClimb does not sell your personal data to advertisers or third parties.

                    • Condition reports: Reports you post are public and associated with your chosen display name.

                    • Push notifications: Alert preferences are stored locally on your device. If you opt in to email alerts, your email is stored only to send those alerts.

                    • Analytics: The app may collect anonymous crash reports and usage statistics to improve performance. No personally identifiable information is included.

                    You may delete your account at any time by contacting me at rlifrank18@gmail.com. Upon request I will delete your profile and associated data within 30 days.
                    """
                }

                LegalSection(title: "6. Limitation of Liability") {
                    """
                    To the fullest extent permitted by applicable law, CodClimb and its developer shall not be liable for any injury, death, property damage, or other loss arising from your use of this app or your decision to climb based on information provided herein.

                    The app is provided "as is" without warranties of any kind, expressed or implied, including but not limited to fitness for a particular purpose or accuracy of information.
                    """
                }

                LegalSection(title: "7. Changes to These Terms") {
                    """
                    I may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the revised terms. Material changes will be noted with an updated date at the top of this page.
                    """
                }

                LegalSection(title: "8. Contact") {
                    """
                    Questions about these terms or your data? Email: rlifrank18@gmail.com
                    """
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Legal section block

private struct LegalSection: View {
    let title: String
    let content: String

    init(title: String, content: () -> String) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(content)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.surface)
        )
    }
}
