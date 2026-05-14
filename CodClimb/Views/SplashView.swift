import SwiftUI

// MARK: - SplashView
// Translated from codclimb_splash.tsx
// Sequence: logo in → 3 phrases → loading dots → fade to dark → dismiss

struct SplashView: View {
    @Binding var isShowing: Bool

    // Timing matches TSX: t0=300ms, t1=1200, t2=2800, t3=4600, t4=6800, t5=7600
    @State private var logoVisible    = false
    @State private var phraseIdx      = -1
    @State private var fadingOut      = false
    @State private var entered        = false

    // River shimmer offset
    @State private var shimmerOffset: CGFloat = 0
    // Sun pulse
    @State private var sunPulse: CGFloat = 1.0
    // Bird positions (3 birds, each with an x offset cycling 0→1)
    @State private var bird0: CGFloat = -0.15
    @State private var bird1: CGFloat = -0.15
    @State private var bird2: CGFloat = -0.15

    private let phrases: [(text: String, fontSize: CGFloat, bold: Bool, color: Color)] = [
        ("Climbing life.",               26, true,  Color(red:1, green:0.9, blue:0.4)),
        ("Live condition & community.",  20, false, Color.white.opacity(0.92)),
        ("Embraced with nature.",        22, false, Color.white.opacity(0.92)),
    ]

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Scale factor so scene coords (375×812) fit the screen
            let sx = W / 375
            let sy = H / 812

            ZStack {
                // ── Background scene ──────────────────────────────────────
                Canvas { ctx, size in
                    drawScene(ctx: ctx, W: W, H: H, sx: sx, sy: sy)
                }
                .ignoresSafeArea()

                // ── Logo + Wordmark (top) ─────────────────────────────────
                VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        // Mini icon badge
                        MiniIconView()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)

