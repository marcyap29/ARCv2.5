class RedactionRules {
  // People names - proper case patterns with stoplist (avoid sentence starters)
  static final peopleNameRegex = RegExp(r'(?<![.!?]\s)([A-Z][a-z]{2,}(?:\s[A-Z][a-z]{2,}){0,2})\b');
  
  // Stoplist - common words that match name pattern but aren't names
  static const nameStoplist = {
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 
    'September', 'October', 'November', 'December',
    'Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough',
    'Happy', 'Sad', 'Angry', 'Anxious', 'Calm', 'Excited', 'Frustrated', 'Grateful',
    'North', 'South', 'East', 'West', 'Center', 'Hospital', 'Station', 'Department',
    'CPR', 'ALS', 'BLS', 'EMS', 'ER', 'ICU', 'EMT', 'Paramedic',
    'Spoke', 'Called', 'Went', 'Arrived', 'Left', 'Started', 'Responded',
    'Baker', 'Main', 'First', 'Second', 'Third', 'Oak', 'Maple', 'Pine', 'Church',
    'Today', 'Tomorrow', 'Yesterday', 'Weather', 'Nice'
  };
  
  // Locations
  static final streetAddressRegex = RegExp(r'\b\d{1,5}[A-Za-z]?\s[A-Za-z0-9.\- ]+(?:Ave|St|Rd|Blvd|Dr|Ln|Hwy|Pkwy)\b');
  static final intersectionRegex = RegExp(r'\b([A-Za-z.\- ]+(?:Ave|St|Rd|Blvd|Dr|Ln))\s(?:and|&|at)\s([A-Za-z.\- ]+(?:Ave|St|Rd|Blvd|Dr|Ln))\b');
  static final facilityRegex = RegExp(r'\b([A-Z][a-zA-Z\s]{2,}\s(?:Hospital|Medical Center|Med Center))\b');
  
  // Units/Callsigns
  static final unitsRegex = RegExp(r'\b(?:Engine|Truck|Ladder|Rescue|Medic|Battalion|Chief)\s\d{1,3}\b');
  
  // Timestamps/Dates
  static final timeRegex = RegExp(r'\b(?:[01]?\d|2[0-3]):[0-5]\d(?:\s?(?:AM|PM))?\b');
  static final dateRegex = RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b');
  
  // Contact info
  static final phoneRegex = RegExp(r'\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}\b');
  static final emailRegex = RegExp(r'\b[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}\b', caseSensitive: false);
  
  // GPS coordinates
  static final gpsRegex = RegExp(r'\b-?\d{1,2}\.\d{4,},\s?-?\d{1,3}\.\d{4,}\b');
  
  // License plates (simple US pattern with context)
  static final plateRegex = RegExp(r'(?:plate|tag|license)\s+([A-Z0-9]{1,8})\b', caseSensitive: false);
  
  static bool isValidName(String match) {
    // Check if match is in stoplist
    if (nameStoplist.contains(match)) return false;
    
    // Check if it's too short (likely an abbreviation)
    if (match.length < 3) return false;
    
    // Check if it's all caps (likely acronym)
    if (match == match.toUpperCase()) return false;
    
    return true;
  }
  
  static bool isValidUnit(String match) {
    // More sophisticated validation for units to avoid false positives
    final lowerMatch = match.toLowerCase();
    
    // Skip common words that might match unit pattern
    if (lowerMatch.contains('page') || lowerMatch.contains('line') || lowerMatch.contains('item')) {
      return false;
    }
    
    return true;
  }
}