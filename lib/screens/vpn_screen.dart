import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:openvpn_flutter/openvpn_flutter.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  late OpenVPN _vpn;
  String duration = "00:00:00";
  String _stage = "Disconnected";
  bool _isConnected = false;

  // Variables to Calculate Speed
  int? _prevByteIn;
  int? _prevByteOut;
  DateTime? _lastUpdate;
  double downloadSpeed = 0.0;
  double uploadSpeed = 0.0;

  String _vpnIP = "Not Connected"; // Default IP
  bool _hasFetchedIP = false;

  @override
  void initState() {
    super.initState();
    _vpn = OpenVPN(
        onVpnStatusChanged: _onVpnStatusChanged,
        onVpnStageChanged: _onVpnStageChanged);
    _vpn
        .initialize(
      groupIdentifier: "group.com.hashmaker.openvpn",
      providerBundleIdentifier: "com.hashmaker.openvpn",
    )
        .then((_) {
      print("OpenVPN initialized successfully!");
    }).catchError((error) {
      print("Error initializing OpenVPN: $error");
    });
  }

  void _onVpnStatusChanged(VpnStatus? vpnStatus) {
    if (vpnStatus == null) return;

    setState(() {
      duration = vpnStatus.duration ?? "00:00:00";
      _isConnected = vpnStatus.connectedOn != null;

      if (_isConnected && !_hasFetchedIP) {
        _vpnIP = "Fetching IP...";
        _fetchPublicIP(); // Fetch actual IP
      }
    });

    // Get current bytes
    int currentByteIn = int.parse(vpnStatus.byteIn!);
    int currentByteOut = int.parse(vpnStatus.byteOut!);
    DateTime now = DateTime.now();

    if (_prevByteIn != null && _prevByteOut != null && _lastUpdate != null) {
      double timeDiff = now.difference(_lastUpdate!).inMilliseconds /
          1000.0; // Convert ms to seconds

      if (timeDiff > 0) {
        downloadSpeed =
            (currentByteIn - _prevByteIn!) / timeDiff / 1024; // KB/s
        uploadSpeed =
            (currentByteOut - _prevByteOut!) / timeDiff / 1024; // KB/s
      }
    }

    // Store previous values
    _prevByteIn = currentByteIn;
    _prevByteOut = currentByteOut;
    _lastUpdate = now;
  }

  // Fetch the actual public IP after connecting
  Future<void> _fetchPublicIP() async {
    try {
      final response =
          await http.get(Uri.parse("https://api64.ipify.org?format=json"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _vpnIP = data["ip"];
          _hasFetchedIP = true;
        });
      } else {
        setState(() {
          _vpnIP = "Failed to fetch IP";
        });
      }
    } catch (e) {
      setState(() {
        _vpnIP = "Error fetching IP";
      });
    }
  }

  void _onVpnStageChanged(VPNStage stage, String message) {
    String stageDescription =
        stage.toString().split('.').last.replaceAll('_', ' ');
    setState(() {
      _stage = stageDescription;
      _isConnected = stage == VPNStage.connected;
    });
  }

  void _connect() async {
    try {
      final ovpnConfig = await rootBundle.loadString('assets/openvpn.ovpn');
      _vpn.connect(
        ovpnConfig,
        "us1.freeopenvpn.online",
        username: "freeopenvpn",
        password: "391626552",
        bypassPackages: [],
        certIsRequired: true,
      );
    } catch (e) {
      print("Error while connecting to VPN: $e");
      setState(() {
        _stage = "Connection Error";
      });
    }
  }

  void _disconnect() {
    _vpn.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: "Server"),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: "Speed"),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: "Statistic"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            width: double.infinity,
            color: Colors.purple[400],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Welcome",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.white),
                    SizedBox(width: 15),
                    Icon(Icons.star_border, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          // Connection Timer
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.symmetric(vertical: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(duration,
                    style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Text(_stage,
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Power Button (Connect/Disconnect)
          GestureDetector(
            onTap: _isConnected ? _disconnect : _connect,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.purple, spreadRadius: 5, blurRadius: 20)
                  ],
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.red : Colors.purple[400],
                  ),
                  child: Center(
                    child: Icon(Icons.power_settings_new,
                        size: 50, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          // Download & Upload Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpeedBox(Icons.download, "Download", downloadSpeed),
              SizedBox(width: 10),
              _buildSpeedBox(Icons.upload, "Upload", uploadSpeed),
            ],
          ),

          SizedBox(height: 20),

          // Server Information
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Image.network("https://flagcdn.com/w320/us.png",
                    width: 40, height: 30),
                // USA Flag
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("United States",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                    Text(_vpnIP,
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Spacer(),
                Icon(Icons.info_outline, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedBox(IconData icon, String title, double speed) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.purple[400]),
          SizedBox(height: 5),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
          Text("${speed.toStringAsFixed(2)} KB/s",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
