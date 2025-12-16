# ARC Voice Mode - User Guide

## 🎤 How Voice Mode Works

ARC's voice mode uses a **conversation loop** - you tap the microphone once to start, then each subsequent tap processes your speech and gets LUMARA's response. The system automatically routes your voice input to either **Journal entries** or **Chat conversations** based on what you say.

---

## 📱 Basic Usage

### Starting a Conversation

1. **Tap the microphone button once** → Starts the conversation and begins listening 🎤
2. **Speak your message** - you'll see partial transcription appear in real-time
   - You can **pause to think** (up to 10 seconds) - it will auto-resume and continue capturing
   - All your speech accumulates into one turn until you tap the mic again

### Getting LUMARA's Response

3. **Tap the microphone a second time** → Processes your accumulated speech and gets LUMARA's response
   - ARC processes your text (scrubs PII, routes intent, calls LLM)
   - ARC responds via text-to-speech 🔊
4. **Auto-resume** → After LUMARA finishes speaking, it automatically starts listening again for your next turn

### Continuing the Conversation

5. **Speak again** (can pause/think as needed)
6. **Tap microphone again** → Processes this turn and gets LUMARA's response
7. **Repeat** as many times as you want - each tap processes that turn and gets a response

### Ending a Session

- **Tap "End Session"** → Processes your final accumulated text, saves everything, and ends the conversation
  - All turns are automatically saved during the conversation
  - End Session ensures the final turn is processed and saved before ending

---

## 🔀 Auto-Routing: Journal vs Chat

ARC automatically detects your intent and routes your voice input to the appropriate destination:

### 📔 **Routes to Journal** when you say:

- **"new journal"** or **"start a journal"** → Creates a new journal entry
- **"add to"** or **"append"** or **"update journal"** → Adds to today's journal entry
- **"summarize journal"** → Queries and summarizes your journal entries

**Example:**
- You say: *"New journal entry. Today I felt really grateful for my morning walk."*
- ARC: Creates a new journal entry with that content
- ARC responds: *"Created a new journal entry."*

### 💬 **Routes to Chat** (default) when you say:

- Anything that doesn't match journal keywords
- Questions, conversations, or general queries

**Example:**
- You say: *"What should I focus on today?"*
- ARC: Routes to chat, processes through LLM, responds conversationally
- ARC responds: *"Based on your recent entries, I'd suggest focusing on..."*

### 📁 **File Operations** (future):

- **"search file"** → Searches your files
- **"summarize paper"** or **"summarize document"** → Summarizes a file

---

## 🎨 Microphone State Indicators

The microphone button shows different colors and states to indicate what's happening:

- **🟢 Green Icon**: Ready to transcribe (idle state) - You can tap to start
- **🔴 Red Icon**: Listening (active) - Recording your speech
- **🟡 Yellow/Amber Icon**: Processing (thinking state) - ARC is processing your input
- **⚫ Grayed-Out Icon**: Speaking (TTS active) - LUMARA is speaking, microphone is disabled

**Important**: The microphone button is **disabled** (grayed out) during processing and speaking. You must wait for transcription and TTS to complete before pressing the microphone again.

---

## 🔄 Complete Flow Example

### Example: Multi-Turn Conversation

**Turn 1:**
1. **Tap mic (1st time)** → State: **Listening** 🔴 (Red icon)
2. **Speak**: *"What should I focus on today?"* (can pause to think - auto-resumes)
3. **Tap mic (2nd time)** → State: **Processing** 🟡 (Yellow icon, button disabled)
4. **ARC processes** and responds: *"Based on your recent entries, I'd suggest focusing on..."* 
5. **State changes to Speaking** ⚫ (Gray icon, button disabled)
6. **TTS completes** → State: **Ready** 🟢 (Green icon, ready for next turn)

**Turn 2:**
7. **Tap mic (3rd time)** → State: **Listening** 🔴
8. **Speak**: *"That's helpful. Can you help me plan my day?"* (can pause/think)
9. **Tap mic (4th time)** → State: **Processing** 🟡 (Yellow icon, button disabled)
10. **ARC processes** and responds: *"Sure! Let's break down your day into..."* 
11. **State changes to Speaking** ⚫ (Gray icon, button disabled)
12. **TTS completes** → State: **Ready** 🟢 (Green icon, ready for next turn)

**Turn 3:**
13. **Tap mic (5th time)** → State: **Listening** 🔴
14. **Speak**: *"Thanks, that's perfect."*
15. **Tap "End Session"** → Processes final turn, saves everything, ends conversation

### Key Points

- **First tap** = Start conversation (green → red)
- **Subsequent taps** = Process turn and get LUMARA response (red → yellow → gray → green)
- **Wait for green** = You must wait until the microphone shows green (ready) before tapping again
- **End Session** = Processes final turn and saves everything (no LUMARA response triggered)

---

## 🛡️ Privacy & Security

### PII Scrubbing

All voice transcripts are **automatically scrubbed** of personally identifiable information (PII) before being sent to the LLM or saved to your journal. This includes:
- Names
- Email addresses
- Phone numbers
- Addresses
- Other sensitive data

**What gets scrubbed:**
- ✅ Raw audio → Transcribed to text
- ✅ Text → PII scrubbed
- ✅ Scrubbed text → Sent to LLM / Saved to Journal

### Temporary Files

- Audio files are stored temporarily during transcription
- All temporary audio files are automatically deleted after processing
- Only the scrubbed text transcript is persisted

---

## 🎯 State Machine

Voice mode has 5 states that you'll see in the UI:

