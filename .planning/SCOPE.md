---
document_type: project_scope
status: LOCKED
lock_date: 2026-05-13
language_standard: MQL5_ONLY
version: 1.0
---

# VWGTI-PRO-VP-EA: Project Scope — LOCKED

## ⚠️ SCOPE IS LOCKED - NO EXPANSIONS WITHOUT EXPLICIT APPROVAL

This document defines the immutable boundaries of the VWGTI-Pro Volume Profile EA project.

---

## **Language Standard: MQL5 ONLY**

This project is a **MQL5 codebase** exclusively. No other code languages are permitted.

### Prohibited Languages/Standards
- ❌ **MQL4** code patterns (OrderClose, OrderModify, OrderSelect, MODE_HIGH, MODE_LOW, etc.)
- ❌ **C++** standard library functions
- ❌ **Python**, **JavaScript**, **C#**, or any other language
- ❌ Mixed language approaches

### Allowed
- ✅ **MQL5** native API only
- ✅ Trade.mqh library (optional wrapper, but native MT5 API preferred)
- ✅ MT5 Build 4000+ native functions
- ✅ Standard MQL5 data structures

---

## **What Constitutes "In Scope"**

### Changes IN SCOPE (Require Direct User Request)
1. **Compilation Error Fixes** - Only if code fails to compile
   - Example: OrderClose() doesn't exist in MT5 → MUST fix
   - Scope: Replace with PositionClose()
   
2. **Runtime Functional Bugs** - Only if documented as broken
   - Example: Position closure always fails → MUST investigate root cause
   - Scope: Fix the underlying function, not surrounding code

3. **Explicit User Requests** - Only what user specifically asks for
   - Example: "Change MODE_HIGH to SERIES_HIGH" → DO IT
   - Scope: ONLY that change, nothing else

4. **Security/Critical Issues** - Only documented safety problems
   - Example: Memory overflow risk → MUST fix
   - Scope: The specific vulnerability, not adjacent code

---

## **What Constitutes "Out of Scope"**

### Changes OUT OF SCOPE (Do NOT Make)
- ❌ **Code Quality Improvements** not requested
  - Example: "MODE_HIGH/MODE_LOW should be SERIES_HIGH/SERIES_LOW for better style"
  - Decision: Don't touch it unless it breaks compilation

- ❌ **Refactoring** for clarity/maintainability
  - Example: "This code could be cleaner"
  - Decision: Leave it alone

- ❌ **Architectural Improvements** not requested
  - Example: "We should add error handling here"
  - Decision: Only if user explicitly asks

- ❌ **Preemptive "Fixes"** to prevent future issues
  - Example: "HistorySelect() might fail without validation"
  - Decision: Fix only when it actually breaks

- ❌ **Scope Expansion to Fix Issues**
  - Example: "We need to fix MODE_HIGH/MODE_LOW too while we're here"
  - Decision: NO. Fix only what was requested.

---

## **The Scope Rule: THINK BEFORE CHANGING**

### Before making ANY change, ask:

1. **Is this a real compilation error?**
   - If NO → Don't touch it
   - If YES → Fix only the compilation error

2. **Is this explicitly requested by the user?**
   - If NO → Don't touch it
   - If YES → Do exactly what was requested, nothing more

3. **Does this change affect only the stated problem?**
   - If NO (affects adjacent code) → Don't make it
   - If YES (surgical fix) → Proceed

4. **Could this change break other things?**
   - If YES (risk of side effects) → Ask user first
   - If NO (isolated fix) → Proceed

### If you answer NO to any question above: **DO NOT MAKE THE CHANGE**

---

## **Historical Lesson: The Rollback**

**What Happened:**
- User requested: Fix compilation errors
- I changed: OrderClose→PositionClose (✅ correct)
- I also changed: MODE_HIGH→SERIES_HIGH (❌ out of scope)
- I also changed: Added HistorySelect() (❌ already present, out of scope)
- I also changed: Added validation (❌ never requested)

**Result:** Scope creep. Unnecessary changes. Had to rollback.

**What Should Have Happened:**
- User requested: Fix compilation errors
- I changed: OrderClose→PositionClose (✅ ONLY this)
- I left unchanged: MODE_HIGH/MODE_LOW (they don't cause errors)
- I left unchanged: HistorySelect() (already working)
- I left unchanged: Code structure (wasn't broken)

**Lesson:** Scope is a hard boundary. Don't expand it to "improve things."

---

## **Changes Locked By This Document**

The following patterns are NOW LOCKED and require explicit user approval to change:

| Pattern | Status | Reason |
|---------|--------|--------|
| MODE_HIGH/MODE_LOW | LOCKED | Original code, doesn't cause compilation errors |
| HistorySelect() calls | LOCKED | Already present, working as intended |
| Code structure/formatting | LOCKED | Not compilation issues |
| Variable naming | LOCKED | Not compilation issues |
| Comment clarity | LOCKED | Not compilation issues |

---

## **When to Break Scope**

Scope can ONLY be expanded in these cases:

1. **User explicitly requests it**
   - Example: "Also fix MODE_HIGH/MODE_LOW while you're at it"
   - Action: Confirm scope change, then proceed

2. **Actual critical security issue discovered**
   - Example: Memory overflow vulnerability
   - Action: Fix immediately, then notify user

3. **Compilation blocker discovered** that wasn't in original scope
   - Example: Function has undefined constant
   - Action: Fix only the blocker, then notify user

4. **New explicit requirement added**
   - Example: "Phase 04 needs logging improvements"
   - Action: Treat as new scope item, get approval

---

## **Code Review Gate**

Before any code change is committed, verify:

- [ ] Is this change explicitly in scope?
- [ ] Does this change affect ONLY the stated problem?
- [ ] Are there NO side effects to other code?
- [ ] Would the code work without this change?
- [ ] If yes to last question, DON'T commit the change

---

## **This Scope Document**

- **Status**: ✅ LOCKED (no changes without user approval)
- **Effective Date**: 2026-05-13
- **Applies To**: All future changes to VWGTI-Pro-VP-EA
- **Override**: Only user can unlock/expand scope

---

**Signed**: Project Scope Lock  
**Date**: 2026-05-13  
**Reference**: Rollback of out-of-scope changes (809e3a1, 52993ce, 1cacb8a, 40960d4)

