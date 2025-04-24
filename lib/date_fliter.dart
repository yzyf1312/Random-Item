import "package:flutter/material.dart";

bool checkAllConditions(DateTime now, List<Map<String, dynamic>> configList) {
  bool result = true;
  for (var config in configList) {
    try {
      // 日期检查
      if (config.containsKey('date') && !_checkDate(now, config['date'])) {
        result = false;
      }

      // 时间段检查
      if (config.containsKey('time_range') &&
          !_checkTimeRange(now, config['time_range'])) {
        result = false;
      }

      // 星期检查
      if (config.containsKey('weekdays') &&
          !_checkWeekdays(now, config['weekdays'])) {
        result = false;
      }

      // 月份检查
      if (config.containsKey('months') &&
          !_checkMonths(now, config['months'])) {
        result = false;
      }

      // 年份检查
      if (config.containsKey('years') && !_checkYears(now, config['years'])) {
        result = false;
      }
    } catch (e) {
      debugPrint('条件检查错误: $e');
      result = false;
    }
  }
  return result;
}

bool _checkDate(DateTime now, String dateStr) {
  try {
    final parts = dateStr.split('-');
    if (parts.length != 3) throw const FormatException('日期格式不正确');

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    return now.year == year && now.month == month && now.day == day;
  } catch (e) {
    debugPrint('日期解析错误: $e');
    return false;
  }
}

bool _checkTimeRange(DateTime now, Map<String, dynamic> timeRange) {
  try {
    final start = _parseTime(timeRange['start']);
    final end = _parseTime(timeRange['end']);
    final current = now.hour * 60 + now.minute;

    if (start <= end) {
      return current >= start && current <= end;
    } else {
      return current >= start || current <= end;
    }
  } catch (e) {
    debugPrint('时间段解析错误: $e');
    return false;
  }
}

int _parseTime(String timeStr) {
  final parts = timeStr.split(':');
  if (parts.length != 2) throw const FormatException('时间格式不正确');

  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw const FormatException('无效的时间值');
  }

  return hour * 60 + minute;
}

bool _checkWeekdays(DateTime now, List<dynamic> weekdays) {
  try {
    return weekdays.cast<int>().contains(now.weekday);
  } catch (e) {
    debugPrint('星期参数错误: $e');
    return false;
  }
}

bool _checkMonths(DateTime now, List<dynamic> months) {
  try {
    return months.cast<int>().contains(now.month);
  } catch (e) {
    debugPrint('月份参数错误: $e');
    return false;
  }
}

bool _checkYears(DateTime now, List<dynamic> years) {
  try {
    return years.cast<int>().contains(now.year);
  } catch (e) {
    debugPrint('年份参数错误: $e');
    return false;
  }
}
