//
//  PlacesViewModel.swift
//  app ch3
//
//  ViewModel per gestire il caricamento dei luoghi da Supabase
//

import Foundation
import CoreLocation
import Combine
import Supabase
import PostgREST
import MapKit

struct EquatableRegion: Equatable {
    let region: MKCoordinateRegion
    
    static func == (lhs: EquatableRegion, rhs: EquatableRegion) -> Bool {
        lhs.region.center.latitude == rhs.region.center.latitude &&
        lhs.region.center.longitude == rhs.region.center.longitude &&
        lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
        lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadedRegion: MKCoordinateRegion?
    @Published var regionToRecenter: EquatableRegion?
    @Published var searchText = ""
    @Published var clusteredItems: [MapItem] = []
    
    @Published var selectedCategories: Set<String> = []
    @Published var favoriteIDs: Set<Int64> = []
    @Published var visitedIDs: Set<Int64> = []
    @Published var favoritePlacesFull: [Place] = [] // Full Place objects for favorites
    
    private let userDefaults = UserDefaultsManager.shared
    private var loadingTask: Task<Void, Never>?
    
    init() {
        // Carica dati persistenti
        self.selectedCategories = userDefaults.getSelectedCategories()
        self.favoriteIDs = userDefaults.getFavorites()
        self.visitedIDs = userDefaults.getVisited()
    }
    
    // Tutte le categorie disponibili dai luoghi caricati
    var availableCategories: [String] {
        let allCategories = places.compactMap { $0.categoryName }
        return Array(Set(allCategories)).sorted()
    }
    
    // Filtra i luoghi per mostrare solo quelli con coordinate valide
    var validPlaces: [Place] {
        places.filter { $0.coordinate != nil && $0.hide_from_maps != "true" }
    }
    
    // Luoghi preferiti
    var favoritePlaces: [Place] {
        validPlaces.filter { favoriteIDs.contains($0.id) }
    }
    
    // Filtra i luoghi in base alla ricerca e alle categorie selezionate
    var filteredPlaces: [Place] {
        var filtered = validPlaces
        
        // Filtro per categorie se ce ne sono selezionate
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { place in
                guard let category = place.categoryName else { return false }
                return selectedCategories.contains(category)
            }
        }
        
        // Filtro per ricerca
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { place in
                // Cerca nel titolo
                if let title = place.title?.lowercased(), title.contains(searchLower) {
                    return true
                }
                
                // Cerca nel subtitle
                if let subtitle = place.subtitle?.lowercased(), subtitle.contains(searchLower) {
                    return true
                }
                
                // Cerca nella città
                if let city = place.city?.lowercased(), city.contains(searchLower) {
                    return true
                }
                
                // Cerca nel paese
                if let country = place.country?.lowercased(), country.contains(searchLower) {
                    return true
                }
                
                // Cerca nella descrizione (first 200 chars only for performance)
                if let description = place.description?.prefix(200).lowercased(), description.contains(searchLower) {
                    return true
                }
                
                return false
            }
        }
        
