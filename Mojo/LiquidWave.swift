import SwiftUI

struct LiquidWave: Shape {
    var progress: CGFloat // 0.0 to 1.0, representing fill level
    var waveAmplitude: CGFloat // How tall the waves are
    var waveFrequency: CGFloat // How many waves across the width
    var phaseRadians: Double // Use Double for animatable phase

    // AnimatableData for smooth transitions
    // Now, animatableData.second will be a Double for phase, not an Angle
    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(progress, phaseRadians) }
        set {
            progress = newValue.first
            phaseRadians = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate the liquid's current height based on progress
        let liquidHeight = rect.height * progress
        let startY = rect.height - liquidHeight

        path.move(to: CGPoint(x: rect.minX, y: startY))

        // Draw the wavy top surface
        for x in stride(from: rect.minX, through: rect.maxX, by: 1) {
            let relativeX = (x / rect.width) * waveFrequency * .pi * 2
            // Use phaseRadians directly in the sine function
            let yOffset = sin(relativeX + phaseRadians) * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: startY + yOffset))
        }

        // Complete the path to form a filled shape
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct LiquidFillBoxView: View {
    @State private var fillProgress: CGFloat = 0.1
    @State private var wavePhaseRadians: Double = 0.0

    let boxWidth: CGFloat = 350
    let boxHeight: CGFloat = 120
    let boxCornerRadius: CGFloat = 15

    // MARK: - New Liquid Color (Green)
    let liquidColor: Color = Color.green // Changed to green

    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                // MARK: - The Outer Glass Box
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .fill(.ultraThinMaterial)
                    // .glassEffect(.regular, in: .roundedRectangle(cornerRadius: boxCornerRadius)) // Uncomment when on iOS 26+
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .frame(width: boxWidth, height: boxHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: boxCornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // MARK: - The Liquid Inside
                LiquidWave(progress: fillProgress, waveAmplitude: 5, waveFrequency: 2, phaseRadians: wavePhaseRadians)
                    // MARK: - More Transparent Liquid
                    .fill(liquidColor.opacity(0.4)) // Reduced opacity for more transparency
                    .frame(width: boxWidth, height: boxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: boxCornerRadius))
                    .overlay(
                        // MARK: - Enhanced Shininess/Highlight
                        RoundedRectangle(cornerRadius: boxCornerRadius)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        // Top highlight: Brighter white for shininess
                                        Color.white.opacity(0.7),
                                        // Transition colors, can lean into the liquid's green
                                        liquidColor.opacity(0.2),
                                        liquidColor.opacity(0.1),
                                        // Bottom area for subtle depth
                                        liquidColor.opacity(0.3)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5 // Slightly thicker stroke for more prominent shine
                            )
                            // Experiment with blend modes for different shine effects
                            .blendMode(.screen) // .screen or .lighten often work well for highlights
                            .mask(LiquidWave(progress: fillProgress, waveAmplitude: 5, waveFrequency: 2, phaseRadians: wavePhaseRadians))
                    )
            }
            .padding()

            Slider(value: $fillProgress, in: 0...1, step: 0.01) {
                Text("Fill Level")
            }
            .padding()

            Button("Fill/Empty") {
                withAnimation(.easeInOut(duration: 2.0)) {
                    fillProgress = (fillProgress == 0.1) ? 0.9 : 0.1
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                wavePhaseRadians = 2 * .pi
            }
        }
    }
}

// (LiquidFillBoxView_Previews struct remains the same, adjusted to show a solid background)
struct LiquidFillBoxView_Previews: PreviewProvider {
    static var previews: some View {
        // To see the box on a simple, uniform background (e.g., default Xcode background)
        LiquidFillBoxView()
    }
}
