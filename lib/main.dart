import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MT5 AI Starter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  List<double> prices = [];
  List<double> ma13 = [], ma50 = [], ma200 = [], ma800 = [];
  final _picker = ImagePicker();

  Future pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() => _image = File(img.path));
    // For starter: use a sample generated price series (replace later with image->prices)
    generateSamplePrices();
    computeMAs();
  }

  void generateSamplePrices() {
    prices = [];
    double p = 1.1000;
    final rnd = Random();
    for (int i = 0; i < 500; i++) {
      p += (rnd.nextDouble() - 0.48) * 0.002;
      prices.add(double.parse(p.toStringAsFixed(5)));
    }
  }

  List<double> sma(List<double> arr, int period) {
    List<double> out = List.filled(arr.length, double.nan);
    double sum = 0;
    for (int i = 0; i < arr.length; i++) {
      sum += arr[i];
      if (i >= period) sum -= arr[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  void computeMAs() {
    ma13 = sma(prices, 13);
    ma50 = sma(prices, 50);
    ma200 = sma(prices, 200);
    ma800 = sma(prices, 800);
    setState(() {});
  }

  String simpleSignal() {
    if (prices.isEmpty) return 'No data';
    int i = prices.length - 1;
    double p = prices[i];
    if (!ma13[i].isFinite || !ma50[i].isFinite) return 'Not enough data';
    if (ma13[i] > ma50[i] && ma50[i] > ma200[i]) return 'Bullish (consider LONG)';
    if (ma13[i] < ma50[i] && ma50[i] < ma200[i]) return 'Bearish (consider SHORT)';
    return 'Neutral / Mixed';
  }

  // pip calc: simple for demo (assumes 5-digit EURUSD-like)
  Map<String, dynamic> pipCalc(double entry, double sl, double lot) {
    double pipSize = 0.00010;
    double pipDist = (entry - sl).abs() / pipSize;
    double pipValuePerLot = 10.0; // approx for standard lot on EURUSD
    double profitLoss = pipDist * pipValuePerLot * lot * (entry > sl ? -1 : 1);
    return {'pips': pipDist, 'pnl': profitLoss};
  }

  final entryController = TextEditingController();
  final slController = TextEditingController();
  final lotController = TextEditingController(text: '0.1');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MT5 AI Starter')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          ElevatedButton.icon(
            icon: Icon(Icons.photo_library),
            label: Text('Import MT5 Screenshot'),
            onPressed: pickImage,
          ),
          SizedBox(height: 8),
          _image != null ? Image.file(_image!, height: 160) : Container(height: 160, color: Colors.grey[200], child: Center(child: Text('No image'))),
          SizedBox(height: 12),
          Text('Signal: ${simpleSignal()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Container(height: 200, child: prices.isEmpty ? Center(child: Text('No series')) : LineChart(sampleChartData())),
          SizedBox(height: 12),
          Text('Pip Calculator', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: entryController, decoration: InputDecoration(labelText: 'Entry price (e.g. 1.12345)')),
          TextField(controller: slController, decoration: InputDecoration(labelText: 'Stop Loss price')),
          TextField(controller: lotController, decoration: InputDecoration(labelText: 'Lot size (0.1)')),
          SizedBox(height: 8),
          ElevatedButton(
            child: Text('Calculate Pips/PnL'),
            onPressed: () {
              double entry = double.tryParse(entryController.text) ?? 0;
              double sl = double.tryParse(slController.text) ?? 0;
              double lot = double.tryParse(lotController.text) ?? 0.1;
              if (entry == 0 || sl == 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter entry and SL')));
                return;
              }
              final res = pipCalc(entry, sl, lot);
              showDialog(context: context, builder: (_) => AlertDialog(content: Text('Pips: ${res['pips'].toStringAsFixed(1)}\nEst PnL: ${res['pnl'].toStringAsFixed(2)}')));
            },
          ),
          SizedBox(height: 20),
          Text('Notes: This is a starter. Image->price extraction not implemented yet.'),
        ]),
      ),
    );
  }

  LineChartData sampleChartData() {
    List<FlSpot> spots = [];
    for (int i = 0; i < prices.length; i++) spots.add(FlSpot(i.toDouble(), prices[i]));
    List<LineChartBarData> lines = [
      LineChartBarData(spots: spots, isCurved: false, color: Colors.black, dotData: FlDotData(show: false), barWidth: 1),
      if (ma13.isNotEmpty) LineChartBarData(spots: makeSpots(ma13), color: Colors.orange, dotData: FlDotData(show: false), width: 2),
      if (ma50.isNotEmpty) LineChartBarData(spots: makeSpots(ma50), color: Colors.blue, dotData: FlDotData(show: false), width: 2),
      if (ma200.isNotEmpty) LineChartBarData(spots: makeSpots(ma200), color: Colors.green, dotData: FlDotData(show: false), width: 2),
    ];
    return LineChartData(
      lineBarsData: lines,
      titlesData: FlTitlesData(show: false),
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
    );
  }

  List<FlSpot> makeSpots(List<double> arr) {
    List<FlSpot> s = [];
    for (int i = 0; i < arr.length; i++) {
      if (arr[i].isFinite) s.add(FlSpot(i.toDouble(), arr[i]));
    }
    return s;
  }
}
