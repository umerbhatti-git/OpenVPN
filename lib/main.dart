import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VpnScreen(),
    );
  }
}

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  late OpenVPN _vpn;
  late String duration;
  String _stage = "Disconnect";

  @override
  void initState() {
    super.initState();
    _vpn = OpenVPN(onVpnStatusChanged: _onVpnStatusChanged, onVpnStageChanged: _onVpnStageChanged);
    // Initialize OpenVPN
    _vpn.initialize(
      groupIdentifier: "group.com.example.openvpn", // Use your app's group identifier (for iOS, it's required)
      providerBundleIdentifier: "com.example.openvpn", // Your app's bundle identifier
    ).then((_) {
      print("OpenVPN initialized successfully!");
    }).catchError((error) {
      print("Error initializing OpenVPN: $error");
    });
  }

  void _onVpnStatusChanged(VpnStatus? vpnStatus) {
    print(vpnStatus);
    setState(() {
      duration = vpnStatus!.duration!;
    });
  }

  void _onVpnStageChanged(VPNStage stage, String message) {
    String stageDescription;

    switch (stage) {
      case VPNStage.disconnected:
        stageDescription = "Disconnected";
        break;
      case VPNStage.vpn_generate_config:
        stageDescription = "Generating VPN Configuration";
        break;
      case VPNStage.resolve:
        stageDescription = "Resolving Hostname";
        break;
      case VPNStage.tcp_connect:
        stageDescription = "Connecting via TCP";
        break;
      case VPNStage.wait_connection:
        stageDescription = "Waiting for Connection";
        break;
      case VPNStage.authenticating:
        stageDescription = "Authenticating User";
        break;
      case VPNStage.get_config:
        stageDescription = "Retrieving Configuration";
        break;
      case VPNStage.assign_ip:
        stageDescription = "Assigning IP Address";
        break;
      case VPNStage.connected:
        stageDescription = "Connected";
        break;
      case VPNStage.unknown:
        stageDescription = message.isNotEmpty ? message : "Unknown Stage";
        break;
      default:
        stageDescription = "Unknown";
        break;
    }

    setState(() {
      _stage = stageDescription;
    });

    print("VPN Stage: $stageDescription - $message");
  }

  void _connect() async {
    try {
      // Load the configuration file dynamically from assets
      final ovpnConfig = await rootBundle.loadString('assets/openvpn.ovpn');

      // Connect using the loaded configuration
      _vpn.connect(
        ovpnConfig,
        "us1.freeopenvpn.online", // The VPN server address
        username: "freeopenvpn",
        password: "332654846",
        bypassPackages: [], // Add any package names to exclude from VPN if needed
        certIsRequired: true, // iOS specific: Set true to avoid "connecting" stuck issues
      );
    } catch (e) {
      // Handle any exceptions or errors while loading the file or connecting
      print("Error while connecting to VPN: $e");
      setState(() {
        _stage = "Error while connecting";
      });
    }
  }

  void _disconnect() {
    _vpn.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OpenVPN")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Round button for Connect/Disconnect
            ElevatedButton(
              onPressed: _stage == "Connected" ? _disconnect : _connect,
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(), // Makes the button round
                padding: EdgeInsets.all(100), // Adjust padding for size
                backgroundColor: _stage == "Connected"
                    ? Colors.red // Red for disconnect
                    : Colors.green, // Green for connect
                foregroundColor: Colors.white, // Text color
                elevation: 10, // Adds shadow
              ),
              child: Text(
                _stage == "Connected" ? "Disconnect" : "Connect",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 40), // Spacing below the button
            // Display duration dynamically
            Text(
              _stage == "Connected" ? duration : _stage,
              style: TextStyle(
                fontSize: 18,
                color: _stage == "Connected" ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vpn.disconnect();
    super.dispose();
  }
}
