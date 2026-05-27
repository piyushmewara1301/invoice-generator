class GeoData {
  static const List<String> countries = [
    'India', 'United States', 'United Kingdom', 'Australia', 'Canada',
    'Singapore', 'United Arab Emirates', 'Germany', 'France', 'Japan',
    'China', 'Bangladesh', 'Pakistan', 'Sri Lanka', 'Nepal', 'Bhutan',
    'Maldives', 'Afghanistan', 'Iran', 'Iraq', 'Saudi Arabia', 'Kuwait',
    'Qatar', 'Bahrain', 'Oman', 'Jordan', 'Lebanon', 'Israel', 'Turkey',
    'Egypt', 'South Africa', 'Nigeria', 'Kenya', 'Ethiopia', 'Ghana',
    'Tanzania', 'Uganda', 'Rwanda', 'Morocco', 'Algeria', 'Tunisia',
    'Russia', 'Ukraine', 'Poland', 'Netherlands', 'Belgium', 'Switzerland',
    'Austria', 'Sweden', 'Norway', 'Denmark', 'Finland', 'Portugal',
    'Spain', 'Italy', 'Greece', 'Czech Republic', 'Hungary', 'Romania',
    'Brazil', 'Argentina', 'Chile', 'Colombia', 'Peru', 'Venezuela',
    'Mexico', 'New Zealand', 'Indonesia', 'Malaysia', 'Thailand',
    'Vietnam', 'Philippines', 'South Korea', 'Taiwan', 'Hong Kong',
    'Myanmar', 'Cambodia', 'Laos', 'Mongolia', 'Kazakhstan', 'Uzbekistan',
  ];

  static const Map<String, List<String>> _states = {
    'India': [
      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
      'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
      'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
      'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
      'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
      'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
      'Andaman and Nicobar Islands', 'Chandigarh',
      'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
      'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
    ],
    'United States': [
      'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
      'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
      'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana',
      'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
      'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
      'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
      'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon',
      'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
      'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
      'Washington D.C.', 'West Virginia', 'Wisconsin', 'Wyoming',
    ],
    'United Kingdom': [
      'England', 'Scotland', 'Wales', 'Northern Ireland',
    ],
    'Australia': [
      'Australian Capital Territory', 'New South Wales', 'Northern Territory',
      'Queensland', 'South Australia', 'Tasmania', 'Victoria',
      'Western Australia',
    ],
    'Canada': [
      'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
      'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
      'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
      'Saskatchewan', 'Yukon',
    ],
    'United Arab Emirates': [
      'Abu Dhabi', 'Ajman', 'Dubai', 'Fujairah', 'Ras Al Khaimah',
      'Sharjah', 'Umm Al Quwain',
    ],
    'Germany': [
      'Baden-Württemberg', 'Bavaria', 'Berlin', 'Brandenburg', 'Bremen',
      'Hamburg', 'Hesse', 'Lower Saxony', 'Mecklenburg-Vorpommern',
      'North Rhine-Westphalia', 'Rhineland-Palatinate', 'Saarland',
      'Saxony', 'Saxony-Anhalt', 'Schleswig-Holstein', 'Thuringia',
    ],
    'France': [
      'Auvergne-Rhône-Alpes', 'Bourgogne-Franche-Comté', 'Bretagne',
      'Centre-Val de Loire', 'Corse', 'Grand Est', 'Hauts-de-France',
      'Île-de-France', 'Normandie', 'Nouvelle-Aquitaine', 'Occitanie',
      'Pays de la Loire', "Provence-Alpes-Côte d'Azur",
    ],
    'Japan': [
      'Aichi', 'Akita', 'Aomori', 'Chiba', 'Ehime', 'Fukui', 'Fukuoka',
      'Fukushima', 'Gifu', 'Gunma', 'Hiroshima', 'Hokkaido', 'Hyogo',
      'Ibaraki', 'Ishikawa', 'Iwate', 'Kagawa', 'Kagoshima', 'Kanagawa',
      'Kochi', 'Kumamoto', 'Kyoto', 'Mie', 'Miyagi', 'Miyazaki',
      'Nagano', 'Nagasaki', 'Nara', 'Niigata', 'Oita', 'Okayama',
      'Okinawa', 'Osaka', 'Saga', 'Saitama', 'Shiga', 'Shimane',
      'Shizuoka', 'Tochigi', 'Tokushima', 'Tokyo', 'Tottori', 'Toyama',
      'Wakayama', 'Yamagata', 'Yamaguchi', 'Yamanashi',
    ],
    'China': [
      'Anhui', 'Beijing', 'Chongqing', 'Fujian', 'Gansu', 'Guangdong',
      'Guangxi', 'Guizhou', 'Hainan', 'Hebei', 'Heilongjiang', 'Henan',
      'Hong Kong', 'Hubei', 'Hunan', 'Inner Mongolia', 'Jiangsu',
      'Jiangxi', 'Jilin', 'Liaoning', 'Macau', 'Ningxia', 'Qinghai',
      'Shaanxi', 'Shandong', 'Shanghai', 'Shanxi', 'Sichuan', 'Tianjin',
      'Tibet', 'Xinjiang', 'Yunnan', 'Zhejiang',
    ],
    'Malaysia': [
      'Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Labuan', 'Malacca',
      'Negeri Sembilan', 'Pahang', 'Penang', 'Perak', 'Perlis',
      'Putrajaya', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu',
    ],
    'Indonesia': [
      'Aceh', 'Bali', 'Bangka Belitung', 'Banten', 'Bengkulu',
      'Central Java', 'Central Kalimantan', 'Central Sulawesi',
      'East Java', 'East Kalimantan', 'East Nusa Tenggara',
      'Gorontalo', 'Jakarta', 'Jambi', 'Lampung', 'Maluku',
      'North Kalimantan', 'North Maluku', 'North Sulawesi',
      'North Sumatra', 'Papua', 'Riau', 'Riau Islands',
      'South Kalimantan', 'South Sulawesi', 'South Sumatra',
      'Southeast Sulawesi', 'West Java', 'West Kalimantan',
      'West Nusa Tenggara', 'West Papua', 'West Sulawesi',
      'West Sumatra', 'Yogyakarta',
    ],
    'Pakistan': [
      'Azad Kashmir', 'Balochistan', 'Gilgit-Baltistan',
      'Islamabad Capital Territory', 'Khyber Pakhtunkhwa', 'Punjab', 'Sindh',
    ],
    'Bangladesh': [
      'Barisal', 'Chittagong', 'Dhaka', 'Khulna', 'Mymensingh',
      'Rajshahi', 'Rangpur', 'Sylhet',
    ],
    'Sri Lanka': [
      'Central', 'Eastern', 'North Central', 'North Western', 'Northern',
      'Sabaragamuwa', 'Southern', 'Uva', 'Western',
    ],
    'Saudi Arabia': [
      'Al Bahah', 'Al Jawf', 'Al Madinah', 'Al Qassim', 'Asir',
      'Eastern Province', "Ha'il", 'Jazan', 'Mecca', 'Najran',
      'Northern Borders', 'Riyadh', 'Tabuk',
    ],
    'Singapore': [],
    'New Zealand': [
      'Auckland', 'Bay of Plenty', 'Canterbury', 'Gisborne',
      "Hawke's Bay", 'Manawatu-Whanganui', 'Marlborough', 'Nelson',
      'Northland', 'Otago', 'Southland', 'Taranaki', 'Tasman',
      'Waikato', 'Wellington', 'West Coast',
    ],
    'South Africa': [
      'Eastern Cape', 'Free State', 'Gauteng', 'KwaZulu-Natal', 'Limpopo',
      'Mpumalanga', 'North West', 'Northern Cape', 'Western Cape',
    ],
    'Brazil': [
      'Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará',
      'Distrito Federal', 'Espírito Santo', 'Goiás', 'Maranhão',
      'Mato Grosso', 'Mato Grosso do Sul', 'Minas Gerais', 'Pará',
      'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 'Rio de Janeiro',
      'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 'Roraima',
      'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins',
    ],
    'Netherlands': [
      'Drenthe', 'Flevoland', 'Friesland', 'Gelderland', 'Groningen',
      'Limburg', 'North Brabant', 'North Holland', 'Overijssel',
      'South Holland', 'Utrecht', 'Zeeland',
    ],
  };

  static List<String> statesFor(String country) =>
      _states[country] ?? [];

  static bool hasStates(String country) =>
      _states.containsKey(country) && _states[country]!.isNotEmpty;
}
