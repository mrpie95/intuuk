//
//  IntuukWidgetLiveActivity.swift
//  IntuukWidget
//
//  Created by Michael Pieniazek on 14/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct IntuukWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct IntuukWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntuukWidgetAttributes.self) { context in
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

extension IntuukWidgetAttributes {
    fileprivate static var preview: IntuukWidgetAttributes {
        IntuukWidgetAttributes(name: "World")
    }
}

extension IntuukWidgetAttributes.ContentState {
    fileprivate static var smiley: IntuukWidgetAttributes.ContentState {
        IntuukWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: IntuukWidgetAttributes.ContentState {
         IntuukWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: IntuukWidgetAttributes.preview) {
   IntuukWidgetLiveActivity()
} contentStates: {
    IntuukWidgetAttributes.ContentState.smiley
    IntuukWidgetAttributes.ContentState.starEyes
}
