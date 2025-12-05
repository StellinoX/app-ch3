//
//  FilterView.swift
//  app ch3
//
//  Filter view with glass morphism effect
//

import SwiftUI

struct FilterView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background with blur effect
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Glass morphism card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Filters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                
                // Category list
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.availableCategories.isEmpty {
                            Text("No categories available")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.availableCategories.sorted(), id: \.self) { category in
                                CategoryFilterRow(
                                    category: category,
                                    isSelected: viewModel.selectedCategories.contains(category),
                                    action: {
                                        viewModel.toggleCategory(category)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Clear filters button
                if !viewModel.selectedCategories.isEmpty {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        Button {
                            viewModel.clearCategoryFilters()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear all filters")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                // Glass morphism effect
                ZStack {
                    Color.appBackground.opacity(0.85)
                    
                    // Blur layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 100)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Category filter row
struct CategoryFilterRow: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Checkmark circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 16, height: 16)
                    }
                }
                
                // Category name
                Text(category)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.appAccent.opacity(0.15) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterView(viewModel: PlacesViewModel())
}
