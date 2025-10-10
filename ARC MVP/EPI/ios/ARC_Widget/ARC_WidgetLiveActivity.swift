//
//  ARC_WidgetLiveActivity.swift
//  ARC_Widget
//
//  Created by Marc Yap on 10/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ARC_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ARC_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ARC_WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ARC_WidgetAttributes {
    fileprivate static var preview: ARC_WidgetAttributes {
        ARC_WidgetAttributes(name: "World")
    }
}

extension ARC_WidgetAttributes.ContentState {
    fileprivate static var smiley: ARC_WidgetAttributes.ContentState {
        ARC_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ARC_WidgetAttributes.ContentState {
         ARC_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ARC_WidgetAttributes.preview) {
   ARC_WidgetLiveActivity()
} contentStates: {
    ARC_WidgetAttributes.ContentState.smiley
    ARC_WidgetAttributes.ContentState.starEyes
}
