import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nativeshell/nativeshell.dart';

class DragDropWindow extends WindowBuilder {
  @override
  Widget build(BuildContext context) {
    return DragDropExample();
  }

  @override
  Future<void> initializeWindow(
      LocalWindow window, Size intrinsicContentSize) async {
    await super.initializeWindow(window, intrinsicContentSize);
    await window.setGeometry(Geometry(
      minContentSize: intrinsicContentSize,
    ));
    final parent = window.parentWindow;
    if (parent != null) {
      // open this file right next to parent
      final parentGeometry = await parent.getGeometry();
      if (parentGeometry.frameSize != null &&
          parentGeometry.frameOrigin != null) {
        await window.setGeometry(Geometry(
          frameOrigin: parentGeometry.frameOrigin!
              .translate(parentGeometry.frameSize!.width + 20, 0),
        ));
      }
    }
  }

  static DragDropWindow? fromInitData(dynamic initData) {
    if (initData is Map && initData['class'] == 'dragDrop') {
      return DragDropWindow();
    }
    return null;
  }

  static dynamic toInitData() => {
        'class': 'dragDrop',
      };
}

class DragDropExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DragSource(
                  title: 'Drag File Source',
                  data: DragData([
                    DragData.files([
                      '/fictional/file/path_1.dart',
                      '/fictional/file/path_2.dart',
                    ]),
                    customDragData({
                      'key1': 'value1',
                      'key2': '20',
                    })
                  ]),
                ),
              ),
              Container(width: 20),
              Expanded(
                child: DragSource(
                  title: 'Drag URL Source',
                  data: DragData([
                    DragData.uris([
                      Uri.parse('https://google.com'),
                    ]),
                    customDragData({
                      'key3': 'value3',
                      'key4': '50',
                    })
                  ]),
                ),
              )
            ],
          ),
          Container(height: 20),
          Expanded(
            child: DropTarget(),
          )
        ],
      ),
    );
  }
}

final customDragData = DragDataKey<Map>('custom-drag-data');

class DragSource extends StatelessWidget {
  final String title;
  final DragData data;

  const DragSource({Key? key, required this.title, required this.data})
      : super(key: key);

  void startDrag(BuildContext context) async {
    final session = await DragSession.beginWithContext(
        context: context,
        data: data,
        allowedEffects: [DragEffect.Copy, DragEffect.Link, DragEffect.Move]);
    final res = await session.waitForResult();
    print('Drop result: $res');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Builder(
        builder: (context) {
          return _buildInner(context);
        },
      ),
    );
  }

  Widget _buildInner(BuildContext context) {
    return GestureDetector(
      onPanStart: (e) {
        startDrag(context);
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.lightBlueAccent,
          ),
        ),
        child: Center(child: Text(title)),
      ),
    );
  }
}

class DropTarget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _DropTargetState();
  }
}

class _DropTargetState extends State<DropTarget> {
  DragEffect pickEffect(Set<DragEffect> allowedEffects) {
    if (allowedEffects.contains(DragEffect.Link)) {
      return DragEffect.Link;
    } else if (allowedEffects.contains(DragEffect.Copy)) {
      return DragEffect.Copy;
    } else {
      return allowedEffects.isNotEmpty ? allowedEffects.first : DragEffect.None;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      onDropOver: (event) async {
        final res = pickEffect(event.info.allowedEffects);

        final data = event.info.data;
        _files = await data.get(DragData.files);
        _uris = await data.get(DragData.uris);
        _customData = await data.get(customDragData);

        return res;
      },
      onDropExit: () {
        setState(() {
          _files = null;
          _uris = null;
          _customData = null;
          dropping = false;
        });
      },
      onDropEnter: () {
        setState(() {
          dropping = true;
        });
      },
      onPerformDrop: (e) {
        print('Performed drop!');
      },
      child: AnimatedContainer(
        decoration: BoxDecoration(
          color: dropping
              ? Colors.amber.withAlpha(50)
              : Colors.amber.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.amber,
          ),
        ),
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(20),
        child: ClipRect(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 200),
            child: Wrap(
              children: [
                Text('Drop Area'),
                if (_uris != null || _files != null || _customData != null) ...[
                  Container(
                    height: 20,
                  ),
                  if (dropping) Text(_describeDragData()),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _describeDragData() {
    final res = StringBuffer();

    for (final f in _files ?? []) {
      res.writeln('$f');
    }
    for (final uri in _uris ?? []) {
      res.writeln('$uri');
    }
    final custom = _customData;
    if (custom != null) {
      if (res.isNotEmpty) {
        res.writeln();
      }
      res.writeln('Custom Data:');
      res.writeln('$custom');
    }
    return res.toString();
  }

  List<Uri>? _uris;
  List<String>? _files;
  Map? _customData;

  bool dropping = false;
}
