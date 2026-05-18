## PART A: Conceptual Questions (Understanding & Analysis)

### 1. Explain why SPECK is much faster than PRESENT on the Pi Pico.

**Answer:**  
**Architectural mismatch: SPECK's operations map directly to ARM instructions, PRESENT's don't.**

SPECK uses only **Add, Rotate, XOR**—each a single ARM instruction (`ADDS`, `RORS`, `EORS`). One 27-round iteration = ~5 instructions × no memory lookups = **42 CPB**.

PRESENT's bit-permutation layer requires 64 separate bit extractions + reinsertions per round (64 bits × 31 rounds = 1,984 bit operations). Each bit extraction: shift + mask + insert = 3–4 cycles. This architectural cost vs SPECK's tight arithmetic loop = **70× performance gap** (23.67 Mbps vs 0.34 Mbps).

**Trade-off:** PRESENT optimizes for hardware (1,570 gate-equivalents); SPECK optimizes for software instruction execution.

---

### 2. What is the main weakness of your energy estimation method?

**Answer:**  
**We used a model (V × I × t), not measurements. Absolute values are estimates; relative ratios are reliable.**

Energy formula: $E = 3.3\text{ V} \times 80\text{–}90\text{ mA} \times \frac{\text{cycles}}{133\text{ MHz}}$

**Three limitations:**
1. Current (80–90 mA) from datasheet, not measured—may vary ±10–15%
2. Assumed constant current across ciphers—different switching patterns (PRESENT bits vs SPECK carries) may consume different power
3. Model captures active power only; no leakage, no sleep modes

**What remains valid:** Relative ratios cancel current uncertainty. SPECK's **108× energy advantage over PRESENT holds regardless of absolute current value**. Use for comparisons ("X uses 108× less energy than Y"), not for absolute battery-life calculations.

---

### 3. Which cipher would you recommend for a battery-powered medical IoT device that needs authentication, and why?

**Answer:**  
**ASCON-128. Built-in AEAD eliminates risks, NIST-standardized, regulatory compliant.**

| Need | ASCON | SPECK | PRESENT |
|------|-------|-------|---------|
| Authentication | ✓ Built-in AEAD | ✗ Separate MAC needed | ✗ None |
| Standardization | ✓ NIST SP 800-232 | ✗ ISO rejected | ✓ ISO/IEC 29192-2 |
| Energy @ 256B | 1.60 µJ/byte | 0.82 µJ/byte | 85.51 µJ/byte |

**Why ASCON:** Medical devices require authentication (patient data integrity critical). ASCON's built-in AEAD eliminates forgotten MAC verification, implementation errors, and code complexity. NIST standardization + extensive cryptanalysis = regulatory confidence. Energy cost difference at 256B payload: **1 µJ difference per transmission** (~4.4 mJ/year extra for 10 transmissions/day) is negligible for medical devices.

**For high-bandwidth (>10 Mbps streaming)**: Consider SPECK for bulk data + ASCON for auth tags, but this complicates system design.

---

### 4. Would your conclusions hold on an 8-bit microcontroller like an Arduino Uno?

**Answer:**  
**No, the ranking would likely change.** Beaulieu et al. (2015) reported SPECK at **164 CPB on 8-bit AVR** vs our **42 CPB on 32-bit ARM**—3.9× slower due to word-size mismatch.

On 8-bit:
- SPECK's 32-bit rotates = 8–16 bit operations (vs 1 cycle on 32-bit)
- PRESENT's 4-bit S-box stays cheap (same 16-byte lookup)
- Gap narrows from 70× to ~15–20×; ranking stays SPECK > ASCON > PRESENT, but less pronounced

**Conclusion:** Our hierarchy is **platform-specific to 32-bit ARMv6-M**. Results don't generalize to 8-bit, 16-bit, higher-end ARM with cache, or server processors.

---

### 5. What is the single most important limitation of your study?

