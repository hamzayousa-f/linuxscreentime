import 'dart:io';
import 'package:flutter/material.dart';

class IconManager {
  // Common Arch Linux system app icon paths
  static const List<String> iconSearchPaths = [
    '/usr/share/icons/hicolor/48x48/apps/',
    '/usr/share/icons/hicolor/scalable/apps/',
    '/usr/share/icons/pixmaps/',
    '~/.local/share/icons/',
  ];

  /// Resolves an app process string to an active system image file
  static Widget getAppIcon(String appProcessName, {double size = 24.0}) {
    final String cleanName = appProcessName.toLowerCase().trim();

    // Hardcoded dictionary mappings for binary names to standard desktop icons
    final Map<String, String> iconMap = {
      'zen-browser': 'zen',
      'zen': 'zen',
      'code': 'vscode',
      'visual-studio-code': 'vscode',
      'kitty': 'kitty',
      'foot': 'foot',
      'alacritty': 'alacritty',
      'thunar': 'system-file-manager',
      'discord': 'discord',
      'spotify': 'spotify',
      'chromium': 'chromium',
    };

    final String targetIconName = iconMap[cleanName] ?? cleanName;

    for (String basePath in iconSearchPaths) {
      if (basePath.startsWith('~')) {
        final String? home = Platform.environment['HOME'];
        if (home != null) {
          basePath = basePath.replaceFirst('~', home);
        }
      }

      final File pngFile = File('$basePath$targetIconName.png');
      if (pngFile.existsSync()) {
        return Image.file(pngFile,
            width: size, height: size, fit: BoxFit.contain);
      }
    }

    return Icon(
      _getFallbackIconData(cleanName),
      size: size,
      color: Colors.purpleAccent.withOpacity(0.8),
    );
  }

  static IconData _getFallbackIconData(String name) {
    if (name.contains('term') || name == 'kitty' || name == 'alacritty') {
      return Icons.terminal_rounded;
    } else if (name.contains('browser') || name == 'zen' || name == 'chrome') {
      return Icons.language_rounded;
    } else if (name.contains('code') || name == 'nvim') {
      return Icons.code_rounded;
    } else if (name.contains('file') || name == 'thunar') {
      return Icons.folder_rounded;
    }
    return Icons.window_rounded;
  }
}
