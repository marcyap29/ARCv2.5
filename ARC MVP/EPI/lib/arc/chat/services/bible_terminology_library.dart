// lib/arc/chat/services/bible_terminology_library.dart
// Comprehensive Bible Terminology Library for LUMARA
// Used to automatically detect Bible-related queries and trigger Bible API

/// Comprehensive Bible Terminology Library
/// 
/// Contains terms, phrases, concepts, and patterns that indicate
/// Bible-related queries. Used by LUMARA to automatically identify
/// when users are asking about biblical topics.
class BibleTerminologyLibrary {
  /// All 66 books of the Bible (Old and New Testament)
  static const List<String> bibleBooks = [
    // Old Testament (39 books)
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy',
    'joshua', 'judges', 'ruth', '1 samuel', '2 samuel', '1 kings', '2 kings',
    '1 chronicles', '2 chronicles', 'ezra', 'nehemiah', 'esther', 'job',
    'psalm', 'psalms', 'proverbs', 'ecclesiastes', 'song of solomon', 'song',
    'isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea',
    'joel', 'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk',
    'zephaniah', 'haggai', 'zechariah', 'malachi',
    // New Testament (27 books)
    'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1 corinthians',
    '2 corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
    '1 thessalonians', '2 thessalonians', '1 timothy', '2 timothy', 'titus',
    'philemon', 'hebrews', 'james', '1 peter', '2 peter', '1 john', '2 john',
    '3 john', 'jude', 'revelation',
  ];
  
  /// Bible book abbreviations
  static const Map<String, String> bibleBookAbbreviations = {
    'gen': 'genesis', 'ex': 'exodus', 'lev': 'leviticus', 'num': 'numbers',
    'deut': 'deuteronomy', 'dt': 'deuteronomy', 'josh': 'joshua', 'judg': 'judges',
    '1 sam': '1 samuel', '1sam': '1 samuel', '2 sam': '2 samuel', '2sam': '2 samuel',
    '1 kgs': '1 kings', '1kgs': '1 kings', '2 kgs': '2 kings', '2kgs': '2 kings',
    '1 chr': '1 chronicles', '1chr': '1 chronicles', '2 chr': '2 chronicles', '2chr': '2 chronicles',
    'ps': 'psalms', 'psa': 'psalms', 'prov': 'proverbs', 'eccl': 'ecclesiastes',
    'ecc': 'ecclesiastes', 'song': 'song of solomon', 'sos': 'song of solomon',
    'isa': 'isaiah', 'jer': 'jeremiah', 'lam': 'lamentations', 'ezek': 'ezekiel',
    'ezk': 'ezekiel', 'dan': 'daniel', 'hos': 'hosea', 'jol': 'joel', 'am': 'amos',
    'obad': 'obadiah', 'jon': 'jonah', 'mic': 'micah', 'nah': 'nahum', 'hab': 'habakkuk',
    'zeph': 'zephaniah', 'hag': 'haggai', 'zech': 'zechariah', 'mal': 'malachi',
    'matt': 'matthew', 'mt': 'matthew', 'mk': 'mark', 'lk': 'luke', 'jn': 'john',
    'jhn': 'john', 'rom': 'romans', '1 cor': '1 corinthians', '1cor': '1 corinthians',
    '2 cor': '2 corinthians', '2cor': '2 corinthians', 'gal': 'galatians',
    'eph': 'ephesians', 'phil': 'philippians', 'col': 'colossians',
    '1 thes': '1 thessalonians', '1thes': '1 thessalonians',
    '2 thes': '2 thessalonians', '2thes': '2 thessalonians',
    '1 tim': '1 timothy', '1tim': '1 timothy', '2 tim': '2 timothy', '2tim': '2 timothy',
    'philem': 'philemon', 'heb': 'hebrews', 'jas': 'james', '1 pet': '1 peter',
    '1pet': '1 peter', '2 pet': '2 peter', '2pet': '2 peter', '1 jn': '1 john',
    '1jn': '1 john', '2 jn': '2 john', '2jn': '2 john', '3 jn': '3 john',
    '3jn': '3 john', 'rev': 'revelation',
  };
  
