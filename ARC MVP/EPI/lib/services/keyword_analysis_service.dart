import 'dart:math';

class KeywordAnalysisService {
  static final KeywordAnalysisService _instance = KeywordAnalysisService._internal();
  factory KeywordAnalysisService() => _instance;
  KeywordAnalysisService._internal();

  // Keyword categories for intelligent analysis
  static const Map<String, List<String>> _keywordCategories = {
    'Places': [
      'city', 'town', 'village', 'country', 'state', 'province', 'region', 'area', 'location',
      'home', 'house', 'apartment', 'office', 'work', 'school', 'university', 'college',
      'park', 'beach', 'mountain', 'forest', 'lake', 'river', 'ocean', 'sea', 'island',
      'restaurant', 'cafe', 'bar', 'club', 'theater', 'cinema', 'museum', 'library',
      'hospital', 'clinic', 'pharmacy', 'store', 'shop', 'mall', 'market', 'grocery',
      'airport', 'station', 'bus', 'train', 'subway', 'metro', 'highway', 'road', 'street',
      'hotel', 'resort', 'vacation', 'trip', 'travel', 'journey', 'adventure', 'destination'
    ],
    'Time': [
      'early', 'late', 'morning', 'afternoon', 'evening', 'night', 'midnight', 'dawn', 'dusk',
      'am', 'pm', 'o\'clock', 'hour', 'minute', 'second', 'today', 'yesterday', 'tomorrow',
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
      'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
      'spring', 'summer', 'fall', 'autumn', 'winter', 'season', 'weekend', 'weekday',
      'breakfast', 'lunch', 'dinner', 'snack', 'brunch', 'midnight', 'noon', 'midday',
      'rush hour', 'peak time', 'off hours', 'business hours', 'after hours',
      'timely', 'punctual', 'tardy', 'delayed', 'on time', 'ahead of time', 'behind schedule'
    ],
    'Energy Levels': [
      'full of energy', 'drained', 'exhausted', 'hyped', 'energetic', 'lively', 'vibrant', 'alive',
      'tired', 'weary', 'fatigued', 'sleepy', 'drowsy', 'lethargic', 'sluggish', 'slow',
      'pumped', 'stoked', 'psyched', 'buzzed', 'wired', 'jacked', 'fired up', 'ready to go',
      'burned out', 'worn out', 'spent', 'depleted', 'empty', 'low energy', 'no energy',
      'recharged', 'refreshed', 'revitalized', 'rejuvenated', 'restored', 'renewed',
      'adrenaline', 'rush', 'boost', 'surge', 'spike', 'crash', 'dip', 'slump',
      'motivated', 'unmotivated', 'driven', 'ambitious', 'determined', 'focused',
      'unfocused', 'scattered', 'distracted', 'zoned out', 'spaced out', 'out of it'
    ],
    'Emotions': [
      'happy', 'sad', 'angry', 'excited', 'nervous', 'anxious', 'worried', 'scared', 'afraid',
      'confident', 'proud', 'ashamed', 'embarrassed', 'guilty', 'jealous', 'envious',
      'grateful', 'thankful', 'blessed', 'fortunate', 'lucky', 'unlucky', 'unfortunate',
      'hopeful', 'hopeless', 'optimistic', 'pessimistic', 'positive', 'negative',
      'calm', 'peaceful', 'serene', 'tranquil', 'relaxed', 'stressed', 'overwhelmed',
      'frustrated', 'annoyed', 'irritated', 'upset', 'disappointed', 'devastated',
      'thrilled', 'ecstatic', 'elated', 'joyful', 'cheerful', 'merry', 'gleeful'
    ],
    'Feelings': [
      'love', 'hate', 'like', 'dislike', 'enjoy', 'appreciate', 'admire', 'respect',
      'care', 'concern', 'worry', 'fear', 'trust', 'distrust', 'doubt', 'believe',
      'hope', 'wish', 'desire', 'want', 'need', 'crave', 'long', 'yearn', 'miss',
      'cherish', 'treasure', 'value', 'prize', 'adore', 'worship', 'idolize',
      'despise', 'loathe', 'abhor', 'detest', 'resent', 'bitter', 'sour', 'cold',
      'warm', 'hot', 'passionate', 'intense', 'deep', 'profound', 'meaningful'
    ],
    'States of Being': [
      'serenity', 'tranquility', 'peace', 'calm', 'stillness', 'quiet', 'silence',
      'meditation', 'mindfulness', 'awareness', 'consciousness', 'presence', 'being',
      'flow', 'zen', 'balance', 'harmony', 'equilibrium', 'stability', 'grounded',
      'centered', 'focused', 'concentrated', 'attentive', 'mindful', 'present',
      'awake', 'alert', 'aware', 'conscious', 'lucid', 'clear', 'sharp', 'keen',
      'tired', 'exhausted', 'drained', 'fatigued', 'weary', 'sleepy', 'drowsy',
      'energetic', 'vibrant', 'alive', 'lively', 'dynamic', 'active', 'vigorous'
    ],
    'Adjectives': [
      'challenging', 'easy', 'difficult', 'hard', 'simple', 'complex', 'complicated',
      'beautiful', 'ugly', 'pretty', 'handsome', 'attractive', 'unattractive',
      'big', 'small', 'large', 'tiny', 'huge', 'enormous', 'massive', 'miniature',
      'fast', 'slow', 'quick', 'rapid', 'swift', 'sluggish', 'lethargic',
      'bright', 'dark', 'light', 'heavy', 'thick', 'thin', 'wide', 'narrow',
      'hot', 'cold', 'warm', 'cool', 'freezing', 'boiling', 'scorching',
      'loud', 'quiet', 'silent', 'noisy', 'peaceful', 'chaotic', 'calm',
      'smooth', 'rough', 'soft', 'hard', 'gentle', 'harsh', 'tender', 'tough'
    ],
    'Slang': [
      'sucked', 'awesome', 'amazing', 'incredible', 'fantastic', 'terrible', 'awful',
      'chillin', 'hanging', 'vibes', 'mood', 'energy', 'vibe', 'feeling', 'feels',
      'lit', 'fire', 'dope', 'sick', 'sweet', 'cool', 'rad', 'epic', 'legendary',
      'trash', 'garbage', 'rubbish', 'crap', 'junk', 'waste', 'useless', 'pointless',
      'bomb', 'killer', 'beast', 'monster', 'beastmode', 'savage', 'brutal',
      'chill', 'relaxed', 'laid-back', 'mellow', 'easy-going', 'casual', 'informal',
      'hype', 'pumped', 'stoked', 'psyched', 'excited', 'thrilled', 'buzzed',
      'bummed', 'down', 'low', 'blue', 'sad', 'depressed', 'miserable', 'gloomy'
    ]
  };

