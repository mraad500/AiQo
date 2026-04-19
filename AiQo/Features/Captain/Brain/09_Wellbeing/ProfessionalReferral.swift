import Foundation

/// Region-aware professional support resources used when the wellbeing stack
/// decides the user should be shown real-world help options.
enum ProfessionalReferral {
    struct Resource: Sendable, Equatable, Identifiable {
        let name: String
        let phone: String?
        let website: String?
        let region: Region
        let languages: [String]
        let availability: String

        var id: String {
            [
                name,
                phone ?? "",
                website ?? "",
                region.rawValue
            ].joined(separator: "|")
        }
    }

    enum Region: String, Sendable {
        case uae
        case saudi
        case iraq
        case gulfOther
        case global
    }

    nonisolated static func resources(for region: Region = detectRegion()) -> [Resource] {
        switch region {
        case .uae:
            return [
                Resource(
                    name: "MOHAP Mental Health Counselling",
                    phone: "04-5192519",
                    website: "https://u.ae/en/information-and-services/health-and-fitness/handling-the-covid-19-outbreak/maintaining-mental-health-in-times-of-covid19",
                    region: .uae,
                    languages: ["ar", "en"],
                    availability: "Sun-Thu 9:00-21:00"
                ),
                Resource(
                    name: "Estijaba / Abu Dhabi Health Support",
                    phone: "8001717",
                    website: "https://u.ae/en/information-and-services/health-and-fitness/handling-the-covid-19-outbreak/emergency-helpline-for-covid-19",
                    region: .uae,
                    languages: ["ar", "en"],
                    availability: "24/7"
                )
            ]

        case .saudi:
            return [
                Resource(
                    name: "National Center for Mental Health Promotion",
                    phone: "920033360",
                    website: "https://www.ncmh.org.sa/Contact-us",
                    region: .saudi,
                    languages: ["ar"],
                    availability: "Daily 8:00-20:00; Sat 13:00-20:00"
                )
            ]

        case .iraq:
            return [
                Resource(
                    name: "Find a Helpline Iraq",
                    phone: nil,
                    website: "https://findahelpline.com/countries/iq",
                    region: .iraq,
                    languages: ["multiple"],
                    availability: "varies"
                ),
                Resource(
                    name: "IASP Crisis Centres & Helplines",
                    phone: nil,
                    website: "https://dev.new.iasp.info/crisis-centres-helplines/",
                    region: .global,
                    languages: ["multiple"],
                    availability: "varies"
                )
            ]

        case .gulfOther, .global:
            return [
                Resource(
                    name: "Find a Helpline",
                    phone: nil,
                    website: "https://findahelpline.com",
                    region: .global,
                    languages: ["multiple"],
                    availability: "varies"
                ),
                Resource(
                    name: "IASP Crisis Centres & Helplines",
                    phone: nil,
                    website: "https://dev.new.iasp.info/crisis-centres-helplines/",
                    region: .global,
                    languages: ["multiple"],
                    availability: "varies"
                )
            ]
        }
    }

    nonisolated static func detectRegion(locale: Locale = .current) -> Region {
        let code = (locale.region?.identifier ?? "").uppercased()

        switch code {
        case "AE":
            return .uae
        case "SA":
            return .saudi
        case "IQ":
            return .iraq
        case "KW", "OM", "QA", "BH":
            return .gulfOther
        default:
            return .global
        }
    }

    nonisolated static func supportMessage(
        language: AppLanguage,
        urgency: InterventionPolicy.Decision.Urgency,
        region: Region = detectRegion()
    ) -> String {
        let emergencyLine = emergencyInstruction(language: language, region: region, urgency: urgency)
        let intro = introduction(language: language, urgency: urgency)
        let formattedResources = resources(for: region)
            .map { formatted(resource: $0, language: language) }
            .joined(separator: "\n")

        return [emergencyLine, intro, formattedResources]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    nonisolated private static func emergencyInstruction(
        language: AppLanguage,
        region: Region,
        urgency: InterventionPolicy.Decision.Urgency
    ) -> String {
        guard urgency == .immediate else { return "" }

        switch language {
        case .arabic:
            switch region {
            case .uae:
                return "إذا كنت قد تؤذي نفسك الآن أو لا تستطيع البقاء بأمان، اتصل بخدمات الطوارئ المحلية فوراً. داخل الإمارات تقدر تتصل بالإسعاف على 998."
            case .saudi:
                return "إذا كنت قد تؤذي نفسك الآن أو لا تستطيع البقاء بأمان، اتصل بخدمات الطوارئ المحلية فوراً. داخل السعودية تقدر تتصل على 937 لطلب دعم صحي عاجل."
            default:
                return "إذا كنت قد تؤذي نفسك الآن أو لا تستطيع البقاء بأمان، اتصل بخدمات الطوارئ المحلية فوراً أو تواصل مع شخص قريب منك حالاً."
            }

        case .english:
            switch region {
            case .uae:
                return "If you might act on these thoughts or cannot stay safe right now, call local emergency services immediately. In the UAE, you can call ambulance services on 998."
            case .saudi:
                return "If you might act on these thoughts or cannot stay safe right now, call local emergency services immediately. In Saudi Arabia, you can call 937 for urgent health support."
            default:
                return "If you might act on these thoughts or cannot stay safe right now, call local emergency services immediately or contact a trusted person right away."
            }
        }
    }

    nonisolated private static func introduction(
        language: AppLanguage,
        urgency: InterventionPolicy.Decision.Urgency
    ) -> String {
        switch (language, urgency) {
        case (.arabic, .immediate):
            return "تواصل مع جهة دعم مهني الآن:"
        case (.arabic, .suggested):
            return "أنصحك تتواصل اليوم مع جهة دعم مهني موثوقة:"
        case (.arabic, .informational):
            return "إذا تحب دعماً إضافياً، هذي جهات ممكن تساعدك:"
        case (.english, .immediate):
            return "Please contact a professional support service right now:"
        case (.english, .suggested):
            return "Please consider contacting a professional support service today:"
        case (.english, .informational):
            return "If extra support would help, these services may help:"
        }
    }

    nonisolated private static func formatted(resource: Resource, language: AppLanguage) -> String {
        let phoneLabel = language == .arabic ? "الهاتف" : "Phone"
        let websiteLabel = language == .arabic ? "الموقع" : "Website"
        let availabilityLabel = language == .arabic ? "التوفر" : "Availability"

        var segments: [String] = ["- \(resource.name)"]
        if let phone = resource.phone {
            segments.append("\(phoneLabel): \(phone)")
        }
        if let website = resource.website {
            segments.append("\(websiteLabel): \(website)")
        }
        segments.append("\(availabilityLabel): \(resource.availability)")
        return segments.joined(separator: " | ")
    }
}
