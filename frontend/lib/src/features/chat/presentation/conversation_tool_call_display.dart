import 'dart:convert';

import 'package:ling/src/features/chat/application/conversation_entry.dart';
import 'package:ling/src/features/chat/application/tool_call_result_mapper.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

enum LingToolCallDisplayVariant {
  hidden,
  loading,
  calendarMutation,
  travelFlightCandidates,
  travelHotelCandidates,
  weatherForecast,
}

enum LingToolCallCardType {
  calendarMutation,
  travelFlightCandidates,
  travelHotelCandidates,
  weatherForecast,
}

enum LingToolCallCardAction {
  none,
  openCalendarEvent,
}

class LingToolCallCardProfile {
  const LingToolCallCardProfile({
    required this.type,
    required this.presentationKey,
    required this.defaultExpanded,
    required this.priority,
    this.action = LingToolCallCardAction.none,
  });

  final LingToolCallCardType type;
  final String presentationKey;
  final bool defaultExpanded;
  final int priority;
  final LingToolCallCardAction action;

  bool get canOpen => action != LingToolCallCardAction.none;
}

class LingCalendarToolCallData {
  const LingCalendarToolCallData({
    required this.eventId,
    required this.functionName,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.startAt,
    required this.endAt,
    required this.timeShape,
    required this.timezone,
    required this.location,
    required this.metadataMarkdown,
  });

  final String eventId;
  final String functionName;
  final String title;
  final String subtitle;
  final String category;
  final String startAt;
  final String endAt;
  final String timeShape;
  final String timezone;
  final String location;
  final String metadataMarkdown;

  bool get isCreate => functionName == 'calendar_create_event';
  bool get isComplete => functionName == 'calendar_complete_event';
  bool get isDelete => functionName == 'calendar_delete_event';
}

class LingTravelFlightToolCallData {
  const LingTravelFlightToolCallData({
    required this.presentationKey,
    required this.title,
    required this.subtitle,
    required this.flights,
  });

  final String presentationKey;
  final String title;
  final String subtitle;
  final List<LingTravelFlightCandidate> flights;
}

class LingTravelFlightCandidate {
  const LingTravelFlightCandidate({
    required this.summary,
    required this.cabins,
    required this.airline,
    required this.flightNo,
    required this.departureTime,
    required this.arrivalTime,
    required this.routeLabel,
    required this.durationLabel,
    required this.aircraftLabel,
    required this.priceLabel,
    required this.cabinLabels,
  });

  final String summary;
  final List<String> cabins;
  final String airline;
  final String flightNo;
  final String departureTime;
  final String arrivalTime;
  final String routeLabel;
  final String durationLabel;
  final String aircraftLabel;
  final String priceLabel;
  final List<String> cabinLabels;
}

class LingTravelHotelToolCallData {
  const LingTravelHotelToolCallData({
    required this.presentationKey,
    required this.title,
    required this.subtitle,
    required this.hotels,
  });

  final String presentationKey;
  final String title;
  final String subtitle;
  final List<LingTravelHotelCandidate> hotels;
}

class LingTravelHotelCandidate {
  const LingTravelHotelCandidate({
    required this.name,
    required this.summary,
    required this.priceLabel,
    required this.meta,
  });

  final String name;
  final String summary;
  final String priceLabel;
  final List<String> meta;
}

class LingWeatherToolCallData {
  const LingWeatherToolCallData({
    required this.presentationKey,
    required this.city,
    required this.province,
    required this.reportTime,
    required this.forecasts,
  });

  final String presentationKey;
  final String city;
  final String province;
  final String reportTime;
  final List<LingWeatherForecastDay> forecasts;
}

class LingWeatherForecastDay {
  const LingWeatherForecastDay({
    required this.date,
    required this.week,
    required this.dayWeather,
    required this.nightWeather,
    required this.dayTemp,
    required this.nightTemp,
    required this.dayWind,
    required this.nightWind,
    required this.dayPower,
    required this.nightPower,
  });

  final String date;
  final String week;
  final String dayWeather;
  final String nightWeather;
  final String dayTemp;
  final String nightTemp;
  final String dayWind;
  final String nightWind;
  final String dayPower;
  final String nightPower;
}

