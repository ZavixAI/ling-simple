class PhoneCountry {
  const PhoneCountry({
    required this.code,
    required this.dialCode,
    required this.label,
    required this.name,
    this.searchAliases = const [],
  });

  final String code;
  final String dialCode;
  final String label;
  final String name;
  final List<String> searchAliases;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return code.toLowerCase().contains(normalized) ||
        dialCode.toLowerCase().contains(normalized) ||
        dialCode.replaceAll('+', '').contains(normalized) ||
        label.toLowerCase().contains(normalized) ||
        name.toLowerCase().contains(normalized) ||
        searchAliases.any((alias) => alias.toLowerCase().contains(normalized));
  }
}

const List<PhoneCountry> phoneCountries = [
  PhoneCountry(
    code: 'CN',
    dialCode: '+86',
    label: 'CN +86',
    name: '中国大陆',
    searchAliases: ['China', 'Mainland China', 'zhongguo', '中国'],
  ),
  PhoneCountry(
    code: 'US',
    dialCode: '+1',
    label: 'US +1',
    name: '美国 / 加拿大',
    searchAliases: ['United States', 'Canada', 'USA', 'America', '美国', '加拿大'],
  ),
  PhoneCountry(
    code: 'HK',
    dialCode: '+852',
    label: 'HK +852',
    name: '中国香港',
    searchAliases: ['Hong Kong', '香港'],
  ),
  PhoneCountry(
    code: 'TW',
    dialCode: '+886',
    label: 'TW +886',
    name: '中国台湾',
    searchAliases: ['Taiwan', '台湾'],
  ),
  PhoneCountry(
    code: 'JP',
    dialCode: '+81',
    label: 'JP +81',
    name: '日本',
    searchAliases: ['Japan', '日本'],
  ),
  PhoneCountry(
    code: 'KR',
    dialCode: '+82',
    label: 'KR +82',
    name: '韩国',
    searchAliases: ['Korea', 'South Korea', '韩国'],
  ),
  PhoneCountry(
    code: 'SG',
    dialCode: '+65',
    label: 'SG +65',
    name: '新加坡',
    searchAliases: ['Singapore', '新加坡'],
  ),
  PhoneCountry(
    code: 'GB',
    dialCode: '+44',
    label: 'GB +44',
    name: '英国',
    searchAliases: ['United Kingdom', 'UK', 'Great Britain', '英国'],
  ),
];
