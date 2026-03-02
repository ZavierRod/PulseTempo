//
//  PulseTempoWidgetBundle.swift
//  PulseTempoWidget
//
//  Created by Zavier Rodrigues on 3/2/26.
//

import WidgetKit
import SwiftUI

@main
struct PulseTempoWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseTempoWidget()
        PulseTempoWidgetControl()
        PulseTempoWidgetLiveActivity()
    }
}
