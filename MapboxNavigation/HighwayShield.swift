import UIKit

enum HighwayShield {
    enum RoadClass: String {
        case alternate, duplex, business, truck, bypass, b
        case oneB = "1b", twoA = "2a", twoB = "2b"
    }
    
    enum RoadType: RawRepresentable {
        typealias RawValue = String
        typealias RoadTypeForLocaleRoadClassClosure = (Locale, RoadClass?) -> RoadType
        typealias RoadTypeForLocaleClosure = (Locale) -> RoadType
        
        var rawValue: String {
            switch self {
            case .generic:
                return "generic"
            case let .motorway(locale):
                return "\(locale.rawValue)-motorway"
            case let .expressway(locale):
                return "\(locale.rawValue)-expressway"
            case let .state(locale, roadClass):
                guard let currentRoadClass = roadClass else { return "\(locale)-state" }
                return "\(locale.rawValue)-state-\(currentRoadClass.rawValue)"
            case let .highway(locale, roadClass):
                guard let currentRoadClass = roadClass else { return "\(locale)-highway" }
                return "\(locale.rawValue)-highway-\(currentRoadClass.rawValue)"
            case let .national(locale):
                return "\(locale.rawValue)-national"
            case let .federal(locale):
                return "\(locale.rawValue)-federal"
            case let .main(locale):
                return "\(locale.rawValue)-main"
            case let .road(locale):
                return "\(locale.rawValue)-road"
            case let .primary(locale):
                return "\(locale.rawValue)-primary"
            case let .secondary(locale):
                return "\(locale.rawValue)-secondary"
            case let .trunk(locale):
                return "\(locale.rawValue)-trunk"
            case let .regional(locale):
                return "\(locale.rawValue)-regional"
            case let .voivodeship(locale):
                return "\(locale.rawValue)-voivodeship"
            case let .county(locale):
                return "\(locale.rawValue)-county"
            case let .communal(locale):
                return "\(locale)-communal"
            case let .interstate(locale, roadClass):
                guard let currentRoadClass = roadClass else { return "\(locale.rawValue)-interstate" }
                return "\(locale.rawValue)-interstate-\(currentRoadClass.rawValue)"
            case let .metropolitan(locale):
                return "\(locale.rawValue)-metropolitan"
            case let .provincial(locale):
                return "\(locale.rawValue)-provincial"
            }
        }
        
        init?(rawValue: RawValue) {
            let fields = rawValue.split(separator: "-").compactMap(String.init(_:))
            switch fields.count {
            case 1 where rawValue == "default":
                self = .generic
            case 2:
                guard let roadType = RoadType.type(for: fields.last!),
                      let locale = Locale(rawValue: fields.first!) else {
                    return nil
                }
                self = roadType(locale, nil)
            case 3:
                guard let roadType = RoadType.type(for: fields[1]),
                      let locale = Locale(rawValue: fields[0]), let roadClass = RoadClass(rawValue: fields[2]) else {
                    return nil
                }
                self = roadType(locale, roadClass)
            default:
                return nil
            }
        }
        
        private static func type(for identifier: String) -> RoadTypeForLocaleRoadClassClosure? {
            switch identifier {
            case "motorway":
                self.localeOnlyTransform(RoadType.motorway)
            case "expressway":
                self.localeOnlyTransform(RoadType.expressway)
            case "national":
                self.localeOnlyTransform(RoadType.national)
            case "federal":
                self.localeOnlyTransform(RoadType.federal)
            case "main":
                self.localeOnlyTransform(RoadType.main)
            case "road":
                self.localeOnlyTransform(RoadType.road)
            case "primary":
                self.localeOnlyTransform(RoadType.primary)
            case "secondary":
                self.localeOnlyTransform(RoadType.secondary)
            case "trunk":
                self.localeOnlyTransform(RoadType.trunk)
            case "regional":
                self.localeOnlyTransform(RoadType.regional)
            case "voivodeship":
                self.localeOnlyTransform(RoadType.voivodeship)
            case "county":
                self.localeOnlyTransform(RoadType.county)
            case "communal":
                self.localeOnlyTransform(RoadType.communal)
            case "provincial":
                self.localeOnlyTransform(RoadType.provincial)
            case "metropolitan":
                self.localeOnlyTransform(RoadType.metropolitan)
            case "state":
                RoadType.state
            case "highway":
                RoadType.highway
            case "interstate":
                RoadType.interstate
            default:
                nil
            }
        }
        
        static func localeOnlyTransform(_ closure: @escaping RoadTypeForLocaleClosure) -> RoadTypeForLocaleRoadClassClosure {
            { locale, _ in
                closure(locale)
            }
        }
        
        var textColor: UIColor? {
            switch self {
            case let .highway(locale, _):
                if locale == .slovakia {
                    return .white
                }
                return .black
            case .generic, .communal, .voivodeship, .trunk, .primary, .secondary:
                return .black
            case .motorway, .expressway, .road, .interstate:
                return .white
            case let .state(locale, roadClass):
                switch locale {
                case .austria, .croatia, .newZealand,
                     .serbia where roadClass == RoadClass.oneB:
                    return .white
                default:
                    return .black
                }
            case .regional, .metropolitan, .provincial:
                return .yellow
            case let .county(locale):
                if locale == .romania {
                    return .white
                }
                return .black
            case let .main(locale):
                if locale == .slovenia {
                    return .black
                }
                return .white
            case let .national(locale):
                switch locale {
                case .southAfrica:
                    return .yellow
                case .poland, .romania, .greece, .bulgeria:
                    return .white
                default:
                    return .black
                }
            default:
                return nil
            }
        }
        
        case generic, motorway(Locale), expressway(Locale), state(Locale, RoadClass?), highway(Locale, RoadClass?)
        case national(Locale), federal(Locale), main(Locale), road(Locale), primary(Locale), secondary(Locale), trunk(Locale), regional(Locale)
        case voivodeship(Locale), county(Locale), communal(Locale), interstate(Locale, RoadClass?), metropolitan(Locale), provincial(Locale)
    }
    
    enum Locale: String {
        case austria = "at", bulgeria = "bg", brazil = "br", switzerland = "ch", czech = "cz", germany = "de", denmark = "dk", finland = "fi", greece = "gr", croatia = "hr", hungary = "hu", india = "in", mexico = "mx", newZealand = "nz", peru = "pe", poland = "pl", romania = "ro", serbia = "rs", sweden = "se", slovenia = "si", slovakia = "sk", usa = "us", southAfrica = "za", e
    }
}
