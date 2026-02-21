# Bible Reference Retrieval Implementation

**Version:** 1.0.0  
**Last Updated:** December 20, 2025  
**Status:** ✅ Complete

---

## Overview

LUMARA now has the capability to retrieve accurate Bible verses from the HelloAO Bible API when users request Bible references, chapters, books, translations, or related commentary.

---

## Implementation Components

### 1. Bible API Service
**File:** `lib/arc/chat/services/bible_api_service.dart`

- **Primary Source:** HelloAO Bible API (`https://bible.helloao.org/api/`)
- **Default Translation:** BSB (Berean Study Bible)
- **Features:**
  - Verse/chapter retrieval
  - Translation metadata
  - Book code resolution
  - Commentary support
  - Cross-reference datasets

**Key Methods:**
- `getVerses()` - Fetches verses for a reference (e.g., "John 3:16")
- `getChapter()` - Fetches entire chapter
- `getBooks()` - Lists books for a translation
- `getAvailableTranslations()` - Lists available translations
- `getCommentaryChapter()` - Fetches commentary chapters

**Reference Parsing:**
Supports common formats:
- "John 3:16"
- "Jn 3:16"
- "1 Cor 13"
- "Genesis 1"
- "Psalm 23"
- "Romans 8:28–30"
- "John 3:16-18 (ESV)"

### 2. Bible Retrieval Helper
**File:** `lib/arc/chat/services/bible_retrieval_helper.dart`

- Detects Bible verse requests in user messages
- Extracts references and translation preferences
- Fetches verses and formats them for LUMARA context
- Provides formatted output for LUMARA responses

**Key Methods:**
- `isBibleRequest()` - Checks if message is requesting Bible verses
- `extractReference()` - Extracts Bible reference from message
- `extractTranslation()` - Extracts translation preference
- `fetchVersesForRequest()` - Main method to fetch verses for a request

### 3. LUMARA Master Prompt Integration
**File:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`

Added comprehensive Bible retrieval capability section to the master prompt:
- Retrieval policy (HelloAO as primary source)
- Reference resolution rules
- Output format guidelines
- Safety and integrity constraints
- Error handling procedures

### 4. LUMARA Assistant Integration
**File:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

- Automatically detects Bible verse requests
- Fetches verses before sending to Gemini
- Includes verses in context as `[BIBLE_VERSE_CONTEXT]` blocks
- Works in both ArcLLM and streaming paths

---

## How It Works

### User Request Flow

1. **User asks for Bible verse:**
   - "What does John 3:16 say?"
   - "Show me Romans 8:28"
   - "What does the Bible say about love?"

2. **Bible Retrieval Helper detects request:**
   - `BibleRetrievalHelper.isBibleRequest()` checks message
   - Extracts reference and translation if specified

3. **Bible API Service fetches verses:**
   - Parses reference (book, chapter, verse range)
   - Resolves book code (e.g., "John" → "JHN")
   - Fetches chapter JSON from HelloAO API
   - Extracts requested verses

4. **Verses included in LUMARA context:**
   - Verses added as `[BIBLE_VERSE_CONTEXT]` block
   - LUMARA receives exact verse text
   - LUMARA can quote verbatim and provide interpretation

5. **LUMARA responds:**
   - Quotes exact verse text (verbatim from source)
   - Provides context (speaker, audience, narrative moment)
   - Offers interpretation (within safety constraints)
   - Clearly labels translation used

---

## Safety & Integrity

### Constraints

- **No fabrication:** LUMARA never quotes from memory - always fetches from HelloAO
- **Accurate quoting:** Verse text is verbatim from source
- **Safe interpretation:** Stays within ARC/LUMARA safety policies
- **No coercion:** Interpretation offered as help, not used to shame or threaten
- **Sensitive content:** Uses gentler tone for violence, abuse, trauma-related verses

### Privacy

- Only sends reference, translation code, and commentary identifier to HelloAO
- No personally identifying information sent
- No logging of user's private context alongside verse lookups

---

## Error Handling

### HelloAO Unavailable

1. LUMARA states it couldn't retrieve from HelloAO
2. Offers fallback options:
   - Try again
   - Use different translation
   - Fetch from reputable web sources (Google Search)
3. Clearly labels fallback sources

### Invalid Reference

1. LUMARA attempts to resolve book name
2. If resolution fails, asks user to clarify
3. Provides list of available books if needed

---

## Example Interactions

### Example 1: Simple Verse Request
**User:** "What does John 3:16 say?"

**LUMARA Response:**
```
**John 3:16 (BSB)**

16 For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.

**Context:** Jesus speaking to Nicodemus, a Pharisee, explaining the nature of salvation and God's love.

