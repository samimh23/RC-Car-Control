import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polyauto RC Car',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey.shade300,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Roboto',
        ),
      ),
      home: const PolyautoController(),
    );
  }
}

class PolyautoController extends StatefulWidget {
  const PolyautoController({super.key});
  @override
  State<PolyautoController> createState() => _PolyautoControllerState();
}

class _PolyautoControllerState extends State<PolyautoController>
    with SingleTickerProviderStateMixin {
  double _speed = 0.5;
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isConnected = false;
  String status = "Disconnected";


  final Set<String> _activeDirections = {};

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    connection?.dispose();
    super.dispose();
  }

  String? get _currentBlinkDirection {
    if (_activeDirections.contains('f') && _activeDirections.contains('g')) return 'q';
    if (_activeDirections.contains('f') && _activeDirections.contains('l')) return 'e';
    if (_activeDirections.contains('b') && _activeDirections.contains('g')) return 'z';
    if (_activeDirections.contains('b') && _activeDirections.contains('l')) return 'c';
    if (_activeDirections.contains('f')) return 'f';
    if (_activeDirections.contains('b')) return 'b';
    if (_activeDirections.contains('g')) return 'g';
    if (_activeDirections.contains('l')) return 'l';
    if (_activeDirections.contains('s')) return 's';
    return null;
  }

  Future<void> _selectAndConnectDevice() async {
    setState(() {
      isConnecting = true;
      status = "Scanning...";
    });

    List<BluetoothDevice> devices =
    await FlutterBluetoothSerial.instance.getBondedDevices();

    if (devices.isEmpty) {
      setState(() {
        isConnecting = false;
        status = "No paired devices found";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No paired devices found. Pair with your RC car first!')));
      return;
    }

    BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select RC Car'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name ?? device.address),
                onTap: () => Navigator.pop(context, device),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDevice == null) {
      setState(() {
        isConnecting = false;
        status = "No device selected";
      });
      return;
    }

    try {
      BluetoothConnection newConnection =
      await BluetoothConnection.toAddress(selectedDevice.address);
      setState(() {
        connection = newConnection;
        isConnected = true;
        isConnecting = false;
        status = "Connected";
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connected to ${selectedDevice.name}!')));
    } catch (e) {
      setState(() {
        isConnecting = false;
        status = "Connection failed";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connection failed! Make sure your RC car is powered on and Bluetooth is enabled.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnect() {
    connection?.dispose();
    setState(() {
      isConnected = false;
      status = "Disconnected";
    });
  }

  void _sendCommand(String cmd) {
    if (isConnected && connection != null) {
      connection!.output.add(Uint8List.fromList(cmd.codeUnits));
      connection!.output.allSent;
    }
  }

  void _sendSpeed(double speed) {
    int percent = (speed * 100).round();
    _sendCommand('v$percent');
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("How to Connect to RC Car"),
        content: const Text(
            "1. Power on your ESP32-based RC Car.\n"
                "2. Pair your RC car via Bluetooth in your phone's settings.\n"
                "3. In this app, tap the settings ⚙️ icon and choose 'Connect'.\n"
                "4. Select your RC car from the list.\n"
                "5. Wait for 'Connected' status at the top.\n\n"
                "Buttons will work only after you are connected."),
        actions: [
          TextButton(
              child: const Text("Connect"),
              onPressed: () {
                Navigator.pop(context);
                _selectAndConnectDevice();
              }),
          TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _onDirectionPress(String dir) {
    if (_activeDirections.add(dir)) {
      setState(() {});
      _sendCommand(dir);
    }
  }

  void _onDirectionRelease(String dir) {
    if (_activeDirections.remove(dir)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.13,
                child: Image.asset(
                  "assets/images/back1.png", // << your transparent logo!
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.75,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _largeButton(
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  label: "Forward",
                                  direction: 'f',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _largeButton(
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  label: "Backward",
                                  direction: 'b',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: _modernDPad(),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18.0, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _largeRectButton(
                                  icon: Icons.keyboard_arrow_left_rounded,
                                  label: "Left",
                                  direction: 'g',
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _largeRectButton(
                                  icon: Icons.keyboard_arrow_right_rounded,
                                  label: "Right",
                                  direction: 'l',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    Color statusColor = isConnected ? Colors.green : Colors.red;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [

          GestureDetector(
            onTapDown: (_) => _onDirectionPress('s'),
            onTapUp: (_) => _onDirectionRelease('s'),
            onTapCancel: () => _onDirectionRelease('s'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.15),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),

          const SizedBox(width: 12),


          Text(
            "POLYAUTO",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 3,
              fontFamily: 'Roboto',
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 5,
                  color: Colors.black12,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),


          Row(
            children: [
              Icon(
                Icons.bluetooth_connected,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Speed control!
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.black, size: 24),
              SizedBox(
                width: 160,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                    activeTrackColor: Colors.black,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: Colors.black,
                    overlayColor: Colors.black.withOpacity(0.07),
                  ),
                  child: Slider(
                    value: _speed,
                    onChanged: (v) {
                      setState(() => _speed = v);
                      if (isConnected) _sendSpeed(_speed);
                    },
                    min: 0,
                    max: 1,
                  ),
                ),
              ),
              Text(
                '${(_speed * 100).round()}%',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),


          GestureDetector(
            onTap: _showSettingsDialog,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeButton(
      {required IconData icon, String? label, required String direction}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size =
        constraints.maxHeight < 100 ? constraints.maxHeight : 100;
        return GestureDetector(
          onTapDown: (_) => _onDirectionPress(direction),
          onTapUp: (_) => _onDirectionRelease(direction),
          onTapCancel: () => _onDirectionRelease(direction),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: size,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.black, size: 44),
                  ),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _largeRectButton(
      {required IconData icon, String? label, required String direction}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size =
        constraints.maxHeight < 100 ? constraints.maxHeight : 100;
        return GestureDetector(
          onTapDown: (_) => _onDirectionPress(direction),
          onTapUp: (_) => _onDirectionRelease(direction),
          onTapCancel: () => _onDirectionRelease(direction),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  width: size,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.black, size: 44),
                  ),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _modernDPad() {
    double size = 150;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _dPadArrow(Icons.arrow_upward, const Alignment(0, -1.2), 'f'),
          _dPadArrow(Icons.arrow_downward, const Alignment(0, 1.2), 'b'),
          _dPadArrow(Icons.arrow_back, const Alignment(-1.2, 0), 'g'),
          _dPadArrow(Icons.arrow_forward, const Alignment(1.2, 0), 'l'),
          _dPadArrow(Icons.north_west, const Alignment(-0.9, -0.9), 'q'),
          _dPadArrow(Icons.north_east, const Alignment(0.9, -0.9), 'e'),
          _dPadArrow(Icons.south_west, const Alignment(-0.9, 0.9), 'z'),
          _dPadArrow(Icons.south_east, const Alignment(0.9, 0.9), 'c'),
          GestureDetector(
            onTapDown: (_) => _onDirectionPress('s'),
            onTapUp: (_) => _onDirectionRelease('s'),
            onTapCancel: () => _onDirectionRelease('s'),
            child: AnimatedBuilder(
              animation: _blinkController,
              builder: (context, child) {
                final blink =
                    _currentBlinkDirection == 's' && _blinkController.value > 0.5;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: blink ? Colors.black : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: blink
                            ? Colors.black.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        blurRadius: blink ? 12 : 8,
                        spreadRadius: blink ? 5 : 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.stop,
                      color: blink ? Colors.white : Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dPadArrow(IconData icon, Alignment align, String direction) {
    return Align(
      alignment: align,
      child: GestureDetector(
        onTapDown: (_) => _onDirectionPress(direction),
        onTapUp: (_) => _onDirectionRelease(direction),
        onTapCancel: () => _onDirectionRelease(direction),
        child: AnimatedBuilder(
          animation: _blinkController,
          builder: (context, child) {
            final blink = _currentBlinkDirection == direction && _blinkController.value > 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: blink ? Colors.black : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: blink
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: blink ? 12 : 6,
                    spreadRadius: blink ? 5 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: blink ? Colors.white : Colors.black,
                  size: 17,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}