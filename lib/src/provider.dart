import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';

class MainProvider with ChangeNotifier {
  PermissionStatus _blPersmission = PermissionStatus.denied;
  PermissionStatus _blScanPersmission = PermissionStatus.denied;
  PermissionStatus _blConnectPersmission = PermissionStatus.denied;
  // final blueClassic =
  // FlutterBlueClassic(usesFineLocation: true);
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _deviceConnected;
  int times = 0;

  bool get blOkPermissionisGranted => _blPersmission.isGranted && _blScanPersmission.isGranted && _blConnectPersmission.isGranted;
  BluetoothDevice? get deviceConnected => _deviceConnected;
  bool get btIsConected => _connection?.isConnected ?? false;
  bool get btIsConecting => _isConnecting;
  bool get bluetoothState => _bluetoothState;
  List<BluetoothDevice> get btDevices => _devices;

  btEnable(bool r) async {
    if (r) {
      await _bluetooth.requestEnable();
    } else {
      await _bluetooth.requestDisable();
    }
  }

  MainProvider(BuildContext context) {
    checkBTPermissiosn();
    _bluetooth.state.then((state) {
      _bluetoothState = state.isEnabled;
      notifyListeners();
    });
    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          _bluetoothState = false;
          notifyListeners();
          break;
        case BluetoothState.STATE_ON:
          _bluetoothState = true;
          notifyListeners();
          break;
        // case BluetoothState.STATE_TURNING_OFF:
        //   break;
        // case BluetoothState.STATE_TURNING_ON:
        //   break;
      }
    });
  }

  Future checkBTPermissiosn() async {
    _blPersmission = await Permission.bluetooth.status;
    _blScanPersmission = await Permission.bluetoothScan.status;
    _blConnectPersmission = await Permission.bluetoothConnect.status;
  }

  Future reqBTPermission() async {
    if (_blPersmission.isDenied) {
      await Permission.bluetooth.onGrantedCallback(() {
        _blPersmission = PermissionStatus.granted;
        notifyListeners();
      }).request();
    }
    if (_blScanPersmission.isDenied) {
      await Permission.bluetoothScan.onGrantedCallback(() {
        _blScanPersmission = PermissionStatus.granted;
        notifyListeners();
      }).request();
    }
    if (_blConnectPersmission.isDenied) {
      await Permission.bluetoothConnect.onGrantedCallback(() {
        _blConnectPersmission = PermissionStatus.granted;
        notifyListeners();
      }).request();
    }
  }

  void getDevices() async {
    var res = await _bluetooth.getBondedDevices();

    _devices = res;
  }

  void sendData(String data) {
    if (btIsConected) {
      _connection?.output.add(ascii.encode(data));
    }
  }

  Future btConnectTo(BluetoothDevice devc) async {
    _isConnecting = true;
    _connection = await BluetoothConnection.toAddress(devc.address);
    _deviceConnected = devc;
    _devices = [];
    _isConnecting = false;
    notifyListeners();
  }
}
