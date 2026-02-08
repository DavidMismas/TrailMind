import Foundation

struct DefaultTerrainInsightService: TerrainInsightService {
    func insight(speed: Double, slopePercent: Double, cadence: Double) -> TerrainInsight {
        if slopePercent > 10 {
            return TerrainInsight(
                terrain: .climb,
                pacingAdvice: speed > 1.2 ? "Slow down slightly to protect energy." : "Good uphill pacing.",
                safetyHint: "Keep short steps and stable rhythm on steep grade."
            )
        }

        if slopePercent < -6 {
            return TerrainInsight(
                terrain: .downhill,
                pacingAdvice: "Control stride and avoid sudden acceleration.",
                safetyHint: "Downhill load stresses knees. Keep cadence balanced."
            )
        }

        if cadence < 1.25 {
            return TerrainInsight(
                terrain: .technical,
                pacingAdvice: "Use shorter, frequent steps through technical patches.",
                safetyHint: "Watch footing and maintain center of gravity."
            )
        }

        return TerrainInsight(
            terrain: .flat,
            pacingAdvice: "Maintain current rhythm.",
            safetyHint: "Hydrate early before next climb."
        )
    }
}
