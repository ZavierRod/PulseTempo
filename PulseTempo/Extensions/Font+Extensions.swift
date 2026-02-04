//
//  Font+Extensions.swift
//  PulseTempo
//
//  Created by AI Assistant on 2/3/26.
//

import SwiftUI

extension Font {
    // MARK: - Custom Font: Bebas Neue
    
    /// Base function to create Bebas Neue font with custom size
    static func bebasNeue(size: CGFloat) -> Font {
        return .custom("BebasNeue-Regular", size: size)
    }
    
    // MARK: - Predefined Sizes
    
    /// Extra large display font (72pt) - Used for large metrics like BPM
    static var bebasNeueDisplay: Font {
        return bebasNeue(size: 72)
    }
    
    /// Large font (60pt) - Used for large headers and icons
    static var bebasNeueExtraLarge: Font {
        return bebasNeue(size: 60)
    }
    
    /// Large font (40pt) - Used for headings
    static var bebasNeueLarge: Font {
        return bebasNeue(size: 40)
    }
    
    /// Medium-large font (30pt) - Used for section headers
    static var bebasNeueMediumLarge: Font {
        return bebasNeue(size: 30)
    }
    
    /// Medium font (28pt) - Used for subheadings
    static var bebasNeueMedium: Font {
        return bebasNeue(size: 28)
    }
    
    /// Title font (22pt) - Used for titles
    static var bebasNeueTitle: Font {
        return bebasNeue(size: 22)
    }
    
    /// Body font (18pt) - Used for regular text
    static var bebasNeueBody: Font {
        return bebasNeue(size: 18)
    }
    
    /// Small body (17pt) - Used for secondary text
    static var bebasNeueBodySmall: Font {
        return bebasNeue(size: 17)
    }
    
    /// Subheadline (16pt) - Used for subheadings
    static var bebasNeueSubheadline: Font {
        return bebasNeue(size: 16)
    }
    
    /// Caption font (14pt) - Used for small text
    static var bebasNeueCaption: Font {
        return bebasNeue(size: 14)
    }
    
    /// Small caption font (12pt) - Used for very small text
    static var bebasNeueCaptionSmall: Font {
        return bebasNeue(size: 12)
    }
}
