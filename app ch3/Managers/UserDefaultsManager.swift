//
//  UserDefaultsManager.swift
//  app ch3
//
//  Gestisce la persistenza di preferiti, visitati e filtri categorie
//

import Foundation

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let favoritesKey = "favoritePlaceIDs"
    private let visitedKey = "visitedPlaceIDs"
    private let selectedCategoriesKey = "selectedCategories"
    
    private init() {}
    
    // MARK: - Preferiti
    
    func getFavorites() -> Set<Int64> {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let ids = try? JSONDecoder().decode(Set<Int64>.self, from: data) {
            return ids
        }
        return []
    }
    
    func saveFavorites(_ ids: Set<Int64>) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
    
    func addFavorite(_ id: Int64) {
        var favorites = getFavorites()
        favorites.insert(id)
        saveFavorites(favorites)
    }
    
    func removeFavorite(_ id: Int64) {
        var favorites = getFavorites()
        favorites.remove(id)
        saveFavorites(favorites)
    }
    
    func isFavorite(_ id: Int64) -> Bool {
        getFavorites().contains(id)
    }
    
    // MARK: - Visitati
    
    func getVisited() -> Set<Int64> {
        if let data = UserDefaults.standard.data(forKey: visitedKey),
           let ids = try? JSONDecoder().decode(Set<Int64>.self, from: data) {
            return ids
        }
        return []
    }
    
    func saveVisited(_ ids: Set<Int64>) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: visitedKey)
        }
    }
    
    func addVisited(_ id: Int64) {
        var visited = getVisited()
        visited.insert(id)
        saveVisited(visited)
    }
    
    func removeVisited(_ id: Int64) {
        var visited = getVisited()
        visited.remove(id)
        saveVisited(visited)
    }
    
    func isVisited(_ id: Int64) -> Bool {
        getVisited().contains(id)
    }
    
    func toggleVisited(_ id: Int64) {
        if isVisited(id) {
            removeVisited(id)
        } else {
            addVisited(id)
        }
    }
    
    // MARK: - Categorie selezionate
    
    func getSelectedCategories() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: selectedCategoriesKey),
           let categories = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return categories
        }
        return []
    }
    
    func saveSelectedCategories(_ categories: Set<String>) {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: selectedCategoriesKey)
        }
    }
}
