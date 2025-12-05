//
//  PlaceDetailView.swift
//  app ch3
//
//  Full details view for a secret place - Redesigned
//

import SwiftUI
import CoreLocation
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let userLocation: CLLocationCoordinate2D?
    @ObservedObject var viewModel: PlacesViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isFavorite: Bool = false
    @State private var isVisited: Bool = false
    
    private var distanceString: String? {
        guard let userLocation = userLocation,
              let placeCoordinate = place.coordinate else {
            return nil
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let placeCLLocation = CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: placeCLLocation)
        let distanceInKm = distanceInMeters / 1000.0
        
        if distanceInKm < 1 {
            return String(format: "%.0f m", distanceInMeters)
        } else {
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Image with Parallax effect
                GeometryReader { geometry in
                    let minY = geometry.frame(in: .global).minY
                    
                    if let imageUrl = place.image_cover ?? place.thumbnail_url,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height + (minY > 0 ? minY : 0))
                                    .clipped()
                                    .offset(y: minY > 0 ? -minY : 0)
                            case .empty, .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                    }
                }
                .frame(height: 300)
                
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(place.displayName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                isFavorite.toggle()
                                viewModel.toggleFavorite(place.id)
                            } label: {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isFavorite ? .red : .gray)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        
                        if let subtitle = place.subtitle {
                            Text(subtitle)
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 16) {
                            if let location = place.fullLocation {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            if let dist = distanceString {
                                Label(dist, systemImage: "figure.walk")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            if let coordinate = place.coordinate {
                                openInMaps(coordinate: coordinate)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                Text("Directions")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            isVisited.toggle()
                            viewModel.toggleVisited(place.id)
                        } label: {
                            HStack {
                                Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                                Text(isVisited ? "Visited" : "Mark Visited")
                            }
                            .font(.headline)
                            .foregroundColor(isVisited ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isVisited ? Color.green : Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Description
                    if let description = place.description {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }
                    
                    // Directions Text
                    if let directions = place.directions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Getting There")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(directions)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Reviews Placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Reviews")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("Coming soon")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<3) { _ in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                            VStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 10)
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 40, height: 8)
                                            }
                                        }
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 40)
                                    }
                                    .padding()
                                    .frame(width: 200)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                }
                .padding(20)
                .background(Color.appBackground)
                // Corner radius for the content sheet effect
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .offset(y: -20) // Overlap with image
            }
        }
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
        .onAppear {
            isFavorite = viewModel.isFavorite(place.id)
            isVisited = viewModel.isVisited(place.id)
        }
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = place.displayName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// Extension for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
