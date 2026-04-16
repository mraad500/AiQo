import Foundation

struct HealthSource: Identifiable, Hashable {
    let id: String
    let title: String
    let summaryKey: String
    let urlString: String

    var url: URL? {
        URL(string: urlString)
    }
}

enum HealthSourceLibrary {
    static let all: [HealthSource] = [
        HealthSource(
            id: "apple-healthkit",
            title: "Apple HealthKit",
            summaryKey: "health.sources.appleHealthKit.summary",
            urlString: "https://developer.apple.com/documentation/healthkit"
        ),
        HealthSource(
            id: "who-physical-activity",
            title: "WHO Physical Activity",
            summaryKey: "health.sources.who.summary",
            urlString: "https://www.who.int/news-room/fact-sheets/detail/physical-activity"
        ),
        HealthSource(
            id: "cdc-sleep",
            title: "CDC Sleep",
            summaryKey: "health.sources.cdcSleep.summary",
            urlString: "https://www.cdc.gov/sleep/"
        ),
        HealthSource(
            id: "aha-fitness",
            title: "American Heart Association",
            summaryKey: "health.sources.aha.summary",
            urlString: "https://www.heart.org/en/healthy-living/fitness"
        ),
        HealthSource(
            id: "medlineplus-nutrition",
            title: "NIH MedlinePlus Nutrition",
            summaryKey: "health.sources.medline.summary",
            urlString: "https://medlineplus.gov/nutrition.html"
        ),
        HealthSource(
            id: "acsm-activity-guidelines",
            title: "ACSM Physical Activity Guidance",
            summaryKey: "health.sources.acsm.summary",
            urlString: "https://www.acsm.org/education-resources/trending-topics-resources/physical-activity-guidelines"
        )
    ]
}
