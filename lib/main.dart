import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

// 全局变量
// 用于存储从JSON加载的数据
Map? itemListData;
String? titleData;
String? descriptionData;
String? tipsData;
// 用于存储从JSON加载的配置
double? itemFontSize;
String? themeState;
int? randomInterval;

bool isTimerRunning = false;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

// 这个组件是你的应用程序的根。
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ThemeData themeData =
            MediaQuery.of(context).platformBrightness == Brightness.dark
                ? ThemeData(
                    // 使用 darkDynamic 作为主题的颜色方案
                    colorScheme: darkDynamic ?? ThemeData.dark().colorScheme,
                    useMaterial3: true,
                  )
                : ThemeData(
                    // 使用 lightDynamic 作为主题的颜色方案
                    colorScheme: lightDynamic ?? ThemeData.light().colorScheme,
                    useMaterial3: true,
                  );

        return MaterialApp(
          title: 'Random Item',
          theme: themeData,
          home: const HomePage(title: 'Random Item 主页'),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

// 这个组件是你的应用程序的首页。它是有状态的，意味着它有一个 State 对象（下面定义），其中包含影响其外观的字段。

// 这个类是状态的配置。它保存由父组件（在这个例子中是 App 组件）提供的值（在这个例子中是标题），并由 State 的 build 方法使用。Widget 子类中的字段总是标记为 "final"。

  final String title;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  // 用于存储当前显示的随机元素
  dynamic _currentItem;

  @override
  void initState() {
    // 程序启动时加载JSON数据
    loadDataAndConfig();
    super.initState();
  }

  void _refreshDataFile() async {
    await copyJsonFile(await filePickTry());
    loadDataAndConfig();
    setState(() {});
  }

  Future<void> _refreshItem() async {
    // 随机抽取元素
    _currentItem = getTargetDataInFormatMapItem(randomMapItem(itemListData));
    setState(() {
      // 这个调用 setState 告诉 Flutter 框架这个 State 中的某些东西已经改变了，这会导致重新运行下面的 build 方法，以便显示屏可以反映更新后的值。
      // 如果我们改变值而没有调用 setState()，那么 build 方法将不会被再次调用，因此看起来什么也没有发生。
    });
  } // 添加一个方法来处理导航到设置页面的动作

  // Timer 相关函数
  Timer? _timer;

  void changeTimerState() {
    if (isTimerRunning) {
      _pauseTimer();
      isTimerRunning = false;
    } else {
      _startTimer();
      isTimerRunning = true;
    }
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: randomInterval ?? 10),
        (timer) async {
      await _refreshItem();
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // 每次调用 setState 时，这个方法都会重新运行，例如上面 _refreshItem 方法所做的那样。

    // Flutter 框架已经优化，使得重新运行 build 方法非常快速，这样你就可以重建任何需要更新的内容，而不必单独更改 widget 的实例。
    return Scaffold(
      appBar: AppBar(
        // 在这里，我们从由 App.build 方法创建的 MyHomePage 对象中获取值，
        // 并使用它来设置我们的 appbar 标题。
        title: Text(
          titleData ?? widget.title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary, // 使用主题中的主要颜色
          ),
        ),
      ),
      body: Center(
        child: Column(
          // Column 也是一个布局组件。它接收一组子组件列表，
          // 并将它们垂直排列。默认情况下，它会根据其子组件的水平尺寸来调整自己的尺寸，
          // 并尝试与父组件的高度一致。
          //
          // Column 有各种属性来控制它如何调整自己的尺寸以及如何定位其子组件。
          // 在这里，我们使用mainAxisAlignment来垂直居中子组件；这里的主轴是垂直轴，
          // 因为Column是垂直的（交叉轴将是水平的）。
          //
          // 试试这个：调用“调试绘制”（在IDE中选择“切换调试绘制”动作，
          // 或在控制台中按“p”），以查看每个组件的线框图。
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              tipsData ?? "This time is",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(
              height: (itemFontSize ?? 60) * 1.5,
              child: Text(
                '$_currentItem',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, // 使用主题中的主要颜色
                  fontSize: itemFontSize ?? 60, // 设置文字大小为60像素
                ),
              ),
            ),
            SizedBox(
              width: 60.0, // 设置容器的宽度
              height: 60.0, // 设置容器的高度
              // 添加圆形裁剪
              child: ClipOval(
                child: Material(
                  color:
                      Theme.of(context).colorScheme.primaryContainer, // 设置背景颜色
                  child: IconButton(
                    onPressed: changeTimerState,
                    tooltip: isTimerRunning ? 'Start' : 'Stop',
                    icon: Icon(isTimerRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer, // 图标颜色
                    iconSize: 24, // 图标大小
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end, // 将按钮放置在屏幕的末端
        children: <Widget>[
          FloatingActionButton(
            heroTag: 'refreshDataFileFloatingActionButton',
            onPressed: _refreshDataFile,
            tooltip: 'Refresh Data File',
            child: const Icon(Icons.file_open_rounded),
          ),
          const SizedBox(width: 16.0), // 空间间隔
          FloatingActionButton(
            heroTag: 'refreshItemFloatingActionButton',
            onPressed: _refreshItem,
            tooltip: 'Refresh Item',
            child: const Icon(Icons.refresh_rounded),
          ),
        ],
      ), // 这个尾随逗号使得自动格式化对于构建方法更加友好。
    );
  }
}

// 以下为自定义的函数++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Future<Map?> loadJsonAsMap(String filePath) async {
  try {
    // 解析JSON字符串到Dart对象
    return jsonDecode(await File(filePath).readAsString());
  } catch (error) {
    return null;
  }
}

Map? randomMapItem(Map? itemListMap) {
  return (itemListMap == null || itemListMap.isEmpty)
      ? null
      : itemListMap[
          itemListMap.keys.toList()[Random().nextInt(itemListMap.length)]];
}

String? getTargetDataInFormatMapItem(Map? formatMapItem) {
  return (formatMapItem == null || formatMapItem.isEmpty)
      ? null
      : formatMapItem['name'];
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

Future<List<PlatformFile>?> filePickTry() async {
  try {
    List<PlatformFile>? result = (await FilePicker.platform.pickFiles(
      type: FileType.custom, // 使用自定义文件类型
      allowedExtensions: ['json'], // 指定允许的文件扩展名列表
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
    for (PlatformFile i in sourcePathList) {
      String sourcePath = i.path ?? "";
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
    } else {
      // 如果 jsonData 为 null，重置相关数据
      itemListData = null;
      titleData = null;
      descriptionData = null;
      tipsData = null;
    }

    // 加载并解析 config.json
    final String configPath = path.join(appDocDir, "config.json");
    jsonConfig = await loadJsonAsMap(configPath);
    if (jsonConfig != null) {
      Map configData = jsonConfig['data'];
      themeState = configData['themeState'];
      itemFontSize = configData['itemFontSize'].toDouble();
      randomInterval = configData['randomInterval'].toInt();
    } else {
      // 如果 jsonConfig 为 null，重置相关配置
      themeState = null;
      itemFontSize = null;
      randomInterval = null;
    }
  } catch (error) {
    // 如果发生异常，打印堆栈信息
    print(error.toString());
    // 可以选择不重置任何数据，因为已经通过 jsonData 和 jsonConfig 检查了 null 情况
    // 或者，如果需要，可以在这里添加额外的错误处理逻辑
  }
}