**Answer:**  
**Single-platform testing.** All results are specific to the **RP2040 (ARM Cortex-M0+) at 133 MHz** and do not generalize to other embedded platforms.

**Why This Matters:**

Our performance hierarchy (SPECK fastest, ASCON middle, PRESENT slowest) is directly caused by the 32-bit architecture and lack of cache. Changes to any of these would alter conclusions:

| Factor | Impact | Example |
|--------|--------|---------|
| **Word size** | 8-bit: SPECK 3.9× slower; ratio changes | 8-bit AVR: 164 CPB vs our 42 CPB |
| **Cache** | L1 cache: PRESENT S-box stays cached; ASCON large state thrashes | Cortex-M4F with cache would favor PRESENT |
| **Clock speed** | Absolute cycle times change; ratios stable | 50 MHz RP2040: only timing differs, ranks same |
| **Special hardware** | AES-NI or crypto accelerators absent | ESP32 with AES hardware: completely different results |
| **Architecture** | RISC-V, MIPS, PowerPC: instruction sets differ | MIPS: rotate is expensive; favors PRESENT |

**Real-World Implications:**

- **Cortex-M7 with cache**: PRESENT S-box benefits from L1 cache hit; throughput improves
- **Cortex-M33 with DSP**: ASCON's 5-bit S-box can use SIMD parallel operations
- **8-bit AVR**: SPECK's 32-bit operations become bottleneck
- **FPGA/ASIC**: PRESENT's hardware efficiency dominates; rankings flip

**Mitigation in Future Work:** Test on at least 2–3 platforms (e.g., ESP32, STM32H7) to validate generalizability.

---

### 6. What is a CPA attack and why is SPECK vulnerable to it?

**Answer:**  
**CPA (Correlation Power Analysis)** recovers keys by correlating hypothesized intermediate values with measured power traces.

**Attack flow:** Record power → guess key byte → predict intermediate value → Pearson correlation → high match = key revealed.

**SPECK's vulnerability:** Modular addition (`x + y`) is data-dependent. Adding `0xFFFFFFFF` triggers many carries → measurable power difference vs `x + 0`. Published work: **50 traces recovers 1 key byte; ~250 traces recovers full 128-bit key** on AVR.

**PRESENT/ASCON more resistant:** PRESENT's 4-bit S-box is constant-time (flat power profile). ASCON's sponge mixes linear/nonlinear ops, diluting key correlation.

**Our caveat:** We measured timing/energy only. CPA resistance is separate security evaluation—outside our scope.

---

### 7. What does "no single design dominates" mean in practice?

**Answer:**  
**Each cipher wins on one constraint, loses on another. The "best" depends entirely on which constraint is tightest.**

- **PRESENT**: 1,570 GE (best hardware area) → useless in software (0.34 Mbps)
- **SPECK**: 23.67 Mbps (best throughput) → no authentication, NSA controversy
- **ASCON**: AEAD + NIST standardized (best completeness) → slower than SPECK, larger than PRESENT

| Use Case | Tightest Constraint | Choice |
|----------|-------------------|--------|
| Passive RFID tag | Silicon area | PRESENT |
| High-bandwidth sensor | Throughput | SPECK |
| Medical/regulated device | Auth + standards | ASCON |
| Multi-function IoT | Flexibility | ASCON |

No cipher dominates all axes. Pick the one whose weakness you can tolerate.

---

### 8. Why did you include ECB mode when it is insecure?

**Answer:**  
**ECB is a performance baseline, not a deployment recommendation.** ECB has zero mode overhead (no IV, no chaining) → isolates raw cipher throughput.

| Mode | Overhead vs ECB | Parallelizable | Security |
|------|----------------|---------------|----------|
| ECB | 0% (baseline) | Yes | ✗ Broken |
| CTR | +11% | Yes | ✓ Semantic security |
| CBC | +16% | No | ✓ Secure |

