/**
 * Crisis Template Responses
 * 
 * Pre-written responses for crisis situations
 * Used instead of Gemini API calls to avoid sending crisis content externally
 */

import { CrisisDetectionResult } from '../sentinel/crisis_detector';

export function generateCrisisTemplate(result: CrisisDetectionResult): string {
  // Critical severity (score 85-100)
  if (result.crisis_score >= 85) {
    return `I can hear how much pain you're in right now, and I want you to know that your safety is what matters most.

Please reach out for immediate support:
• National Suicide Prevention Lifeline: 988
• Crisis Text Line: Text HOME to 741741  
• Emergency Services: 911

What you're feeling is real, and you don't have to face this alone. Professional crisis counselors are available 24/7 and want to help.

Would you be willing to reach out to one of these resources right now?`;
  }
  
  // High severity (score 70-84)
  if (result.crisis_score >= 70) {
    return `I'm hearing a lot of pain in what you've shared, and I want you to know that I'm here with you right now.

If you're having thoughts of harming yourself, please reach out to:
• National Suicide Prevention Lifeline: 988
• Crisis Text Line: Text HOME to 741741

These are people who understand what you're going through and can provide immediate support.

How are you feeling right now? Are you safe?`;
  }
  
  // Fallback (shouldn't reach here)
  return `I hear that you're going through something difficult. If you need support, these resources are available 24/7:
• Lifeline: 988
• Crisis Text: HOME to 741741`;
}
