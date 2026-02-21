//
//  ARC_WidgetBundle.swift
//  ARC_Widget
//
//  Created by Marc Yap on 10/10/25.
//

import WidgetKit
import SwiftUI

@main
struct ARC_WidgetBundle: WidgetBundle {
    var body: some Widget {
        ARC_Widget()
        ARC_WidgetControl()
        ARC_WidgetLiveActivity()
    }
}