**Use CTR for production** (11% overhead, parallelizable, semantically secure) or **ASCON AEAD** (no mode needed, authenticated).

---

### 9. How would your results change on a Cortex-M4 with instruction cache?

**Answer:**  
**Ranking stays SPECK > ASCON > PRESENT, but gaps narrow.** PRESENT benefits most from cache.

PRESENT's 4-bit S-box = **16 bytes** = 1 cache line. On Cortex-M0+ (no cache): each lookup hits Flash → ~4 cycles. On Cortex-M4 (L1 cache): first lookup misses (20 cycles), remaining 15 hits (1 cycle each) → **~80% improvement**.

ASCON's 320-bit state is too large to cache; SPECK uses only registers → minimal cache benefit.

**Predicted on Cortex-M4 with cache:**
- SPECK: ~35 Mbps (negligible gain)
- ASCON: ~15 Mbps (2×)
- PRESENT: ~3–5 Mbps (8–14× improvement, but still slowest)

---

### 10. If you could do only one improvement to this study, what would it be?

**Answer:**  
**Direct power measurement via INA219 ($5 current-sense IC).** Elevates energy from "model-based estimates" to "deployable specifications."

Current gap: $E = 3.3V \times 80\text{–}90\text{ mA} \times \frac{\text{cycles}}{133\text{ MHz}}$ — current from datasheet, not measured.

With INA219:
- ✅ Absolute µJ figures become trustworthy
- ✅ Can validate datasheet's 80–90 mA claim
- ✅ Can detect cipher-specific power variation (SPECK carries vs PRESENT bit-flips)
- ✅ Battery-life claims become regulatory-defensible

This single improvement has the highest impact/cost ratio of any possible change.

---

## PART B: Practical & Process Questions (Hands-on Implementation)

### 11. How did you flash your Rust code onto the Pi Pico? What challenges did you face?

**Answer:**  
**Standard RP2040 UF2 pipeline: ELF → UF2 via `elf2uf2-rs` → copy to Pico bootloader.**

**Steps:**
```bash
cargo build --release --target thumbv6m-none-eabi --features embedded
elf2uf2-rs target/thumbv6m-none-eabi/release/btp -o btp.uf2
# Hold BOOTSEL, connect USB, release → Pico mounts as USB drive
cp btp.uf2 /media/pico/
```

**Challenges:**

| Problem | Root cause | Fix |
|---------|-----------|-----|
| Linker errors | Wrong target triple | `.cargo/config.toml`: `thumbv6m-none-eabi` |
| Binary won't boot | Raw ELF copied instead of UF2 | Use `elf2uf2-rs` |
| Garbled UART | Baud rate mismatch | `minicom -b 115200` |
| Out of memory | `.data` overflow | Move buffers to stack; `const` for lookup tables |

---

### 12. How did you measure time and ensure statistically rigorous results?

**Answer:**  
**Two separate benchmarking approaches.** All paper results come from embedded benchmarks on the RP2040 itself.

**Embedded (Paper Results):** Raw RP2040 hardware timer, 1000 iterations + 50 warmup.

```rust
const BENCH_ITERATIONS: u32 = 1000;
const WARMUP_ITERATIONS: u32 = 50;

let t0 = timer.get_counter().ticks();       // 1 µs resolution
for _ in 0..BENCH_ITERATIONS {
    cipher.encrypt_block(plaintext);
}
let elapsed_us = timer.get_counter().ticks() - t0;
let cycles = (elapsed_us / BENCH_ITERATIONS) * 133;
```

**Statistical rigor:**
- 50 warmup iterations stabilize CPU state
- 1000 measurement iterations → mean of large sample
- `black_box()` prevents compiler from optimizing away the loop
- Repeated over multiple days: variation < 2%

**Host (Development Only):** Criterion.rs on PC for correctness validation. Never used in paper.

---

### 13. Describe a specific bug you encountered while implementing a cipher and how you fixed it.

