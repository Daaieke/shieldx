import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(ShieldXApp());

class ShieldXApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF121212),
        primaryColor: Color(0xFF1E1E1E),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF50769B),
          secondary: Color(0xFF67A38D),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: ShieldXDashboard(),
    );
  }
}

class ShieldXDashboard extends StatefulWidget {
  @override
  _ShieldXDashboardState createState() => _ShieldXDashboardState();
}

class _ShieldXDashboardState extends State<ShieldXDashboard> {
  final String apiBase = "https://shieldx-backend.fly.dev";
  Map<String, dynamic>? stateData;
  String directive = "Initializing SHIELDX Uplink...";
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _refreshIntelligence();
  }

  Future<void> _refreshIntelligence() async {
    try {
      // Parallel fetch for speed
      final results = await Future.wait([
        http.get(Uri.parse("$apiBase/user/state")),
        http.get(Uri.parse("$apiBase/intel/directive")),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        setState(() {
          stateData = json.decode(results[0].body);
          directive = json.decode(results[1].body)['directive'];
          isOffline = false;
        });
      }
    } catch (e) {
      setState(() {
        isOffline = true;
        directive = "CONNECTION SEVERED. OFFLINE PROTOCOLS ACTIVE.";
        // Fallback dummy data for offline demo
        stateData = {
          'cash_balance_aed': 0.0,
          'energy_level': 10,
          'visa_days_remaining': 0,
        };
      });
    }
  }

  void _showLogActivity(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityModal(onActivityLogged: _refreshIntelligence),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SHIELDX", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w300, fontSize: 16)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.wifi,
            color: isOffline ? Colors.redAccent : Colors.white24,
            size: 16,
          ),
          SizedBox(width: 20),
        ],
      ),
      body: stateData == null
          ? Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _refreshIntelligence,
              color: Color(0xFF50769B),
              backgroundColor: Color(0xFF1E1E1E),
              child: ListView(
                padding: EdgeInsets.all(24),
                children: [
                  _buildHeader("INTELLIGENCE BRIEF"),
                  _buildDirectiveCard(directive),
                  SizedBox(height: 32),
                  _buildHeader("VITAL TELEMETRY"),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("LIQUIDITY (AED)", "${stateData!['cash_balance_aed']}", Icons.account_balance_wallet_outlined)),
                      SizedBox(width: 16),
                      Expanded(child: _buildStatCard("ENERGY", "${stateData!['energy_level']}/10", Icons.battery_charging_full)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildStatCard("VISA STATUS", "${stateData!['visa_days_remaining']} DAYS REMAINING", Icons.timer_outlined, isFullWidth: true),
                  SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _showLogActivity(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text("LOG TACTICAL ACTIVITY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(title, style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDirectiveCard(String text) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFF50769B), size: 20),
          SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.white, fontSize: 15, height: 1.6, fontFamily: "Monospace")),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool isFullWidth = false}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
              Icon(icon, color: Colors.white12, size: 16),
            ],
          ),
          SizedBox(height: 12),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ActivityModal extends StatefulWidget {
  final VoidCallback onActivityLogged;
  ActivityModal({required this.onActivityLogged});
  @override
  _ActivityModalState createState() => _ActivityModalState();
}

class _ActivityModalState extends State<ActivityModal> {
  final _zoneCtrl = TextEditingController();
  final _companiesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse("https://shieldx-backend.fly.dev/ops/log-activity"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "zone": _zoneCtrl.text,
          "companies": _companiesCtrl.text.split(','),
          "spend": 0, "energy_post": 5, "notes": _notesCtrl.text
        }),
      );
      if (res.statusCode == 200) {
        widget.onActivityLogged();
        Navigator.pop(context);
      }
    } catch (e) {
      // Silent fail for UI demo
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LOG ACTIVITY", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          _field("ZONE", _zoneCtrl),
          SizedBox(height: 16),
          _field("COMPANIES", _companiesCtrl),
          SizedBox(height: 16),
          _field("NOTES", _notesCtrl),
          SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF50769B)),
            child: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text("CONFIRM ENTRY"),
          ))
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return TextField(
      controller: c,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
        filled: true, fillColor: Color(0xFF222222),
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