  /// Major biblical characters and figures
  static const List<String> biblicalCharacters = [
    // Old Testament
    'adam', 'eve', 'cain', 'abel', 'noah', 'abraham', 'sarah', 'isaac', 'rebecca',
    'jacob', 'esau', 'joseph', 'moses', 'aaron', 'joshua', 'gideon', 'samson',
    'david', 'saul', 'solomon', 'jonathan', 'ruth', 'naomi', 'boaz', 'esther',
    'mordecai', 'job', 'elijah', 'elisha', 'isaiah', 'jeremiah', 'ezekiel',
    'daniel', 'hosea', 'joel', 'amos', 'jonah', 'micah', 'nahum', 'habakkuk',
    'zephaniah', 'haggai', 'zechariah', 'malachi', 'nehemiah', 'ezra',
    // New Testament
    'jesus', 'christ', 'jesus christ', 'mary', 'joseph', 'john the baptist',
    'peter', 'paul', 'apostle paul', 'john', 'james', 'andrew', 'philip',
    'bartholomew', 'thomas', 'matthew', 'james son of zebedee', 'jude',
    'simon', 'judas', 'luke', 'mark', 'timothy', 'titus', 'philemon',
    'barnabas', 'stephen', 'philip the evangelist', 'cornelius', 'lydia',
    'priscilla', 'aquila', 'apollos', 'silas', 'apostles', 'disciples',
  ];
  
  /// Prophets (major and minor)
  static const List<String> prophets = [
    'isaiah', 'jeremiah', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
    'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai',
    'zechariah', 'malachi', 'elijah', 'elisha', 'samuel', 'nathan', 'gad',
    'prophet', 'prophets', 'major prophet', 'minor prophet',
  ];
  
  /// Apostles and disciples
  static const List<String> apostles = [
    'peter', 'andrew', 'james', 'john', 'philip', 'bartholomew', 'thomas',
    'matthew', 'james son of alphaeus', 'thaddaeus', 'simon the zealot',
    'judas iscariot', 'matthias', 'paul', 'apostle', 'apostles', 'disciple',
    'disciples', 'the twelve', 'twelve apostles',
  ];
  
  /// Biblical events and stories
  static const List<String> biblicalEvents = [
    'creation', 'fall of man', 'flood', 'noah\'s ark', 'tower of babel',
    'abraham\'s call', 'sodom and gomorrah', 'isaac\'s birth', 'jacob\'s ladder',
    'joseph in egypt', 'exodus', 'red sea', 'ten commandments', 'golden calf',
    'joshua and jericho', 'samson and delilah', 'david and goliath',
    'david and bathsheba', 'solomon\'s temple', 'elijah and the prophets of baal',
    'daniel in the lion\'s den', 'jonah and the whale', 'nehemiah\'s wall',
    'birth of jesus', 'nativity', 'wise men', 'magi', 'baptism of jesus',
    'temptation of jesus', 'sermon on the mount', 'feeding the 5000',
    'walking on water', 'raising lazarus', 'last supper', 'garden of gethsemane',
    'crucifixion', 'resurrection', 'ascension', 'pentecost', 'paul\'s conversion',
    'road to damascus',
  ];
  
  /// Biblical places and locations
  static const List<String> biblicalPlaces = [
    'eden', 'garden of eden', 'babel', 'babylon', 'jerusalem', 'bethlehem',
    'nazareth', 'galilee', 'jordan river', 'red sea', 'mount sinai', 'mount zion',
    'jericho', 'samaria', 'judea', 'egypt', 'canaan', 'promised land',
    'israel', 'assyria', 'nineveh', 'damascus', 'antioch', 'ephesus', 'rome',
    'corinth', 'thessalonica', 'philippi', 'colossae', 'patmos',
  ];
  
