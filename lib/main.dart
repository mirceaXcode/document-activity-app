import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // For date formatting

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Activity App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DocumentActivityScreen(),
    );
  }
}

class DocumentActivityScreen extends StatefulWidget {
  const DocumentActivityScreen({super.key});

  @override
  DocumentActivityState createState() => DocumentActivityState();
}

class DocumentActivityState extends State<DocumentActivityScreen> {
  final _instanceIdController = TextEditingController();
  final _bearerTokenController = TextEditingController();
  List<Map<String, dynamic>> _activities = [];
  String _error = '';

  Future<void> _fetchActivities() async {
    setState(() {
      _activities = [];
      _error = '';
    });

    final trimmedInstanceId = _instanceIdController.text.trim();
    final trimmedBearerToken = _bearerTokenController.text.trim();

    if (trimmedInstanceId.isEmpty) {
      setState(() {
        _error = 'Instance ID cannot be empty';
      });
      return;
    }

    final url = Uri.parse('https://services.assureid.net/AssureIDService/Document/$trimmedInstanceId/activity');
    debugPrint('Fetching activities with URL: $url, Bearer Token: $trimmedBearerToken');
    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $trimmedBearerToken',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Connection timed out');
      });
      debugPrint('Response received - Status: ${response.statusCode}, Full Body: ${response.body}, Headers: ${response.headers}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _activities = data.map((item) {
            final startMillis = _parseEpoch(item['StartTime']);
            final endMillis = _parseEpoch(item['EndTime']);
            final processTime = startMillis != null && endMillis != null
                ? '${((endMillis - startMillis) / 1000).toStringAsFixed(3)} seconds'
                : 'N/A';
            return {
              'apiName': item['ApiName'] ?? 'N/A',
              'startTime': _formatDate(startMillis),
              'endTime': _formatDate(endMillis),
              'processTime': processTime,
              'statusCode': item['StatusCode'] ?? 'N/A',
              'instanceId': item['InstanceId'] ?? 'N/A',
            };
          }).toList();
        });
      } else if (response.statusCode == 404 || response.statusCode == 433) {
        setState(() {
          _error = 'Invalid SessionID';
        });
        debugPrint('API returned invalid session error - Status: ${response.statusCode}, Full Body: ${response.body}, Headers: ${response.headers}');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _error = 'Invalid Token';
        });
        debugPrint('API returned authentication error - Status: ${response.statusCode}, Full Body: ${response.body}, Headers: ${response.headers}');
      } else {
        setState(() {
          _error = 'API Error: Status ${response.statusCode} - ${response.body.isNotEmpty ? response.body : 'No additional details'}';
        });
        debugPrint('API returned error - Status: ${response.statusCode}, Full Body: ${response.body}, Headers: ${response.headers}');
      }
    } catch (e) {
      debugPrint('Exception during request: $e');
      setState(() {
        _error = 'Network error: $e';
      });
    }
  }

  int? _parseEpoch(String? epochDate) {
    if (epochDate == null || epochDate.isEmpty) {
      debugPrint('Epoch date is null or empty: $epochDate');
      return null;
    }
    debugPrint('Parsing epoch: $epochDate');
    final match = RegExp(r'/Date\((\d+)\+0000\)/').firstMatch(epochDate);
    if (match == null) {
      debugPrint('No match found in epoch: $epochDate');
      return null;
    }
    final millis = int.tryParse(match.group(1)!);
    if (millis == null) {
      debugPrint('Failed to parse milliseconds from: ${match.group(1)}');
      return null;
    }
    debugPrint('Parsed milliseconds: $millis');
    return millis;
  }

  String _formatDate(int? milliseconds) {
    if (milliseconds == null) {
      debugPrint('Milliseconds is null, returning Invalid Date');
      return 'Invalid Date';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
    debugPrint('Formatted date for $milliseconds: ${DateFormat("MMMM dd 'at' yyyy 'at' hh:mm:ss a").format(date)}');
    return DateFormat("MMMM dd 'at' yyyy 'at' hh:mm:ss a").format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Activity App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _instanceIdController,
              decoration: const InputDecoration(labelText: 'Instance ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bearerTokenController,
              decoration: const InputDecoration(labelText: 'Bearer Token'),
              maxLines: 2, // Allow multiple lines for token
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _fetchActivities, child: const Text('Fetch Activities')),
            const SizedBox(height: 20),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
            if (_activities.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey),
                        columnWidths: {
                          0: const FlexColumnWidth(1.5),
                          1: const FlexColumnWidth(2),
                          2: const FlexColumnWidth(2),
                          3: const FlexColumnWidth(1.5),
                          4: const FlexColumnWidth(1),
                          5: const FlexColumnWidth(2),
                        }, // Removed const from the map
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Colors.grey),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('ApiName', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('StartTime', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('EndTime', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('ProcessTime', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('StatusCode', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('InstanceId', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          ..._activities.map((activity) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['apiName']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['startTime']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['endTime']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['processTime']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['statusCode'].toString()),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(activity['instanceId']),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _instanceIdController.dispose();
    _bearerTokenController.dispose();
    super.dispose();
  }
}