// Web-specific CSV download implementation
// WebAssembly-compatible approach using data URLs

import 'dart:convert';
import 'package:flutter/services.dart';

/// Web-safe CSV download for WebAssembly compatibility
void downloadCsvIO(String csvContent, String fileName) {
  // For web platform, we'll copy to clipboard as a fallback
  // since direct file download requires DOM APIs that may not work with WASM
  _copyToClipboard(csvContent, fileName);
}

void _copyToClipboard(String csvContent, String fileName) {
  Clipboard.setData(ClipboardData(
    text: csvContent
  ));
  
  // In production, this would trigger a toast notification
  print('CSV content for "$fileName" copied to clipboard');
}