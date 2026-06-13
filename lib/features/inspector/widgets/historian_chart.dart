import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:modbus_studio/src/rust/api/historian.dart';

class HistorianChart extends HookWidget {
  final String ipAddress;
  final int address;
  
  const HistorianChart({super.key, required this.ipAddress, required this.address});

  @override
  Widget build(BuildContext context) {
    final dataPoints = useState<List<HistorianPoint>>([]);
    final isLoading = useState<bool>(true);

    useEffect(() {
      bool isMounted = true;
      Timer? timer;

      Future<void> fetchData() async {
        try {
          final data = await getHistoricalData(dbPath: "historian.db", ip: ipAddress, address: address, limit: 50);
          if (isMounted) {
            dataPoints.value = data;
            isLoading.value = false;
          }
        } catch (e) {
          debugPrint("Failed to load historical data: $e");
        }
      }

      fetchData();
      timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());

      return () {
        isMounted = false;
        timer?.cancel();
      };
    }, [ipAddress, address]);

    if (isLoading.value) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (dataPoints.value.isEmpty) {
      return const Center(child: Text("No historical data available", style: TextStyle(color: CupertinoColors.systemGrey)));
    }

    // Determine min/max X for the chart domain
    final minX = dataPoints.value.first.timestampMs.toDouble();
    final maxX = dataPoints.value.last.timestampMs.toDouble();

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.5),
        border: Border.all(color: const Color(0xFF2C2C2E).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.waveform_path_ecg, color: CupertinoColors.systemTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                "Register $address History", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints.value.map((p) {
                      return FlSpot(p.timestampMs.toDouble(), p.value.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: CupertinoColors.systemTeal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: CupertinoColors.systemTeal.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
