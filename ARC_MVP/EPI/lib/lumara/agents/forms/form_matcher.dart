// lib/lumara/agents/forms/form_matcher.dart
// Phase 6: Keyword matching of form labels to profile keys.

import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';

class FormFieldMatch {
  final String detectedLabel;
  final String? profileKey;
  final String? proposedValue;
  final double confidence;
  final bool isSensitive;

  const FormFieldMatch({
    required this.detectedLabel,
    this.profileKey,
    this.proposedValue,
    this.confidence = 0.0,
    this.isSensitive = false,
  });
}

/// Maps form label keywords to profile keys. Multiple keywords can map to the same key.
final Map<String, String> _labelToProfileKey = {
  'name': 'full_name',
  'full name': 'full_name',
  'your name': 'full_name',
  'first name': 'first_name', // special: split full_name
  'last name': 'last_name',
  'surname': 'last_name',
  'email': 'email',
  'email address': 'email',
  'e-mail': 'email',
  'phone': 'phone',
  'mobile': 'phone',
  'telephone': 'phone',
  'contact number': 'phone',
  'address': 'address_street',
  'street address': 'address_street',
  'street': 'address_street',
  'city': 'address_city',
  'suburb': 'address_city',
  'town': 'address_city',
  'state': 'address_state',
  'province': 'address_state',
  'postcode': 'address_postcode',
  'zip': 'address_postcode',
  'zip code': 'address_postcode',
  'postal code': 'address_postcode',
  'country': 'address_country',
  'date of birth': 'date_of_birth',
  'dob': 'date_of_birth',
  'birth date': 'date_of_birth',
  'birthday': 'date_of_birth',
  'employer': 'employer',
  'company': 'employer',
  'organisation': 'employer',
  'organization': 'employer',
  'workplace': 'employer',
  'job title': 'job_title',
  'position': 'job_title',
  'role': 'job_title',
  'occupation': 'job_title',
  'emergency contact': 'emergency_contact_name',
  'next of kin': 'emergency_contact_name',
  'emergency phone': 'emergency_contact_phone',
  'emergency number': 'emergency_contact_phone',
  'medicare': 'health_insurance_number',
  'insurance number': 'health_insurance_number',
  'health fund number': 'health_insurance_number',
};

String _normalise(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class FormMatcher {
  FormMatcher._();

  static List<FormFieldMatch> match(ParsedDocument doc, Map<String, String> profile) {
    final service = UserProfileService.instance;
    final matches = <FormFieldMatch>[];

    for (final field in doc.keyFields) {
    final label = field.label;
    final normalised = _normalise(label);

    String? profileKey;
    double confidence = 0.0;
    String? proposedValue;

    for (final entry in _labelToProfileKey.entries) {
      final keyword = entry.key;
      final key = entry.value;

      if (normalised == keyword) {
        profileKey = key;
        confidence = 1.0;
        break;
      }
      if (normalised.contains(keyword)) {
        profileKey = key;
        confidence = 0.75;
        break;
      }
    }

    if (profileKey != null) {
      if (profileKey == 'first_name') {
        final full = profile['full_name'] ?? '';
        final parts = full.split(' ').where((s) => s.isNotEmpty).toList();
        proposedValue = parts.isNotEmpty ? parts.first : null;
      } else if (profileKey == 'last_name') {
        final full = profile['full_name'] ?? '';
        final parts = full.split(' ').where((s) => s.isNotEmpty).toList();
        proposedValue = parts.length > 1 ? parts.last : (parts.length == 1 ? parts.first : null);
      } else {
        proposedValue = profile[profileKey];
      }
    }
    // When no profile match, use the scanned value so "Use to fill form" shows extracted data.
    proposedValue = proposedValue ?? field.value;

    final isSensitive = profileKey != null && service.isSensitive(profileKey);

    matches.add(FormFieldMatch(
      detectedLabel: label,
      profileKey: profileKey,
      proposedValue: proposedValue,
      confidence: confidence,
      isSensitive: isSensitive,
    ));
    }

    return matches;
  }
}
