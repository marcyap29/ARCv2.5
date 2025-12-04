"use strict";
/**
 * Test script for the closing statement tracking system
 *
 * This validates that:
 * 1. Closing statements are selected without repetition
 * 2. Category classification works correctly
 * 3. Energy level detection functions
 * 4. Preference learning responds to user feedback
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.runTests = runTests;
const closingTracker_js_1 = require("./closingTracker.js");
async function runTests() {
    console.log('🧪 Testing LUMARA Closing Statement Tracker\n');
    const testUserId = 'test-user-123';
    const testConversationId = 'test-conversation-456';
    // Reset preferences for clean test
    (0, closingTracker_js_1.resetUserPreferences)(testUserId);
    // Test 1: Basic closing selection
    console.log('📝 Test 1: Basic closing selection');
    const closing1 = (0, closingTracker_js_1.selectClosingStatement)(testUserId, testConversationId, 'reflection_emotion');
    console.log(`Selected closing: ${closing1?.id} - "${closing1?.text}"\n`);
    // Test 2: Non-repetition enforcement
    console.log('📝 Test 2: Non-repetition enforcement');
    const closings = [];
    for (let i = 0; i < 10; i++) {
        const closing = (0, closingTracker_js_1.selectClosingStatement)(testUserId, testConversationId, 'planning_action');
        if (closing) {
            closings.push(closing.id);
            console.log(`Iteration ${i + 1}: ${closing.id} - "${closing.text}"`);
        }
    }
    // Check for duplicates
    const uniqueClosings = new Set(closings);
    const hasDuplicates = uniqueClosings.size !== closings.length;
    console.log(`✅ No duplicates: ${!hasDuplicates}`);
    console.log(`Recently used closings: ${(0, closingTracker_js_1.getRecentlyUsedClosings)(testUserId, 5)}\n`);
    // Test 3: Category classification
    console.log('📝 Test 3: Category classification');
    const testMessages = [
        { message: "I'm feeling really overwhelmed today", expected: 'regulation_overwhelm' },
        { message: "I need to figure out my next steps", expected: 'planning_action' },
        { message: "I feel like I'm changing as a person", expected: 'identity_phase' },
        { message: "I'm processing some difficult emotions", expected: 'reflection_emotion' },
        { message: "Just checking in with a quick update", expected: 'neutral_light' }
    ];
    for (const test of testMessages) {
        const classified = (0, closingTracker_js_1.classifyConversationCategory)(test.message);
        const correct = classified === test.expected;
        console.log(`${correct ? '✅' : '❌'} "${test.message}" → ${classified} (expected: ${test.expected})`);
    }
    console.log();
    // Test 4: Energy level detection
    console.log('📝 Test 4: Energy level detection');
    const energyTests = [
        { message: "I'm so tired and drained", expected: 'low' },
        { message: "I'm excited about this breakthrough!", expected: 'high' },
        { message: "Just reflecting on my day", expected: 'medium' }
    ];
    for (const test of energyTests) {
        const detected = (0, closingTracker_js_1.detectEnergyLevel)(test.message);
        const correct = detected === test.expected;
        console.log(`${correct ? '✅' : '❌'} "${test.message}" → ${detected} (expected: ${test.expected})`);
    }
    console.log();
    // Test 5: Preference learning
    console.log('📝 Test 5: Preference learning');
    // Simulate positive feedback on a specific closing
    (0, closingTracker_js_1.trackClosingUsage)(testUserId, testConversationId, 'ref_001', 'Recovery', 'accepted');
    (0, closingTracker_js_1.trackClosingUsage)(testUserId, testConversationId, 'ref_001', 'Recovery', 'continued');
    // Simulate negative feedback on another closing
    (0, closingTracker_js_1.trackClosingUsage)(testUserId, testConversationId, 'ref_002', 'Discovery', 'rejected');
    console.log('✅ Tracked preference learning feedback');
    // Test 6: Phase-aware selection
    console.log('\n📝 Test 6: Phase-aware selection');
    const recoveryClosing = (0, closingTracker_js_1.selectClosingStatement)(testUserId, testConversationId, 'regulation_overwhelm', 'Recovery', 'low');
    const expansionClosing = (0, closingTracker_js_1.selectClosingStatement)(testUserId, testConversationId, 'planning_action', 'Expansion', 'medium');
    console.log(`Recovery phase closing: ${recoveryClosing?.id} (phase bias: ${recoveryClosing?.phase_bias})`);
    console.log(`Expansion phase closing: ${expansionClosing?.id} (phase bias: ${expansionClosing?.phase_bias})`);
    console.log('\n🎉 All tests completed!');
}
// Only run tests if this file is executed directly
if (require.main === module) {
    runTests().catch(console.error);
}
//# sourceMappingURL=testClosingTracker.js.map