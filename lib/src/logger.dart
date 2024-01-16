import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

class Logger {
  static final Logger _singleton = Logger._internal();

  int numberTotalEntriesWritten = 0;
  int maxWriteEntries = 1000;

  factory Logger() {
    return _singleton;
  }

  Logger._internal();
  String? apiKey;
  String? appShort;
  String? version;
  String? tkuuid;

  String lastError = "";
  var isBusy = false;

  static initialize({required String appName, required String apiKey, required String tkuuid}) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    _singleton.apiKey = apiKey;
    _singleton.appShort = appName;
    _singleton.version = version;
    _singleton.tkuuid = tkuuid;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _handleQueue();
    });
  }

  static _handleQueue() async {
    final queue = _singleton.messageQueue;
    if (queue.isEmpty) {
      return;
    }
    if (_singleton.isBusy) {
      _singleton.lastError = "Queue busy";
      return;
    }

    final messageBody = queue.first;
    _singleton.isBusy = true;
    final success = await _logToGTA(messageBody);

    if (success) {
      _singleton.lastError = "";
      queue.removeAt(0);
    }
    _singleton.isBusy = false;
  }

  static setMaxEntries(int max) {
    _singleton.maxWriteEntries = max;
  }

  var messageQueue = [];
  int sending_errors = 0;
  var doNotAcceptMoreMessages = false;

  static _logMessage(String message, String severity) async {
    assert(_singleton.apiKey != null, "Queue not initialized.");
    if (_singleton.doNotAcceptMoreMessages) {
      print("Queue bloicked.");
      return;
    }
    _singleton.numberTotalEntriesWritten++;
    if (_singleton.numberTotalEntriesWritten > _singleton.maxWriteEntries) {
      print("Maximum numbers to send reached.");
      _singleton.doNotAcceptMoreMessages = true;
      _singleton.lastError = "Maxmimum number of Messages reached.";
    }
    debugPrint(message);
    final now = DateTime.now();
    final appTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.toUtc()).toString();
    final body = jsonEncode({
      'log': message,
      'app': _singleton.appShort!,
      'version': _singleton.version!,
      'severity': severity,
      'tkuuid': _singleton.tkuuid!,
      'apptime': appTime,
      'queue': _singleton.messageQueue.length,
      'last_error': _singleton.lastError
    });
    _singleton.messageQueue.add(body);
  }

  static Future<bool> _logToGTA(body) async {
    final url = Uri.parse('http://logger.madetk.com/log?apikey=${_singleton.apiKey}');
    const headers = {'Content-type': 'application/json; charset=UTF-8', 'Accept': '*/*'};
    try {
      final res = await http.post(url, headers: headers, body: body);
      return (res.statusCode == 200);
    } catch (e) {
      _singleton.lastError = e.toString();
      return false;
    }
  }

  static info(String message) {
    _logMessage(message, 'info');
  }

  static warning(String message) {
    _logMessage(message, 'warning');
  }

  static error(String message) {
    _logMessage('⛔️$message', 'error');
  }
}
