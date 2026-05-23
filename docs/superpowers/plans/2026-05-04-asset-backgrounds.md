# Asset Backgrounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the baked checkerboard in both Zyntro PNG assets with the approved electric gradient background.

**Architecture:** This is a deterministic image-processing edit. A one-off local script will isolate saturated logo pixels, composite them over a generated dark teal radial glow, and overwrite only the two requested assets.

**Tech Stack:** PowerShell, .NET `System.Drawing`, PNG assets used by Flutter native splash and launcher icon tooling.

---

### Task 1: Generate Updated PNG Assets

**Files:**
- Modify: `assets/splash_z_v5.png`
- Modify: `assets/app_icon.png`

- [ ] **Step 1: Generate a dark teal glow background**

Use a 1024x1024 full-canvas diagonal gradient: deep blue/navy in the bottom-left and left side, dark teal through the middle, and dark green toward the upper-right/right side. Do not add a circular glow layer.

- [ ] **Step 2: Isolate logo pixels**

Treat high-saturation cyan/green pixels as foreground and low-saturation gray checkerboard pixels as background. Preserve anti-aliased logo edges by deriving alpha from saturation strength.

- [ ] **Step 3: Composite and overwrite the requested assets**

Write the updated PNGs to the existing asset paths so `pubspec.yaml` continues to point at the same files.

- [ ] **Step 4: Verify**

Run a metadata check to confirm both files are still 1024x1024 PNGs, then visually inspect the updated images to confirm no checkerboard remains.