                        // Wordmark
                        HStack(spacing: 0) {
                            Text("Cod")
                                .foregroundStyle(Color(red:1, green:0.9, blue:0.4))
                            Text("Climb")
                                .foregroundStyle(.white)
                        }
                        .font(.system(size: 38, weight: .medium))
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                    }
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.82)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.3), value: logoVisible)
                    .padding(.top, 72)

                    Spacer()

                    // ── Phrases ──────────────────────────────────────────
                    VStack(spacing: 10) {
                        ForEach(0..<3) { i in
                            Text(phrases[i].text)
                                .font(.system(size: phrases[i].fontSize,
                                              weight: phrases[i].bold ? .medium : .regular))
                                .foregroundStyle(phrases[i].color)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                                .opacity(phraseIdx >= i ? 1 : 0)
                                .offset(y: phraseIdx >= i ? 0 : 18)
                                .animation(
                                    .interpolatingSpring(stiffness: 200, damping: 20),
                                    value: phraseIdx
                                )
                        }

                        // Loading dots (appear after phrase 3)
                        if phraseIdx >= 2 {
                            HStack(spacing: 8) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(Color.white.opacity(0.75))
                                        .frame(width: 7, height: 7)
                                        .scaleEffect(dotScale(index: i))
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.2),
                                            value: phraseIdx
                                        )
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 200)
                }

                // ── Bottom tagline ────────────────────────────────────────
                VStack {
                    Spacer()
                    Text("CODCLIMB · BETA")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .tracking(2)
                        .padding(.bottom, 60)
                }

                // ── Fade-to-dark overlay ──────────────────────────────────
                if entered {
                    Color(red: 0.051, green: 0.122, blue: 0.051)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 12) {
                                HStack(spacing: 0) {
                                    Text("Cod").foregroundStyle(Color(red:1,green:0.9,blue:0.4))
                                    Text("Climb").foregroundStyle(.white)
                                }
                                .font(.system(size: 22, weight: .medium))
                                Text("Loading your conditions…")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                    .tracking(1)
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

    // MARK: - Scene drawing

    private func drawScene(ctx: GraphicsContext, W: CGFloat, H: CGFloat, sx: CGFloat, sy: CGFloat) {
        func x(_ v: CGFloat) -> CGFloat { v * sx }
        func y(_ v: CGFloat) -> CGFloat { v * sy }
        func pt(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: x(px), y: y(py)) }
        func poly(_ coords: [(CGFloat,CGFloat)]) -> Path {
            var p = Path(); p.move(to: pt(coords[0].0, coords[0].1))
            for c in coords.dropFirst() { p.addLine(to: pt(c.0, c.1)) }; p.closeSubpath(); return p
        }

        // Sky gradient layers
        ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)), with:.color(Color(red:0.788,green:0.310,blue:0.071)))
        ctx.fill(Path(CGRect(x:0,y:0,width:W,height:y(340))), with:.color(Color(red:0.878,green:0.447,blue:0.102).opacity(0.85)))
        ctx.fill(Path(CGRect(x:0,y:0,width:W,height:y(200))), with:.color(Color(red:0.961,green:0.627,blue:0.188).opacity(0.72)))
        ctx.fill(Path(CGRect(x:0,y:0,width:W,height:y(100))), with:.color(Color(red:1,green:0.753,blue:0.376).opacity(0.45)))

        // Sun
        let sunX = x(188), sunY = y(155)
        ctx.fill(Path(ellipseIn: CGRect(x:sunX-x(52*sunPulse*1.1),y:sunY-x(52*sunPulse*1.1),width:x(104*sunPulse*1.1),height:x(104*sunPulse*1.1))),
                 with:.color(Color(red:1,green:0.898,blue:0.4).opacity(0.06)))
        ctx.fill(Path(ellipseIn: CGRect(x:sunX-x(52),y:sunY-x(52),width:x(104),height:x(104))),
                 with:.color(Color(red:1,green:0.898,blue:0.4).opacity(0.18)))
        ctx.fill(Path(ellipseIn: CGRect(x:sunX-x(52),y:sunY-x(52),width:x(104),height:x(104))),
                 with:.color(Color(red:1,green:0.898,blue:0.4).opacity(0.95)))

        // Birds (flying across screen via bird0/1/2 offset)
        func drawBird(_ offset: CGFloat, _ baseY: CGFloat, _ span: CGFloat) {
            let bx = offset * (W + x(80)) - x(40)
            var bp = Path()
            bp.move(to: CGPoint(x:bx, y:y(baseY)))
            bp.addQuadCurve(to: CGPoint(x:bx+x(span/2),y:y(baseY-7)),
                            control: CGPoint(x:bx+x(span/4),y:y(baseY-5)))
            bp.move(to: CGPoint(x:bx+x(span/2),y:y(baseY-7)))
            bp.addQuadCurve(to: CGPoint(x:bx+x(span),y:y(baseY)),
                            control: CGPoint(x:bx+x(span*3/4),y:y(baseY-5)))
            ctx.stroke(bp, with:.color(Color(red:0.392,green:0.196,blue:0.039).opacity(0.7)),
                       style: StrokeStyle(lineWidth:x(1.8), lineCap:.round))
        }
        drawBird(bird0, 118, 24); drawBird(bird1, 98, 20); drawBird(bird2, 136, 18)

        // Far hazy mountains
        ctx.fill(poly([(0,460),(60,340),(115,390),(162,330),(210,372),(258,318),(305,360),(352,325),(400,358),(445,330),(490,355),(530,340),(530,480),(0,480)]),
                 with:.color(Color(red:0.545,green:0.227,blue:0.059).opacity(0.42)))
        // Mid mountains
        ctx.fill(poly([(0,530),(55,415),(108,462),(150,400),(200,448),(250,390),(300,438),(348,385),(398,432),(448,394),(500,428),(530,408),(530,560),(0,560)]),
                 with:.color(Color(red:0.478,green:0.180,blue:0.031)))
        ctx.fill(poly([(0,540),(55,432),(105,468),(148,412),(198,460),(248,408),(298,452),(346,402),(396,448),(446,410),(500,442),(530,424),(530,560),(0,560)]),
                 with:.color(Color(red:0.557,green:0.220,blue:0.063)))
        // Main mountain peak — raised to y:195 so spike reaches near the sun
        ctx.fill(poly([(118,560),(188,195),(258,560)]), with:.color(Color(red:0.353,green:0.118,blue:0.020)))
        ctx.fill(poly([(188,195),(258,560),(228,560)]), with:.color(Color(red:0.239,green:0.071,blue:0.012).opacity(0.52)))
        // Crack
        var crack = Path(); crack.move(to:pt(188,213))
        for cp in [(184,250),(190,300),(185,370),(189,430),(186,490)] as [(CGFloat,CGFloat)] {
            crack.addLine(to: pt(cp.0,cp.1))
        }
        ctx.stroke(crack, with:.color(Color(red:0.165,green:0.051,blue:0.008).opacity(0.45)),
                   style:StrokeStyle(lineWidth:x(1.5)))

        // Trees left
        let treesL: [(CGFloat,CGFloat,CGFloat)] = [(62,490,34),(76,498,34),(50,500,34),(90,495,36),(104,502,36)]
        for (tx,ty,th) in treesL {
            ctx.fill(poly([(tx-14,ty),(tx,ty-th),(tx+14,ty)]),
                     with:.color(Color(red:0.102,green:0.361,blue:0.102)))
        }
        // Trees right
        let treesR: [(CGFloat,CGFloat,CGFloat)] = [(268,490,34),(282,498,34),(254,500,34),(296,495,36),(310,502,36)]
        for (tx,ty,th) in treesR {
            ctx.fill(poly([(tx-14,ty),(tx,ty-th),(tx+14,ty)]),
                     with:.color(Color(red:0.133,green:0.420,blue:0.133)))
        }

        // River
        ctx.fill(Path(CGRect(x:0,y:y(505),width:W,height:y(30))),
                 with:.color(Color(red:0.102,green:0.310,blue:0.478).opacity(0.9)))
        // River shimmer lines (animated offset)
        for (ly, dashOffset): (CGFloat, CGFloat) in [(514, shimmerOffset), (522, shimmerOffset * 0.75)] {
            var rp = Path()
            var cx2: CGFloat = dashOffset.truncatingRemainder(dividingBy: x(60)) - x(60)
            while cx2 < W {
                rp.move(to: CGPoint(x:cx2, y:y(ly)))
                rp.addLine(to: CGPoint(x:cx2+x(40), y:y(ly)))
                cx2 += x(60)
            }
            ctx.stroke(rp, with:.color(Color(red:0.353,green:0.690,blue:0.910).opacity(0.45)),
                       style:StrokeStyle(lineWidth:x(2), lineCap:.round))
        }
        ctx.fill(Path(CGRect(x:0,y:y(500),width:W,height:y(6))),
                 with:.color(Color(red:0.353,green:0.188,blue:0.082).opacity(0.55)))
        ctx.fill(Path(CGRect(x:0,y:y(533),width:W,height:y(8))),
                 with:.color(Color(red:0.051,green:0.165,blue:0.271).opacity(0.6)))
        ctx.fill(Path(CGRect(x:0,y:y(540),width:W,height:H-y(540))),
                 with:.color(Color(red:0.051,green:0.122,blue:0.051)))

        // Rope anchor dot — sits just below the mountain peak
        ctx.fill(Path(ellipseIn: CGRect(x:x(196)-x(4),y:y(209)-x(4),width:x(8),height:x(8))),
                 with:.color(Color(red:0.816,green:0.784,blue:0.690).opacity(0.9)))
        // Rope curve — from anchor near peak down to climber's harness
        var rope = Path()
        rope.move(to:pt(196,209))
        rope.addCurve(to:pt(183,400),
                      control1:pt(193,270), control2:pt(185,365))
        ctx.stroke(rope, with:.color(Color(red:0.910,green:0.847,blue:0.627).opacity(0.9)),
                   style:StrokeStyle(lineWidth:x(2.5), lineCap:.round))

        // ── Climber ───────────────────────────────────────────────────────
        drawClimber(ctx: ctx, x: x, y: y, pt: pt)
    }

    private func drawClimber(ctx: GraphicsContext,
                              x: (CGFloat)->CGFloat,
                              y: (CGFloat)->CGFloat,
                              pt: (CGFloat,CGFloat)->CGPoint) {
        let lw = StrokeStyle(lineWidth: x(7), lineCap: .round)
        let lw2 = StrokeStyle(lineWidth: x(6), lineCap: .round)
        let armW = StrokeStyle(lineWidth: x(5.5), lineCap: .round)
        let arm2W = StrokeStyle(lineWidth: x(5), lineCap: .round)

        // Left leg
        var p = Path(); p.move(to:pt(183,415)); p.addLine(to:pt(176,438))
        ctx.stroke(p, with:.color(Color(red:0.290,green:0.353,blue:0.478)), style:lw)
        var p2 = Path(); p2.move(to:pt(176,438)); p2.addLine(to:pt(171,452))
        ctx.stroke(p2, with:.color(Color(red:0.290,green:0.353,blue:0.478)), style:lw2)
        // Left foot shoe
        drawShoe(ctx:ctx, cx:x(170), cy:y(455), angleDeg:195, x:x, y:y)

        // Right leg (high step)
        var p3 = Path(); p3.move(to:pt(183,415)); p3.addLine(to:pt(188,400))
        ctx.stroke(p3, with:.color(Color(red:0.290,green:0.353,blue:0.478)), style:lw)
        var p4 = Path(); p4.move(to:pt(188,400)); p4.addLine(to:pt(193,408))
        ctx.stroke(p4, with:.color(Color(red:0.290,green:0.353,blue:0.478)), style:lw2)
        // Right foot shoe
        drawShoe(ctx:ctx, cx:x(194), cy:y(411), angleDeg:30, x:x, y:y)

        // Torso (red jacket)
        var torso = Path()
        torso.addRoundedRect(in: CGRect(x:x(175),y:y(395),width:x(16),height:y(24)),
                             cornerSize: CGSize(width:x(5),height:x(5)))
        var tc = ctx
        tc.translateBy(x: pt(183,407).x, y: pt(183,407).y)
        tc.rotate(by: .degrees(-14))
        tc.translateBy(x: -pt(183,407).x, y: -pt(183,407).y)
        tc.fill(torso, with:.color(Color(red:0.816,green:0.251,blue:0.125)))

        // Chalk bag
        var cb = Path()
        cb.addEllipse(in: CGRect(x:x(183),y:y(409),width:x(14),height:y(11)))
        var cc = ctx
        cc.translateBy(x: pt(190,414).x, y: pt(190,414).y)
        cc.rotate(by: .degrees(-14))
        cc.translateBy(x: -pt(190,414).x, y: -pt(190,414).y)
        cc.fill(cb, with:.color(Color(red:0.541,green:0.439,blue:0.376).opacity(0.9)))

        // Left arm lower
        var la1 = Path(); la1.move(to:pt(178,402)); la1.addLine(to:pt(169,415))
        ctx.stroke(la1, with:.color(Color(red:0.753,green:0.659,blue:0.533)), style:armW)
        var la2 = Path(); la2.move(to:pt(169,415)); la2.addLine(to:pt(166,426))
        ctx.stroke(la2, with:.color(Color(red:0.753,green:0.659,blue:0.533)), style:arm2W)
        // Left hand
        drawHand(ctx:ctx, cx:x(165), cy:y(429), angleDeg:250, x:x, y:y,
                 color:Color(red:0.784,green:0.659,blue:0.502))

        // Right arm high
        var ra1 = Path(); ra1.move(to:pt(185,399)); ra1.addLine(to:pt(191,378))
        ctx.stroke(ra1, with:.color(Color(red:0.753,green:0.659,blue:0.533)), style:armW)
        var ra2 = Path(); ra2.move(to:pt(191,378)); ra2.addLine(to:pt(196,366))
        ctx.stroke(ra2, with:.color(Color(red:0.753,green:0.659,blue:0.533)), style:arm2W)
        // Right hand
        drawHand(ctx:ctx, cx:x(197), cy:y(363), angleDeg:75, x:x, y:y,
                 color:Color(red:0.784,green:0.659,blue:0.502))

        // Hold for right hand
        var hold = Path()
        hold.addRoundedRect(in: CGRect(x:x(192),y:y(360),width:x(18),height:y(5)),
                            cornerSize: CGSize(width:x(2),height:x(2)))
        ctx.fill(hold, with:.color(Color(red:0.478,green:0.376,blue:0.314).opacity(0.9)))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x:x(170),y:y(380),width:x(20),height:y(20))),
                 with:.color(Color(red:0.910,green:0.784,blue:0.596)))
        // Helmet
        var helm = Path()
        helm.addArc(center:pt(180,390), radius:x(11),
                    startAngle:.degrees(200), endAngle:.degrees(340), clockwise:false)
        ctx.stroke(helm, with:.color(.white.opacity(0.92)), style:StrokeStyle(lineWidth:x(5), lineCap:.round))
        var helmBrim = Path()
        helmBrim.move(to:pt(169,389)); helmBrim.addLine(to:pt(176,392))
        ctx.stroke(helmBrim, with:.color(.gray.opacity(0.7)), style:StrokeStyle(lineWidth:x(3)))

        // Harness
        ctx.fill(Path(ellipseIn: CGRect(x:x(179),y:y(405),width:x(8),height:y(8))),
                 with:.color(Color(red:0.847,green:0.800,blue:0.565)))

        // Eye (single, side-profile facing right-upward)
        ctx.fill(Path(ellipseIn: CGRect(x:x(182),y:y(385),width:x(3),height:y(3))),
                 with:.color(Color(red:0.18,green:0.12,blue:0.08).opacity(0.9)))

        // Smile
        var smile = Path()
        smile.addArc(center:pt(182, 395), radius:x(3),
                     startAngle:.degrees(15), endAngle:.degrees(165), clockwise:false)
        ctx.stroke(smile, with:.color(Color(red:0.18,green:0.12,blue:0.08).opacity(0.8)),
                   style:StrokeStyle(lineWidth:x(1.4), lineCap:.round))
    }

    // MARK: - Hand shape (simple rotated palm — clean, no finger bumps)
    private func drawHand(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                          angleDeg: Double, x: (CGFloat)->CGFloat, y: (CGFloat)->CGFloat,
                          color: Color) {
        let a = Angle.degrees(angleDeg)
        let palmW = x(10), palmH = x(7)
        var palm = Path()
        palm.addEllipse(in: CGRect(x:cx-palmW/2, y:cy-palmH/2, width:palmW, height:palmH))
        var pc = ctx
        pc.translateBy(x: cx, y: cy)
        pc.rotate(by: a)
        pc.translateBy(x: -cx, y: -cy)
        pc.fill(palm, with:.color(color))
    }

    // MARK: - Improved shoe shape (elongated toe + sole)
    private func drawShoe(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                          angleDeg: Double, x: (CGFloat)->CGFloat, y: (CGFloat)->CGFloat) {
        let a = angleDeg * .pi / 180
        let shoeLen = x(16), shoeH = x(8)
        // Heel
        let heelX = cx - cos(a) * shoeLen * 0.38
        let heelY = cy - sin(a) * shoeLen * 0.38
        // Toe (wider)
        let toeX = cx + cos(a) * shoeLen * 0.62
        let toeY = cy + sin(a) * shoeLen * 0.62

        var shoe = Path()
        shoe.addEllipse(in: CGRect(x:heelX - shoeH*0.55, y:heelY - shoeH*0.55,
                                    width:shoeH*1.1, height:shoeH*1.1))
        shoe.addEllipse(in: CGRect(x:toeX - shoeH*0.75, y:toeY - shoeH*0.75,
                                    width:shoeH*1.5, height:shoeH*1.2))
        // Fill between with convex hull (approx)
        let perp = a + .pi/2
        shoe.move(to:CGPoint(x:heelX+cos(perp)*shoeH*0.55, y:heelY+sin(perp)*shoeH*0.55))
        shoe.addLine(to:CGPoint(x:toeX+cos(perp)*shoeH*0.75, y:toeY+sin(perp)*shoeH*0.75))
        shoe.addLine(to:CGPoint(x:toeX-cos(perp)*shoeH*0.75, y:toeY-sin(perp)*shoeH*0.75))
        shoe.addLine(to:CGPoint(x:heelX-cos(perp)*shoeH*0.55, y:heelY-sin(perp)*shoeH*0.55))
        shoe.closeSubpath()
        ctx.fill(shoe, with:.color(Color(red:0.2,green:0.2,blue:0.2)))

        // Sole line
        var sole = Path()
        sole.move(to:CGPoint(x:heelX+cos(perp)*shoeH*0.55, y:heelY+sin(perp)*shoeH*0.55))
        sole.addLine(to:CGPoint(x:toeX+cos(perp)*shoeH*0.75, y:toeY+sin(perp)*shoeH*0.75))
        ctx.stroke(sole, with:.color(Color(red:0.1,green:0.1,blue:0.1)),
                   style:StrokeStyle(lineWidth:x(2.5), lineCap:.round))
    }

    // MARK: - Animation sequence

    private func startSequence() {
        // Birds continuously cycle (each with different period/delay)
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { bird0 = 1.15 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { bird1 = 1.15 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) { bird2 = 1.15 }
        }
        // River shimmer
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            shimmerOffset = 60
        }
        // Sun pulse
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            sunPulse = 1.08
        }
        // Logo in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { logoVisible = true }
        // Phrases
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { phraseIdx = 0 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { withAnimation { phraseIdx = 1 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) { withAnimation { phraseIdx = 2 } }
        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8) { fadingOut = true }
        // Dark overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.2) { withAnimation { entered = true } }
        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.6) {
            withAnimation { isShowing = false }
        }
    }

    private func dotScale(index: Int) -> CGFloat {
        phraseIdx >= 2 ? 1.0 : 0.6
    }
}

