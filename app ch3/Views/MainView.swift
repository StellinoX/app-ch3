//
//  MainView.swift
//  app ch3
//
//  Vista principale con TabView per mappa e lista
//

import SwiftUI
import MapKit

struct MainView: View {
    @StateObject private var viewModel = PlacesViewModel()
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedTab = 0
    @State private var selectedPlace: Place?
    @State private var showingDetail = false
    @State private var showingFilters = false
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "Map"
        case 1: return "List"
        case 2: return "Favorites"
        default: return "Map"
        }
    }
    
    var body: some View {
        NavigationStack {
            mainTabView
                .tint(.appAccent)
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search secret places..."
                )
                .onSubmit(of: .search) {
                    Task {
                        await viewModel.performGlobalSearch()
                    }
                }
                .navigationTitle(selectedTab == 0 ? "" : navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        filtersButton
                    }
                }
                .sheet(isPresented: $showingDetail) {
                    if let place = selectedPlace {
                        PlaceDetailView(place: place, userLocation: locationManager.location, viewModel: viewModel)
                    }
                }
                .overlay {
                    filterOverlay
                }
                .task {
                    // Initial setup
                    if locationManager.authorizationStatus == .notDetermined {
                        locationManager.requestPermission()
                    } else if locationManager.location == nil {
                        locationManager.startUpdating()
                    }
                }
        }
        .tint(.appAccent)
    }
    
    // MARK: - Subviews
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            mapTab
            listTab
            favoritesTab
        }
    }
    
    private var mapTab: some View {
        ImprovedMapView(
            viewModel: viewModel,
            locationManager: locationManager,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail
        )
        .tabItem {
            Label("Map", systemImage: "map.fill")
        }
        .tag(0)
    }
    
    private var listTab: some View {
        PlacesListView(
            viewModel: viewModel,
            userLocation: locationManager.location,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail
        )
        .tabItem {
            Label("List", systemImage: "list.bullet")
        }
        .tag(1)
    }
    
    private var favoritesTab: some View {
        FavoritesView(
            viewModel: viewModel,
            userLocation: locationManager.location,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail
        )
        .tabItem {
            Label("Favorites", systemImage: "heart.fill")
        }
        .tag(2)
    }
    
    @ViewBuilder
    private var filterOverlay: some View {
        if showingFilters {
            FilterView(viewModel: viewModel)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showingFilters = false
                    }
                }
        }
    }
    
    private var filtersButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingFilters.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body)
                Text("Filters")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.appAccent)
        }
    }
}

#Preview {
    MainView()
}
