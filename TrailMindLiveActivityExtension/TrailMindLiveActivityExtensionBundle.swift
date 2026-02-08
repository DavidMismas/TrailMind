//
//  TrailMindLiveActivityExtensionBundle.swift
//  TrailMindLiveActivityExtension
//
//  Created by David Mišmaš on 8. 2. 26.
//

import WidgetKit
import SwiftUI

@main
struct TrailMindLiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        TrailMindLiveActivityExtension()
        TrailMindLiveActivityExtensionLiveActivity()
    }
}
