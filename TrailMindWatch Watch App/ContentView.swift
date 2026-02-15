import SwiftUI
import HealthKit
import WatchConnectivity



// MARK: - View
struct ContentView: View {
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isTracking {
                metricsView
            } else {
                startView
            }
        }
        .padding()
    }
    
    var startView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            
            Text("TrailMind")
                .font(.headline)
            
            Button(action: {
                viewModel.start()
            }) {
                Text("Start Hike")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .background(Color.green)
            .clipShape(Capsule())
        }
    }
    
    var metricsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("\(Int(viewModel.heartRate))")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.2f", viewModel.distance / 1000)) km")
                        .font(.title3)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Energy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(viewModel.energy)) kcal")
                        .font(.title3)
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.stop()
            }) {
                Text("End")
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    ContentView()
}
