//
//  CustomTopAppBar.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI

struct CustomTopAppBar: View {
    @Binding var isMenuOpen: Bool
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut) { isMenuOpen.toggle() }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                Button(action: { withAnimation { selectedTab = 0 } }) {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(selectedTab == 0 ? .white : .gray)
                        .frame(maxWidth: .infinity)
                }
                
                Button(action: { withAnimation { selectedTab = 1 } }) {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 56)
            .background(Color.black)
            
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geo.size.width / 2, height: 2)
                    .offset(x: selectedTab == 0 ? 0 : geo.size.width / 2)
                    .animation(.easeInOut, value: selectedTab)
            }
            .frame(height: 2)
            
            Divider().background(Color.gray)
        }
    }
}
