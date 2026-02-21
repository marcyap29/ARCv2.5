// Masking Strategy Interface
// Defines the contract for PII masking services across all EPI modules

import '../models/pii_types.dart';
import '../models/masking_result.dart';

/// Interface for PII masking strategies
abstract class MaskingStrategy {
  /// Masks PII in the given text
  /// 
  /// [text] - The text containing PII to mask
  /// [piiItems] - List of PII items to mask
  /// Returns a [MaskingResult] containing the masked text and mapping
  MaskingResult maskText(String text, List<PIIItem> piiItems);
  
  /// Masks PII with custom options
  /// 
  /// [text] - The text containing PII to mask
  /// [piiItems] - List of PII items to mask
  /// [options] - Custom masking options
  /// Returns a [MaskingResult] containing the masked text and mapping
  MaskingResult maskTextWithOptions(String text, List<PIIItem> piiItems, MaskingOptions options);
  
  /// Unmasks text using the provided mapping
  /// 
  /// [maskedText] - The masked text
  /// [mapping] - The mapping used for masking
  /// Returns the original text with PII restored
  String unmaskText(String maskedText, Map<String, String> mapping);
}