        return filtered
    }
    
    // MARK: - Preferiti
    
    func toggleFavorite(_ id: Int64) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
            userDefaults.removeFavorite(id)
            favoritePlacesFull.removeAll { $0.id == id }
        } else {
            favoriteIDs.insert(id)
            userDefaults.addFavorite(id)
            // Add the place to favoritePlacesFull if it exists in places
            if let place = places.first(where: { $0.id == id }) {
                favoritePlacesFull.append(place)
            }
        }
    }
    
    func isFavorite(_ id: Int64) -> Bool {
        favoriteIDs.contains(id)
    }
    
    // MARK: - Visitati
    
    func toggleVisited(_ id: Int64) {
        if visitedIDs.contains(id) {
            visitedIDs.remove(id)
            userDefaults.removeVisited(id)
        } else {
            visitedIDs.insert(id)
            userDefaults.addVisited(id)
        }
    }
    
    func isVisited(_ id: Int64) -> Bool {
        visitedIDs.contains(id)
    }
    
    // MARK: - Categorie
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        userDefaults.saveSelectedCategories(selectedCategories)
    }
    
    func clearCategoryFilters() {
        selectedCategories.removeAll()
        userDefaults.saveSelectedCategories(selectedCategories)
    }
    
    // MARK: - Data Loading
    
    /// Carica i luoghi nella regione visibile della mappa
    func fetchPlacesInRegion(_ region: MKCoordinateRegion) async {
        // Cancella il task precedente se esiste
        loadingTask?.cancel()
        
        // Evita di ricaricare se siamo ancora nella stessa regione (con margine ridotto)
        if let loadedRegion = loadedRegion {
            let latDiff = abs(loadedRegion.center.latitude - region.center.latitude)
            let lngDiff = abs(loadedRegion.center.longitude - region.center.longitude)
            let spanDiff = abs(loadedRegion.span.latitudeDelta - region.span.latitudeDelta)
            
            // Ricarica se ci siamo spostati anche poco o abbiamo zoomato
            let hasMovedSignificantly = latDiff > region.span.latitudeDelta * 0.2 || 
                                        lngDiff > region.span.longitudeDelta * 0.2
            let hasZoomedSignificantly = spanDiff > region.span.latitudeDelta * 0.3
            
            if !hasMovedSignificantly && !hasZoomedSignificantly {
                return // Ancora nella stessa area, usa la cache
            }
        }
        
        // Crea un nuovo task di caricamento
        loadingTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            // Calcola i bounds della regione con margine ridotto per seguire meglio la visuale
            let margin = 1.2 // Carica solo 20% in più per essere più preciso
            let latDelta = region.span.latitudeDelta * margin
            let lngDelta = region.span.longitudeDelta * margin
            
            let minLat = region.center.latitude - latDelta / 2
            let maxLat = region.center.latitude + latDelta / 2
            let minLng = region.center.longitude - lngDelta / 2
            let maxLng = region.center.longitude + lngDelta / 2
            
            do {
                var query = SupabaseManager.shared.client
                    .from("places")
                    .select()
                    .gte("coordinates_lat", value: minLat)
                    .lte("coordinates_lat", value: maxLat)
                    .gte("coordinates_lng", value: minLng)
                    .lte("coordinates_lng", value: maxLng)
                
                // Se c'è una ricerca attiva, filtra anche per testo
                if !searchText.isEmpty {
                    let searchStr = searchText.lowercased()
                    query = query.or("title.ilike.%\(searchStr)%,description.ilike.%\(searchStr)%,city.ilike.%\(searchStr)%")
                }
                
                let data: [Place] = try await query
                    .limit(300) // Ridotto da 500 a 300 per migliori performance
                    .execute()
                    .value
                
                // Controlla se il task è stato cancellato
                if Task.isCancelled { return }
                
                // SOSTITUISCI i luoghi invece di fare merge - mostra solo quelli nella regione visibile
                self.places = data
                self.loadedRegion = region
                print("✅ Loaded \(data.count) places in visible region")
                print("   Region: lat \(String(format: "%.2f", minLat))-\(String(format: "%.2f", maxLat)), lng \(String(format: "%.2f", minLng))-\(String(format: "%.2f", maxLng))")
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Loading error: \(error.localizedDescription)"
                    print("❌ Supabase error: \(error)")
                }
            }
            
            // Nascondi loading dopo un breve delay per evitare flickering
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondi minimo
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
    
    /// Carica tutti i luoghi dal database (da usare solo se necessario)
    func fetchAllPlaces(limit: Int = 1000) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .limit(limit)
                .execute()
                .value
            
            self.places = data
            print("✅ Loaded \(data.count) places from Supabase")
        } catch {
            self.errorMessage = "Loading error: \(error.localizedDescription)"
            print("❌ Supabase error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Carica i luoghi vicini a una coordinata specifica
    func fetchPlacesNearby(
        coordinate: CLLocationCoordinate2D,
        radiusInKm: Double = 50
    ) async {
        isLoading = true
        errorMessage = nil
        
        // Converti km in gradi approssimativamente (1 grado ≈ 111 km)
        let radiusInDegrees = radiusInKm / 111.0
        
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLng = coordinate.longitude - radiusInDegrees
        let maxLng = coordinate.longitude + radiusInDegrees
        
        do {
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .gte("coordinates_lat", value: minLat)
                .lte("coordinates_lat", value: maxLat)
                .gte("coordinates_lng", value: minLng)
                .lte("coordinates_lng", value: maxLng)
                .execute()
                .value
            
            self.places = data
            print("✅ Trovati \(data.count) luoghi vicini")
        } catch {
            self.errorMessage = "Errore nella ricerca: \(error.localizedDescription)"
            print("❌ Errore ricerca vicini: \(error)")
        }
        
        isLoading = false
    }
    
    /// Calcola la distanza di un luogo dalla posizione corrente
    func distance(from userLocation: CLLocationCoordinate2D, to place: Place) -> Double? {
        guard let placeCoordinate = place.coordinate else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let placeCLLocation = CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude)
        
        return userCLLocation.distance(from: placeCLLocation) / 1000.0 // distanza in km
    }
    
    // MARK: - Fetch Favorites
    
    func fetchFavoritePlaces() async {
        guard !favoriteIDs.isEmpty else {
            favoritePlacesFull = []
            return
        }
        
        do {
            // Build OR filter for each ID: id.eq.1,id.eq.2,id.eq.3,...
            let orFilter = favoriteIDs.map { "id.eq.\($0)" }.joined(separator: ",")
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .or(orFilter)
                .execute()
                .value
            
            self.favoritePlacesFull = data
            print("✅ Fetched \(data.count) favorite places")
        } catch {
            print("❌ Error fetching favorites: \(error)")
        }
    }
    
    // MARK: - Global Search
    
    func performGlobalSearch() async {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let query = searchText.lowercased()
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .or("title.ilike.%\(query)%,description.ilike.%\(query)%,city.ilike.%\(query)%")
                .limit(50)
                .execute()
                .value
            
            if !Task.isCancelled {
                self.places = data
                self.calculateRegionForPlaces(data)
            }
            
            print("✅ Found \(data.count) places for query: \(query)")
        } catch {
            self.errorMessage = "Search error: \(error.localizedDescription)"
            print("❌ Search error: \(error)")
        }
        
        isLoading = false
    }
    
    
    private func calculateRegionForPlaces(_ places: [Place]) {
        guard !places.isEmpty else { return }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0
        
        for place in places {
            guard let coord = place.coordinate else { continue }
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }
        
        // If only one place, use a fixed span
        if places.count == 1 {
            let center = CLLocationCoordinate2D(latitude: minLat, longitude: minLng)
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            self.regionToRecenter = EquatableRegion(region: MKCoordinateRegion(center: center, span: span))
            return
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.05)
        )
        
        self.regionToRecenter = EquatableRegion(region: MKCoordinateRegion(center: center, span: span))
    }
    
    // MARK: - Clustering
    
    func updateClusteredItems(for region: MKCoordinateRegion) {
        let places = filteredPlaces
        guard !places.isEmpty else {
            clusteredItems = []
            return
        }
        
        // Soglia di distanza per raggruppare (dipende dallo zoom)
        // Più alto è lo zoom (delta piccolo), più piccola è la soglia
        // Ridotto divisore: i pin si separano prima durante lo zoom
        let threshold = region.span.latitudeDelta / 30.0
        
        var items: [MapItem] = []
        var processedIndices = Set<Int>()
        
        for i in 0..<places.count {
            if processedIndices.contains(i) { continue }
            
            let placeA = places[i]
            guard let coordA = placeA.coordinate else { continue }
            
            var clusterPlaces: [Place] = [placeA]
            processedIndices.insert(i)
            
            // Cerca vicini
            for j in (i + 1)..<places.count {
                if processedIndices.contains(j) { continue }
                
                let placeB = places[j]
                guard let coordB = placeB.coordinate else { continue }
                
                let latDiff = abs(coordA.latitude - coordB.latitude)
                let lngDiff = abs(coordA.longitude - coordB.longitude)
                
                if latDiff < threshold && lngDiff < threshold {
                    clusterPlaces.append(placeB)
                    processedIndices.insert(j)
                }
            }
            
            if clusterPlaces.count > 1 {
                // Crea cluster
                let avgLat = clusterPlaces.reduce(0.0) { $0 + ($1.coordinate?.latitude ?? 0) } / Double(clusterPlaces.count)
                let avgLng = clusterPlaces.reduce(0.0) { $0 + ($1.coordinate?.longitude ?? 0) } / Double(clusterPlaces.count)
                let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
                
                items.append(.cluster(id: UUID().uuidString, coordinate: center, places: clusterPlaces))
            } else {
                items.append(.place(placeA))
            }
        }
        
        self.clusteredItems = items
    }
}