class LingToolCallDisplayState {
  const LingToolCallDisplayState({
    required this.variant,
    this.cardProfile,
    this.calendarData,
    this.travelFlightData,
    this.travelHotelData,
    this.weatherData,
  });

  const LingToolCallDisplayState.hidden()
    : variant = LingToolCallDisplayVariant.hidden,
      cardProfile = null,
      calendarData = null,
      travelFlightData = null,
      travelHotelData = null,
      weatherData = null;

  const LingToolCallDisplayState.loading()
    : variant = LingToolCallDisplayVariant.loading,
      cardProfile = null,
      calendarData = null,
      travelFlightData = null,
      travelHotelData = null,
      weatherData = null;

  factory LingToolCallDisplayState.calendarMutation(
    LingCalendarToolCallData data,
  ) {
    return LingToolCallDisplayState(
      variant: LingToolCallDisplayVariant.calendarMutation,
      cardProfile: LingToolCallCardProfile(
        type: LingToolCallCardType.calendarMutation,
        presentationKey: 'calendar:${data.eventId}',
        defaultExpanded: true,
        priority: 100,
        action: data.isDelete
            ? LingToolCallCardAction.none
            : LingToolCallCardAction.openCalendarEvent,
      ),
      calendarData: data,
    );
  }

  factory LingToolCallDisplayState.travelFlightCandidates(
    LingTravelFlightToolCallData data,
  ) {
    return LingToolCallDisplayState(
      variant: LingToolCallDisplayVariant.travelFlightCandidates,
      cardProfile: LingToolCallCardProfile(
        type: LingToolCallCardType.travelFlightCandidates,
        presentationKey: data.presentationKey,
        defaultExpanded: true,
        priority: 80,
      ),
      travelFlightData: data,
    );
  }

  factory LingToolCallDisplayState.travelHotelCandidates(
    LingTravelHotelToolCallData data,
  ) {
    return LingToolCallDisplayState(
      variant: LingToolCallDisplayVariant.travelHotelCandidates,
      cardProfile: LingToolCallCardProfile(
        type: LingToolCallCardType.travelHotelCandidates,
        presentationKey: data.presentationKey,
        defaultExpanded: true,
        priority: 80,
      ),
      travelHotelData: data,
    );
  }

  factory LingToolCallDisplayState.weatherForecast(
    LingWeatherToolCallData data,
  ) {
    return LingToolCallDisplayState(
      variant: LingToolCallDisplayVariant.weatherForecast,
      cardProfile: LingToolCallCardProfile(
        type: LingToolCallCardType.weatherForecast,
        presentationKey: data.presentationKey,
        defaultExpanded: true,
        priority: 75,
      ),
      weatherData: data,
    );
  }

  final LingToolCallDisplayVariant variant;
  final LingToolCallCardProfile? cardProfile;
  final LingCalendarToolCallData? calendarData;
  final LingTravelFlightToolCallData? travelFlightData;
  final LingTravelHotelToolCallData? travelHotelData;
  final LingWeatherToolCallData? weatherData;

  String? get presentationKey => cardProfile?.presentationKey;

  bool get collapsedByDefault => !(cardProfile?.defaultExpanded ?? false);

  bool get hasCard => cardProfile != null;
}

