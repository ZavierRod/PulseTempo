//
//  InSyncLogo.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/6/26.
//

import SwiftUI

/// inSync logo component using the PNG asset
struct InSyncLogo: View {
    var size: LogoSize = .medium
    
    enum LogoSize {
        case small, medium, large
        
        var width: CGFloat {
            switch self {
            case .small: return 140
            case .medium: return 240
            case .large: return 340
            }
        }
    }
    
    var body: some View {
        Image("inSyncLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width)
    }
}

#Preview("Medium") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .medium)
    }
}

#Preview("Large") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .large)
    }
}

#Preview("Small") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .small)
    }
}
