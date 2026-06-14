import CoreLocation
import Darwin
import Foundation

enum DeviceContextSnapshotBuilder {
  static func buildSnapshot(location: CLLocation?, placemark: CLPlacemark?) -> [String: Any] {
    var payload: [String: Any] = [
      "device_model": deviceModelIdentifier(),
      "timezone": TimeZone.current.identifier
    ]

    if let location {
      payload["latitude"] = location.coordinate.latitude
      payload["longitude"] = location.coordinate.longitude
      payload["accuracy_meters"] = location.horizontalAccuracy
      payload["captured_at"] = deviceContextISOFormatter.string(from: location.timestamp)
    }

    if let placemark {
      let formattedAddress = formattedAddress(from: placemark)
      if !formattedAddress.isEmpty {
        payload["formatted_address"] = formattedAddress
      }
      if let name = placemark.name, !name.isEmpty {
        payload["name"] = name
      }
      if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
        payload["thoroughfare"] = thoroughfare
      }
      if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
        payload["sub_thoroughfare"] = subThoroughfare
      }
      if let subLocality = placemark.subLocality, !subLocality.isEmpty {
        payload["sub_locality"] = subLocality
      }
      if let locality = placemark.locality, !locality.isEmpty {
        payload["locality"] = locality
      }
      if let subAdministrativeArea = placemark.subAdministrativeArea,
        !subAdministrativeArea.isEmpty
      {
        payload["sub_administrative_area"] = subAdministrativeArea
      }
      let city = resolvedCity(from: placemark)
      if let city, !city.isEmpty {
        payload["city"] = city
      }
      if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
        payload["administrative_area"] = administrativeArea
      }
      if let postalCode = placemark.postalCode, !postalCode.isEmpty {
        payload["postal_code"] = postalCode
      }
      if let country = placemark.country, !country.isEmpty {
        payload["country"] = country
      }
      if let isoCountryCode = placemark.isoCountryCode, !isoCountryCode.isEmpty {
        payload["iso_country_code"] = isoCountryCode
      }
      let areasOfInterest = (placemark.areasOfInterest ?? []).filter { !$0.isEmpty }
      if !areasOfInterest.isEmpty {
        payload["areas_of_interest"] = areasOfInterest
      }
    }

    return payload
  }

  private static func deviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    return mirror.children.reduce(into: "") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else {
        return
      }
      identifier.append(String(UnicodeScalar(UInt8(value))))
    }
  }

  private static func formattedAddress(from placemark: CLPlacemark) -> String {
    var parts: [String] = []
    let street = [placemark.subThoroughfare, placemark.thoroughfare]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    if !street.isEmpty {
      parts.append(street)
    }
    for value in [
      placemark.subLocality,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
      placemark.postalCode,
      placemark.country,
    ] {
      let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !normalized.isEmpty && !parts.contains(normalized) {
        parts.append(normalized)
      }
    }
    return parts.joined(separator: ", ")
  }

  private static func resolvedCity(from placemark: CLPlacemark) -> String? {
    if let locality = placemark.locality, !locality.isEmpty {
      return locality
    }
    if let subAdministrativeArea = placemark.subAdministrativeArea, !subAdministrativeArea.isEmpty {
      return subAdministrativeArea
    }
    if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
      return administrativeArea
    }
    return nil
  }
}

private let deviceContextISOFormatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  return formatter
}()