  /// Biblical concepts and themes
  static const List<String> biblicalConcepts = [
    'salvation', 'redemption', 'atonement', 'grace', 'mercy', 'forgiveness',
    'repentance', 'faith', 'hope', 'love', 'charity', 'righteousness',
    'holiness', 'sanctification', 'justification', 'reconciliation',
    'covenant', 'promise', 'prophecy', 'prophecies', 'messiah', 'christ',
    'kingdom of god', 'kingdom of heaven', 'eternal life', 'resurrection',
    'judgment', 'hell', 'heaven', 'paradise', 'new jerusalem', 'second coming',
    'rapture', 'tribulation', 'millennium', 'apocalypse', 'revelation',
    'trinity', 'god the father', 'god the son', 'holy spirit', 'holy ghost',
    'incarnation', 'virgin birth', 'crucifixion', 'resurrection', 'ascension',
    'pentecost', 'baptism', 'communion', 'lord\'s supper', 'eucharist',
    'sin', 'original sin', 'temptation', 'trial', 'suffering', 'persecution',
    'martyrdom', 'worship', 'prayer', 'praying', 'praise', 'thanksgiving',
    'blessing', 'curse', 'covenant', 'law', 'commandments', 'ten commandments',
    'gospel', 'gospels', 'epistle', 'epistles', 'psalm', 'psalms', 'proverb',
    'wisdom', 'foolishness', 'pride', 'humility', 'meekness', 'gentleness',
    'patience', 'longsuffering', 'kindness', 'goodness', 'faithfulness',
    'self-control', 'temperance', 'joy', 'peace', 'peace of god',
  ];
  
  /// Common Bible-related phrases and questions
  static const List<String> biblePhrases = [
    'what does the bible say',
    'what does scripture say',
    'bible verse',
    'bible verses',
    'scripture',
    'scriptures',
    'biblical',
    'biblically',
    'according to the bible',
    'in the bible',
    'bible study',
    'bible reading',
    'bible passage',
    'bible chapter',
    'bible book',
    'old testament',
    'new testament',
    'gospel',
    'gospels',
    'epistle',
    'psalm',
    'psalms',
    'proverb',
    'prophecy',
    'prophecies',
    'tell me about',
    'who is',
    'what is',
    'explain',
    'meaning of',
    'verse',
    'verses',
    'chapter',
    'chapters',
    'book of',
    'prophet',
    'apostle',
    'disciple',
    'jesus said',
    'jesus teaches',
    'paul wrote',
    'david wrote',
    'solomon wrote',
    'moses wrote',
    'god said',
    'lord said',
    'christ said',
  ];
  
  /// Religious and theological terms
  static const List<String> theologicalTerms = [
    'theology', 'theological', 'doctrine', 'doctrinal', 'dogma', 'creed',
    'denomination', 'church', 'congregation', 'worship', 'sermon', 'preaching',
    'pastor', 'minister', 'priest', 'bishop', 'deacon', 'elder', 'evangelist',
    'missionary', 'ministry', 'ministries', 'evangelism', 'discipleship',
    'fellowship', 'communion', 'sacrament', 'sacraments', 'baptism', 'confirmation',
    'confession', 'absolution', 'eucharist', 'mass', 'liturgy', 'liturgical',
    'hymn', 'hymns', 'praise', 'worship song', 'spiritual', 'spirituality',
    'devotion', 'devotional', 'meditation', 'contemplation', 'prayer', 'praying',
    'intercession', 'supplication', 'petition', 'thanksgiving', 'adoration',
    'confession', 'repentance', 'fasting', 'tithing', 'offering', 'sacrifice',
    'sanctuary', 'altar', 'pulpit', 'pew', 'choir', 'organ', 'bells',
  ];
  
  /// Christian holidays and observances
  static const List<String> christianHolidays = [
    'advent', 'christmas', 'nativity', 'epiphany', 'lent', 'palm sunday',
    'good friday', 'easter', 'resurrection sunday', 'ascension', 'pentecost',
    'whitsunday', 'trinity sunday', 'all saints day', 'all souls day',
    'reformation day', 'thanksgiving', 'christmas eve', 'christmas day',
  ];
  
  /// Parables of Jesus
  static const List<String> parables = [
    'parable of the sower', 'parable of the good samaritan',
    'parable of the prodigal son', 'parable of the lost sheep',
    'parable of the lost coin', 'parable of the talents',
    'parable of the wise and foolish virgins', 'parable of the mustard seed',
    'parable of the yeast', 'parable of the hidden treasure',
    'parable of the pearl', 'parable of the net', 'parable of the workers',
    'parable of the two sons', 'parable of the tenants', 'parable',
    'parables',
  ];
  
