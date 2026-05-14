import SwiftUI

// MARK: - SplashView (v2 — forest green brand, matches new app icon)
// Sequence: logo in → 3 phrases → loading dots → fade out → dismiss

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var logoVisible  = false
    @State private var phraseIdx    = -1
    @State private var fadingOut    = false
    @State private var entered      = false

    // Subtle floating dot animation
    @State private var dotFloat: CGFloat = 0
    // Star twinkle
    @State private var twinkle: Double = 0.4

    private let phrases: [(text: String, fontSize: CGFloat, bold: Bool)] = [
        ("Climbing life.",              26, true),
        ("Live conditions & community.", 20, false),
        ("Embraced with nature.",        22, false),
    ]

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height

            ZStack {
                // ── Background gradient ───────────────────────────────────
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.14, blue: 0.04),
                        Color(red: 0.18, green: 0.35, blue: 0.12),
                        Color(red: 0.22, green: 0.42, blue: 0.15),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Static scene (stars + mountain) ──────────────────────
                Canvas { ctx, size in
                    drawScene(ctx: ctx, W: size.width, H: size.height)
                }
                .ignoresSafeArea()

                // ── Floating data dots (animated) ─────────────────────────
                Canvas { ctx, size in
                    drawDataDots(ctx: ctx, W: size.width, H: size.height, floatOffset: dotFloat)
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: dotFloat)

                // ── Logo + Wordmark ───────────────────────────────────────
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        // App icon badge
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)

                        // Wordmark
                        HStack(spacing: 0) {
                            Text("Cod")
                                .foregroundStyle(Color(red: 0.42, green: 0.75, blue: 0.27))
                            Text("Climb")
                                .foregroundStyle(.white)
                        }
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                    }
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.82)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.3), value: logoVisible)
                    .padding(.top, 80)

                    Spacer()

                    // ── Phrases ──────────────────────────────────────────
                    VStack(spacing: 12) {
                        ForEach(0..<3) { i in
                            Text(phrases[i].text)
                                .font(.system(size: phrases[i].fontSize,
                                              weight: phrases[i].bold ? .semibold : .regular,
                                              design: .rounded))
                                .foregroundStyle(
                                    i == 0
                                    ? Color(red: 0.42, green: 0.75, blue: 0.27)
                                    : Color.white.opacity(0.88)
                                )
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                                .opacity(phraseIdx >= i ? 1 : 0)
                                .offset(y: phraseIdx >= i ? 0 : 16)
                                .animation(
                                    .interpolatingSpring(stiffness: 220, damping: 22),
                                    value: phraseIdx
                                )
                        }

                        // Loading dots
                        if phraseIdx >= 2 {
                            HStack(spacing: 8) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(Color(red: 0.42, green: 0.75, blue: 0.27).opacity(0.8))
                                        .frame(width: 7, height: 7)
                                        .scaleEffect(phraseIdx >= 2 ? 1.0 : 0.6)
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.22),
                                            value: phraseIdx
                                        )
                                }
                            }
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 44)
                    .padding(.bottom, 180)
                }

                // ── Bottom tagline ────────────────────────────────────────
                VStack {
                    Spacer()
                    Text("CODCLIMB · BETA")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(3)
                        .padding(.bottom, 56)
                }

                // ── Fade-to-dark overlay ──────────────────────────────────
                if entered {
                    Color(red: 0.05, green: 0.14, blue: 0.04)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 10) {
                                HStack(spacing: 0) {
                                    Text("Cod")
                                        .foregroundStyle(Color(red: 0.42, green: 0.75, blue: 0.27))
                                    Text("Climb")
                                        .foregroundStyle(.white)
                                }
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                Text("Loading your conditions…")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .tracking(0.5)
                            }
                        }
                        .transition(.opacity)
                }
            }
            .opacity(fadingOut ? 0 : 1)
            .animation(.easeInOut(duration: 0.8), value: fadingOut)
        }
        .ignoresSafeArea()
        .onAppear { startSequence() }
    }

    // MARK: - Scene: stars + mountain peak
    private func drawScene(ctx: GraphicsContext, W: CGFloat, H: CGFloat) {
        func x(_ v: CGFloat) -> CGFloat { v * W / 375 }
        func y(_ v: CGFloat) -> CGFloat { v * H / 812 }
        func pt(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: x(px), y: y(py)) }

        // Stars
        let stars: [(CGFloat, CGFloat, CGFloat)] = [
            (40,80,1.4),(80,50,1.0),(130,70,1.6),(200,40,1.2),(260,65,1.0),
            (310,50,1.4),(350,80,1.2),(30,130,1.0),(100,120,1.6),(165,100,1.2),
            (230,115,1.0),(290,100,1.4),(340,130,1.0),(60,160,1.2),(320,155,1.0),
        ]
        for (sx, sy, sr) in stars {
            ctx.fill(
                Path(ellipseIn: CGRect(x: x(sx)-x(sr), y: y(sy)-x(sr), width: x(sr*2), height: x(sr*2))),
                with: .color(Color.white.opacity(Double.random(in: 0.4...0.75)))
            )
        }

        // Mountain silhouette — white, clean, matches icon
        func poly(_ coords: [(CGFloat, CGFloat)]) -> Path {
            var p = Path()
            p.move(to: pt(coords[0].0, coords[0].1))
            for c in coords.dropFirst() { p.addLine(to: pt(c.0, c.1)) }
            p.closeSubpath()
            return p
        }

        // Far background mountains (dark green)
        ctx.fill(
            poly([(0,580),(50,470),(100,510),(150,455),(200,490),(250,445),(300,475),(350,450),(375,465),(375,620),(0,620)]),
            with: .color(Color(red: 0.10, green: 0.22, blue: 0.08).opacity(0.7))
        )

        // Main mountain shadow (slightly darker left face)
        ctx.fill(
            poly([(188,220),(260,580),(115,580)]),
            with: .color(Color(red: 0.90, green: 0.96, blue: 0.88).opacity(0.12))
        )

        // Main mountain — bright white
        ctx.fill(
            poly([(188,220),(115,580),(260,580)]),
            with: .color(Color.white.opacity(0.92))
        )

        // Left face shadow overlay
        ctx.fill(
            poly([(188,220),(115,580),(160,580)]),
            with: .color(Color(red: 0.05, green: 0.14, blue: 0.04).opacity(0.18))
        )

        // Snow cap highlight
        ctx.fill(
            poly([(188,220),(175,265),(200,265)]),
            with: .color(Color.white)
        )

        // Summit flag pole
        var pole = Path()
        pole.move(to: pt(188, 220))
        pole.addLine(to: pt(188, 195))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.9)),
                   style: StrokeStyle(lineWidth: x(2.5), lineCap: .round))

        // Flag
        ctx.fill(
            poly([(188,195),(206,200),(188,208)]),
            with: .color(Color(red: 0.42, green: 0.75, blue: 0.27))
        )

        // Ground band
        ctx.fill(
            Path(CGRect(x: 0, y: y(590), width: W, height: H - y(590))),
            with: .color(Color(red: 0.05, green: 0.14, blue: 0.04))
        )

        // Foreground tree silhouettes
        let trees: [(CGFloat, CGFloat, CGFloat)] = [
            (30,590,45),(50,595,50),(70,590,42),(290,590,44),(310,595,50),(330,590,42),(350,592,38)
        ]
        for (tx, ty, th) in trees {
            ctx.fill(
                poly([(tx-13,ty),(tx,ty-th),(tx+13,ty)]),
                with: .color(Color(red: 0.08, green: 0.20, blue: 0.06))
            )
        }
    }

    // MARK: - Data dots (6 green dots on mountain slopes, gently floating)
    private func drawDataDots(ctx: GraphicsContext, W: CGFloat, H: CGFloat, floatOffset: CGFloat) {
        func x(_ v: CGFloat) -> CGFloat { v * W / 375 }
        func y(_ v: CGFloat) -> CGFloat { v * H / 812 }

        // positions along the mountain slopes
        let dots: [(CGFloat, CGFloat, Double)] = [
            (145, 380, 0.0),
            (160, 330, 0.3),
            (172, 290, 0.5),
            (210, 310, 0.1),
            (222, 360, 0.4),
            (235, 420, 0.2),
        ]

        for (dx, dy, phase) in dots {
            let floatY = CGFloat(sin((Double(floatOffset) + phase) * .pi)) * 4
            let radius: CGFloat = 4.5
            // Glow
            ctx.fill(
                Path(ellipseIn: CGRect(x: x(dx)-radius*2, y: y(dy)+floatY-radius*2,
                                       width: radius*4, height: radius*4)),
                with: .color(Color(red: 0.42, green: 0.75, blue: 0.27).opacity(0.18))
            )
            // Core dot
            ctx.fill(
                Path(ellipseIn: CGRect(x: x(dx)-radius, y: y(dy)+floatY-radius,
                                       width: radius*2, height: radius*2)),
                with: .color(Color(red: 0.42, green: 0.75, blue: 0.27).opacity(0.85))
            )
        }
    }

    // MARK: - Animation sequence
    private func startSequence() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            dotFloat = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)  { logoVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2)  { withAnimation { phraseIdx = 0 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8)  { withAnimation { phraseIdx = 1 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6)  { withAnimation { phraseIdx = 2 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8)  { fadingOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.2)  { withAnimation { entered = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.6)  { withAnimation { isShowing = false } }
    }
}
