import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'dart:async';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.color,
    required this.text,
    this.onTap,
  });

  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 150.0,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _deviceConnected;
  int times = 0;
  List<String> lastLog = [""];

  double inputSL1 = 1;
  double inputSL2 = 1;

  Timer? _timerS1;
  Timer? _timerS2;

  Future _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

  bool get btIsConected => _connection?.isConnected ?? false;

  void _receiveData() {
    _connection?.input?.listen((event) {
      if (String.fromCharCodes(event) == "p") {
        setState(() => times = times + 1);
      }
    });
  }

  void _sendData(int data) {
    var result = Uint8List(1);

    result[0] = data;

    if (_connection?.isConnected ?? false) {
      print(result);
      setState(() {
        lastLog.add("${DateTime.now().toLocal()}|$result");
        if (lastLog.length > 3) {
          lastLog.removeAt(0);
        }
      });
      _connection?.output.add(result);
    }
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          setState(() => _bluetoothState = false);
          break;
        case BluetoothState.STATE_ON:
          setState(() => _bluetoothState = true);
          break;
        // case BluetoothState.STATE_TURNING_OFF:
        //   break;
        // case BluetoothState.STATE_TURNING_ON:
        //   break;
      }
    });
  }

  double? degree;
  double? dist;
  final int period1 = 30;

  @override
  Widget build(BuildContext context) {
    FlutterSliderTrackBar trackbarStyle = FlutterSliderTrackBar(
      inactiveTrackBar: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // color: Theme.of(context).colorScheme.onBackground,
        color: Theme.of(context).colorScheme.primary,
        // backgroundBlendMode: Colors.red
        // border: Border.all(width: 14, color: Theme.of(context).colorScheme.primary.withOpacity(1)),
      ),
      activeTrackBarHeight: 18,
      inactiveTrackBarHeight: 20,
      centralWidget: Container(
        width: 22,
        height: 22,
        // color: Colors.red,
      ),
      activeTrackBar: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Theme.of(context).colorScheme.primary.withOpacity(0)),
    );

    Future loadBleBTNFunc() async {
      if (!_bluetoothState) {
        await _bluetooth.requestEnable();
      }
      if (!_bluetoothState) {
        return;
      }
      showDialog(
          context: context,
          builder: (context) {
            return const Center(child: CircularProgressIndicator());
          });
      if (btIsConected) {
        await _connection?.finish();
        setState(() => _deviceConnected = null);
        Navigator.of(context).pop();
        return;
      }

      await _getDevices();
      Navigator.of(context).pop();

      showModalBottomSheet(
          context: context,
          useSafeArea: true,
          constraints: const BoxConstraints(
            maxHeight: 650,
          ),
          scrollControlDisabledMaxHeightRatio: 1,
          builder: (context) {
            return SizedBox(
              height: 1000,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: Text(
                            "Dispositivos Bluetooth",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                              // color: Colors.black54
                            ),
                          ),
                        ),
                        IconButton(
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () async {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return const Center(child: CircularProgressIndicator());
                                  });
                              await _getDevices();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.refresh)),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final device in _devices)
                          ListTile(
                            title: Text(device.name ?? device.address),
                            trailing: TextButton(
                              child: const Text('conectar'),
                              onPressed: () async {
                                try {
                                  setState(() => _isConnecting = true);
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return const Center(child: CircularProgressIndicator());
                                      });
                                  _connection = await BluetoothConnection.toAddress(device.address);
                                  _sendData(255);
                                  _deviceConnected = device;
                                  _devices = [];
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();

                                  _receiveData();
                                } catch (e) {
                                  print(e);
                                }

                                _isConnecting = false;
                                setState(() {});
                              },
                            ),
                          )
                      ])),
                    )
                  ]),
                ),
              ),
            );
          });
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('FIEE 2024-II'),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   backgroundColor: Colors.pink,
      //   selectedItemColor: Colors.white,
      //   unselectedItemColor: const Color.fromARGB(96, 0, 0, 0),
      //   unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      //   selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      //   // currentIndex: _currIndex,
      //   onTap: (int newIdx) {
      //     // setState(() {
      //     // _currIndex = newIdx;
      //     // });
      //   },
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
      //     BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ticket"),
      //     // BottomNavigationBarItem(icon: Icon(Icons.home), label: "Cursos"),
      //     BottomNavigationBarItem(icon: Icon(Icons.person), label: "usuario")
      //   ],
      // ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                // decoration: BoxDecoration(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.05),),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Center(
                            child: IconButton(
                              onPressed: loadBleBTNFunc,
                              icon: const Icon(Icons.bluetooth),
                              style: ButtonStyle(
                                  // iconSize: !ctxWatch.btIsConected ? const MaterialStatePropertyAll(100) : null,
                                  backgroundColor: btIsConected
                                      ? MaterialStatePropertyAll(Theme.of(context).colorScheme.primary.withOpacity(0.4))
                                      : MaterialStatePropertyAll(Theme.of(context).colorScheme.onBackground.withOpacity(0.1))),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text("Conectado a: ${_deviceConnected?.name ?? "ninguno"}"),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.05),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              // child: SingleChildScrollView(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                // decoration: BoxDecoration(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.05),),
                                child: Column(
                                  children: [
                                    for (var t in lastLog) Text(">$t"),
                                    Center(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Column(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 180,
                                                child: FlutterSlider(
                                                  onDragStarted: (handlerIndex, lowerValue, upperValue) {
                                                    if (_timerS1 != null) {
                                                      _timerS1!.cancel();
                                                      _timerS1 = null;
                                                    }
                                                    _timerS1 = Timer.periodic(Duration(milliseconds: period1), (timer) {
                                                      print("SHOULDER:$inputSL1");
                                                      if (inputSL1 == 2) {
                                                        _sendData(62);
                                                      } else if (inputSL1 == 1) {
                                                        _sendData(61);
                                                      } else {
                                                        _sendData(60);
                                                      }
                                                    });
                                                  },
                                                  onDragCompleted: (handlerIndex, lowerValue, upperValue) {
                                                    if (lowerValue == 2) {
                                                      _sendData(62);
                                                    } else if (lowerValue == 1) {
                                                      _sendData(61);
                                                    } else {
                                                      _sendData(60);
                                                    }
                                                    if (_timerS1 != null) {
                                                      _timerS1!.cancel();
                                                      _timerS1 = null;
                                                    }
                                                  },
                                                  handlerWidth: 46,
                                                  jump: true,
                                                  trackBar: trackbarStyle,
                                                  handler: FlutterSliderHandler(
                                                    child: Text("A"),
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.background,
                                                        borderRadius: BorderRadius.circular(40),
                                                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 5)),
                                                  ),
                                                  axis: Axis.vertical,
                                                  rtl: true,
                                                  values: [inputSL1],
                                                  max: 2,
                                                  min: 0,
                                                  // trackBar: FlutterSliderTrackBar(inactiveDisabledTrackBarColor: Colors.red),
                                                  step: const FlutterSliderStep(step: 1),
                                                  onDragging: (handlerIndex, lowerValue, upperValue) {
                                                    if (inputSL1 != lowerValue) {
                                                      print(lowerValue);
                                                      setState(() {
                                                        inputSL1 = lowerValue;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              Text("$inputSL1")
                                            ],
                                          ),
                                          const SizedBox(width: 50),
                                          Column(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 180,
                                                child: FlutterSlider(
                                                  onDragStarted: (handlerIndex, lowerValue, upperValue) {
                                                    if (_timerS2 != null) {
                                                      _timerS2!.cancel();
                                                      _timerS2 = null;
                                                    }
                                                    _timerS2 = Timer.periodic(Duration(milliseconds: period1), (timer) {
                                                      print("ELBOW:$inputSL2");
                                                      if (inputSL2 == 2) {
                                                        _sendData(52);
                                                      } else if (inputSL2 == 1) {
                                                        _sendData(51);
                                                      } else {
                                                        _sendData(50);
                                                      }
                                                    });
                                                  },
                                                  onDragCompleted: (handlerIndex, lowerValue, upperValue) {
                                                    if (lowerValue == 2) {
                                                      _sendData(52);
                                                    } else if (lowerValue == 1) {
                                                      _sendData(51);
                                                    } else {
                                                      _sendData(50);
                                                    }
                                                    if (_timerS2 != null) {
                                                      _timerS2!.cancel();
                                                      _timerS2 = null;
                                                    }
                                                  },
                                                  trackBar: trackbarStyle,
                                                  handler: FlutterSliderHandler(
                                                    child: Text(
                                                      "B",
                                                      style: TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.background,
                                                        borderRadius: BorderRadius.circular(40),
                                                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 5)),
                                                  ),
                                                  axis: Axis.vertical,
                                                  values: [inputSL2],
                                                  max: 2,
                                                  min: 0,
                                                  rtl: true,
                                                  step: const FlutterSliderStep(step: 1),
                                                  onDragging: (handlerIndex, lowerValue, upperValue) {
                                                    if (inputSL2 != lowerValue) {
                                                      print(lowerValue);
                                                      setState(() {
                                                        inputSL2 = lowerValue;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              Text("$inputSL2")
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 30),
                                    Center(
                                      child: Joystick(
                                        base: JoystickBase(
                                          decoration: JoystickBaseDecoration(
                                            color: Theme.of(context).colorScheme.background,
                                            // drawOuterCircle: false,
                                            // innerCircleColor: Theme.of(context).colorScheme.primary,
                                            // middleCircleColor: Theme.of(context).colorScheme.primary,

                                            outerCircleColor: Theme.of(context).colorScheme.primary,
                                          ),
                                          arrowsDecoration: JoystickArrowsDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        stick: JoystickStick(
                                          decoration: JoystickStickDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        period: Duration(milliseconds: period1),
                                        onStickDragEnd: () {
                                          _sendData(2);
                                          _sendData(2);
                                          _sendData(2);
                                          _sendData(2);
                                        },
                                        listener: (details) {
                                          //    9
                                          // 8 <=> 7
                                          //   10

                                          _sendData(10 + ((details.x + 1) * 10).floor());

                                          // if (details.x < 0) {
                                          //   _sendData(8);
                                          // }
                                          // if (details.x > 0) {
                                          //   _sendData(7);
                                          // }

                                          _sendData(30 + ((details.y + 1) * 10).floor());

                                          // if (details.y > 0) {
                                          //   _sendData(10);
                                          // }
                                          // if (details.y < 0) {
                                          //   _sendData(9);
                                          // }
                                        },
                                      ),
                                    ),
                                    // _inputSerial(),
                                    // _buttons(),
                                    SizedBox(height: 20),
                                    Text(
                                      "<YR/>",
                                      style: TextStyle(fontSize: 20, color: Colors.white.withOpacity(0.1), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              // ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            // btIsConected
            //     ? SizedBox()
            //     : Center(
            //         child: IconButton(
            //           onPressed: () async {
            //             if (!_bluetoothState) {
            //               await _bluetooth.requestEnable();
            //             }
            //             if (!_bluetoothState) {
            //               return;
            //             }
            //             showDialog(
            //                 context: context,
            //                 builder: (context) {
            //                   return const Center(child: CircularProgressIndicator());
            //                 });
            //             if (btIsConected) {
            //               await _connection?.finish();
            //               setState(() => _deviceConnected = null);
            //               return;
            //             }

            //             await _getDevices();
            //             Navigator.of(context).pop();

            //             showModalBottomSheet(
            //                 context: context,
            //                 useSafeArea: true,
            //                 constraints: const BoxConstraints(
            //                   maxHeight: 650,
            //                 ),
            //                 scrollControlDisabledMaxHeightRatio: 1,
            //                 builder: (context) {
            //                   return SizedBox(
            //                     height: 1000,
            //                     child: Center(
            //                       child: Container(
            //                         padding: const EdgeInsets.all(20),
            //                         child: Column(
            //                             mainAxisAlignment: MainAxisAlignment.start,
            //                             crossAxisAlignment: CrossAxisAlignment.stretch,
            //                             children: [
            //                               Row(
            //                                 crossAxisAlignment: CrossAxisAlignment.center,
            //                                 children: [
            //                                   Icon(
            //                                     Icons.bluetooth_searching,
            //                                     color: Theme.of(context).colorScheme.primary,
            //                                   ),
            //                                   const SizedBox(width: 10),
            //                                   Expanded(
            //                                     flex: 4,
            //                                     child: Text(
            //                                       "Dispositivos Bluetooth",
            //                                       style: TextStyle(
            //                                         fontWeight: FontWeight.bold, fontSize: 18,
            //                                         color: Theme.of(context).colorScheme.primary,
            //                                         // color: Colors.black54
            //                                       ),
            //                                     ),
            //                                   ),
            //                                   IconButton(
            //                                       color: Theme.of(context).colorScheme.primary,
            //                                       onPressed: () async {
            //                                         showDialog(
            //                                             context: context,
            //                                             builder: (context) {
            //                                               return const Center(child: CircularProgressIndicator());
            //                                             });
            //                                         await _getDevices();
            //                                         Navigator.of(context).pop();
            //                                       },
            //                                       icon: const Icon(Icons.refresh)),
            //                                 ],
            //                               ),
            //                               Expanded(
            //                                 child: SingleChildScrollView(
            //                                     child: Column(
            //                                         mainAxisAlignment: MainAxisAlignment.start,
            //                                         crossAxisAlignment: CrossAxisAlignment.stretch,
            //                                         children: [
            //                                       for (final device in _devices)
            //                                         ListTile(
            //                                           title: Text(device.name ?? device.address),
            //                                           trailing: TextButton(
            //                                             child: const Text('conectar'),
            //                                             onPressed: () async {
            //                                               try {
            //                                                 setState(() => _isConnecting = true);

            //                                                 _connection = await BluetoothConnection.toAddress(device.address);
            //                                                 _deviceConnected = device;
            //                                                 _devices = [];

            //                                                 _receiveData();
            //                                               } catch (e) {
            //                                                 print(e);
            //                                               }

            //                                               _isConnecting = false;
            //                                               setState(() {});
            //                                             },
            //                                           ),
            //                                         )
            //                                     ])),
            //                               )
            //                             ]),
            //                       ),
            //                     ),
            //                   );
            //                 });
            //           },
            //           icon: const Icon(Icons.bluetooth),
            //           style: ButtonStyle(
            //               iconSize: const MaterialStatePropertyAll(100),
            //               backgroundColor: btIsConected ? MaterialStatePropertyAll(Theme.of(context).colorScheme.primary) : null),
            //         ),
            //       ),
            // // _controlBT(),
            // _infoDevice(),
            // const SizedBox(height: 60),
            //   Expanded(
            //     flex: 4,
            //     child: Container(
            //       height: 200,
            //       child: SingleChildScrollView(
            //         child: Container(
            //           padding: EdgeInsets.symmetric(vertical: 40),
            //           decoration: BoxDecoration(
            //             color: Theme.of(context).colorScheme.onBackground.withOpacity(0.05),
            //             borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            //           ),
            //           child: Column(
            //             children: [
            //               Center(
            //                 child: Row(
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   mainAxisAlignment: MainAxisAlignment.center,
            //                   children: [
            //                     Column(
            //                       children: [
            //                         Container(
            //                           width: 50,
            //                           height: 180,
            //                           child: FlutterSlider(
            //                             onDragStarted: (handlerIndex, lowerValue, upperValue) {
            //                               if (_timerS1 != null) {
            //                                 _timerS1!.cancel();
            //                                 _timerS1 = null;
            //                               }
            //                               _timerS1 = Timer.periodic(Duration(milliseconds: period1), (timer) {
            //                                 print("SHOULDER:$inputSL1");
            //                                 if (inputSL1 == 2) {
            //                                   _sendData(42);
            //                                 } else if (inputSL1 == 1) {
            //                                   _sendData(41);
            //                                 } else {
            //                                   _sendData(40);
            //                                 }
            //                               });
            //                             },
            //                             onDragCompleted: (handlerIndex, lowerValue, upperValue) {
            //                               if (lowerValue == 2) {
            //                                 _sendData(42);
            //                               } else if (lowerValue == 1) {
            //                                 _sendData(41);
            //                               } else {
            //                                 _sendData(40);
            //                               }
            //                               if (_timerS1 != null) {
            //                                 _timerS1!.cancel();
            //                                 _timerS1 = null;
            //                               }
            //                             },
            //                             handlerWidth: 46,
            //                             jump: true,
            //                             trackBar: trackbarStyle,
            //                             handler: FlutterSliderHandler(
            //                               child: Text("A"),
            //                               decoration: BoxDecoration(
            //                                   color: Theme.of(context).colorScheme.background,
            //                                   borderRadius: BorderRadius.circular(40),
            //                                   border: Border.all(color: Theme.of(context).colorScheme.primary, width: 5)),
            //                             ),
            //                             axis: Axis.vertical,
            //                             rtl: true,
            //                             values: [inputSL1],
            //                             max: 2,
            //                             min: 0,
            //                             // trackBar: FlutterSliderTrackBar(inactiveDisabledTrackBarColor: Colors.red),
            //                             step: const FlutterSliderStep(step: 1),
            //                             onDragging: (handlerIndex, lowerValue, upperValue) {
            //                               if (inputSL1 != lowerValue) {
            //                                 print(lowerValue);
            //                                 setState(() {
            //                                   inputSL1 = lowerValue;
            //                                 });
            //                               }
            //                             },
            //                           ),
            //                         ),
            //                         Text("$inputSL1")
            //                       ],
            //                     ),
            //                     const SizedBox(width: 50),
            //                     Column(
            //                       children: [
            //                         Container(
            //                           width: 50,
            //                           height: 180,
            //                           child: FlutterSlider(
            //                             onDragStarted: (handlerIndex, lowerValue, upperValue) {
            //                               if (_timerS2 != null) {
            //                                 _timerS2!.cancel();
            //                                 _timerS2 = null;
            //                               }
            //                               _timerS2 = Timer.periodic(Duration(milliseconds: period1), (timer) {
            //                                 print("ELBOW:$inputSL2");
            //                                 if (inputSL2 == 2) {
            //                                   _sendData(52);
            //                                 } else if (inputSL2 == 1) {
            //                                   _sendData(51);
            //                                 } else {
            //                                   _sendData(50);
            //                                 }
            //                               });
            //                             },
            //                             onDragCompleted: (handlerIndex, lowerValue, upperValue) {
            //                               if (lowerValue == 2) {
            //                                 _sendData(52);
            //                               } else if (lowerValue == 1) {
            //                                 _sendData(51);
            //                               } else {
            //                                 _sendData(50);
            //                               }
            //                               if (_timerS2 != null) {
            //                                 _timerS2!.cancel();
            //                                 _timerS2 = null;
            //                               }
            //                             },
            //                             trackBar: trackbarStyle,
            //                             handler: FlutterSliderHandler(
            //                               child: Text(
            //                                 "B",
            //                                 style: TextStyle(fontWeight: FontWeight.bold),
            //                               ),
            //                               decoration: BoxDecoration(
            //                                   color: Theme.of(context).colorScheme.background,
            //                                   borderRadius: BorderRadius.circular(40),
            //                                   border: Border.all(color: Theme.of(context).colorScheme.primary, width: 5)),
            //                             ),
            //                             axis: Axis.vertical,
            //                             values: [inputSL2],
            //                             max: 2,
            //                             min: 0,
            //                             rtl: true,
            //                             step: const FlutterSliderStep(step: 1),
            //                             onDragging: (handlerIndex, lowerValue, upperValue) {
            //                               if (inputSL2 != lowerValue) {
            //                                 print(lowerValue);
            //                                 setState(() {
            //                                   inputSL2 = lowerValue;
            //                                 });
            //                               }
            //                             },
            //                           ),
            //                         ),
            //                         Text("$inputSL2")
            //                       ],
            //                     ),
            //                   ],
            //                 ),
            //               ),
            //               Center(
            //                 child: Joystick(
            //                   base: JoystickBase(
            //                     decoration: JoystickBaseDecoration(
            //                       color: Theme.of(context).colorScheme.background,
            //                       // drawOuterCircle: false,
            //                       // innerCircleColor: Theme.of(context).colorScheme.primary,
            //                       // middleCircleColor: Theme.of(context).colorScheme.primary,

            //                       outerCircleColor: Theme.of(context).colorScheme.primary,
            //                     ),
            //                     arrowsDecoration: JoystickArrowsDecoration(
            //                       color: Theme.of(context).colorScheme.primary,
            //                     ),
            //                   ),
            //                   stick: JoystickStick(
            //                     decoration: JoystickStickDecoration(
            //                       color: Theme.of(context).colorScheme.primary,
            //                     ),
            //                   ),
            //                   period: Duration(milliseconds: period1),
            //                   listener: (details) {
            //                     //    9
            //                     // 8 <=> 7
            //                     //   10
            //                     if (details.x < 0) {
            //                       _sendData(8);
            //                     }
            //                     if (details.x > 0) {
            //                       _sendData(7);
            //                     }

            //                     if (details.y > 0) {
            //                       _sendData(10);
            //                     }
            //                     if (details.y < 0) {
            //                       _sendData(9);
            //                     }
            //                   },
            //                 ),
            //               ),
            //               // _inputSerial(),
            //               // _buttons(),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _controlBT() {
    return SwitchListTile(
      value: _bluetoothState,
      onChanged: (bool value) async {
        if (value) {
          await _bluetooth.requestEnable();
        } else {
          await _bluetooth.requestDisable();
        }
      },
      tileColor: Colors.black26,
      title: Text(
        _bluetoothState ? "Bluetooth encendido" : "Bluetooth apagado",
      ),
    );
  }

  Widget _infoDevice() {
    return ListTile(
      tileColor: Colors.black12,
      title: Text("Conectado a: ${_deviceConnected?.name ?? "ninguno"}"),
      trailing: _connection?.isConnected ?? false
          ? TextButton(
              onPressed: () async {
                await _connection?.finish();
                setState(() => _deviceConnected = null);
              },
              child: const Text("Desconectar"),
            )
          : TextButton(
              onPressed: _getDevices,
              child: const Text("Ver dispositivos"),
            ),
    );
  }

  Widget _listDevices() {
    return _isConnecting
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  ...[
                    for (final device in _devices)
                      ListTile(
                        title: Text(device.name ?? device.address),
                        trailing: TextButton(
                          child: const Text('conectar'),
                          onPressed: () async {
                            try {
                              setState(() => _isConnecting = true);

                              _connection = await BluetoothConnection.toAddress(device.address);
                              _deviceConnected = device;
                              _devices = [];

                              _receiveData();
                            } catch (e) {
                              print(e);
                            }

                            _isConnecting = false;
                            setState(() {});
                          },
                        ),
                      )
                  ]
                ],
              ),
            ),
          );
  }

  Widget _inputSerial() {
    return ListTile(
      trailing: TextButton(
        child: const Text('reiniciar'),
        onPressed: () => setState(() => times = 0),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          "Pulsador presionado (x$times)",
          style: const TextStyle(fontSize: 18.0),
        ),
      ),
    );
  }

  Widget _buttons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      color: Colors.black12,
      child: Column(
        children: [
          const Text('Controles para LED', style: TextStyle(fontSize: 18.0)),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  text: "Encender",
                  color: Colors.green,
                  onTap: () => _sendData(1),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: ActionButton(
                  color: Colors.red,
                  text: "Apagar",
                  onTap: () => _sendData(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