LingToolCallDisplayState buildLingToolCallDisplayState(
  LingConversationEntry entry,
) {
  if (entry.entryType != LingConversationEntryType.toolCall) {
    return const LingToolCallDisplayState.hidden();
  }
  if (entry.isStreaming || entry.status == 'running') {
    return const LingToolCallDisplayState.hidden();
  }

  final functionName =
      resolveLingToolCallResultFunctionName(entry.toolResult) ?? entry.toolName;
  switch (functionName) {
    case 'calendar_create_event':
    case 'calendar_update_event':
    case 'calendar_complete_event':
    case 'calendar_delete_event':
      final data = parseLingCalendarToolCallData(
        functionName: functionName!,
        toolResult: entry.toolResult,
      );
      if (data == null) {
        return const LingToolCallDisplayState.hidden();
      }
      return LingToolCallDisplayState.calendarMutation(data);
    case 'travel_flight_search':
      final data = parseLingTravelFlightToolCallData(
        toolArguments: entry.toolArguments,
        toolResult: entry.toolResult,
      );
      if (data == null) {
        return const LingToolCallDisplayState.hidden();
      }
      return LingToolCallDisplayState.travelFlightCandidates(data);
    case 'travel_hotel_search':
      final data = parseLingTravelHotelToolCallData(
        toolArguments: entry.toolArguments,
        toolResult: entry.toolResult,
      );
      if (data == null) {
        return const LingToolCallDisplayState.hidden();
      }
      return LingToolCallDisplayState.travelHotelCandidates(data);
    case 'location_weather_query':
      final data = parseLingWeatherToolCallData(
        toolArguments: entry.toolArguments,
        toolResult: entry.toolResult,
      );
      if (data == null) {
        return const LingToolCallDisplayState.hidden();
      }
      return LingToolCallDisplayState.weatherForecast(data);
    default:
      return const LingToolCallDisplayState.hidden();
  }
}

LingWeatherToolCallData? parseLingWeatherToolCallData({
  required String? toolArguments,
  required String? toolResult,
}) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null || payload['ok'] != true) {
    return null;
  }
  final location = _locationWeatherData(payload);
  if (location == null) {
    return null;
  }
  final forecastItems = location['forecasts'];
  if (forecastItems is! List || forecastItems.isEmpty) {
    return null;
  }
  final forecast = _asStringKeyedMap(forecastItems.first);
  if (forecast == null) {
    return null;
  }
  final rawCasts = forecast['casts'];
  if (rawCasts is! List) {
    return null;
  }
  final casts = rawCasts
      .map(_parseWeatherForecastDay)
      .whereType<LingWeatherForecastDay>()
      .take(5)
      .toList(growable: false);
  if (casts.isEmpty) {
    return null;
  }
  final args = decodeLingToolCallResultPayload(toolArguments);
  final city = _normalizedString(forecast['city']) ?? '';
  final province = _normalizedString(forecast['province']) ?? '';
  final adcode =
      _normalizedString(forecast['adcode']) ??
      _normalizedString(args?['adcode']) ??
      _normalizedString(args?['city_adcode']) ??
      '';
  return LingWeatherToolCallData(
    presentationKey: _queryPresentationKey('location_weather_query', {
      'city': city,
      'province': province,
      'adcode': adcode,
      'extensions': args?['extensions'],
    }),
    city: city,
    province: province,
    reportTime: _normalizedString(forecast['reporttime']) ?? '',
    forecasts: casts,
  );
}

LingWeatherForecastDay? _parseWeatherForecastDay(Object? value) {
  final data = _asStringKeyedMap(value);
  if (data == null) {
    return null;
  }
  final date = _normalizedString(data['date']);
  if (date == null) {
    return null;
  }
  return LingWeatherForecastDay(
    date: date,
    week: _normalizedString(data['week']) ?? '',
    dayWeather: _normalizedString(data['dayweather']) ?? '',
    nightWeather: _normalizedString(data['nightweather']) ?? '',
    dayTemp: _normalizedString(data['daytemp']) ?? '',
    nightTemp: _normalizedString(data['nighttemp']) ?? '',
    dayWind: _normalizedString(data['daywind']) ?? '',
    nightWind: _normalizedString(data['nightwind']) ?? '',
    dayPower: _normalizedString(data['daypower']) ?? '',
    nightPower: _normalizedString(data['nightpower']) ?? '',
  );
}

