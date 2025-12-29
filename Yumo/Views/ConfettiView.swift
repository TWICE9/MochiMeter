
import SwiftUI

struct ConfettiView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let timeAlive = now - particle.creationDate
                    if timeAlive < particle.duration {
                        // Simple physics: Start at top, fall down with gravity accel
                        // y = y0 + v0*t + 0.5*g*t^2. v0=0. g=400 approx pixels/sec^2?
                        let gravity = 500.0
                        let y = particle.y + (0.5 * gravity * timeAlive * timeAlive)
                        let x = particle.x + (particle.drift * timeAlive)
                        let rotation = particle.rotationSpeed * timeAlive
                        
                        var innerContext = context
                        innerContext.translateBy(x: x, y: y)
                        innerContext.rotate(by: .degrees(rotation))
                                                
                        innerContext.fill(
                            Path(roundedRect: CGRect(x: -4, y: -8, width: 8, height: 16), cornerRadius: 2),
                            with: .color(particle.color)
                        )
                    }
                }
            }
        }
        .onAppear {
            createParticles()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    
    private func createParticles() {
        let width = UIScreen.main.bounds.width
        for _ in 0..<100 {
            particles.append(Particle(x: Double.random(in: 0...width)))
        }
    }
}

struct Particle {
    let creationDate = Date().timeIntervalSinceReferenceDate
    let x: Double
    let y: Double = -100
    let drift: Double = Double.random(in: -100...100)
    let rotationSpeed: Double = Double.random(in: -720...720)
    let duration: Double = Double.random(in: 2...5)
    let color: Color = [.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan].randomElement()!
}