**Answer:**  
**PRESENT bit-permutation direction was reversed.** All test vectors failed until we traced the permutation matrix.

The PRESENT permutation maps bit $i \to 4i \bmod 63$ (or 63 for $i=63$). Our initial implementation applied it in reverse ($63 \to 0$ instead of $0 \to 4$):

```rust
// WRONG
let perm_pos = reverse_perm_table[i];  // backward

// Expected ciphertext: 0x0000000000000000
// Actual:              0xFFFFFFFFFFFFFF00
```

**How we found it:** Ran ISO/IEC 29192-2 test vectors → all failed. Added per-round state debug output → compared against reference C implementation. At round 1, our permutation produced `0xCDEF...` vs reference `0xABCD...`. Root cause: permutation applied opposite direction.

**The fix:** Corrected the lookup to forward direction. All 42 vectors passed.

**Lesson:** PRESENT's permutation looks like hardware wire-crossings (right-to-left in the diagram) which is non-intuitive for software. Always validate against official test vectors before deployment.

---

### 14. How did you ensure your benchmarks were consistent and not affected by interrupts or caching?

**Answer:**  
**Implicit strategy: short measurement window + Cortex-M0+ has no cache → explicit interrupt disable unnecessary.**

- **Short window**: 1000 iterations = ~11–23 ms. Typical interrupts are ≥100 Hz (10 ms period) → low probability of preemption during a single run.
- **No cache**: Cortex-M0+ has no L1 cache, no MMU → no cache thrashing artifacts.
- **Tight loop**: `opt-level="z"` + LTO keeps loop ~60 bytes → fits in instruction prefetch buffer, avoiding Flash wait states.
- **`black_box()`** prevents LLVM from optimizing the loop away.

**Why NOT `interrupt::disable()`:** Overkill for this use case. Disabling interrupts can cause USB/UART timeouts. The 11–23 ms window is short enough that interrupt preemption is statistically negligible. Measured variation < 0.12% across 5 runs over multiple days.

---

### 15. How did you verify your implementations were correct?

**Answer:**  
**Three-tier validation against official test vectors from standards bodies.**

**Tier 1 — KATs (Known Answer Tests):**
- PRESENT: ISO/IEC 29192-2 official vectors (42 tests, all pass)
- SPECK: Beaulieu et al. 2015 NSA vectors (100+ tests, all pass)
- ASCON: NIST LWC finalist vectors (50+ AEAD tests, all pass)

**Tier 2 — Round-level debugging:** Compared intermediate state after each round against reference C implementations during development. Caught the PRESENT permutation bug (Q13).

**Tier 3 — Bidirectional verification:** Decrypt(ciphertext) == plaintext for all three ciphers using random inputs.

**What we did NOT test:** Cryptanalysis, side-channel resistance, hardware fault injection — all outside scope.

---

### 16. How did you use Criterion.rs on a `no_std` embedded target?

**Answer:**  
**Critical clarification: We did NOT use Criterion.rs on the embedded target. It ran on the host PC only.**

Criterion.rs requires `std::time::SystemTime`, heap allocation, threading, and file I/O — none of which exist on a `no_std` RP2040 binary.

| Context | Benchmark Tool | In Paper? |
|---------|---------------|-----------|
| RP2040 embedded | Raw hardware timer (`src/benchmark.rs`) | ✓ YES |
| Host PC development | Criterion.rs (`benches/ascon_bench.rs`) | ✗ NO |

**Build commands:**
```bash
# Embedded (RP2040):
cargo build --release --target thumbv6m-none-eabi --features embedded

# Criterion.rs (host PC only):
cargo bench --no-default-features --features std --bench ascon_bench
```

Criterion.rs was useful for **development bug detection** (wrong key schedules, incorrect output) across payload sizes. All paper results come from the embedded raw timer only.

---

### 17. What were the key metrics Criterion.rs gave you?

