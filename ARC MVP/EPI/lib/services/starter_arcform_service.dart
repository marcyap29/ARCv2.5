import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:logger/logger.dart';

class StarterArcformService {
  static final Logger _logger = Logger();
  
  /// Creates a starter Arcform from onboarding data
  static SimpleArcform createFromOnboarding(UserProfile userProfile) {
    _logger.d('Creating starter Arcform from onboarding data');
    
    // Build meaningful content from onboarding answers
    final contentParts = <String>[];
    
    if (userProfile.onboardingPurpose != null) {
      contentParts.add('I am here for ${userProfile.onboardingPurpose?.toLowerCase()}');
    }
    
    if (userProfile.onboardingFeeling != null) {
      contentParts.add('Right now I feel ${userProfile.onboardingFeeling?.toLowerCase()}');
    }
    
    if (userProfile.onboardingCurrentSeason != null) {
      contentParts.add('I am in a season of ${userProfile.onboardingCurrentSeason?.toLowerCase()}');
    }
    
    if (userProfile.onboardingCentralWord != null) {
      contentParts.add('The word that feels most central to my story is "${userProfile.onboardingCentralWord}"');
    }
    
    if (userProfile.onboardingRhythm != null) {
      contentParts.add('I want to follow a ${userProfile.onboardingRhythm?.toLowerCase()} rhythm');
    }
    
    final content = contentParts.isEmpty 
        ? 'Beginning my journey of self-discovery and growth' 
        : '${contentParts.join('. ')}.';
    
    // Extract keywords from onboarding data
    final keywords = <String>[];
    
    if (userProfile.onboardingPurpose != null) {
      keywords.add(userProfile.onboardingPurpose!);
    }
    if (userProfile.onboardingFeeling != null) {
      keywords.add(userProfile.onboardingFeeling!);
    }
    if (userProfile.onboardingCurrentSeason != null) {
      keywords.add(userProfile.onboardingCurrentSeason!);
    }
    if (userProfile.onboardingCentralWord != null) {
      keywords.add(userProfile.onboardingCentralWord!);
    }
    if (userProfile.onboardingRhythm != null) {
      keywords.add(userProfile.onboardingRhythm!);
    }
    
    // Add some foundational keywords
    keywords.addAll(['beginning', 'journey', 'awareness']);
    
    // Ensure we have at least 3 keywords for a meaningful Arcform
    if (keywords.length < 3) {
      keywords.addAll(['growth', 'discovery', 'intention']);
    }
    
    // Determine the most appropriate geometry based on ATLAS phase
    ArcformGeometry geometry = ArcformGeometry.spiral; // Default to Discovery
    
    if (userProfile.onboardingCurrentSeason != null) {
      switch (userProfile.onboardingCurrentSeason!) {
        case 'Discovery':
          geometry = ArcformGeometry.spiral; // 🌱 Discovery
          break;
        case 'Expansion':
          geometry = ArcformGeometry.flower; // 🌸 Expansion
          break;
        case 'Transition':
          geometry = ArcformGeometry.branch; // 🌿 Transition
          break;
        case 'Consolidation':
          geometry = ArcformGeometry.weave; // 🧵 Consolidation
          break;
        case 'Recovery':
          geometry = ArcformGeometry.glowCore; // ✨ Recovery
          break;
        case 'Breakthrough':
          geometry = ArcformGeometry.fractal; // 💥 Breakthrough
          break;
        default:
          geometry = ArcformGeometry.spiral; // Default Discovery
      }
    }
    
    // Create the starter Arcform with phase-specific title
    final phaseTitle = userProfile.onboardingCurrentSeason != null 
        ? '${userProfile.onboardingCurrentSeason} - My Journey Begins'
        : 'Discovery - My Journey Begins';
        
    final arcform = SimpleArcform.fromJournalEntry(
      entryId: 'starter_${DateTime.now().millisecondsSinceEpoch}',
      title: phaseTitle,
      content: content,
      mood: userProfile.onboardingFeeling ?? 'Hopeful',
      keywords: keywords.take(8).toList(), // Limit to 8 keywords for better visualization
    );
    
    // Override geometry if we determined a better match
    final customArcform = SimpleArcform(
      id: arcform.id,
      title: arcform.title,
      content: arcform.content,
      mood: arcform.mood,
      keywords: arcform.keywords,
      geometry: geometry,
      colorMap: arcform.colorMap,
      edges: arcform.edges,
      phaseHint: geometry.description,
      createdAt: arcform.createdAt,
      isGeometryAuto: true,
    );
    
    _logger.i('Created starter Arcform with ${keywords.length} keywords and ${geometry.name} phase');
    
    return customArcform;
  }
}