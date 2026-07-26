# -*- coding: utf-8 -*-
"""
disable_stt.py - Replace the ocw-stt (local speech-to-text) submodule with an
empty no-op stub. This removes the dependency on CMake + Clang + whisper-rs-sys
native compilation, so the build succeeds without a C++ toolchain.

The stub keeps the EXACT same public API (struct names, method signatures,
consts) that surfaces/gui/src-tauri/src/lib.rs uses, so that file needs NO
changes. Only the voice-input feature becomes a no-op.

Run this ONLY as a fallback when the full build fails at the STT/whisper CMake step.
"""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
STT = os.path.join(ROOT, "openworker", "stt")
STTCARGO = os.path.join(STT, "Cargo.toml")
STTLIB = os.path.join(STT, "src", "lib.rs")

STUB_CARGO = """[package]
name = "ocw-stt"
version = "0.1.0"
description = "STUB: local speech-to-text disabled for Windows build"
edition = "2021"
rust-version = "1.77"
license = "MIT"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
"""

STUB_LIB = """// STUB ocw-stt - voice input disabled in this Windows build.
// Keeps the same public API so surfaces/gui needs no changes.
use serde::Serialize;
use std::path::{Path, PathBuf};

pub const DEFAULT_MODEL_BYTES: u64 = 147_964_211;
pub const DEFAULT_MODEL_SHA256: &str =
    "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002";

#[derive(Debug, Clone, Serialize)]
pub struct DictationStatus {
    pub recording: bool,
    pub model_installed: bool,
    pub model_verified: bool,
    pub test_passed: bool,
    pub download_in_progress: bool,
    pub model_name: &'static str,
    pub model_bytes: u64,
}

#[derive(Debug, Clone, Copy, Serialize)]
pub struct DownloadProgress {
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
}

/// No-op dictation session manager (voice input disabled).
pub struct Dictation {
    model_path: PathBuf,
}

impl Dictation {
    pub fn new(model_dir: impl Into<PathBuf>) -> Self {
        Dictation { model_path: model_dir.into() }
    }

    pub fn status(&self) -> DictationStatus {
        DictationStatus {
            recording: false,
            model_installed: false,
            model_verified: false,
            test_passed: false,
            download_in_progress: false,
            model_name: "n/a",
            model_bytes: DEFAULT_MODEL_BYTES,
        }
    }

    pub fn model_path(&self) -> &Path {
        &self.model_path
    }

    pub fn install_default_model(&self) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn install_default_model_with_progress(
        &self,
        _on_progress: impl FnMut(DownloadProgress),
    ) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn verify_default_model(&self) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn cancel_model_download(&self) {}

    pub fn mark_test_passed(&self) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn delete_default_model(&self) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn start(&self) -> Result<(), String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn stop_and_transcribe(&self) -> Result<String, String> {
        Err("voice input disabled in this Windows build".to_string())
    }

    pub fn input_level(&self) -> f32 {
        0.0
    }

    pub fn cancel(&self) {}
}
"""


def main():
    print("Replacing ocw-stt with empty stub (voice input disabled)...")
    if not os.path.isdir(STT):
        print("  [skip] stt folder not found at:", STT)
        return
    with open(STTCARGO, "w", encoding="utf-8") as f:
        f.write(STUB_CARGO)
    os.makedirs(os.path.dirname(STTLIB), exist_ok=True)
    with open(STTLIB, "w", encoding="utf-8") as f:
        f.write(STUB_LIB)
    print("  [done] stt/src/lib.rs + Cargo.toml replaced with stub.")
    print("         The build no longer needs CMake / Clang / whisper-rs-sys.")


if __name__ == "__main__":
    main()