1. **Idle** 🟢 - Ready to start a new conversation (Green microphone icon)
2. **Listening** 🔴 - Recording your voice (Red microphone icon, pulsing)
3. **Thinking** 🟡 - Processing your message and getting LUMARA's response (Yellow/amber icon, button disabled)
4. **Speaking** ⚫ - LUMARA is responding via TTS (Grayed-out microphone icon, button disabled)
5. **Error** ⚠️ - Something went wrong

### State Transitions

```
Idle (🟢) → [Tap Mic (1st)] → Listening (🔴)
Listening (🔴) → [Tap Mic (2nd+)] → Thinking (🟡) → Speaking (⚫) → Idle (🟢)
Listening (🔴) → [Tap End Session] → Idle (🟢) (saves everything, no LUMARA response)
Any State → [Error] → Error → Idle (🟢)
```

**Important**: The microphone button is **disabled** during Thinking and Speaking states. You must wait until the state returns to Idle (green) before tapping the microphone again.

### Conversation Loop

The conversation continues until you tap "End Session":
- Each mic tap (after the first) processes that turn and gets a response
- After each response completes (TTS finishes), state returns to Idle (green/ready)
- **You must tap the microphone again** to continue the conversation (no auto-resume)
- You can have as many turns as you want
- All turns are saved automatically during the conversation

---

## 🔧 Technical Details

### Mode A (Current Implementation)

**Flow:** Speech → STT (AssemblyAI v3) → PII Scrub → LLM → Write to UI → TTS

1. **Speech-to-Text**: Real-time transcription using AssemblyAI Universal Streaming v3 (premium users)
   - WebSocket connection to `wss://streaming.assemblyai.com/v3/ws`
   - Raw binary audio streaming (16kHz, 16-bit, mono PCM)
   - Receives "Turn" messages with partial and final transcripts
   - Low-latency real-time transcription with word-level timing
2. **PII Scrubbing**: Removes sensitive information using PRISM scrubber
3. **LLM Processing**: Sends scrubbed text to EnhancedLumaraApi
4. **Write to UI**: LUMARA response is written to journal view first (creates inline box)
5. **Text-to-Speech**: Converts response to speech using flutter_tts
6. **State Management**: Returns to Idle (ready) state after TTS completes - user must tap mic again

### Voice Journal Mode Features

- **LUMARA Responses**: Displayed as purple InlineBlocks (same as regular journal mode)
- **Memory Attribution**: Shows links to past entries, drafts, images, responses (e.g., "1 memories, 100% confidence")
- **Summary Generation**: Automatically generates summaries with PII scrubbing/restoration
- **Keyword Extraction**: Uses same keyword saving mechanism as regular journal entries
- **No Duplicate Responses**: LUMARA responses saved as InlineBlocks only (no duplicate markdown text)

### Mode B (Future)

- Direct audio-to-LLM processing (not yet implemented)
- Bypasses local transcription

---

## 📝 Intent Detection Keywords

The system uses keyword-based intent detection. Here's what triggers each route:

| Intent | Keywords | Destination |
|--------|----------|-------------|
| **Journal New** | "new journal", "start a journal" | Creates new journal entry |
| **Journal Append** | "add to", "append", "update journal" | Adds to today's journal |
| **Journal Query** | "summarize journal" | Queries journal entries |
| **File Search** | "search file" | Searches files |
| **File Summarize** | "summarize paper/doc/file" | Summarizes file |
| **Chat** | (default) | Routes to main chat |

**Note:** If your phrase doesn't match any keywords, it defaults to **Chat** mode.

---

## 🎨 Visual Indicators

The microphone button shows different colors based on state:

- **Red** 🔴 - Listening (recording)
- **Orange** 🟠 - Processing/Thinking
- **Green** 🟢 - Ready/Idle
- **Pulsing animation** - Active recording state

---

## ⚠️ Troubleshooting

### Microphone Not Working

1. **Check permissions**: Settings → Privacy & Security → Microphone → ARC should be enabled
2. **Restart the app** if permissions were just granted
3. **Check device microphone** isn't being used by another app

### No Response from ARC

1. **Check internet connection** - LLM requires network access
2. **Check if you're in a conversation** - Make sure you've started a chat session
3. **Try speaking more clearly** - Background noise can affect transcription

### Transcription Issues

1. **Speak clearly** and at a normal pace
2. **Reduce background noise**
3. **Check microphone permissions** are granted
4. **Restart voice mode** if transcription seems stuck

---

## 💡 Tips for Best Results

1. **First tap starts, subsequent taps get responses**: Remember - first tap begins listening, second tap processes and gets LUMARA's response
2. **Pause to think**: You can pause up to 10 seconds while speaking - it will auto-resume and continue capturing
3. **Wait for LUMARA to finish**: After LUMARA responds, it automatically resumes listening - you don't need to tap again
4. **End Session saves everything**: All turns are saved automatically, but End Session ensures the final turn is processed
5. **Be specific with journal intents**: Say "new journal" or "add to journal" clearly if you want journal routing
6. **Speak naturally** - the system handles normal speech patterns well
7. **Check the partial transcript** to see if your words are being captured correctly

---

## 🔮 Future Enhancements

- [ ] LLM-based intent detection (more accurate than keywords)
- [ ] Silence detection (auto-stop after 2 seconds of silence)
- [ ] Context peek (shows what context is being used)
- [ ] Session transcript export to Journal
- [ ] Voice confirmation for destructive journal edits
- [ ] Mode B implementation (direct audio-to-LLM)

---

## 📚 Related Documentation

- **Technical Implementation**: `lib/arc/chat/voice/VOICE_MODE_PUSH_TO_TALK.md`
- **Permissions Setup**: See onboarding permissions page
- **PII Scrubbing**: Uses existing PRISM scrubber service

---

*Last updated: December 13, 2025 (AssemblyAI v3 migration)*
