//
//  ConfirmationToast.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import SwiftUI

struct ConfirmationToast: View {
    let message: String
    let icon: String
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25))
        .shadow(radius: 10)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

// Toast modifier for easy use
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    ConfirmationToast(message: message, icon: icon)
                        .padding(.bottom, 100)
                    Spacer()
                }
                .onAppear {
                    // Auto-hide
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon))
    }
}

#Preview {
    VStack {
        Spacer()
        ConfirmationToast(message: "Video collection created with 3 videos!", icon: "checkmark.circle.fill")
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}