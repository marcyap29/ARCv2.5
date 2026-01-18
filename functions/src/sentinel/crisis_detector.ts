/**
 * SENTINEL Crisis Detector
 * 
 * Internal-only, keyword-based crisis detection
 * No external APIs, no ML - pure pattern matching
 * Optimized for speed and precision
 */

// ============================================
// KEYWORD LIBRARY
// ============================================

const CRITICAL_PATTERNS = [
  /\bsuicid/i,
  /\bkill myself/i,
  /\bend my life/i,
  /\bwant to die/i,
  /\bshoot myself/i,
  /\bhang myself/i,
  /\boverdose/i,
  /\bjump off/i,
  /\bcut my wrists/i,
  /\btake my (own )?life/i
];

const HIGH_PATTERNS = [
  /\bhurt myself/i,
  /\bcut myself/i,
  /\bharm myself/i,
  /\bno reason to live/i,
  /\bcan't go on/i,
  /\bend it all/i,
  /\bno hope/i,
  /\bgive up/i,
  /\bworthless/i,
  /\bburden/i,
  /\bbetter off dead/i,
  /\bdisappear/i,
  /\bdon't want to (be here|exist)/i
];

const MODERATE_PATTERNS = [
  /\bcan't take (it|this)/i,
  /\btoo much/i,
  /\bcan't handle/i,
  /\boverwhelm(ed|ing)/i,
  /\bbreaking down/i,
  /\bfalling apart/i,
  /\bno point/i,
  /\bnothing matters/i,
  /\bcan't do this/i,
  /\blosing it/i
];

const INTENSITY_AMPLIFIERS = {
  temporal: [
    /\bright now/i,
    /\btoday/i,
    /\btonight/i,
    /\bsoon/i,
    /\bcan't wait/i,
    /\bready to/i
  ],
  absolute: [
    /\bonly (way|option|choice)/i,
    /\bno other/i,
    /\bnothing else/i,
    /\bmust/i,
    /\bhave to/i,
    /\bneed to/i
  ],
  isolation: [
    /\balone/i,
    /\bnobody/i,
    /\bno one/i,
    /\bby myself/i,
    /\bisolat/i
  ],
  finality: [
    /\bforever/i,
    /\bnever/i,
    /\balways/i,
    /\bcan't go back/i,
    /\bpermanent/i
  ]
};

// ============================================
// DETECTION LOGIC
// ============================================

export interface CrisisDetectionResult {
  crisis_detected: boolean;
  crisis_score: number;
  crisis_level: 'NONE' | 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';
  detected_patterns: string[];
  intensity_factors: string[];
  confidence: number;
  timestamp: Date;
}

export function detectCrisis(text: string): CrisisDetectionResult {
  const normalizedText = text.toLowerCase();
  let score = 0;
  const detectedPatterns: string[] = [];
  const intensityFactors: string[] = [];
  
  // Check critical patterns (40 points each)
  for (const pattern of CRITICAL_PATTERNS) {
    if (pattern.test(normalizedText)) {
      score += 40;
      detectedPatterns.push(`CRITICAL: ${pattern.source}`);
    }
  }
  
  // Check high patterns (15 points each)
  for (const pattern of HIGH_PATTERNS) {
    if (pattern.test(normalizedText)) {
      score += 15;
      detectedPatterns.push(`HIGH: ${pattern.source}`);
    }
  }
  
  // Check moderate patterns (5 points each if clustered)
  let moderateMatches = 0;
  for (const pattern of MODERATE_PATTERNS) {
    if (pattern.test(normalizedText)) {
      moderateMatches++;
      detectedPatterns.push(`MODERATE: ${pattern.source}`);
    }
  }
  if (moderateMatches >= 2) {
    score += moderateMatches * 5;
  }
  
  // Check intensity amplifiers (up to +30)
  let intensityBonus = 0;
  for (const [category, patterns] of Object.entries(INTENSITY_AMPLIFIERS)) {
    for (const pattern of patterns) {
      if (pattern.test(normalizedText)) {
        intensityBonus += 7.5;
        intensityFactors.push(`${category}: ${pattern.source}`);
      }
    }
  }
  score += Math.min(intensityBonus, 30);
  
  // Cap at 100
  score = Math.min(score, 100);
  
  // Classify
  let level: CrisisDetectionResult['crisis_level'] = 'NONE';
  if (score >= 85) level = 'CRITICAL';
  else if (score >= 70) level = 'HIGH';
  else if (score >= 50) level = 'MODERATE';
  else if (score > 0) level = 'LOW';
  
  // Calculate confidence
  const confidence = Math.min(
    (detectedPatterns.length * 20) + (intensityFactors.length * 5),
    100
  );
  
  return {
    crisis_detected: score >= 70, // Crisis threshold
    crisis_score: score,
    crisis_level: level,
    detected_patterns: detectedPatterns,
    intensity_factors: intensityFactors,
    confidence: confidence,
    timestamp: new Date()
  };
}

// ============================================
// FALSE POSITIVE FILTERING
// ============================================

function containsFalsePositiveMarkers(text: string): boolean {
  const falsePositivePatterns = [
    /he said/i,
    /she said/i,
    /they said/i,
    /someone told me/i,
    /i heard that/i,
    /in the news/i,
    /read about/i,
    /movie about/i
  ];
  
  return falsePositivePatterns.some(p => p.test(text));
}

export function detectCrisisEnhanced(text: string): CrisisDetectionResult {
  const result = detectCrisis(text);
  
  // If crisis detected, check for false positive markers
  if (result.crisis_detected && containsFalsePositiveMarkers(text)) {
    result.confidence = Math.max(result.confidence - 30, 30);
    result.detected_patterns.push('WARNING: Possible false positive markers detected');
  }
  
  return result;
}