  // Analyze text and extract keywords by category
  Map<String, List<String>> analyzeKeywords(String text) {
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2) // Filter short words
        .toList();

    final categorizedKeywords = <String, List<String>>{};
    
    for (final category in _keywordCategories.keys) {
      final categoryKeywords = <String>[];
      final categoryWords = _keywordCategories[category]!;
      
      for (final word in words) {
        if (categoryWords.contains(word)) {
          categoryKeywords.add(word);
        }
      }
      
      if (categoryKeywords.isNotEmpty) {
        categorizedKeywords[category] = categoryKeywords.toSet().toList();
      }
    }
    
    return categorizedKeywords;
  }

  // Get all available categories
  List<String> getCategories() {
    return _keywordCategories.keys.toList();
  }

  // Get keywords for a specific category
  List<String> getKeywordsForCategory(String category) {
    return _keywordCategories[category] ?? [];
  }

  // Suggest keywords based on text analysis
  List<String> suggestKeywords(String text) {
    final categorized = analyzeKeywords(text);
    final suggestions = <String>[];
    
    for (final category in categorized.keys) {
      suggestions.addAll(categorized[category]!);
    }
    
    return suggestions.toSet().toList();
  }

  // Get random keywords from a category for suggestions
  List<String> getRandomKeywords(String category, int count) {
    final keywords = getKeywordsForCategory(category);
    if (keywords.isEmpty) return [];
    
    final random = Random();
    final shuffled = List<String>.from(keywords)..shuffle(random);
    return shuffled.take(count).toList();
  }

  // Check if a word belongs to a specific category
  bool isKeywordInCategory(String word, String category) {
    final categoryWords = _keywordCategories[category] ?? [];
    return categoryWords.contains(word.toLowerCase());
  }

  // Get category for a specific keyword
  String? getCategoryForKeyword(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    for (final entry in _keywordCategories.entries) {
      if (entry.value.contains(lowerKeyword)) {
        return entry.key;
      }
    }
    return null;
  }
}
