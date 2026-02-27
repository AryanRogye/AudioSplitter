//
//  DraggableBottomSheet.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/9/26.
//

import SwiftUI

struct DraggableBottomSheet<Content: View>: View {
    @Binding var isOpen: Bool
    var areaHeight: CGFloat
    var title: String
    let collapsedHeight: CGFloat
    let content: () -> Content
    
    init(
        isOpen: Binding<Bool>,
        areaHeight: CGFloat,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isOpen = isOpen
        self.areaHeight = areaHeight
        self.title = title
        self.collapsedHeight = areaHeight / 8
        self.content = content
    }
    
    // Internal State
    @GestureState private var dragY: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 10) {
            // Grabber
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
            
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if isOpen {
                    Button {
                        withAnimation { isOpen = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            // Injected Content
            content()
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, areaHeight))
        .background(.ultraThinMaterial, in: shape)
        .overlay(
            shape.stroke(.white.opacity(0.12))
        )
        .shadow(radius: isOpen ? 0 : 20)
        .offset(y: sheetOffset)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isOpen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: dragY)
        .gesture(dragGesture)
        .onTapGesture {
            if !isOpen { isOpen = true }
        }
    }
    
    // MARK: - Styling & Math
    private var shape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 32, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 32,
            style: .continuous
        )
    }
    
    private var sheetOffset: CGFloat {
        let closedY = areaHeight - collapsedHeight
        let base = isOpen ? 0 : closedY
        return max(0, base + dragY)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragY) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let dy = value.translation.height
                let vy = value.velocity.height
                
                if isOpen {
                    if dy > 80 || vy > 600 { isOpen = false }
                } else {
                    if dy < -80 || vy < -600 { isOpen = true }
                }
            }
    }
}