LingTravelFlightToolCallData? parseLingTravelFlightToolCallData({
  required String? toolArguments,
  required String? toolResult,
}) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null || payload['ok'] != true) {
    return null;
  }
  final travel = _travelData(payload);
  if (travel == null) {
    return null;
  }
  final rawFlights = travel['flights'];
  if (rawFlights is! List) {
    return null;
  }
  final flights = rawFlights
      .map(_parseFlightCandidate)
      .whereType<LingTravelFlightCandidate>()
      .take(10)
      .toList(growable: false);
  if (flights.isEmpty) {
    return null;
  }
  final args = decodeLingToolCallResultPayload(toolArguments);
  final from = _normalizedString(args?['from_code']) ?? '';
  final to = _normalizedString(args?['to_code']) ?? '';
  final departDate = _normalizedString(args?['depart_date']) ?? '';
  final route = [from, to].where((item) => item.isNotEmpty).join(' -> ');
  final subtitle = [
    route,
    departDate,
  ].where((item) => item.trim().isNotEmpty).join(' · ');
  return LingTravelFlightToolCallData(
    presentationKey:
        _queryPresentationKey('travel_flight_search', <String, Object?>{
          'trip_mode': args?['trip_mode'],
          'trip_type': args?['trip_type'],
          'from': from,
          'to': to,
          'depart_date': departDate,
          'return_date': args?['return_date'],
          'flight_no': args?['flight_no'],
          'adult_count': args?['adult_count'],
          'child_count': args?['child_count'],
          'infant_count': args?['infant_count'],
          'cabin_class': args?['cabin_class'],
          'page_size': args?['page_size'],
          'sort_by': args?['sort_by'],
        }),
    title: 'flight_options',
    subtitle: subtitle,
    flights: flights,
  );
}

LingTravelFlightCandidate? _parseFlightCandidate(Object? value) {
  final data = _asStringKeyedMap(value);
  if (data == null) {
    return null;
  }
  final summary = _normalizedString(data['summary']);
  if (summary == null) {
    return null;
  }
  final parsedSummary = _parseFlightSummary(summary);
  final structuredRouteLabel = _structuredFlightRouteLabel(data);
  final rawCabins = data['cabins'];
  final cabins = rawCabins is List
      ? rawCabins
            .map(_normalizedString)
            .whereType<String>()
            .take(3)
            .toList(growable: false)
      : const <String>[];
  final cabinLabels = cabins
      .map(_localizedFlightCabinLabel)
      .where((item) => item.isNotEmpty)
      .take(3)
      .toList(growable: false);
  final priceLabel = _lowestFlightPriceLabel(cabins);
  return LingTravelFlightCandidate(
    summary: summary,
    cabins: cabins,
    airline: _normalizedString(data['airline_name']) ?? parsedSummary.airline,
    flightNo: _normalizedString(data['flight_no']) ?? parsedSummary.flightNo,
    departureTime:
        _shortFlightTime(data['dep_time']) ?? parsedSummary.departureTime,
    arrivalTime:
        _shortFlightTime(data['arr_time']) ?? parsedSummary.arrivalTime,
    routeLabel: structuredRouteLabel.isNotEmpty
        ? structuredRouteLabel
        : parsedSummary.routeLabel,
    durationLabel:
        _durationLabelFromMinutes(data['duration_minutes']) ??
        parsedSummary.durationLabel,
    aircraftLabel:
        _normalizedString(data['aircraft_type']) ?? parsedSummary.aircraftLabel,
    priceLabel: priceLabel,
    cabinLabels: cabinLabels,
  );
}

String _structuredFlightRouteLabel(Map<String, dynamic> data) {
  final departure = _structuredAirportLabel(data, prefix: 'dep');
  final arrival = _structuredAirportLabel(data, prefix: 'arr');
  if (departure.isEmpty || arrival.isEmpty) {
    return '';
  }
  return '$departure → $arrival';
}

