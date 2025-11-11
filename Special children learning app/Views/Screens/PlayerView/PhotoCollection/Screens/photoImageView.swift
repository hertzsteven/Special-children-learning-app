//
//  photoImageView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/21/25.
//

import SwiftUI

extension MockPhotoCollectionView {
    func thePhotoView() -> some View {
        Image(uiImage: photos[currentIndex])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        
//                    .contentTransition(.opacity)
//                    .animation(.easeInOut(duration: 0.28), value: currentIndex)
            .scaleEffect(isBouncing ? 1.25 : 1.0)
//                    .animation(.spring(response: 1.22, dampingFraction: 0.6), value: isBouncing)
    }
    
    
    func triggerTapAnimation() {
        isBouncing = true
        withAnimation(.spring(response: 2.22, dampingFraction: 0.6)) {
            isBouncing = false
        }
        
        showRipple = true
        rippleScale = 0.5
        rippleOpacity = 0.6
        withAnimation(.easeOut(duration: 0.55)) {
            rippleScale = 1.6
            rippleOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showRipple = false
        }
    }

}
