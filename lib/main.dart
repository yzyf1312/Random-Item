import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:random_item/date_fliter.dart';

// 全局变量
// 用于存储从JSON加载的数据
Map<String, dynamic>? itemListData;
bool isItemListDataEmpty = true;
String? titleData;
String? descriptionData;
String? tipsData;

// 用于存储从JSON加载的配置
double? itemFontSize;
String? themeState;
int? randomInterval;
List filters = [];

bool isTimerRunning = false;
final Set<String> historyItemSet = {};
final Set<String> toRandomItemKeySet = {};

void main() {
  runApp(const MyApp(brandColorp: Color(0xff6750a4)));
}

class MyApp extends StatelessWidget {
  final Color brandColorp;

  const MyApp({super.key, required this.brandColorp});

  // 这个组件是你的应用程序的根。
  @override
  Widget build(BuildContext context) {
    // 定义应用的主题颜色方案
    final ColorScheme defaultLightColorScheme =
        ColorScheme.fromSeed(seedColor: brandColorp);

    final ColorScheme defaultDarkColorScheme = ColorScheme.fromSeed(
        seedColor: brandColorp, brightness: Brightness.dark);

    // 使用 DynamicColorBuilder 来动态获取颜色方案
    return DynamicColorBuilder(
      builder: (ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
        return MaterialApp(
          title: 'Random Item',
          theme: ThemeData(
            colorScheme: lightColorScheme ?? defaultLightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme ?? defaultDarkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const HomePage(title: 'Random Item 主页'),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _currentItem;
  late String _currentItemKey;
  String? _lastCurrentItemKey;
  bool isInstantRefreshMode = false; // 用于切换抽取随机项目的模式

  @override
  void initState() {
    loadDataAndConfig().then((value) {
      if (toRandomItemKeySet.isNotEmpty) {
        _currentItemKey = toRandomItemKeySet.first;
      }
    });
    super.initState();
  }

  // 所谓的 Skip 只会使匹配的项目在最后被选出，并不是无法选中
  Future<void> _refreshItem() async {
    final now = DateTime.now();

    if (toRandomItemKeySet.isEmpty) return;

    if (toRandomItemKeySet.length == 1) {
      _updateCurrentItem(toRandomItemKeySet.first);
      return;
    }

    String? newKey;
    int attemptCount = 0;
    const maxAttempts = 10;

    while (attemptCount < maxAttempts) {
      newKey = randomSetItem(toRandomItemKeySet);

      if (newKey == _currentItemKey ||
          newKey == _lastCurrentItemKey ||
          historyItemSet.contains(newKey)) {
        attemptCount++;
        continue;
      }

      final shouldSkip = filters.any((filter) {
        final scheduleList = (filter["schedule"] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final filterConditions = (filter["filter"]["conditions"] as List)
            .whereType<Map<String, dynamic>>();

        return checkAllConditions(now, scheduleList) &&
            filterConditions.any((condition) =>
                getTargetDataInFormatMapItem(itemListData![newKey!],
                    key: condition["key"]) ==
                condition["value"]);
      });

      if (!shouldSkip) break;

      attemptCount++;
    }

    if (newKey != null) {
      _updateCurrentItem(newKey);
    }
  }

  void _updateCurrentItem(String key) {
    _lastCurrentItemKey = _currentItemKey;
    _currentItemKey = key;
    _currentItem = getTargetDataInFormatMapItem(itemListData![key]!);
    setState(() {});
  }

  Timer? _timer;

  void changeTimerState() {
    if (isTimerRunning) {
      _pauseTimer();
      historyItemSet.add(_currentItemKey);
      toRandomItemKeySet.remove(_currentItemKey);
      isTimerRunning = false;
    } else {
      _startTimer();
      isTimerRunning = true;
    }
    setState(() {});
  }

  void _startTimer() {
    _timer =
        Timer.periodic(Duration(milliseconds: randomInterval ?? 10), (timer) {
      _refreshItem();
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool isVisible = false;

  @override
  Widget build(BuildContext context) {
    // var sizingInformation =
    //     SizingInformation(MediaQuery.of(context).size.width);

    // var floatingActionButtonList = [
    //   FloatingActionButton(
    //     heroTag: "refreshDataFile_FloatingActionButton",
    //     onPressed: () {
    //       refreshDataFile().then((value) {
    //         setState(() {});
    //       });
    //     },
    //     tooltip: 'Refresh Data File',
    //     child: const Icon(Icons.file_open_rounded),
    //   ),
    //   const SizedBox(height: 8, width: 8),
    //   FloatingActionButton(
    //     heroTag: "cleanHistory_FloatingActionButton",
    //     onPressed: () {
    //       toRandomItemKeySet.addAll(historyItemSet);
    //       historyItemSet.clear();
    //       setState(() {});
    //     },
    //     tooltip: 'Clean History',
    //     child: const Icon(Icons.delete_rounded),
    //   ),
    //   const SizedBox(height: 8, width: 8),
    //   FloatingActionButton(
    //     heroTag: "btn5",
    //     onPressed: () {
    //       if (isTimerRunning) {
    //         changeTimerState();
    //       }
    //       Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //           builder: (context) => const HistoryPage(),
    //         ),
    //       ).then((value) {
    //         setState(() {});
    //       });
    //     },
    //     tooltip: 'View History',
    //     child: const Icon(Icons.history_rounded),
    //   ),
    // ];
    var floatingActionButtonList = [
      IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              FloatingActionButton(
                heroTag: "refreshDataFile_FloatingActionButton",
                onPressed: () {
                  refreshDataFile().then((value) {
                    setState(() {});
                  });
                },
                tooltip: 'Refresh Data File',
                child: const Icon(Icons.file_open_rounded),
              ),
              const SizedBox(height: 8, width: 8),
              FloatingActionButton(
                heroTag: "cleanHistory_FloatingActionButton",
                onPressed: () {
                  toRandomItemKeySet.addAll(historyItemSet);
                  historyItemSet.clear();
                  setState(() {});
                },
                tooltip: 'Clean History',
                child: const Icon(Icons.delete_rounded),
              ),
              const SizedBox(height: 8, width: 8),
              FloatingActionButton(
                heroTag: "btn5",
                onPressed: () {
                  if (isTimerRunning) {
                    changeTimerState();
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryPage(),
                    ),
                  ).then((value) {
                    setState(() {});
                  });
                },
                tooltip: 'View History',
                child: const Icon(Icons.history_rounded),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(
        width: 8,
        height: 8,
      ),
      FloatingActionButton(
        onPressed: () {
          setState(() {
            isVisible = !isVisible;
          });
        },
        child: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
      ),
    ];
    var contextTheme = Theme.of(context);
    const String noItemsMessage = "There is no item for random selection.";
    const String onlyOneItemMessage =
        "Are you sure you want a random selection with only one item?";
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titleData ?? widget.title,
          style: TextStyle(
            color: contextTheme.colorScheme.primary,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(),
            isItemListDataEmpty
                ? const Text(noItemsMessage)
                : _currentItem == null
                    ? Column(
                        children: [
                          Text(
                            "Click to start!",
                            style: contextTheme.textTheme.headlineMedium,
                          ),
                          const Icon(Icons.arrow_downward_rounded),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tipsData ?? "This time is",
                            style: contextTheme.textTheme.headlineMedium,
                          ),
                          SizedBox(
                            height: (itemFontSize ?? 60) * 1.5,
                            child: Text(
                              '$_currentItem',
                              style: TextStyle(
                                color: contextTheme.colorScheme.onSurface,
                                fontSize: itemFontSize ?? 60,
                              ),
                            ),
                          ),
                        ],
                      ),
            const SizedBox(
              height: 8,
            ),
            itemListData?.keys.toSet().length == 1
                ? IconButton.filledTonal(
                    onPressed: () {
                      // 清除当前的SnackBar
                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      // 显示新的SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(onlyOneItemMessage),
                          action: SnackBarAction(
                              label: "Sorry",
                              onPressed: () => ScaffoldMessenger.of(context)
                                  .removeCurrentSnackBar),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bug_report_rounded))
                : isInstantRefreshMode
                    ? IconButton.filledTonal(
                        onPressed: toRandomItemKeySet.isEmpty
                            ? null
                            : () {
                                _refreshItem().then((value) {
                                  historyItemSet.add(_currentItemKey);
                                  toRandomItemKeySet.remove(_currentItemKey);
                                });
                              },
                        tooltip: 'Refresh Item',
                        icon: const Icon(Icons.refresh_rounded),
                      )
                    : IconButton.filledTonal(
                        onPressed: toRandomItemKeySet.isEmpty
                            ? null
                            : changeTimerState,
                        tooltip:
                            isTimerRunning ? 'Start Scroll' : 'Stop Scroll',
                        icon: Icon(isTimerRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
            const Spacer(),
            Text(
              'Current mode is ${isInstantRefreshMode ? "Instant" : "Scroll"}',
              style: contextTheme.textTheme.headlineMedium,
            ),
            const SizedBox(
              height: 8,
            ),
            Switch(
              value: isInstantRefreshMode,
              onChanged: (bool value) {
                if (isTimerRunning) {
                  changeTimerState();
                }
                isInstantRefreshMode = !isInstantRefreshMode;
                setState(() {});
              },
            ),
            const SizedBox(
              height: 8,
            ),
          ],
        ),
      ),
      // floatingActionButton: sizingInformation.isMobile
      //     ? Column(
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         mainAxisSize: MainAxisSize.min,
      //         children: floatingActionButtonList,
      //       )
      //     : Row(
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         mainAxisSize: MainAxisSize.min,
      //         children: floatingActionButtonList,
      //       ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: floatingActionButtonList,
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool isVisible = false;

  @override
  Widget build(BuildContext context) {
    // var floatingActionButtonList = [
    //   FloatingActionButton(
    //     heroTag: "refreshDataFile_FloatingActionButton",
    //     onPressed: () {
    //       refreshDataFile().then((value) {
    //         setState(() {});
    //       });
    //     },
    //     tooltip: 'Refresh Data File',
    //     child: const Icon(Icons.file_open_rounded),
    //   ),
    //   const SizedBox(height: 8, width: 8),
    //   FloatingActionButton(
    //     heroTag: "cleanHistory_FloatingActionButton",
    //     onPressed: () {
    //       toRandomItemKeySet.addAll(historyItemSet);
    //       historyItemSet.clear();
    //       setState(() {});
    //     },
    //     tooltip: 'Clean History',
    //     child: const Icon(Icons.delete_rounded),
    //   ),
    // ];
    var floatingActionButtonList = [
      IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              FloatingActionButton(
                heroTag: "refreshDataFile_FloatingActionButton",
                onPressed: () {
                  refreshDataFile().then((value) {
                    setState(() {});
                  });
                },
                tooltip: 'Refresh Data File',
                child: const Icon(Icons.file_open_rounded),
              ),
              const SizedBox(height: 8, width: 8),
              FloatingActionButton(
                heroTag: "cleanHistory_FloatingActionButton",
                onPressed: () {
                  toRandomItemKeySet.addAll(historyItemSet);
                  historyItemSet.clear();
                  setState(() {});
                },
                tooltip: 'Clean History',
                child: const Icon(Icons.delete_rounded),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(
        width: 8,
        height: 8,
      ),
      FloatingActionButton(
        onPressed: () {
          setState(() {
            isVisible = !isVisible;
          });
        },
        child: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
      ),
    ];

    var contextTheme = Theme.of(context);

    // var sizingInformation =
    //     SizingInformation(MediaQuery.of(context).size.width);
    return Scaffold(
      appBar: AppBar(
        // leading: const BackButton(),
        // automaticallyImplyLeading: false,
        title: Text(
          'History',
          style: TextStyle(
            color: contextTheme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // 清除当前的SnackBar
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              // 显示新的SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Feature not implemented"),
                  action: SnackBarAction(
                      label: "OK",
                      onPressed: () =>
                          ScaffoldMessenger.of(context).removeCurrentSnackBar),
                ),
              );
            },
            icon: const Icon(Icons.output_rounded),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),
      body: historyItemSet.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded),
                  Text(
                    "No data here!",
                    style: TextStyle(fontSize: 24),
                  )
                ],
              ),
            )
          : ListView(
              children: historyItemSet
                  .map((item) => ListTile(
                        title: Text(
                          getTargetDataInFormatMapItem(itemListData![item]) ??
                              "",
                          // style: const TextStyle(fontSize: 24),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            toRandomItemKeySet.add(item);
                            historyItemSet.remove(item);
                            setState(() {});
                          },
                        ),
                      ))
                  .toList(),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: floatingActionButtonList,
      ),
      // floatingActionButton: sizingInformation.isMobile
      //     ? Column(
      //         mainAxisSize: MainAxisSize.min,
      //         crossAxisAlignment: CrossAxisAlignment.end,
      //         children: floatingActionButtonList,
      //       )
      //     : Row(
      //         mainAxisSize: MainAxisSize.min,
      //         crossAxisAlignment: CrossAxisAlignment.end,
      //         children: floatingActionButtonList,
      //       ),
    );
  }
}

class SizingInformation {
  final bool isMobile;
  final bool isTabletOrDesktop;
  final bool isDesktop;

  const SizingInformation(double width)
      : isMobile = width < 700,
        isTabletOrDesktop = width >= 700,
        isDesktop = width >= 800;
}
// 以下为测试的函数++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

// 以下为自定义的函数++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Future<Map?> loadJsonAsMap(String filePath) async {
  try {
    // 解析JSON字符串到Dart对象
    return jsonDecode(await File(filePath).readAsString());
  } catch (error) {
    return null;
  }
}

String? randomSetItem(Set<String> itemSet) {
  return itemSet.isEmpty
      ? null
      : itemSet.toList()[Random().nextInt(itemSet.length)];
}

dynamic getTargetDataInFormatMapItem(Map<String, dynamic>? formatMapItem,
    {String key = "name"}) {
  return (formatMapItem == null || formatMapItem.isEmpty)
      ? null
      : formatMapItem[key];
}

Future<String> initAppDocDir() async {
  try {
    // 获取应用程序文档目录
    Directory docDir = await getApplicationDocumentsDirectory();

    String appDocDir = path.join(docDir.path, "RandomItem");

    await initDirectory(appDocDir);

    return appDocDir;
  } catch (e) {
    // 处理可能发生的错误
    return "Error";
  }
}

Future<void> initDirectory(String directoryPath) async {
  // 创建 Directory 对象
  Directory dir = Directory(directoryPath);

  // 检查目录是否存在
  if (await dir.exists()) {
  } else {
    // 创建目录
    await dir.create(recursive: true);
  }
}

Future<List<PlatformFile>?> filePickTry(
    List<String> allowedExtensionsList) async {
  try {
    List<PlatformFile>? result = (await FilePicker.platform.pickFiles(
      type: FileType.custom, // 使用自定义文件类型
      allowedExtensions: allowedExtensionsList, // 指定允许的文件扩展名列表
      allowMultiple: true,
    ))
        ?.files;
    // 确保不返回 null
    if (result == null) {
      // 处理用户取消或发生错误的情况
      return []; // 返回空列表或根据需要进行其他处理
    }
    // 返回 List<PlatformFile>? 类型的 paths
    return result;
  } catch (error) {
    // 重新抛出错误，让调用者处理
    // 或者返回一个空列表，例如：return [];
    rethrow;
  }
}

Future<void> copyJsonFile(List<PlatformFile>? sourcePathList) async {
  if (sourcePathList != null) {
    String appDocDir = await initAppDocDir(); // 解析JSON字符串到Dart对象
    for (PlatformFile sourceFile in sourcePathList) {
      String sourcePath = sourceFile.path ?? "";
      final Map? jsonData = await loadJsonAsMap(sourcePath);
      String fileName;
      fileName =
          jsonData?['fileType'] == "config" ? "config.json" : "data.json";
      try {
        File sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          String targetJsonPath = path.join(appDocDir, fileName);
          // 复制文件
          await sourceFile.copy(targetJsonPath);
        }
      } catch (error) {
        rethrow;
      }
    }
  }
}

Future<void> loadDataAndConfig() async {
  String appDocDir = await initAppDocDir();
  Map? jsonData;
  Map? jsonConfig;

  try {
    // 加载并解析 data.json
    final String dataPath = path.join(appDocDir, "data.json");
    jsonData = await loadJsonAsMap(dataPath);
    if (jsonData != null) {
      itemListData = jsonData['data'];
      titleData = jsonData['title'];
      descriptionData = jsonData['description'];
      tipsData = jsonData['tips'];
      isItemListDataEmpty = (jsonData['data'] as Map).isEmpty;
      toRandomItemKeySet.clear();
      toRandomItemKeySet.addAll(itemListData!.keys.toSet());
    } else {
      // 如果 jsonData 为 null，重置相关数据
      itemListData = null;
      titleData = null;
      descriptionData = null;
      tipsData = null;
      isItemListDataEmpty = false;
      toRandomItemKeySet.clear();
    }

    // 加载并解析 config.json
    final String configPath = path.join(appDocDir, "config.json");
    jsonConfig = await loadJsonAsMap(configPath);
    if (jsonConfig != null) {
      Map configData = jsonConfig['data'];
      themeState = configData['themeState'];
      itemFontSize = configData['itemFontSize'].toDouble();
      randomInterval = configData['randomInterval'].toInt();
      filters.clear();
      filters.addAll(configData['filters']);
    } else {
      // 如果 jsonConfig 为 null，重置相关配置
      themeState = null;
      itemFontSize = null;
      randomInterval = null;
    }
  } catch (error) {
    // 如果发生异常，打印堆栈信息
    debugPrint(error.toString());
    // 可以选择不重置任何数据，因为已经通过 jsonData 和 jsonConfig 检查了 null 情况
    // 或者，如果需要，可以在这里添加额外的错误处理逻辑
  }
}

Future<void> refreshDataFile() async {
  await copyJsonFile(await filePickTry(["json"]));
  loadDataAndConfig();
}