String _structuredAirportLabel(
  Map<String, dynamic> data, {
  required String prefix,
}) {
  final name = _normalizedString(data['${prefix}_airport_name']);
  final code = _normalizedString(data['${prefix}_airport_code']);
  final terminal = _normalizedString(data['${prefix}_terminal']);
  final base = name ?? code ?? '';
  if (base.isEmpty) {
    return '';
  }
  return [
    base,
    terminal,
  ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
}

String? _shortFlightTime(Object? value) {
  final text = _normalizedString(value);
  if (text == null) {
    return null;
  }
  final match = RegExp(r'\b\d{2}:\d{2}\b').firstMatch(text);
  return match?.group(0);
}

String? _durationLabelFromMinutes(Object? value) {
  final text = _normalizedString(value);
  if (text == null) {
    return null;
  }
  final minutes = int.tryParse(text);
  if (minutes == null) {
    return null;
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours > 0 && remainder > 0) {
    return '${hours}h${remainder}m';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  return '${remainder}m';
}

({
  String airline,
  String flightNo,
  String departureTime,
  String arrivalTime,
  String routeLabel,
  String durationLabel,
  String aircraftLabel,
})
_parseFlightSummary(String summary) {
  var airline = '';
  var flightNo = '';
  var departureTime = '';
  var arrivalTime = '';
  var routeLabel = '';
  var durationLabel = '';
  var aircraftLabel = '';

  final flightNoMatch = RegExp(r'\b([A-Z0-9]{2}\d{2,4})\b').firstMatch(summary);
  if (flightNoMatch != null) {
    flightNo = flightNoMatch.group(1) ?? '';
    airline = summary.substring(0, flightNoMatch.start).trim();
  }

  final timeMatches = RegExp(r'\b\d{2}:\d{2}\b').allMatches(summary).toList();
  if (timeMatches.isNotEmpty) {
    departureTime = timeMatches.first.group(0) ?? '';
  }
  if (timeMatches.length > 1) {
    arrivalTime = timeMatches[1].group(0) ?? '';
  }

  final airportSearchText = timeMatches.length > 1
      ? summary.substring(timeMatches.first.end, timeMatches[1].start)
      : summary;
  final destinationSearchText = timeMatches.length > 1
      ? summary.substring(timeMatches[1].end)
      : summary;
  final fromAirport = _lastAirportMatch(airportSearchText);
  final toAirport = _firstAirportMatch(destinationSearchText);
  final airportMatches = [?fromAirport, ?toAirport];
  if (airportMatches.length >= 2) {
    final fromCode = airportMatches.first.code;
    final fromTerminal = airportMatches.first.terminal;
    final toCode = airportMatches[1].code;
    final toTerminal = airportMatches[1].terminal;
    final from = [
      fromCode,
      fromTerminal,
    ].where((item) => item.isNotEmpty).join(' ');
    final to = [toCode, toTerminal].where((item) => item.isNotEmpty).join(' ');
    routeLabel = '$from → $to';
  }

  final detailMatch = RegExp(r'\(([^)]*)\)').firstMatch(summary);
  final detail = detailMatch?.group(1) ?? '';
  if (detail.isNotEmpty) {
    final parts = detail.split(',').map((item) => item.trim()).toList();
    if (parts.isNotEmpty && RegExp(r'\d+h|\d+m').hasMatch(parts.first)) {
      durationLabel = parts.first;
    }
    for (final part in parts) {
      final aircraft = RegExp(
        r'aircraft:\s*([A-Za-z0-9 -]+)',
        caseSensitive: false,
      ).firstMatch(part);
      if (aircraft != null) {
        aircraftLabel = aircraft.group(1)?.trim() ?? '';
      }
    }
  }

  return (
    airline: airline,
    flightNo: flightNo,
    departureTime: departureTime,
    arrivalTime: arrivalTime,
    routeLabel: routeLabel,
    durationLabel: durationLabel,
    aircraftLabel: aircraftLabel,
  );
}

({String code, String terminal})? _firstAirportMatch(String value) {
  final matches = _airportMatches(value);
  return matches.isEmpty ? null : matches.first;
}

({String code, String terminal})? _lastAirportMatch(String value) {
  final matches = _airportMatches(value);
  return matches.isEmpty ? null : matches.last;
}

List<({String code, String terminal})> _airportMatches(String value) {
  return RegExp(r'\b([A-Z]{3})(?:\s+(T\d+|[A-Z]\d+))?\b')
      .allMatches(value)
      .map(
        (match) => (code: match.group(1) ?? '', terminal: match.group(2) ?? ''),
      )
      .where((item) => item.code.isNotEmpty)
      .toList(growable: false);
}

String _localizedFlightCabinLabel(String value) {
  final cabin = value.split(',').first.trim();
  final price = _flightPriceLabel(value);
  if (cabin.isEmpty && price.isEmpty) {
    return '';
  }
  return [cabin, price].where((item) => item.isNotEmpty).join(' ');
}

String _lowestFlightPriceLabel(List<String> cabins) {
  int? lowest;
  for (final cabin in cabins) {
    final price = _flightPrice(cabin);
    if (price == null) {
      continue;
    }
    lowest = lowest == null ? price : (price < lowest ? price : lowest);
  }
  return lowest == null ? '' : '¥$lowest';
}

String _flightPriceLabel(String value) {
  final price = _flightPrice(value);
  return price == null ? '' : '¥$price';
}

int? _flightPrice(String value) {
  final match = RegExp(
    r'from\s+CNY\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

LingTravelHotelToolCallData? parseLingTravelHotelToolCallData({
  required String? toolArguments,
  required String? toolResult,
}) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null || payload['ok'] != true) {
    return null;
  }
  final travel = _travelData(payload);
  if (travel == null) {
    return null;
  }
  final rawHotels = travel['hotels'];
  if (rawHotels is! List) {
    return null;
  }
  final hotels = rawHotels
      .map(_parseHotelCandidate)
      .whereType<LingTravelHotelCandidate>()
      .take(10)
      .toList(growable: false);
  if (hotels.isEmpty) {
    return null;
  }
  final args = decodeLingToolCallResultPayload(toolArguments);
  final destination = _normalizedString(args?['destination']) ?? '';
  final checkIn = _normalizedString(args?['check_in']) ?? '';
  final checkOut = _normalizedString(args?['check_out']) ?? '';
  final subtitle = [
    destination,
    _dateRangeLabel(checkIn, checkOut),
  ].where((item) => item.trim().isNotEmpty).join(' · ');
  return LingTravelHotelToolCallData(
    presentationKey:
        _queryPresentationKey('travel_hotel_search', <String, Object?>{
          'destination': destination,
          'check_in': checkIn,
          'check_out': checkOut,
          'adult_count': args?['adult_count'],
          'room_count': args?['room_count'],
          'page': args?['page'],
          'page_size': args?['page_size'],
          'sort_by': args?['sort_by'],
          'scene': args?['scene'],
          'adcode': args?['adcode'],
          'latitude': args?['latitude'],
          'longitude': args?['longitude'],
          'max_price': args?['max_price'],
          'min_price': args?['min_price'],
          'star_levels': args?['star_levels'],
          'min_review_score': args?['min_review_score'],
          'max_distance_km': args?['max_distance_km'],
          'breakfast_included': args?['breakfast_included'],
          'refundable': args?['refundable'],
          'has_wifi': args?['has_wifi'],
          'has_parking': args?['has_parking'],
          'hotel_brand': args?['hotel_brand'],
        }),
    title: 'Hotel options',
    subtitle: subtitle.isEmpty ? '${hotels.length} options' : subtitle,
    hotels: hotels,
  );
}

LingTravelHotelCandidate? _parseHotelCandidate(Object? value) {
  final data = _asStringKeyedMap(value);
  if (data == null) {
    return null;
  }
  final name = _normalizedString(data['hotel_name']);
  if (name == null) {
    return null;
  }
  final district = _normalizedString(data['district']);
  final businessZone = _normalizedString(data['business_zone']);
  final address = _normalizedString(data['address']);
  final summary = [district, businessZone, address]
      .where((item) => item != null && item.trim().isNotEmpty)
      .cast<String>()
      .take(2)
      .join(' · ');
  final price = _normalizedString(data['lowest_price']);
  final currency = _normalizedString(data['currency']) ?? 'CNY';
  final priceLabel = price == null ? '' : 'from $currency $price';
  final meta = <String>[];
  final star = _normalizedString(data['star_tag']);
  final score = _normalizedString(data['review_score']);
  final distance = _normalizedString(data['distance_km']);
  if (star != null) {
    meta.add(star);
  }
  if (score != null) {
    meta.add('rating $score');
  }
  if (distance != null) {
    meta.add('$distance km');
  }
  if (data['has_breakfast'] == true) {
    meta.add('breakfast');
  }
  if (data['has_wifi'] == true) {
    meta.add('Wi-Fi');
  }
  if (data['has_parking'] == true) {
    meta.add('parking');
  }
  return LingTravelHotelCandidate(
    name: name,
    summary: summary,
    priceLabel: priceLabel,
    meta: meta,
  );
}

Map<String, dynamic>? _travelData(Map<String, dynamic> payload) {
  final data = _asStringKeyedMap(payload['data']);
  if (data == null) {
    return null;
  }
  return _asStringKeyedMap(data['travel']);
}

Map<String, dynamic>? _locationWeatherData(Map<String, dynamic> payload) {
  final data = _asStringKeyedMap(payload['data']);
  if (data == null) {
    return null;
  }
  return _asStringKeyedMap(data['location']);
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String _queryPresentationKey(String toolName, Map<String, Object?> values) {
  final cleaned = <String, String>{};
  for (final entry in values.entries) {
    final normalized = _normalizedQueryValue(entry.value);
    if (normalized != null) {
      cleaned[entry.key] = normalized.toLowerCase();
    }
  }
  final encoded = jsonEncode(
    Map<String, String>.fromEntries(
      cleaned.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  );
  return '$toolName:$encoded';
}

String? _normalizedQueryValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = _normalizedString(entry.key);
      if (key == null) {
        continue;
      }
      final child = _normalizedQueryValue(entry.value);
      if (child != null) {
        normalized[key] = child;
      }
    }
    if (normalized.isEmpty) {
      return null;
    }
    return jsonEncode(
      Map<String, Object?>.fromEntries(
        normalized.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
  }
  if (value is List) {
    final normalized = value
        .map(_normalizedQueryValue)
        .whereType<String>()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return null;
    }
    return jsonEncode(normalized);
  }
  return _normalizedString(value);
}

String _dateRangeLabel(String start, String end) {
  if (start.isEmpty && end.isEmpty) {
    return '';
  }
  if (end.isEmpty) {
    return start;
  }
  if (start.isEmpty) {
    return end;
  }
  return '$start - $end';
}

bool isLingCalendarMutationToolResultEntry(ConversationEntryDto entry) {
  if (entry.entryType != 'tool_call' || entry.isStreaming) {
    return false;
  }
  if (entry.status.trim() != 'completed') {
    return false;
  }
  return isLingCalendarMutationFunctionName(
    resolveLingCalendarMutationFunctionName(
      entry.toolResult,
      fallbackToolName: entry.toolName,
    ),
  );
}

LingCalendarToolCallData? parseLingCalendarToolCallData({
  required String functionName,
  required String? toolResult,
}) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null) {
    return null;
  }
  final dataValue = payload['data'];
  final data = dataValue is Map<String, dynamic>
      ? dataValue
      : dataValue is Map
      ? Map<String, dynamic>.from(dataValue)
      : null;
  if (data == null) {
    return null;
  }
  final eventId = _normalizedString(data['event_id']);
  if (eventId == null) {
    return null;
  }
  final title = _normalizedString(data['title']);
  if (title == null && functionName != 'calendar_delete_event') {
    return null;
  }
  return LingCalendarToolCallData(
    eventId: eventId,
    functionName: functionName,
    title: title ?? '',
    subtitle: _normalizedString(data['subtitle']) ?? '',
    category: _normalizedString(data['category']) ?? '',
    startAt: _normalizedString(data['start_at']) ?? '',
    endAt: _normalizedString(data['end_at']) ?? '',
    timeShape: _normalizedString(data['time_shape']) ?? 'span',
    timezone: _normalizedString(data['timezone']) ?? '',
    location: _normalizedString(data['location']) ?? '',
    metadataMarkdown: _metadataMarkdown(data['metadata']),
  );
}

String? _normalizedString(Object? value) {
  final normalized = '$value'.trim();
  if (value == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

String _metadataMarkdown(Object? value) {
  if (value is Map<String, dynamic>) {
    return _normalizedString(value['markdown']) ?? '';
  }
  if (value is Map) {
    return _normalizedString(value['markdown']) ?? '';
  }
  return '';
}