**Interpretation:** This verse emphasizes God's love as the foundation of salvation, offering eternal life through belief in Jesus.
```

### Example 2: Verse Range
**User:** "Show me Romans 8:28-30"

**LUMARA Response:**
```
**Romans 8:28-30 (BSB)**

28 And we know that God works all things together for the good of those who love Him, who are called according to His purpose.

29 For those God foreknew, He also predestined to be conformed to the image of His Son, so that He would be the firstborn among many brothers.

30 And those He predestined, He also called; those He called, He also justified; those He justified, He also glorified.

**Context:** Paul writing to the church in Rome about God's sovereignty and purpose in salvation.

**Interpretation:** These verses describe God's purpose in calling and transforming believers, emphasizing that all things work together for good for those who love God.
```

### Example 3: Topic Question
**User:** "What does the Bible say about love?"

**LUMARA Response:**
```
The Bible speaks extensively about love. Here are some key references:

- **1 Corinthians 13** - The "love chapter" describing the nature of love
- **John 15:13** - "Greater love has no one than this: to lay down one's life for one's friends"
- **1 John 4:8** - "God is love"
- **Romans 13:10** - "Love does no harm to a neighbor"

Would you like me to fetch the full text for any of these references?
```

---

## Technical Details

### API Endpoints Used

**Translations:**
- `GET /available_translations.json`
- `GET /{translation}/books.json`
- `GET /{translation}/{book}/{chapter}.json`

**Commentaries:**
- `GET /available_commentaries.json`
- `GET /c/{commentary}/{book}/{chapter}.json`

**Datasets:**
- `GET /available_datasets.json`
- `GET /d/{dataset}/{book}/{chapter}.json`

### Book Code Resolution

The service includes a comprehensive abbreviation map for common book names:
- Full names: "John", "Matthew", "Genesis"
- Abbreviations: "Jn", "Mt", "Gen"
- Numbered books: "1 Cor", "2 Tim", "1 John"

If abbreviation doesn't match, the service fetches the books list from HelloAO and matches by name similarity.

### Translation Handling

- **User-specified:** Uses translation if user mentions it (e.g., "John 3:16 (ESV)")
- **Default:** Uses BSB (Berean Study Bible) if not specified
- **Fallback:** Can use Google Search to find verses from other sources if HelloAO doesn't have the translation

---

## Integration Points

### LUMARA Assistant Cubit

**Location:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Integration:**
1. Detects Bible requests in `sendMessage()`
2. Fetches verses using `BibleRetrievalHelper.fetchVersesForRequest()`
3. Includes verses in context for both:
   - ArcLLM path (line 308)
   - Streaming path (line 645)

**Context Format:**
```
[BIBLE_VERSE_CONTEXT]
**John 3:16 (BSB)**

16 For God so loved the world...
[/BIBLE_VERSE_CONTEXT]
```

### LUMARA Master Prompt

**Location:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`

**Added Section:** "7. BIBLE REFERENCE RETRIEVAL (HelloAO API)"

Includes:
- Retrieval policy
- Reference resolution rules
- Output format guidelines
- Safety constraints
- Error handling

---

## Testing

### Test Cases

1. **Simple verse:** "John 3:16"
2. **Verse range:** "Romans 8:28-30"
3. **With translation:** "John 3:16 (ESV)"
4. **Abbreviated book:** "Jn 3:16"
5. **Numbered book:** "1 Cor 13"
6. **Full chapter:** "Genesis 1"
7. **Topic question:** "What does the Bible say about love?"

### Expected Behavior

- ✅ Fetches exact verse text from HelloAO
- ✅ Quotes verbatim (no fabrication)
- ✅ Includes translation label
- ✅ Provides context and interpretation
- ✅ Handles errors gracefully
- ✅ Falls back to web search if HelloAO unavailable

---

## Files Modified

1. **Created:**
   - `lib/arc/chat/services/bible_api_service.dart` - HelloAO API integration
   - `lib/arc/chat/services/bible_retrieval_helper.dart` - Request detection and formatting
   - `docs/BIBLE_RETRIEVAL_IMPLEMENTATION.md` - This documentation

2. **Modified:**
   - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Added Bible retrieval capability section
   - `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Integrated Bible verse fetching

---

## Future Enhancements

- [ ] Support for multiple translations in single request
- [ ] Commentary integration (Adam Clarke, etc.)
- [ ] Cross-reference dataset support
- [ ] Verse comparison across translations
- [ ] Book/chapter navigation
- [ ] Reading plans integration

---

**Status:** ✅ Implementation Complete  
**Ready for Testing:** Yes  
**Dependencies:** `http` package (already in pubspec.yaml)