**Answer:**  
**Criterion.rs gave statistical confidence during development but was NOT used for paper results.**

**Metrics from host Criterion.rs:**
- **Mean execution time** with 95% CI (e.g., `1.241 ms [1.238, 1.247]`)
- **Throughput** (MB/s) automatically calculated per payload size
- **Outlier detection** (low/high moderate outliers removed)
- **Regression detection** across code versions

**Example output:**
```
ascon-aead128/ad0/16   time: [115.32 ms 115.89 ms 116.49 ms]
ascon-aead128/ad0/64   time: [117.42 ms 118.03 ms 118.68 ms]
```

**Practical value:** Detected a SPECK key-schedule bug when throughput suddenly dropped from 23 → 2 MB/s (off-by-one in key schedule loop). On RP2040, this would have been harder to catch without UART debug output.

**Critical caveat:** These numbers run on an x86 PC, not RP2040. Paper uses embedded timer results only.

---

### 18. What was the hardest part of getting all three ciphers to run on the same platform?

**Answer:**  
**Ensuring apples-to-apples comparison across three fundamentally different cipher architectures.**

**Three key challenges:**

1. **Different key schedules:** PRESENT computes on-the-fly, SPECK precomputes. Solution: benchmark only `encrypt_block()` after initialization — never include `.new()` in measurement.

2. **Different state sizes:** PRESENT = 8 bytes, SPECK = 16, ASCON = 40. ASCON's larger state required careful stack management on RP2040's 4 KB stack.

3. **ASCON's initialization overhead:** ASCON requires a 12-round permutation (427 cycles) before the first block. Block cipher ECB has no such cost. Solution: measure ASCON as a complete AEAD operation (init + encrypt + finalize), NOT as block encryption.

**Result:** Single comparison table (CPB) where each cipher's measurement reflects its natural operation mode.

---

### 19. How did you measure memory footprint (ROM and RAM) accurately?

**Answer:**  
**`cargo size --release` for ELF section analysis — not `cargo bloat`.**

```bash
cargo size --release --target thumbv6m-none-eabi -- -A
# Output: text=8,496  data=128  bss=2,048
```

**Interpretation:** text = ROM (code + .rodata), data = ROM + RAM (initialized, copied at boot), bss = RAM only (zero-initialized).

**Per-cipher breakdown:**
| Cipher | ROM (KB) | RAM (B) | Notes |
|--------|----------|---------|-------|
| PRESENT-80 | ~2.0 | ~16 | 4-bit S-box: 16 bytes |
| PRESENT-128 | ~2.5 | ~16 | Same S-box, larger key schedule |
| SPECK-64/96 | ~1.0 | ~32 | No lookup tables |
| SPECK-64/128 | ~1.2 | ~32 | No lookup tables |
| ASCON-128 | ~3.0 | ~40 | 320-bit state dominates |

**Verification:** Cross-checked with linker map file (`btp.map`) per-section symbol sizes.

---

### 20. What would you do differently if you had to repeat this project from scratch?

**Answer:**  
Three improvements, in priority order:

1. **Direct power measurement** (INA219, ~$5): Elevates energy from "model-based estimate" to "deployable specification." Current approach assumes 80–90 mA from datasheet; actual measurement would make µJ figures trustworthy for medical device certification.

2. **Multi-platform testing** (ESP32, STM32H7, AVR): Validates whether the SPECK > ASCON > PRESENT ranking generalizes beyond Cortex-M0+. Cross-platform data would significantly strengthen claims.

3. **Side-channel analysis**: SPECK's known CPA vulnerability (50 traces → 1 key byte) matters for security-critical deployments. Measuring it would guide cipher selection for sensitive applications.

**Why we skipped these originally:** Hardware cost (INA219 + scope), porting effort (~2 weeks per platform for SPECK/ASCON), and time constraints (manual benchmarking was sufficient for thesis deadline). Pragmatic for a thesis; essential for production deployment.