  /// Miracles of Jesus
  static const List<String> miracles = [
    'turning water into wine', 'healing the official\'s son',
    'healing at the pool of bethesda', 'feeding the 5000',
    'walking on water', 'healing the blind man', 'raising lazarus',
    'healing the leper', 'healing the paralytic', 'healing the woman',
    'calming the storm', 'casting out demons', 'miracles', 'miracle',
  ];
  
  /// Beatitudes
  static const List<String> beatitudes = [
    'blessed are the poor in spirit', 'blessed are those who mourn',
    'blessed are the meek', 'blessed are those who hunger',
    'blessed are the merciful', 'blessed are the pure in heart',
    'blessed are the peacemakers', 'blessed are those who are persecuted',
    'beatitudes', 'sermon on the mount',
  ];
  
  /// Check if a message contains Bible-related terminology
  static bool containsBibleTerminology(String message) {
    final lower = message.toLowerCase();
    
    // Check all categories
    return _containsAny(lower, bibleBooks) ||
           _containsAny(lower, biblicalCharacters) ||
           _containsAny(lower, prophets) ||
           _containsAny(lower, apostles) ||
           _containsAny(lower, biblicalEvents) ||
           _containsAny(lower, biblicalPlaces) ||
           _containsAny(lower, biblicalConcepts) ||
           _containsAny(lower, biblePhrases) ||
           _containsAny(lower, theologicalTerms) ||
           _containsAny(lower, christianHolidays) ||
           _containsAny(lower, parables) ||
           _containsAny(lower, miracles) ||
           _containsAny(lower, beatitudes) ||
           _containsAbbreviation(lower);
  }
  
  /// Check if message contains any Bible book abbreviations
  static bool _containsAbbreviation(String lower) {
    return bibleBookAbbreviations.keys.any((abbr) => lower.contains(abbr));
  }
  
  /// Check if message contains any of the given terms
  static bool _containsAny(String message, List<String> terms) {
    return terms.any((term) => message.contains(term));
  }
  
  /// Get all Bible-related terms found in a message
  static List<String> extractBibleTerms(String message) {
    final lower = message.toLowerCase();
    final found = <String>[];
    
    // Check all categories and collect matches
    for (final term in bibleBooks) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in biblicalCharacters) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in prophets) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in apostles) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in biblicalEvents) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in biblicalPlaces) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in biblicalConcepts) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in biblePhrases) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in theologicalTerms) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in christianHolidays) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in parables) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in miracles) {
      if (lower.contains(term)) found.add(term);
    }
    for (final term in beatitudes) {
      if (lower.contains(term)) found.add(term);
    }
    
    // Check abbreviations
    for (final entry in bibleBookAbbreviations.entries) {
      if (lower.contains(entry.key)) found.add(entry.value);
    }
    
    return found.toSet().toList(); // Remove duplicates
  }
  
  /// Get the primary Bible book mentioned in a message
  static String? getPrimaryBibleBook(String message) {
    final terms = extractBibleTerms(message);
    
    // Prioritize Bible books
    for (final term in terms) {
      if (bibleBooks.contains(term.toLowerCase())) {
        return term;
      }
    }
    
    // Check abbreviations
    final lower = message.toLowerCase();
    for (final entry in bibleBookAbbreviations.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Check if message is asking about a specific biblical character
  static String? getBiblicalCharacter(String message) {
    final terms = extractBibleTerms(message);
    
    for (final term in terms) {
      if (biblicalCharacters.contains(term.toLowerCase()) ||
          prophets.contains(term.toLowerCase()) ||
          apostles.contains(term.toLowerCase())) {
        return term;
      }
    }
    
    return null;
  }
  
  /// Check if message is asking about a biblical concept or theme
  static bool isAskingAboutConcept(String message) {
    final terms = extractBibleTerms(message);
    final lower = message.toLowerCase();
    
    return terms.any((term) => 
      biblicalConcepts.contains(term.toLowerCase()) ||
      biblicalEvents.contains(term.toLowerCase()) ||
      parables.contains(term.toLowerCase()) ||
      miracles.contains(term.toLowerCase())
    ) || lower.contains('what does') || lower.contains('tell me about');
  }
}