// MARK: - Mini Icon Badge (matches the icon design: sunset + mountain + climber)

private struct MiniIconView: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func x(_ v: CGFloat) -> CGFloat { v * w / 80 }
            func y(_ v: CGFloat) -> CGFloat { v * h / 80 }
            func pt(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x:x(px),y:y(py)) }
            func poly(_ c: [(CGFloat,CGFloat)]) -> Path {
                var p = Path(); p.move(to:pt(c[0].0,c[0].1))
                for cc in c.dropFirst() { p.addLine(to:pt(cc.0,cc.1)) }; p.closeSubpath(); return p
            }
            // Sky
            ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)), with:.color(Color(red:0.788,green:0.310,blue:0.071)))
            ctx.fill(Path(CGRect(x:0,y:0,width:w,height:y(36))), with:.color(Color(red:0.961,green:0.627,blue:0.188).opacity(0.65)))
            // Sun
            ctx.fill(Path(ellipseIn:CGRect(x:x(26),y:y(14),width:x(28),height:y(28))),
                     with:.color(Color(red:1,green:0.898,blue:0.4).opacity(0.95)))
            // Birds
            for (bx,by) in [(CGFloat(18),CGFloat(22)),(55,18),(62,26)] as [(CGFloat,CGFloat)] {
                var bp = Path(); bp.move(to:pt(bx,by))
                bp.addQuadCurve(to:pt(bx+3.5,by-3),control:pt(bx+1.5,by-2))
                bp.move(to:pt(bx+3.5,by-3))
                bp.addQuadCurve(to:pt(bx+7,by),control:pt(bx+5,by-2))
                ctx.stroke(bp, with:.color(Color(red:0.392,green:0.188,blue:0.020).opacity(0.6)),
                           style:StrokeStyle(lineWidth:x(1), lineCap:.round))
            }
            // Mountains
            ctx.fill(poly([(0,56),(22,40),(40,50),(60,36),(80,48),(80,80),(0,80)]),
                     with:.color(Color(red:0.478,green:0.180,blue:0.031)))
            ctx.fill(poly([(10,80),(40,30),(70,80)]), with:.color(Color(red:0.353,green:0.118,blue:0.020)))
            ctx.fill(poly([(40,30),(70,80),(58,80)]), with:.color(Color(red:0.239,green:0.071,blue:0.012).opacity(0.5)))
            // Trees
            for (tx,ty) in [(CGFloat(4),CGFloat(74)),(14,76),(50,74),(60,76),(70,74)] as [(CGFloat,CGFloat)] {
                ctx.fill(poly([(tx-7,ty),(tx,ty-18),(tx+7,ty)]),
                         with:.color(Color(red:0.102,green:0.420,blue:0.102)))
            }
            // River
            ctx.fill(Path(CGRect(x:0,y:y(74),width:w,height:y(6))),
                     with:.color(Color(red:0.102,green:0.310,blue:0.478).opacity(0.9)))
            // Rope
            var rope = Path(); rope.move(to:pt(41,34)); rope.addLine(to:pt(38,56))
            ctx.stroke(rope, with:.color(Color(red:0.910,green:0.847,blue:0.627)),
                       style:StrokeStyle(lineWidth:x(1.5), lineCap:.round))
            // Climber (tiny)
            var torso = Path()
            torso.addRoundedRect(in:CGRect(x:x(35),y:y(52),width:x(5),height:y(9)),
                                 cornerSize:CGSize(width:x(2),height:x(2)))
            var tc = ctx
            tc.translateBy(x: pt(37,56).x, y: pt(37,56).y)
            tc.rotate(by: .degrees(-12))
            tc.translateBy(x: -pt(37,56).x, y: -pt(37,56).y)
            tc.fill(torso, with:.color(Color(red:0.816,green:0.251,blue:0.125)))
            // Legs
            var ll = Path(); ll.move(to:pt(38,60)); ll.addLine(to:pt(35,68))
            ctx.stroke(ll, with:.color(Color(red:0.290,green:0.353,blue:0.478)),
                       style:StrokeStyle(lineWidth:x(2.5), lineCap:.round))
            var rl = Path(); rl.move(to:pt(38,60)); rl.addLine(to:pt(41,54))
            ctx.stroke(rl, with:.color(Color(red:0.290,green:0.353,blue:0.478)),
                       style:StrokeStyle(lineWidth:x(2.5), lineCap:.round))
            // Arms
            var la = Path(); la.move(to:pt(36,54)); la.addLine(to:pt(33,60))
            ctx.stroke(la, with:.color(Color(red:0.753,green:0.659,blue:0.533)),
                       style:StrokeStyle(lineWidth:x(2), lineCap:.round))
            var ra = Path(); ra.move(to:pt(37,53)); ra.addLine(to:pt(40,47))
            ctx.stroke(ra, with:.color(Color(red:0.753,green:0.659,blue:0.533)),
                       style:StrokeStyle(lineWidth:x(2), lineCap:.round))
            // Head
            ctx.fill(Path(ellipseIn:CGRect(x:x(33),y:y(44),width:x(8),height:y(8))),
                     with:.color(Color(red:0.910,green:0.784,blue:0.596)))
            // Helmet
            var helm = Path()
            helm.addArc(center:pt(37,48), radius:x(5),
                        startAngle:.degrees(200), endAngle:.degrees(340), clockwise:false)
            ctx.stroke(helm, with:.color(.white.opacity(0.9)),
                       style:StrokeStyle(lineWidth:x(2.5), lineCap:.round))
        }
    }
}
