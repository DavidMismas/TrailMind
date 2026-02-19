import Foundation

enum MemorySafeCollections {
    static func downsampleRoute(_ points: [LocationPoint], to limit: Int) -> [LocationPoint] {
        guard limit > 1, points.count > limit else { return points }

        let stride = Double(points.count - 1) / Double(limit - 1)
        var sampled: [LocationPoint] = []
        sampled.reserveCapacity(limit)

        for index in 0..<limit {
            let sourceIndex = Int((Double(index) * stride).rounded())
            sampled.append(points[min(sourceIndex, points.count - 1)])
        }

        return sampled
    }

    static func mergeSegments(_ segments: [TrailSegment], to limit: Int) -> [TrailSegment] {
        guard limit > 0, segments.count > limit else { return segments }

        let bucketSize = Int(ceil(Double(segments.count) / Double(limit)))
        var merged: [TrailSegment] = []
        merged.reserveCapacity(limit)

        var index = 0
        while index < segments.count {
            let end = min(index + bucketSize, segments.count)
            let bucket = Array(segments[index..<end])
            merged.append(merge(bucket))
            index = end
        }

        return merged
    }

    private static func merge(_ bucket: [TrailSegment]) -> TrailSegment {
        guard let first = bucket.first, let last = bucket.last else {
            return TrailSegment(
                startedAt: .now,
                endedAt: .now,
                duration: 0,
                distance: 0,
                elevationGain: 0,
                slopePercent: 0,
                averageSpeed: 0,
                heartRate: 0,
                cadence: 0,
                terrain: .flat
            )
        }

        let duration = bucket.reduce(0) { $0 + $1.duration }
        let distance = bucket.reduce(0) { $0 + $1.distance }
        let elevationGain = bucket.reduce(0) { $0 + $1.elevationGain }
        let weightedHeartRate = weightedAverage(bucket.map { ($0.heartRate, $0.duration) })
        let weightedCadence = weightedAverage(bucket.map { ($0.cadence, $0.duration) })
        let terrain = dominantTerrain(in: bucket)

        let slopePercent = weightedAverage(
            bucket.map { segment in
                (segment.slopePercent, max(segment.distance, 1))
            }
        )

        let averageSpeed = duration > 0 ? distance / duration : 0

        return TrailSegment(
            startedAt: first.startedAt,
            endedAt: last.endedAt,
            duration: duration,
            distance: distance,
            elevationGain: elevationGain,
            slopePercent: slopePercent,
            averageSpeed: averageSpeed,
            heartRate: weightedHeartRate,
            cadence: weightedCadence,
            terrain: terrain
        )
    }

    private static func weightedAverage(_ items: [(value: Double, weight: Double)]) -> Double {
        let totalWeight = items.reduce(0) { $0 + max(0, $1.weight) }
        guard totalWeight > 0 else { return 0 }
        let weightedSum = items.reduce(0) { $0 + $1.value * max(0, $1.weight) }
        return weightedSum / totalWeight
    }

    private static func dominantTerrain(in bucket: [TrailSegment]) -> TerrainType {
        var score: [TerrainType: Double] = [:]
        for segment in bucket {
            score[segment.terrain, default: 0] += max(segment.duration, 1)
        }
        return score.max(by: { $0.value < $1.value })?.key ?? .flat
    }
}
