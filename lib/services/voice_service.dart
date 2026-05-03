import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// 语音识别服务
/// 使用 speech_to_text 包实现语音转文字功能，支持中文识别
class VoiceService {
  // 单例模式
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  stt.SpeechToText? _speech;
  bool _isInitialized = false;
  bool _isListening = false;

  /// 识别状态变化回调
  VoidCallback? onListeningStateChanged;

  /// 识别结果回调
  ValueChanged<String>? onResult;

  /// 最终结果回调（识别完成时触发）
  ValueChanged<String>? onFinalResult;

  /// 识别错误回调
  ValueChanged<String>? onError;

  /// 音量变化回调
  ValueChanged<double>? onSoundLevelChanged;

  /// 初始化语音识别
  Future<bool> initialize() async {
    try {
      _speech = stt.SpeechToText();
      _isInitialized = await _speech!.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      onError?.call('语音识别初始化失败: $e');
      return false;
    }
  }

  /// 确保已初始化
  Future<bool> _ensureInitialized() async {
    if (!_isInitialized || _speech == null) {
      return await initialize();
    }
    return true;
  }

  /// 开始监听
  /// [languageId] 语言代码，默认中文简体 'zh_CN'
  /// [listenMode] 监听模式
  Future<bool> startListening({
    String languageId = 'zh_CN',
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    int? pauseFor,
    int? listenFor,
    double? sampleRate,
  }) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) {
        onError?.call('语音识别未初始化');
        return false;
      }

      if (_isListening) {
        await stopListening();
      }

      _isListening = true;
      onListeningStateChanged?.call();

      await _speech!.listen(
        onResult: _handleResult,
        listenFor: listenFor != null ? Duration(seconds: listenFor) : const Duration(seconds: 60),
        pauseFor: pauseFor != null ? Duration(seconds: pauseFor) : const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          onSoundLevelChanged?.call(level);
        },
        listenMode: listenMode,
        localeId: languageId,
        sampleRate: sampleRate,
      );

      return true;
    } catch (e) {
      _isListening = false;
      onListeningStateChanged?.call();
      onError?.call('开始监听失败: $e');
      return false;
    }
  }

  /// 停止监听
  Future<void> stopListening() async {
    try {
      if (_speech != null && _isListening) {
        await _speech!.stop();
      }
    } catch (e) {
      // 忽略停止时的错误
    } finally {
      _isListening = false;
      onListeningStateChanged?.call();
    }
  }

  /// 取消监听
  Future<void> cancelListening() async {
    try {
      if (_speech != null && _isListening) {
        await _speech!.cancel();
      }
    } catch (e) {
      // 忽略取消时的错误
    } finally {
      _isListening = false;
      onListeningStateChanged?.call();
    }
  }

  /// 处理识别结果
  void _handleResult(SpeechRecognitionResult result) {
    final String recognizedText = result.recognizedWords;
    final bool isFinal = result.finalResult;

    if (recognizedText.isNotEmpty) {
      onResult?.call(recognizedText);
      if (isFinal) {
        onFinalResult?.call(recognizedText);
      }
    }
  }

  /// 处理错误
  void _handleError(SpeechRecognitionError error) {
    String errorMessage;
    switch (error.errorMsg) {
      case 'error_no_match':
        errorMessage = '未检测到语音输入';
        break;
      case 'error_audio':
        errorMessage = '音频录制失败，请检查麦克风权限';
        break;
      case 'error_network':
        errorMessage = '网络连接失败，请检查网络设置';
        break;
      case 'error_server':
        errorMessage = '语音识别服务暂时不可用';
        break;
      case 'error_not_allowed':
        errorMessage = '没有麦克风使用权限，请在设置中开启';
        break;
      case 'error_timeout':
        errorMessage = '识别超时，请重试';
        break;
      default:
        errorMessage = '语音识别错误: ${error.errorMsg}';
    }

    onError?.call(errorMessage);
  }

  /// 处理状态变化
  void _handleStatus(String status) {
    if (status == 'notListening') {
      _isListening = false;
      onListeningStateChanged?.call();
    } else if (status == 'listening') {
      _isListening = true;
      onListeningStateChanged?.call();
    }
  }

  /// 是否正在监听
  bool get isListening => _isListening;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取当前识别的文本
  String get currentText {
    if (_speech == null) return '';
    return _speech!.lastRecognizedWords;
  }

  /// 获取可用语言列表
  Future<List<LocaleName>> getAvailableLanguages() async {
    final initialized = await _ensureInitialized();
    if (!initialized) return [];

    final locales = await _speech!.locales();
    return locales
        .map((locale) => LocaleName(
              localeId: locale.localeId,
              name: locale.name,
            ))
        .toList();
  }

  /// 获取系统默认语言
  Future<String> getSystemLocale() async {
    final initialized = await _ensureInitialized();
    if (!initialized) return 'zh_CN';
    return (await _speech!.systemLocale())?.localeId ?? 'zh_CN';
  }

  /// 切换语言
  Future<bool> switchLanguage(String languageId) async {
    if (_isListening) {
      await stopListening();
    }
    return await startListening(languageId: languageId);
  }

  /// 释放资源
  void dispose() {
    if (_speech != null) {
      _speech!.stop();
    }
    _isListening = false;
    _isInitialized = false;
    onListeningStateChanged = null;
    onResult = null;
    onFinalResult = null;
    onError = null;
    onSoundLevelChanged = null;
  }
}

/// 语言信息
class LocaleName {
  /// 语言代码（如 'zh_CN'）
  final String localeId;

  /// 语言名称（如 '中文（简体）'）
  final String name;

  const LocaleName({
    required this.localeId,
    required this.name,
  });

  @override
  String toString() => '$name ($localeId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocaleName && other.localeId == localeId;
  }

  @override
  int get hashCode => localeId.hashCode;
}
